// lib/friend_detail_page.dart (공감 시 푸시 알림 추가)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'comment_page.dart';
import 'notification_service.dart'; // ✅ [추가] 푸시 알림 서비스 임포트

class FriendDetailPage extends StatelessWidget {
  final String friendUid;
  final String friendNickname;

  const FriendDetailPage({
    super.key,
    required this.friendUid,
    required this.friendNickname,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$friendNickname 님의 감정 피드'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(friendUid)
            .collection('diaries')
            .where('isPublic', isEqualTo: true)
            .orderBy(FieldPath.documentId, descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("$friendNickname 님이 공개한 감정이 없습니다."));
          }

          final publicDiaries = snapshot.data!.docs;

          return ListView.builder(
            itemCount: publicDiaries.length,
            itemBuilder: (context, index) {
              final doc = publicDiaries[index];
              final data = doc.data() as Map<String, dynamic>;
              final dateKey = doc.id;
              final emotion = data['emotion'] as String? ?? '감정 없음';
              final summary = data['summary'] as String? ?? '오늘의 기록';

              return _DiaryCard(
                friendUid: friendUid,
                diaryDateKey: dateKey,
                emotion: emotion,
                summary: summary,
                friendNickname: friendNickname,
              );
            },
          );
        },
      ),
    );
  }
}

class _DiaryCard extends StatefulWidget {
  final String friendUid;
  final String diaryDateKey;
  final String emotion;
  final String summary;
  final String friendNickname;

  const _DiaryCard({
    required this.friendUid,
    required this.diaryDateKey,
    required this.emotion,
    required this.summary,
    required this.friendNickname,
  });

  @override
  State<_DiaryCard> createState() => _DiaryCardState();
}

class _DiaryCardState extends State<_DiaryCard> {
  final _firestore = FirebaseFirestore.instance;
  final _myUid = FirebaseAuth.instance.currentUser?.uid;
  String _myNickname = '...';

  @override
  void initState() {
    super.initState();
    _loadMyNickname(); // 닉네임 로드
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

  String _emoji(String? e) {
    const map = {"기쁨": "😁", "슬픔": "😢", "화남": "😡", "평온": "😌", "사랑": "😍"};
    return map[e] ?? "✨";
  }

  // ▼▼▼▼▼ [수정됨] 공감 시 푸시 알림 발송 ▼▼▼▼▼
  Future<void> _toggleLike() async {
    if (_myUid == null) return;
    if (_myNickname == '...') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('잠시 후 다시 시도해주세요.'), duration: Duration(seconds: 1)),
      );
      return;
    }

    final interactionRef = _firestore.collection('friend_interactions').doc('${widget.friendUid}_${widget.diaryDateKey}');
    final notificationRef = _firestore
        .collection('users')
        .doc(widget.friendUid) // ⬅️ 일기 주인 UID
        .collection('notifications')
        .doc();

    // 공감 추가 여부를 저장할 변수
    bool isLiked = false;

    await _firestore.runTransaction((transaction) async {
      final docSnapshot = await transaction.get(interactionRef);

      int currentLikes = 0;
      List<String> currentLikers = [];

      if (docSnapshot.exists) {
        currentLikes = (docSnapshot.data()?['likes'] as int?) ?? 0;
        currentLikers = (docSnapshot.data()?['likers'] as List<dynamic>?)?.cast<String>() ?? [];
      }

      if (currentLikers.contains(_myUid)) {
        // --- 공감 취소 ---
        currentLikers.remove(_myUid);
        currentLikes = (currentLikes - 1).clamp(0, 9999);
        isLiked = false; // 공감 취소
      } else {
        // --- 공감 추가 ---
        currentLikers.add(_myUid!);
        currentLikes += 1;
        isLiked = true; // 공감 추가

        // (작업 1) 일기 주인에게 '인앱 알림' 문서 생성
        transaction.set(notificationRef, {
          'type': 'like',
          'fromUid': _myUid,
          'fromNickname': _myNickname,
          'diaryDateKey': widget.diaryDateKey,
          'summary': widget.summary,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      // (작업 2) 상호작용 문서(부모) 업데이트
      transaction.set(interactionRef, {
        'ownerUid': widget.friendUid,
        'diaryDateKey': widget.diaryDateKey,
        'likes': currentLikes,
        'likers': currentLikers,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    // ▼▼▼ [신규] 트랜잭션 성공 후, 공감이 추가된 경우에만 푸시 알림 발송 ▼▼▼
    if (isLiked) {
      try {
        await NotificationService().showLikeNotification(
          widget.friendUid, // ⬅️ 알림 받을 사람 (일기 주인)
          _myNickname,      // ⬅️ 알림 보낸 사람 (나)
          widget.summary,   // ⬅️ 일기 요약
        );
      } catch (e) {
        print("❌ 공감 푸시 알림 발송 실패: $e");
      }
    }
    // ▲▲▲ [신규] 푸시 알림 발송 ▲▲▲
  }
  // ▲▲▲▲▲ [수정됨] 공감 시 푸시 알림 발송 ▲▲▲▲▲


  void _navigateToComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentPage(
          diaryOwnerUid: widget.friendUid,
          diaryDateKey: widget.diaryDateKey,
          friendNickname: widget.friendNickname,
          diarySummary: widget.summary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime date = () {
      try {
        return DateFormat('yyyy-MM-dd').parse(widget.diaryDateKey);
      } catch (e) {
        print('날짜 파싱 오류: $e');
        return DateTime.now();
      }
    }();

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('friend_interactions')
          .doc('${widget.friendUid}_${widget.diaryDateKey}')
          .snapshots(),
      builder: (context, snapshot) {
        bool isLiked = false;
        int likeCount = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          likeCount = (data['likes'] as int?) ?? 0;
          final likers = (data['likers'] as List<dynamic>?)?.cast<String>() ?? [];
          isLiked = likers.contains(_myUid);
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.friendNickname} 님의 ${DateFormat('MM월 dd일').format(date)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(_emoji(widget.emotion), style: const TextStyle(fontSize: 32)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.summary,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$likeCount', style: TextStyle(color: isLiked ? Colors.pink : Colors.grey)),
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.pink : Colors.grey,
                      ),
                      onPressed: _toggleLike,
                    ),
                    IconButton(
                      icon: const Icon(Icons.comment, color: Colors.grey),
                      onPressed: _navigateToComments,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}