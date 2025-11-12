// lib/dm_chat_page.dart (읽음 처리 로직 추가)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class DmChatPage extends StatefulWidget {
  final String peerUid;
  final String peerNickname;

  const DmChatPage({
    super.key,
    required this.peerUid,
    required this.peerNickname,
  });

  @override
  State<DmChatPage> createState() => _DmChatPageState();
}

class _DmChatPageState extends State<DmChatPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String? get _myUid => _auth.currentUser?.uid;
  late final String _chatRoomId;
  late final DocumentReference _chatRoomRef;
  late final CollectionReference _messagesColRef;
  late final types.User _user;
  late final types.User _peer;

  String _myNickname = '...';

  final Uuid _uuid = const Uuid();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _user = types.User(id: _myUid!);
    _peer = types.User(id: widget.peerUid);

    List<String> uids = [_myUid!, widget.peerUid];
    uids.sort();
    _chatRoomId = uids.join('_');

    _chatRoomRef = _firestore.collection('chats').doc(_chatRoomId);
    _messagesColRef = _chatRoomRef.collection('messages');

    _loadMyNickname();

    // ✅ [신규] DM방 진입 시 '읽음' 처리 함수 호출
    _markMessagesAsRead();
  }

  // ✅ [신규] DM방 진입 시 상대방 메시지 '읽음' 처리
  Future<void> _markMessagesAsRead() async {
    if (_myUid == null) return;

    // 1. DM방 문서의 '읽음' 상태 업데이트 (내가 방금 들어왔음을 표시)
    await _chatRoomRef.set({
      'lastReadBy': {
        _myUid!: FieldValue.serverTimestamp() // 내가 마지막으로 읽은 시각
      }
    }, SetOptions(merge: true));

    // 2. 이 DM과 관련된 모든 'DM 알림 기록'을 '읽음' 처리
    // (이렇게 해야 CalendarPage의 친구 아이콘 배지가 사라집니다.)
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_myUid)
          .collection('notifications')
          .where('type', isEqualTo: 'dm')
          .where('fromUid', isEqualTo: widget.peerUid) // ⬅️ 상대방이 보낸 알림만
          .where('read', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in querySnapshot.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
      }
    } catch (e) {
      print("❌ DM 알림 읽음 처리 실패: $e");
    }
  }

  Future<void> _loadMyNickname() async {
    if (_myUid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_myUid).get();
      if (mounted) {
        setState(() {
          _myNickname = doc.data()?['nickname'] ?? '나';
        });
      }
    } catch (e) {
      print("Error loading my nickname: $e");
    }
  }

  /// 텍스트 메시지 전송
  void _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _uuid.v4(),
      text: message.text,
    );
    await _addMessage(textMessage);
  }

  /// 이미지 메시지 전송 (갤러리)
  void _handleImageSelection() async {
    final XFile? imageFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (imageFile != null) {
      final file = File(imageFile.path);
      final bytes = await file.readAsBytes();
      final image = await decodeImageFromList(bytes);

      final String tempMessageId = _uuid.v4();
      final String fileName = file.path.split('/').last;

      final tempMessage = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: tempMessageId,
        name: fileName,
        size: bytes.length,
        uri: imageFile.path,
        width: image.width.toDouble(),
        height: image.height.toDouble(),
        status: types.Status.sending,
      );

      await _addMessage(tempMessage);

      try {
        final ref = _storage.ref('chats/$_chatRoomId/${_user.id}_$tempMessageId.jpg');
        await ref.putData(bytes, SettableMetadata(contentType: "image/jpeg"));
        final downloadUrl = await ref.getDownloadURL();

        final finalMessage = tempMessage.copyWith(
          uri: downloadUrl,
          status: types.Status.sent,
        );

        await _messagesColRef.doc(tempMessageId).update(finalMessage.toJson());

      } catch (e) {
        await _messagesColRef.doc(tempMessageId).update({'status': types.Status.error});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('사진 전송 실패: $e')),
          );
        }
      }
    }
  }

  /// Firestore에 메시지 추가 (공통 함수)
  Future<void> _addMessage(types.Message message) async {
    // 1. messages 하위 컬렉션에 메시지 추가
    await _messagesColRef.doc(message.id).set(message.toJson());

    // 2. chats/{docId} (부모 문서)에 요약 정보 업데이트
    await _updateChatSummary(message);
  }

  /// 채팅방 요약 정보 업데이트 (메시지 보낸 후 호출)
  Future<void> _updateChatSummary(types.Message message) async {
    if (_myNickname == '...') return;

    String lastMessageText = '';
    if (message is types.TextMessage) {
      lastMessageText = message.text;
    } else if (message is types.ImageMessage) {
      lastMessageText = '📷 사진';
    }

    // ✅ [수정] lastReadBy: 내가 보냈으니 내가 마지막으로 읽은 시각 업데이트
    final chatRoomData = {
      'participants': [_myUid, widget.peerUid],
      'participantInfo': {
        _myUid!: {
          'nickname': _myNickname,
        },
        widget.peerUid: {
          'nickname': widget.peerNickname,
        }
      },
      'lastMessage': lastMessageText,
      'lastSenderId': message.author.id,
      'lastTimestamp': FieldValue.serverTimestamp(), // 서버 시간으로 업데이트
      'lastReadBy': {
        _myUid!: FieldValue.serverTimestamp(), // ✅ 내가 보냈으니 내가 읽음
      },
    };

    await _chatRoomRef.set(chatRoomData, SetOptions(merge: true));
  }


  @override
  Widget build(BuildContext context) {
    if (_myUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('1:1 대화 목록')),
        body: const Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerNickname),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _messagesColRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("오류가 발생했습니다."));
          }

          final messages = snapshot.data?.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['createdAt'] is Timestamp) {
              data['createdAt'] = (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
            }
            return types.Message.fromJson(data);
          }).toList() ?? [];

          return Chat(
            messages: messages,
            onSendPressed: _handleSendPressed,
            onAttachmentPressed: _handleImageSelection,
            user: _user,
            showUserAvatars: true,
            avatarBuilder: (author) => _buildAvatar(author),
            theme: const DefaultChatTheme(
              primaryColor: Colors.blue,
              secondaryColor: Color(0xFFEFEFEF),
              receivedMessageBodyTextStyle: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              sentMessageBodyTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            inputOptions: const InputOptions(
              sendButtonVisibilityMode: SendButtonVisibilityMode.always,
            ),
            imageMessageBuilder: (types.ImageMessage imageMessage, {required int messageWidth}) {
              final isLocal = imageMessage.status == types.Status.sending ||
                  imageMessage.status == types.Status.error ||
                  !imageMessage.uri.startsWith('http');

              Widget imageWidget;
              if (isLocal) {
                imageWidget = Image.file(File(imageMessage.uri), fit: BoxFit.cover);
              } else {
                imageWidget = Image.network(imageMessage.uri, fit: BoxFit.cover);
              }

              return Container(
                width: messageWidth.toDouble(),
                height: messageWidth * (imageMessage.height ?? 1.0) / (imageMessage.width ?? 1.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: imageWidget),
                    if (imageMessage.status == types.Status.sending)
                      const CircularProgressIndicator(color: Colors.white),
                    if (imageMessage.status == types.Status.error)
                      const Icon(Icons.error, color: Colors.red, size: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 아바타 위젯 (나 or 상대방)
  Widget _buildAvatar(types.User author) {
    final color = author.id == _user.id ? Colors.blue : Colors.grey;
    final name = author.id == _user.id ? '나' : widget.peerNickname.substring(0, 1);

    return CircleAvatar(
      backgroundColor: color,
      radius: 16,
      child: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}