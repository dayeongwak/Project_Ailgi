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

  @override
  void initState() {
    super.initState();
    // ✅ [핵심] 페이지에 들어오면 즉시 모든 알림을 '읽음'으로 변경
    _markAllAsRead();
  }

  // 1. 모든 알림 '읽음' 처리 함수
  Future<void> _markAllAsRead() async {
    if (_myUid == null) return;

    try {
      // 읽지 않은('read' == false) 알림만 가져오기
      final snapshot = await _firestore
          .collection('users')
          .doc(_myUid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      // 한 번에 업데이트 (Batch)
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
      // print("모든 알림 읽음 처리 완료");
    } catch (e) {
      print("알림 읽음 처리 실패: $e");
    }
  }

  // 2. 개별 알림 삭제 함수 (스와이프)
  Future<void> _deleteNotification(String docId) async {
    if (_myUid == null) return;
    await _firestore
        .collection('users')
        .doc(_myUid)
        .collection('notifications')
        .doc(docId)
        .delete();
  }

  // 3. 전체 알림 삭제 함수 (휴지통 버튼)
  Future<void> _deleteAllNotifications() async {
    if (_myUid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("알림 전체 삭제"),
        content: const Text("모든 알림 기록을 삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("삭제", style: TextStyle(color: Colors.red))),
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
    // 이미 읽음 처리되었겠지만, 안전장치로 한 번 더 확인
    final bool isRead = data['read'] ?? false;
    if (!isRead) {
      docRef.update({'read': true});
    }

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
              // 여기서 read 상태를 확인하지만, initState에서 이미 true로 바꿨으므로
              // 화면에 들어온 직후에는 '읽음(흰색)' 상태로 보일 것입니다.
              final bool isRead = data['read'] ?? false;

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _deleteNotification(doc.id);
                },
                child: _buildNotificationTile(data, isRead, doc.reference),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> data, bool isRead, DocumentReference docRef) {
    final type = data['type'];
    final fromNickname = data['fromNickname'] ?? '알림';

    String titleText = '';
    String subtitleText = data['body'] ?? '';

    // 제목(title)이 있으면 우선 사용 (NotificationService에서 저장한 값)
    if (data['title'] != null && data['title'].toString().isNotEmpty) {
      titleText = data['title'];
    } else if (type == 'like') {
      titleText = '$fromNickname 님이 회원님의 글에 공감했습니다.';
      subtitleText = "'${data['diaryDateKey'] ?? '어느 날'}' 일기: ${data['summary'] ?? ''}";
    } else {
      titleText = '새로운 알림';
    }

    Timestamp? timestamp;
    if (data['timestamp'] is Timestamp) {
      timestamp = data['timestamp'] as Timestamp;
    } else if (data['timestamp'] is int) {
      timestamp = Timestamp.fromMillisecondsSinceEpoch(data['timestamp'] as int);
    }

    IconData iconData = (type == 'system' || type == 'daily_reminder')
        ? Icons.notifications_active
        : Icons.notifications;
    Color iconColor = Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: isRead ? Colors.grey[100] : Colors.blue.shade50, // 읽음: 회색조, 안읽음: 푸른빛
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
          maxLines: 2,
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