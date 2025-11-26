// lib/notification_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationHistoryPage extends StatefulWidget {
  const NotificationHistoryPage({super.key});

  @override
  State<NotificationHistoryPage> createState() => _NotificationHistoryPageState();
}

class _NotificationHistoryPageState extends State<NotificationHistoryPage> {
  final _firestore = FirebaseFirestore.instance;
  final _myUid = FirebaseAuth.instance.currentUser?.uid;

  // 1. 개별 알림 삭제 함수
  Future<void> _deleteNotification(String docId) async {
    if (_myUid == null) return;
    await _firestore
        .collection('users')
        .doc(_myUid)
        .collection('notifications')
        .doc(docId)
        .delete();
  }

  // 2. 전체 알림 삭제 함수
  Future<void> _deleteAllNotifications() async {
    if (_myUid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("알림 전체 삭제"),
        content: const Text("모든 알림 기록을 삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("삭제", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final snapshot = await _firestore
          .collection('users')
          .doc(_myUid)
          .collection('notifications')
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("모든 알림이 삭제되었습니다.")),
        );
      }
    }
  }

  // 알림을 '읽음'으로 처리하는 함수
  Future<void> _markAsRead(DocumentReference docRef) async {
    await docRef.update({'read': true});
  }

  // 모든 알림을 '읽음'으로 처리하는 함수
  Future<void> _markAllAsRead() async {
    if (_myUid == null) return;
    final snapshot = await _firestore
        .collection('users')
        .doc(_myUid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // 타임스탬프 포맷팅
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return DateFormat('MM/dd HH:mm').format(date);
    }
  }

  // 알림 탭 처리 함수
  void _handleNotificationTap(
      BuildContext context, Map<String, dynamic> data, DocumentReference docRef) {

    final bool isRead = data['read'] ?? false;
    if (!isRead) {
      _markAsRead(docRef);
    }

    // 친구 기능이 삭제되었으므로 알림 탭 시 안내 메시지만 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('확인했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_myUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('알림')),
        body: const Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          // 전체 삭제 버튼
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '전체 삭제',
            onPressed: _deleteAllNotifications,
          ),
          // 모두 읽음 버튼
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: '모두 읽음',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(_myUid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('새로운 알림이 없습니다.', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isRead = data['read'] ?? false;

              // ✅ [신규] Dismissible을 사용하여 스와이프 삭제 기능 구현
              return Dismissible(
                key: Key(doc.id), // 각 항목의 고유 키
                direction: DismissDirection.endToStart, // 오른쪽에서 왼쪽으로 스와이프
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _deleteNotification(doc.id); // 스와이프 시 삭제 실행
                },
                child: _buildNotificationTile(data, isRead, doc.reference),
              );
            },
          );
        },
      ),
    );
  }

  // 알림 타일 생성 함수
  Widget _buildNotificationTile(Map<String, dynamic> data, bool isRead, DocumentReference docRef) {
    final type = data['type'];
    final fromNickname = data['fromNickname'] ?? '알림';

    Timestamp? timestamp;
    if (data['timestamp'] is Timestamp) {
      timestamp = data['timestamp'] as Timestamp;
    } else if (data['timestamp'] is int) {
      timestamp = Timestamp.fromMillisecondsSinceEpoch(data['timestamp'] as int);
    }

    IconData iconData;
    Color iconColor;
    String titleText;
    String subtitleText = '';

    if (type == 'like') {
      iconData = Icons.favorite;
      iconColor = Colors.pink;
      titleText = '$fromNickname 님이 회원님의 글에 공감했습니다.';
      subtitleText = "'${data['diaryDateKey'] ?? '어느 날'}' 일기: ${data['summary'] ?? ''}";
    } else if (type == 'comment') {
      iconData = Icons.comment;
      iconColor = Colors.blue;
      titleText = '$fromNickname 님이 회원님의 글에 댓글을 남겼습니다.';
      subtitleText = data['commentText'] ?? '';
    } else if (type == 'friend_request') {
      iconData = Icons.person_add;
      iconColor = Colors.green;
      titleText = '$fromNickname 님이 친구 요청을 보냈습니다.';
      subtitleText = '친구 기능은 현재 지원되지 않습니다.';
    } else if (type == 'dm') {
      iconData = Icons.chat_bubble;
      iconColor = Colors.blueGrey;
      titleText = '$fromNickname 님에게서 메시지가 도착했습니다.';
      subtitleText = data['dmText'] ?? '';
    } else {
      iconData = Icons.notifications;
      iconColor = Colors.grey;
      titleText = '새로운 알림';
      subtitleText = data['body'] ?? '';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: isRead ? Colors.grey[100] : Colors.blue.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(
          titleText,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            color: isRead ? Colors.grey[700] : Colors.black,
          ),
        ),
        subtitle: Text(
          subtitleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _formatTimestamp(timestamp),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        onTap: () => _handleNotificationTap(context, data, docRef),
      ),
    );
  }
}