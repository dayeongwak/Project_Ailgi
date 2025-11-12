// lib/hidden_friends_page.dart (수정 완료된 파일)

import 'package:flutter/material.dart'; // ✅ import 경로 수정 완료
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HiddenFriendsPage extends StatefulWidget {
  const HiddenFriendsPage({super.key});

  @override
  State<HiddenFriendsPage> createState() => _HiddenFriendsPageState();
}

class _HiddenFriendsPageState extends State<HiddenFriendsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? get _uid => _auth.currentUser?.uid;

  // 숨겨진 친구 목록 (UID: 닉NICKNAME)
  Map<String, String> _hiddenFriends = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHiddenFriends();
  }

  // 숨겨진 친구 목록 로드
  Future<void> _loadHiddenFriends() async {
    if (_uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    try {
      final myDoc = await _firestore.collection('users').doc(_uid).get();
      final hiddenUids = (myDoc.data()?['hiddenFriends'] as List<dynamic>?)?.cast<String>() ?? [];

      final friendInfo = <String, String>{};
      if (hiddenUids.isNotEmpty) {
        // 'whereIn' 쿼리는 30개로 제한 (Firestore 최신 기준)
        final friendsSnapshot = await _firestore.collection('users')
            .where(FieldPath.documentId, whereIn: hiddenUids.take(30).toList())
            .get();

        for (var doc in friendsSnapshot.docs) {
          friendInfo[doc.id] = doc.data()['nickname'] ?? '이름 없음';
        }
      }

      if (mounted) {
        setState(() {
          _hiddenFriends = friendInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ 숨겨진 친구 로드 오류: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 숨김 해제 함수
  Future<void> _unhideFriend(String friendUid, String friendNickname) async {
    if (_uid == null) return;

    try {
      // 1. 내 문서의 'hiddenFriends' 배열에서 친구 UID 제거
      // (friend_feed_page의 로직에 따라, 'friends' 배열은 건드리지 않고
      // 'hiddenFriends' 배열에서만 제거하면 됩니다.)
      await _firestore.collection('users').doc(_uid).update({
        'hiddenFriends': FieldValue.arrayRemove([friendUid])
      });

      // 2. UI 즉각 반영
      if (mounted) {
        setState(() {
          _hiddenFriends.remove(friendUid);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$friendNickname 님을 다시 표시합니다. (친구 목록을 새로고침하세요)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('숨김 해제 오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('숨겨진 친구 관리'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hiddenFriends.isEmpty
          ? const Center(
        child: Text('숨겨진 친구가 없습니다.'),
      )
          : ListView.builder(
        itemCount: _hiddenFriends.length,
        itemBuilder: (context, index) {
          final friendUid = _hiddenFriends.keys.elementAt(index);
          final nickname = _hiddenFriends[friendUid]!;

          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(nickname),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.grey.shade200,
              ),
              child: const Text('숨김 해제'),
              onPressed: () => _unhideFriend(friendUid, nickname),
            ),
          );
        },
      ),
    );
  }
}