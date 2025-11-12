import 'package:flutter/material.dart';

// 1. 도움말 항목을 위한 데이터 모델
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
  // 2. 모든 도움말 항목 정의 (✅ 최신 기능 반영 및 순서/설명 수정)
  final List<HelpTopic> _allTopics = [
    HelpTopic(
        title: "AI 채팅 및 일기 (사진 첨부)",
        description: "AI와 대화하며 일기를 작성합니다. '+' 버튼으로 갤러리 사진을 첨부할 수 있습니다. '일기 마무리'를 누르면 AI가 대화 내용을 바탕으로 감정과 요약을 생성합니다.",
        iconWidget: const Icon(Icons.auto_awesome, size: 40, color: Colors.purple),
        keywords: ['ai', '채팅', '일기', 'chat', '감정', '요약', '사진', '첨부', '이미지', 'openai', '포춘']
    ),
    HelpTopic(
        title: "캘린더 (일기 모아보기)",
        description: "메인 캘린더 화면에서 날짜별로 작성한 일기의 감정 이모지를 한눈에 볼 수 있습니다. 날짜를 선택하면 해당 날짜의 일기(채팅)로 바로 이동합니다.",
        iconWidget: const Icon(Icons.calendar_month, size: 40, color: Colors.green),
        keywords: ['캘린더', '달력', '모아보기', 'calendar', 'emotion', '감정']
    ),
    HelpTopic(
        title: "일기 통합 검색",
        description: "메인 화면 상단의 돋보기(🔍) 아이콘을 눌러 '일기 통합 검색'을 할 수 있습니다. 특정 '감정'을 선택하거나, '키워드'를 입력하여 원하는 일기 내용을 빠르게 찾을 수 있습니다.",
        iconWidget: const Icon(Icons.search, size: 40, color: Colors.deepOrange),
        keywords: ['검색', '찾기', '키워드', '감정', 'search', 'find', 'keyword']
    ),
    HelpTopic(
        title: "즐겨찾기",
        description: "일기 채팅 페이지에서 ⭐ 아이콘을 눌러 중요한 일기를 즐겨찾기에 추가할 수 있습니다. 메인 화면의 '즐겨찾기' 탭에서 모아 볼 수 있습니다.",
        iconWidget: const Icon(Icons.star, size: 40, color: Colors.amber),
        keywords: ['즐겨찾기', 'favorite', '별', '중요한']
    ),
    HelpTopic(
        title: "통계 및 감정 트렌드",
        description: "'통계' 탭에서 월별 감정 통계를 확인하고, 내가 가장 많이 사용한 감정 단어를 볼 수 있습니다. (emotion_trend_page, statistics_page)",
        iconWidget: const Icon(Icons.bar_chart, size: 40, color: Colors.lightGreen),
        keywords: ['통계', '차트', '감정분석', '기록', 'summary', 'statistics', '트렌드']
    ),
    HelpTopic(
        title: "감정 피드 (공유, 공감, 댓글)",
        description: "채팅방에서 '감정 공개' 아이콘(💡)을 켜면, 친구가 내 감정과 요약을 '친구 피드'에서 볼 수 있습니다. 친구의 글에 공감(❤️)하거나 댓글을 남길 수 있습니다. (내 댓글은 길게 누르거나 메뉴로 수정/삭제 가능)",
        iconWidget: const Icon(Icons.people_alt, size: 40, color: Colors.blue),
        keywords: ['공유', '공감', '댓글', '피드', '좋아요', '수정', '삭제', 'share', 'like', 'comment']
    ),
    HelpTopic(
        title: "친구 추가 및 검색",
        description: "'친구 관리' 탭에서 이메일, 닉네임, 또는 @아이디로 친구를 검색하고 요청을 보낼 수 있습니다. 받은 요청을 수락하거나 거절할 수 있습니다.",
        iconWidget: const Icon(Icons.person_add_alt_1, size: 40, color: Colors.teal),
        keywords: ['친구', '검색', '추가', '요청', '수락', '거절', 'friend', 'search', 'add', 'email', '이메일']
    ),
    HelpTopic(
        title: "1:1 비공개 대화 (DM)",
        description: "친구의 프로필 페이지에서 '1:1 비공개 대화'를 시작할 수 있습니다. 모든 대화 목록은 메인 화면 상단의 채팅(💬) 아이콘을 눌러 확인할 수 있습니다.",
        iconWidget: const Icon(Icons.chat_bubble, size: 40, color: Colors.cyan),
        keywords: ['dm', '디엠', '채팅', '1:1', '비공개', 'chat', 'message']
    ),
    HelpTopic(
        title: "친구 관리 (숨기기/삭제)",
        description: "친구 목록의 '...' 메뉴를 눌러 친구를 숨기거나 삭제할 수 있습니다. 숨긴 친구는 '환경설정 > 숨겨진 친구 관리'에서 다시 보이게 할 수 있습니다.",
        iconWidget: const Icon(Icons.person_off, size: 40, color: Colors.grey),
        keywords: ['숨기기', '삭제', '관리', '차단', 'hide', 'delete', 'manage']
    ),
    HelpTopic(
        title: "프로필 및 상태 메시지",
        description: "환경설정 > 프로필 수정에서 닉네임과 '상태 메시지'를 설정할 수 있습니다. 이 정보는 친구들이 내 프로필 페이지에서 볼 수 있습니다.",
        iconWidget: const Icon(Icons.account_circle, size: 40, color: Colors.indigo),
        keywords: ['프로필', '상태메시지', '닉네임', 'profile', 'status']
    ),
    HelpTopic(
        title: "알림 (푸시 및 기록)",
        description: "메인 화면 상단의 종(🔔) 아이콘을 눌러 친구 요청, 공감, 댓글의 '알림 기록'을 모두 볼 수 있습니다. '환경설정 > 알림'에서는 앱이 꺼져있을 때 받는 '푸시 알림'을 켜거나 끌 수 있습니다.",
        iconWidget: const Icon(Icons.notifications_active, size: 40, color: Colors.pink),
        keywords: ['알림', '푸시', '기록', 'fcm', '서버', 'remind', 'notification', 'badge']
    ),
    HelpTopic(
        title: "클라우드 동기화 (Firebase)",
        description: "모든 일기, 닉네임, 친구 목록은 Firebase에 안전하게 저장됩니다. Google이나 아이디로 로그인하면 다른 기기에서도 데이터를 볼 수 있습니다.",
        iconWidget: const Icon(Icons.cloud_upload, size: 40, color: Colors.blueAccent),
        keywords: ['firebase', '클라우드', '동기화', '백업', '로그인', 'cloud']
    ),
    HelpTopic(
        title: "앱 잠금 (PIN)",
        description: "환경설정 > 보안에서 앱 비밀번호 잠금을 켤 수 있습니다. 앱을 켤 때마다 4/6자리 PIN을 입력하여 일기를 보호합니다.",
        iconWidget: const Icon(Icons.lock, size: 40, color: Colors.redAccent),
        keywords: ['잠금', '보안', '비밀번호', 'pin', 'lock', 'security']
    ),
    HelpTopic(
        title: "앱 꾸미기 (테마, 폰트, 배경)",
        description: "환경설정 > 앱 꾸미기에서 테마 색상, 앱 폰트, 갤러리의 사진을 배경화면으로 설정할 수 있습니다.",
        iconWidget: const Icon(Icons.palette, size: 40, color: Colors.orange),
        keywords: ['테마', '폰트', '배경', '꾸미기', '커스텀', 'theme', 'font', 'background']
    ),
    HelpTopic(
        title: "계정 관리 (로그아웃, 탈퇴)",
        description: "'환경설정 > 계정 관리'에서 로그아웃을 하거나, 모든 데이터를 삭제하고 회원에서 탈퇴할 수 있습니다.",
        iconWidget: const Icon(Icons.manage_accounts, size: 40, color: Colors.blueGrey),
        keywords: ['계정', '로그아웃', '회원탈퇴', '탈퇴', 'account', 'logout', 'delete']
    ),
  ];

  List<HelpTopic> _displayedTopics = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ✅ 초기화 시 모든 항목을 _allTopics으로 설정
    _displayedTopics = _allTopics;
    _searchController.addListener(_filterHelpTopics);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterHelpTopics);
    _searchController.dispose();
    super.dispose();
  }

  // 3. 검색 필터링 로직 (키워드 포함)
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

  // 4. UI 빌드
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('도움말'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '기능 검색 (예: DM, 사진, 푸시)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
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
                  child: ListTile(
                    leading: topic.iconWidget,
                    title: Text(topic.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(topic.description),
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