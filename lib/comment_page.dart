// lib/comment_page.dart (수정/삭제 기능 및 UI 추가)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart'; // 푸시 알림 서비스

class CommentPage extends StatefulWidget {
  final String diaryOwnerUid;
  final String diaryDateKey;
  final String friendNickname;
  final String diarySummary;

  const CommentPage({
    super.key,
    required this.diaryOwnerUid,
    required this.diaryDateKey,
    required this.friendNickname,
    required this.diarySummary,
  });

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  final _firestore = FirebaseFirestore.instance;
  final _myUid = FirebaseAuth.instance.currentUser?.uid;
  late final DocumentReference _interactionRef;
  final TextEditingController _commentController = TextEditingController();

  String _myNickname = '...';
  bool _isLoadingNickname = true;

  @override
  void initState() {
    super.initState();
    _interactionRef = _firestore
        .collection('friend_interactions')
        .doc('${widget.diaryOwnerUid}_${widget.diaryDateKey}');

    _loadMyNickname();
  }

  Future<void> _loadMyNickname() async {
    if (_myUid == null) {
      setState(() => _isLoadingNickname = false);
      return;
    }
    try {
      final doc = await _firestore.collection('users').doc(_myUid).get();
      if (mounted) {
        setState(() {
          _myNickname = doc.data()?['nickname'] ?? '나';
          _isLoadingNickname = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingNickname = false);
      }
    }
  }

  // 댓글 전송 (인앱 알림 + 푸시 알림)
  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _myUid == null || _isLoadingNickname) return;

    FocusScope.of(context).unfocus();
    _commentController.clear();

    final commentData = {
      'text': text,
      'commenterUid': _myUid,
      'commenterNickname': _myNickname,
      'timestamp': FieldValue.serverTimestamp(),
    };

    final newCommentRef = _interactionRef.collection('comments').doc();
    final notificationRef = _firestore
        .collection('users')
        .doc(widget.diaryOwnerUid)
        .collection('notifications')
        .doc();

    try {
      // (작업 1) 인앱 알림 및 댓글 수 업데이트 (트랜잭션)
      await _firestore.runTransaction((transaction) async {
        final interactionDoc = await transaction.get(_interactionRef);
        int currentCommentCount = 0;
        if (interactionDoc.exists) {
          currentCommentCount = (interactionDoc.data() as Map<String, dynamic>?)?['commentCount'] ?? 0;
        }

        transaction.set(newCommentRef, commentData);
        transaction.set(_interactionRef, {
          'ownerUid': widget.diaryOwnerUid,
          'diaryDateKey': widget.diaryDateKey,
          'lastUpdate': FieldValue.serverTimestamp(),
          'commentCount': currentCommentCount + 1,
          'lastCommenterNickname': _myNickname,
        }, SetOptions(merge: true));

        transaction.set(notificationRef, {
          'type': 'comment',
          'fromUid': _myUid,
          'fromNickname': _myNickname,
          'diaryDateKey': widget.diaryDateKey,
          'summary': widget.diarySummary,
          'commentText': text,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      });

      // (작업 2) 푸시 알림 발송 (트랜잭션 성공 후)
      await NotificationService().showCommentNotification(
        widget.diaryOwnerUid,
        _myNickname,
        text,
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 작성 실패: $e')),
        );
      }
    }
  }

  // ▼▼▼▼▼ [신규] 수정/삭제 옵션 Bottom Sheet ▼▼▼▼▼
  void _showOptionsBottomSheet(String commentDocId, String currentText) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('댓글 수정'),
              onTap: () {
                Navigator.pop(context); // BottomSheet 닫기
                _showEditCommentDialog(commentDocId, currentText);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('댓글 삭제', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // BottomSheet 닫기
                _showDeleteCommentDialog(commentDocId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('취소'),
              onTap: () => Navigator.pop(context),
            )
          ],
        );
      },
    );
  }
  // ▲▲▲▲▲ [신규] 수정/삭제 옵션 Bottom Sheet ▲▲▲▲▲

  // ▼▼▼▼▼ [신규] 댓글 수정 다이얼로그 ▼▼▼▼▼
  Future<void> _showEditCommentDialog(String commentDocId, String currentText) async {
    final TextEditingController editController = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('댓글 수정'),
          content: TextField(
            controller: editController,
            autofocus: true,
            maxLines: null, // 여러 줄 입력 가능
            decoration: const InputDecoration(
              hintText: '댓글 입력...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final newText = editController.text.trim();
                if (newText.isNotEmpty) {
                  Navigator.pop(context); // 다이얼로그 닫기
                  _editComment(commentDocId, newText); // 수정 로직 실행
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }
  // ▲▲▲▲▲ [신규] 댓글 수정 다이얼로그 ▲▲▲▲▲

  // ▼▼▼▼▼ [신규] 댓글 수정 로직 ▼▼▼▼▼
  Future<void> _editComment(String commentDocId, String newText) async {
    final commentRef = _interactionRef.collection('comments').doc(commentDocId);

    try {
      await commentRef.update({
        'text': newText,
        'lastEdited': FieldValue.serverTimestamp(), // 수정 시간 기록
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글이 수정되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 수정 실패: $e')),
        );
      }
    }
  }
  // ▲▲▲▲▲ [신규] 댓글 수정 로직 ▲▲▲▲▲

  // 댓글 삭제 확인 다이얼로그 (기존 로직 재사용)
  Future<void> _showDeleteCommentDialog(String commentDocId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('댓글 삭제'),
          content: const Text('이 댓글을 정말 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteComment(commentDocId);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 댓글 삭제 로직 (기존 로직 재사용)
  Future<void> _deleteComment(String commentDocId) async {
    final commentRef = _interactionRef.collection('comments').doc(commentDocId);

    try {
      await _firestore.runTransaction((transaction) async {
        final interactionDoc = await transaction.get(_interactionRef);
        int currentCommentCount = 0;
        if (interactionDoc.exists) {
          currentCommentCount = (interactionDoc.data() as Map<String, dynamic>?)?['commentCount'] ?? 0;
        }
        transaction.delete(commentRef);
        transaction.update(_interactionRef, {
          'commentCount': (currentCommentCount - 1).clamp(0, 9999),
          'lastUpdate': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.friendNickname} 님 글의 댓글'),
      ),
      body: Column(
        children: [
          _buildDiaryContext(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _interactionRef
                  .collection('comments')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('아직 댓글이 없습니다. 첫 댓글을 남겨보세요!'));
                }

                final comments = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final doc = comments[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMyComment = data['commenterUid'] == _myUid;

                    // ▼▼▼ [수정] text 데이터 전달 ▼▼▼
                    final currentText = data['text'] ?? '';
                    return _buildCommentTile(data, isMyComment, doc.id, currentText);
                  },
                );
              },
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  // ▼▼▼▼▼ [수정됨] 댓글 타일 (두 가지 트리거 및 '수정됨' 표시) ▼▼▼▼▼
  Widget _buildCommentTile(Map<String, dynamic> data, bool isMyComment, String commentDocId, String currentText) {
    bool isEdited = data.containsKey('lastEdited'); // 수정 여부 확인

    return GestureDetector(
      // 1. 꾹 누르기 (Long Press)
      onLongPress: isMyComment ? () {
        _showOptionsBottomSheet(commentDocId, currentText);
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isMyComment ? Colors.blue.shade50.withOpacity(0.5) : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isMyComment ? Colors.blue.shade100 : Colors.grey.shade300,
              child: Icon(
                isMyComment ? Icons.person : Icons.face,
                size: 18,
                color: isMyComment ? Colors.blue.shade800 : Colors.black54,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        data['commenterNickname'] ?? '이름 없음',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMyComment ? Colors.blue.shade900 : Colors.black
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(data['timestamp']),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      // [신규] '수정됨' 표시
                      if (isEdited)
                        const Text(
                          ' (수정됨)',
                          style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(data['text'] ?? ''),
                ],
              ),
            ),
            // 2. 맨 오른쪽 메뉴 버튼 (Click)
            if (isMyComment)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20.0, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditCommentDialog(commentDocId, currentText);
                  } else if (value == 'delete') {
                    _showDeleteCommentDialog(commentDocId);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('수정'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('삭제', style: TextStyle(color: Colors.red)),
                  ),
                ],
              )
            else
            // 다른 사람 댓글일 경우, UI 정렬을 위해 빈 공간 확보
              const SizedBox(width: 48.0),
          ],
        ),
      ),
    );
  }
  // ▲▲▲▲▲ [수정됨] 댓글 타일 ▲▲▲▲▲

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('MM/dd HH:mm').format(timestamp.toDate());
  }

  Widget _buildDiaryContext() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 0,
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          widget.diarySummary,
          style: const TextStyle(color: Colors.black87, fontStyle: FontStyle.italic),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: '댓글을 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
            onPressed: _isLoadingNickname ? null : _sendComment,
          ),
        ],
      ),
    );
  }
}