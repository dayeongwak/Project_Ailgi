// lib/chat_list_page.dart (DM 안 읽음 표시 안정화)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dm_chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? get _myUid => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (_myUid != null) {
      _markAllDmsAsRead(); // DM 목록 진입 시 DM 알림 기록 삭제
    }
  }

  // DM 목록 진입 시 DM 알림 기록을 '읽음'으로 처리
  Future<void> _markAllDmsAsRead() async {
    if (_myUid == null) return;
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_myUid)
          .collection('notifications')
          .where('type', isEqualTo: 'dm')
          .where('read', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print("❌ DM '읽음' 처리 실패: $e");
    }
  }

  // 타임스탬프 포맷팅
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return '';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToday = DateTime(date.year, date.month, date.day);

    if (dateToday == today) {
      return DateFormat('HH:mm').format(date); // 오늘이면 시간
    } else {
      return DateFormat('MM/dd').format(date); // 오늘이 아니면 날짜
    }
  }

  // ✅ [신규] Timestamp를 안전하게 비교하기 위한 헬퍼
  Timestamp? _getTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value;
    } else if (value is int) {
      return Timestamp.fromMillisecondsSinceEpoch(value);
    }
    return null;
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
        title: const Text('1:1 대화 목록'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chats')
            .where('participants', arrayContains: _myUid)
            .orderBy('lastTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '아직 대화 내역이 없습니다.\n친구 프로필에서 1:1 대화를 시작해보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final chatRooms = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final doc = chatRooms[index];
              final data = doc.data() as Map<String, dynamic>;

              final List<dynamic> participants = data['participants'];
              final String peerUid = participants.firstWhere((uid) => uid != _myUid, orElse: () => '');

              if (peerUid.isEmpty) return const SizedBox.shrink();

              final Map<String, dynamic> participantInfo = data['participantInfo'] ?? {};
              final String peerNickname = participantInfo[peerUid]?['nickname'] ?? '알 수 없음';

              final String lastMessage = data['lastMessage'] ?? '...';
              final String lastSenderId = data['lastSenderId'] ?? '';
              final bool isLastMessageByMe = lastSenderId == _myUid;

              // ✅ [수정] 안전하게 Timestamp를 가져옴
              final Timestamp? myLastReadTime = _getTimestamp(data['lastReadBy']?['$_myUid']);
              final Timestamp? lastSentTime = _getTimestamp(data['lastTimestamp']);

              // ✅ [수정] 안 읽은 메시지 여부 확인 로직
              final bool hasUnread = lastSentTime != null &&
                  !isLastMessageByMe &&
                  (myLastReadTime == null || lastSentTime.compareTo(myLastReadTime) > 0);

              return ListTile(
                leading: CircleAvatar(
                  child: Text(peerNickname.substring(0, 1)),
                ),
                title: Text(
                  peerNickname,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isLastMessageByMe ? '나: $lastMessage' : lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                    color: hasUnread ? Colors.black : Colors.grey,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTimestamp(data['lastTimestamp']),
                      style: TextStyle(
                        color: hasUnread ? Colors.blue.shade600 : Colors.grey,
                        fontSize: 12,
                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 안 읽은 메시지 수 표시 (1개 이상이면 1)
                    if (hasUnread)
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DmChatPage(
                        peerUid: peerUid,
                        peerNickname: peerNickname,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}