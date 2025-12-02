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

  Future<void> _deleteNotification(String docId) async {
    if (_myUid == null) return;
    await _firestore.collection('users').doc(_myUid).collection('notifications').doc(docId).delete();
  }

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
      final snapshot = await _firestore.collection('users').doc(_myUid).collection('notifications').get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) batch.delete(doc.reference);
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("모든 알림이 삭제되었습니다.")));
    }
  }

  Future<void> _markAsRead(DocumentReference docRef) async {
    await docRef.update({'read': true});
  }

  Future<void> _markAllAsRead() async {
    if (_myUid == null) return;
    final snapshot = await _firestore.collection('users').doc(_myUid).collection('notifications').where('read', isEqualTo: false).get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) batch.update(doc.reference, {'read': true});
    await batch.commit();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 60) return '${difference.inMinutes}분 전';
    if (difference.inHours < 24) return '${difference.inHours}시간 전';
    return DateFormat('MM/dd HH:mm').format(date);
  }

  void _handleNotificationTap(BuildContext context, Map<String, dynamic> data, DocumentReference docRef) {
    final bool isRead = data['read'] ?? false;
    if (!isRead) _markAsRead(docRef);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('확인했습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_myUid == null) {
      return Scaffold(appBar: AppBar(title: const Text('알림')), body: const Center(child: Text('로그인이 필요합니다.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep), tooltip: '전체 삭제', onPressed: _deleteAllNotifications),
          IconButton(icon: const Icon(Icons.done_all), tooltip: '모두 읽음', onPressed: _markAllAsRead),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').doc(_myUid).collection('notifications').orderBy('timestamp', descending: true).limit(50).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final notifications = snapshot.data?.docs ?? [];
          if (notifications.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.notifications_off, size: 60, color: Colors.grey[400]), const SizedBox(height: 16), Text('새로운 알림이 없습니다.', style: TextStyle(color: Colors.grey[600]))]));
          }
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (_) => _deleteNotification(doc.id),
                child: _buildNotificationTile(data, data['read'] ?? false, doc.reference),
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

    // ✅ [수정됨] 저장된 제목(title)이 있으면 우선 사용
    if (data['title'] != null && data['title'].toString().isNotEmpty) {
      titleText = data['title'];
    } else if (type == 'like') {
      titleText = '$fromNickname 님이 회원님의 글에 공감했습니다.';
      subtitleText = "'${data['diaryDateKey'] ?? '어느 날'}' 일기: ${data['summary'] ?? ''}";
    } else {
      titleText = '새로운 알림';
    }

    Timestamp? timestamp;
    if (data['timestamp'] is Timestamp) timestamp = data['timestamp'] as Timestamp;
    else if (data['timestamp'] is int) timestamp = Timestamp.fromMillisecondsSinceEpoch(data['timestamp'] as int);

    IconData iconData = (type == 'system' || type == 'daily_reminder') ? Icons.notifications_active : Icons.notifications;
    Color iconColor = Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: isRead ? Colors.grey[100] : Colors.blue.shade50,
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.white, child: Icon(iconData, color: iconColor)),
        title: Text(titleText, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, color: isRead ? Colors.grey[700] : Colors.black)),
        subtitle: Text(subtitleText, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(_formatTimestamp(timestamp), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        onTap: () => _handleNotificationTap(context, data, docRef),
      ),
    );
  }
}