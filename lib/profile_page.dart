// lib/profile_page.dart (1:1 DM 버튼 추가)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'friend_detail_page.dart'; // 감정 피드 페이지
import 'dm_chat_page.dart'; // ✅ [추가] 1:1 DM 채팅 페이지

class ProfilePage extends StatelessWidget {
  final String friendUid;

  const ProfilePage({super.key, required this.friendUid});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // 'users' 컬렉션에서 친구의 문서를 실시간으로 구독
        stream: firestore.collection('users').doc(friendUid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('사용자 정보를 불러올 수 없습니다.'));
          }

          // 친구의 프로필 데이터
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String nickname = data['nickname'] ?? '이름 없음';
          final String statusMessage = data['statusMessage'] ?? '상태 메시지가 없습니다.';
          final String profileUrl = data['profileUrl'] ?? '';
          final String username = data['username'] ?? ''; // @아이디
          final String email = data['email'] ?? ''; // 이메일

          // @아이디나 이메일 중 하나를 식별자로 표시
          final String identifier = username.isNotEmpty ? '@$username' : email;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. 프로필 사진
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  child: profileUrl.isEmpty
                      ? const Icon(Icons.person, size: 60, color: Colors.blue)
                      : null,
                ),
                const SizedBox(height: 16),

                // 2. 닉네임
                Text(
                  nickname,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),

                // 3. @아이디 또는 이메일
                Text(
                  identifier,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),

                // 4. 상태 메시지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      statusMessage.isEmpty ? '상태 메시지가 없습니다.' : statusMessage,
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: statusMessage.isEmpty ? FontStyle.italic : FontStyle.normal,
                        color: statusMessage.isEmpty ? Colors.grey.shade700 : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const Spacer(), // 남은 공간 모두 차지

                // ▼▼▼▼▼ [신규] 1:1 비공개 대화 버튼 ▼▼▼▼▼
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text('1:1 비공개 대화'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, // 텍스트/아이콘 색상
                    backgroundColor: Colors.blue, // 버튼 배경색
                    minimumSize: const Size(double.infinity, 50), // 버튼 최대 너비
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DmChatPage(
                          peerUid: friendUid,
                          peerNickname: nickname,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12), // 버튼 사이 간격
                // ▲▲▲▲▲ [신규] 1:1 비공개 대화 버튼 ▲▲▲▲▲

                // 5. 감정 피드 보기 버튼
                ElevatedButton.icon(
                  icon: const Icon(Icons.feed),
                  label: Text('$nickname 님의 감정 피드 보기'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black, // 텍스트/아이콘 색상
                    backgroundColor: Colors.grey.shade300, // 버튼 배경색
                    minimumSize: const Size(double.infinity, 50), // 버튼 최대 너비
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FriendDetailPage(
                          friendUid: friendUid,
                          friendNickname: nickname,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}