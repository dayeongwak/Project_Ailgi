// lib/friend_feed_page.dart (프로필 페이지로 이동하도록 수정)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'friend_detail_page.dart';
import 'notification_service.dart';
import 'profile_page.dart'; // ✅ [추가] 새로 만들 프로필 페이지 임포트

class FriendFeedPage extends StatefulWidget {
  const FriendFeedPage({super.key});

  @override
  State<FriendFeedPage> createState() => _FriendFeedPageState();
}

class _FriendFeedPageState extends State<FriendFeedPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? get _uid => _auth.currentUser?.uid;

  Map<String, String> _friends = {};
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, String>> _receivedRequests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _myNickname = '...'; // 내 닉네임 (알림용)

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (_uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    await Future.wait([
      _loadFriends(),
      _loadReceivedRequests(),
      _loadMyNickname(), // 내 닉네임 로드
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  // 내 닉네임 로드 함수
  Future<void> _loadMyNickname() async {
    if (_uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_uid).get();
      if (mounted) {
        setState(() {
          _myNickname = doc.data()?['nickname'] ?? '나';
        });
      }
    } catch (e) {
      print("Error loading my nickname: $e");
    }
  }

  // 확정된 친구 목록 로드 (숨긴 친구 제외)
  Future<void> _loadFriends() async {
    if (_uid == null) return;
    try {
      final myDoc = await _firestore.collection('users').doc(_uid).get();
      final myData = myDoc.data();
      final friendUids = (myData?['friends'] as List<dynamic>?)?.cast<String>() ?? [];
      final hiddenUids = (myData?['hiddenFriends'] as List<dynamic>?)?.cast<String>() ?? [];

      final friendInfo = <String, String>{};

      final visibleFriendUids = friendUids.where((uid) => !hiddenUids.contains(uid)).toList();

      if (visibleFriendUids.isNotEmpty) {
        final friendsSnapshot = await _firestore.collection('users')
            .where(FieldPath.documentId, whereIn: visibleFriendUids.take(30).toList())
            .get();

        for (var doc in friendsSnapshot.docs) {
          final data = doc.data();
          friendInfo[doc.id] = data['nickname'] ?? '이름 없음';
        }
      }

      if (mounted) {
        setState(() {
          _friends = friendInfo;
        });
      }
    } catch (e) {
      print("❌ 친구 목록 로드 오류: $e");
    }
  }

  // 받은 친구 요청 목록 로드
  Future<void> _loadReceivedRequests() async {
    if (_uid == null) return;
    try {
      final myDoc = await _firestore.collection('users').doc(_uid).get();
      final requestUids = (myDoc.data()?['friendRequestsReceived'] as List<dynamic>?)?.cast<String>() ?? [];

      final requestInfo = <String, String>{};
      if (requestUids.isNotEmpty) {
        final sendersSnapshot = await _firestore.collection('users')
            .where(FieldPath.documentId, whereIn: requestUids.take(30).toList())
            .get();

        for (var doc in sendersSnapshot.docs) {
          final data = doc.data();
          requestInfo[doc.id] = data['nickname'] ?? '이름 없음';
        }
      }

      if (mounted) {
        setState(() {
          _receivedRequests = requestInfo.entries.map((e) => {'uid': e.key, 'nickname': e.value}).toList();
        });
      }
    } catch (e) {
      print("❌ 받은 요청 로드 오류: $e");
    }
  }

  // 실시간 검색어 변경 감지
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
    if (_searchQuery.length > 1) {
      _searchFriends();
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  // 닉네임, @아이디, 또는 이메일로 친구 검색
  Future<void> _searchFriends() async {
    if (_uid == null || _searchQuery.isEmpty) return;

    List<Map<String, dynamic>> results = [];
    QuerySnapshot snapshot;

    try {
      if (_searchQuery.startsWith('@')) {
        final usernameQuery = _searchQuery.substring(1);
        snapshot = await _firestore.collection('users')
            .where('username', isEqualTo: usernameQuery)
            .limit(1).get();

      } else if (_searchQuery.contains('@')) {
        snapshot = await _firestore.collection('users')
            .where('email', isEqualTo: _searchQuery)
            .limit(1).get();

      } else {
        snapshot = await _firestore.collection('users')
            .where('nickname', isEqualTo: _searchQuery)
            .limit(5).get();
      }

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;

        if (data != null && doc.id != _uid) {
          results.add({
            'uid': doc.id,
            'username': data['username'] ?? '',
            'nickname': data['nickname'] ?? '이름 없음',
            'profileUrl': data['profileUrl'],
            'email': data['email'] ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }

    } catch (e) {
      print("❌ 검색 오류: $e");
      if (mounted) setState(() => _searchResults = []);
    }
  }

  // 친구 요청 보내는 로직 (푸시 알림 포함)
  Future<void> _sendFriendRequestFromSearch(String friendUid, String nickname) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || _myNickname == '...') return;

    try {
      // 1. 상대방 문서에 '내가 보낸 요청' 추가
      await _firestore.collection('users').doc(friendUid).update({
        'friendRequestsReceived': FieldValue.arrayUnion([myUid])
      });

      // 2. 내 문서에 '내가 보낸 요청' 추가
      await _firestore.collection('users').doc(myUid).update({
        'friendRequestsSent': FieldValue.arrayUnion([friendUid])
      });

      // 3. 상대방(friendUid)에게 '인앱 알림' 문서 생성
      final notificationRef = _firestore
          .collection('users')
          .doc(friendUid) // ⬅️ 받는 사람 UID
          .collection('notifications')
          .doc();

      await notificationRef.set({
        'type': 'friend_request',
        'fromUid': myUid,
        'fromNickname': _myNickname,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 4. 상대방(friendUid)에게 '푸시 알림' 발송
      await NotificationService().showFriendRequestNotification(friendUid, _myNickname);

      // 5. UI 업데이트
      if (mounted) {
        setState(() {
          _searchController.clear();
          _searchResults = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nickname 님에게 요청을 보냈습니다.')));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('요청 보내기 오류: $e')));
    }
  }


  // 요청 수락 로직
  Future<void> _acceptRequest(String requesterUid, String nickname) async {
    final myUid = _uid;
    if (myUid == null) return;

    await _firestore.runTransaction((transaction) async {
      final myDocRef = _firestore.collection('users').doc(myUid);
      final requesterDocRef = _firestore.collection('users').doc(requesterUid);

      transaction.update(myDocRef, {
        'friendRequestsReceived': FieldValue.arrayRemove([requesterUid]),
        'friends': FieldValue.arrayUnion([requesterUid]),
      });

      transaction.update(requesterDocRef, {
        'friendRequestsSent': FieldValue.arrayRemove([myUid]),
        'friends': FieldValue.arrayUnion([myUid]),
      });
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nickname 님과 친구가 되었습니다! 🎉')));
      await _loadAllData();
    }
  }

  // 요청 거절 로직
  Future<void> _rejectRequest(String requesterUid, String nickname) async {
    final myUid = _uid;
    if (myUid == null) return;

    await _firestore.runTransaction((transaction) async {
      final myDocRef = _firestore.collection('users').doc(myUid);
      final requesterDocRef = _firestore.collection('users').doc(requesterUid);

      transaction.update(myDocRef, {
        'friendRequestsReceived': FieldValue.arrayRemove([requesterUid]),
      });

      transaction.update(requesterDocRef, {
        'friendRequestsSent': FieldValue.arrayRemove([myUid]),
      });
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nickname 님의 요청을 거절했습니다.')));
      await _loadReceivedRequests();
    }
  }

  // 친구 숨기기 함수
  Future<void> _hideFriend(String friendUid, String friendNickname) async {
    if (_uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$friendNickname 님 숨기기'),
        content: const Text('친구 목록에서 이 친구를 숨깁니다. (나중에 설정에서 해제할 수 있습니다.)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('숨기기')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('users').doc(_uid).update({
        'hiddenFriends': FieldValue.arrayUnion([friendUid])
      });

      if (mounted) {
        setState(() {
          _friends.remove(friendUid);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$friendNickname 님을 목록에서 숨겼습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('숨기기 오류: $e')),
        );
      }
    }
  }

  // 친구 삭제 함수 (상호 삭제)
  Future<void> _deleteFriend(String friendUid, String friendNickname) async {
    if (_uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$friendNickname 님과 친구 끊기'),
        content: const Text('정말로 친구 관계를 끊으시겠습니까? 이 작업은 되돌릴 수 없으며, 상대방의 친구 목록에서도 내가 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final myDocRef = _firestore.collection('users').doc(_uid);
        final friendDocRef = _firestore.collection('users').doc(friendUid);

        transaction.update(myDocRef, {
          'friends': FieldValue.arrayRemove([friendUid])
        });
        transaction.update(friendDocRef, {
          'friends': FieldValue.arrayRemove([_uid])
        });
      });

      if (mounted) {
        setState(() {
          _friends.remove(friendUid);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$friendNickname 님과 친구 관계를 끊었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('친구 삭제 오류: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.isNotEmpty;
    final hasReceivedRequests = _receivedRequests.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 목록 및 검색'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
          if (isSearching)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _searchController.clear(),
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. 검색창
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '이메일, 닉네임, @아이디로 검색',
                hintText: 'ailgi@google.com, ailgi, @ailgi1',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          // 2. 받은 친구 요청 목록
          if (!isSearching && hasReceivedRequests)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('받은 친구 요청', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _receivedRequests.length,
                  itemBuilder: (context, index) {
                    final request = _receivedRequests[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_add)),
                      title: Text(request['nickname']!),
                      subtitle: const Text('친구가 되고 싶어합니다.'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _acceptRequest(request['uid']!, request['nickname']!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _rejectRequest(request['uid']!, request['nickname']!),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
              ],
            ),

          // 3. 실시간 검색 결과 출력
          if (isSearching)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  final isFriend = _friends.containsKey(result['uid']);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: result['profileUrl'] != null
                          ? NetworkImage(result['profileUrl'])
                          : null,
                      child: result['profileUrl'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(result['nickname']),
                    subtitle: Text(result['email'].isNotEmpty ? result['email'] : '@${result['username']}'),
                    trailing: isFriend
                        ? const Chip(label: Text('친구'))
                        : ElevatedButton(
                      onPressed: () => _sendFriendRequestFromSearch(
                          result['uid'], result['nickname']),
                      child: const Text('요청'),
                    ),
                  );
                },
              ),
            ),

          // 4. 기존 친구 목록
          if (!isSearching)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _friends.isEmpty && !hasReceivedRequests
                  ? const Center(child: Text("아직 친구가 없습니다. 닉네임이나 아이디로 검색하여 요청을 보내세요."))
                  : _friends.isEmpty && hasReceivedRequests
                  ? const Center(child: Text("친구 요청을 수락하면 여기에 표시됩니다."))
                  : ListView.builder(
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  final friendUid = _friends.keys.elementAt(index);
                  final nickname = _friends[friendUid]!;

                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(nickname),
                    // ▼▼▼▼▼ [수정됨] onTap 로직 변경 ▼▼▼▼▼
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfilePage(
                            friendUid: friendUid,
                          ),
                        ),
                      );
                    },
                    // ▲▲▲▲▲ [수정됨] onTap 로직 변경 ▲▲▲▲▲
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'hide') {
                          _hideFriend(friendUid, nickname);
                        } else if (value == 'delete') {
                          _deleteFriend(friendUid, nickname);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'hide',
                          child: Text('친구 숨기기'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('친구 삭제', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}