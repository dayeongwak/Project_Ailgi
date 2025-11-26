// lib/help_page.dart

import 'package:flutter/material.dart';

class HelpTopic {
  final String title;
  final String description;
  final Widget iconWidget;
  final List<String> keywords;

  HelpTopic({
    required this.title,
    required this.description,
    required this.iconWidget,
    required this.keywords,
  });
}

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  // ✅ 현재 기능에 딱 맞춘 도움말 항목
  final List<HelpTopic> _allTopics = [
    HelpTopic(
        title: "AI 채팅 및 일기",
        description: "AI 친구와 대화하며 일기를 작성합니다. 갤러리 사진을 첨부하거나 음성(마이크)으로 대화할 수 있습니다. '일기 마무리' 시 감정 분석과 요약이 자동으로 생성됩니다.",
        iconWidget: const Icon(Icons.auto_awesome, size: 40, color: Colors.purple),
        keywords: ['ai', '채팅', '일기', 'chat', '감정', '요약', '사진', '음성', '마이크']
    ),
    HelpTopic(
        title: "캘린더 & 포춘 쿠키",
        description: "메인 캘린더에서 감정 이모지를 날짜별로 확인할 수 있습니다. 날짜를 누르면 일기로 이동하며, 매일 새로운 포춘 쿠키 문구를 열어볼 수 있습니다.",
        iconWidget: const Icon(Icons.calendar_month, size: 40, color: Colors.green),
        keywords: ['캘린더', '달력', '모아보기', 'calendar', 'emotion', '감정', '포춘', '운세']
    ),
    HelpTopic(
        title: "즐겨찾기",
        description: "일기 채팅 페이지 상단의 ⭐ 아이콘을 눌러 소중한 일기를 즐겨찾기에 등록하세요. 메인 화면 상단의 별 아이콘 탭에서 모아 볼 수 있습니다.",
        iconWidget: const Icon(Icons.star, size: 40, color: Colors.amber),
        keywords: ['즐겨찾기', 'favorite', '별', '중요한', '북마크']
    ),
    HelpTopic(
        title: "통계 및 감정 트렌드",
        description: "통계 아이콘을 눌러 월별 감정 분포와 감정 점수 변화 그래프를 확인하여 내 마음의 흐름을 파악할 수 있습니다.",
        iconWidget: const Icon(Icons.bar_chart, size: 40, color: Colors.lightGreen),
        keywords: ['통계', '차트', '감정분석', '기록', 'summary', 'statistics', '트렌드']
    ),
    HelpTopic(
        title: "계정 관리 (로그아웃/탈퇴)",
        description: "환경설정 상단의 '계정' 섹션에서 로그아웃하거나, '회원 탈퇴'를 통해 모든 일기 데이터를 영구적으로 삭제할 수 있습니다.",
        iconWidget: const Icon(Icons.manage_accounts, size: 40, color: Colors.blueGrey),
        keywords: ['계정', '로그아웃', '회원탈퇴', '탈퇴', 'account', 'logout', 'delete', '삭제']
    ),
    HelpTopic(
        title: "프로필 설정",
        description: "환경설정 > 프로필 수정에서 닉네임과 프로필 사진을 자유롭게 변경할 수 있습니다.",
        iconWidget: const Icon(Icons.account_circle, size: 40, color: Colors.indigo),
        keywords: ['프로필', '닉네임', 'profile', '사진', '이미지', '변경']
    ),
    HelpTopic(
        title: "알림 설정",
        description: "환경설정에서 매일 일기 작성을 잊지 않도록 푸시 알림 시간을 설정할 수 있습니다. 지난 알림 내역은 메인 화면의 종(🔔) 아이콘에서 확인합니다.",
        iconWidget: const Icon(Icons.notifications_active, size: 40, color: Colors.pink),
        keywords: ['알림', '푸시', '기록', 'fcm', 'remind', 'notification', '시간']
    ),
    HelpTopic(
        title: "데이터 동기화 (클라우드)",
        description: "작성한 모든 일기와 설정은 클라우드에 안전하게 저장됩니다. 앱을 삭제했다가 다시 설치해도 로그인하면 데이터가 복구됩니다.",
        iconWidget: const Icon(Icons.cloud_upload, size: 40, color: Colors.blueAccent),
        keywords: ['firebase', '클라우드', '동기화', '백업', '로그인', 'cloud', '저장']
    ),
    HelpTopic(
        title: "보안 잠금 (PIN)",
        description: "환경설정 > 보안에서 비밀번호 잠금을 설정하면 앱 실행 시 4~6자리 PIN 입력을 요구하여 사생활을 보호합니다.",
        iconWidget: const Icon(Icons.lock, size: 40, color: Colors.redAccent),
        keywords: ['잠금', '보안', '비밀번호', 'pin', 'lock', 'security', '암호']
    ),
    HelpTopic(
        title: "앱 꾸미기",
        description: "환경설정 > 앱 꾸미기에서 테마 색상(파스텔 톤), 글씨체(폰트), 캘린더 배경 이미지를 자유롭게 변경할 수 있습니다.",
        iconWidget: const Icon(Icons.palette, size: 40, color: Colors.orange),
        keywords: ['테마', '폰트', '배경', '꾸미기', '커스텀', 'theme', 'font', 'background']
    ),
  ];

  List<HelpTopic> _displayedTopics = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _displayedTopics = _allTopics;
    _searchController.addListener(_filterHelpTopics);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterHelpTopics);
    _searchController.dispose();
    super.dispose();
  }

  void _filterHelpTopics() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _displayedTopics = _allTopics);
      return;
    }

    final filtered = _allTopics.where((topic) {
      return topic.title.toLowerCase().contains(query) ||
          topic.description.toLowerCase().contains(query) ||
          topic.keywords.any((key) => key.toLowerCase().contains(query));
    }).toList();

    setState(() => _displayedTopics = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('도움말')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '기능 검색 (예: 알림, 탈퇴, 테마)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                    : null,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _displayedTopics.length,
              itemBuilder: (context, index) {
                final topic = _displayedTopics[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                        child: topic.iconWidget,
                      ),
                      title: Text(topic.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(topic.description, style: TextStyle(color: Colors.grey.shade700, height: 1.3)),
                      ),
                    ),
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