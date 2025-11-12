// lib/calendar_page.dart (포춘 쿠키 아이콘 원복 및 크기 통일)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'chat_page.dart';
import 'statistics_page.dart';
import 'favorite_page.dart';
import 'api_key.dart';
import 'settings_page.dart';
import 'friend_feed_page.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_history_page.dart';
import 'search_page.dart';
import 'chat_list_page.dart';

// 설정 키 정의
const String KEY_BACKGROUND_URL = '_app_background_image_url';
const String KEY_THEME_COLOR = '_theme_color_index';

class CalendarPage extends StatefulWidget {
  final ValueChanged<Color>? onThemeChanged;
  const CalendarPage({super.key, this.onThemeChanged});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? get _uid => _auth.currentUser?.uid;

  String _getPrefKey(String suffix) {
    return "${_uid ?? 'GUEST'}$suffix";
  }

  final Map<String, String> _emotions = {};
  final Set<String> _favorites = {};

  String? _todayFortune;
  String? _customBackgroundUrl;

  final ImagePicker _picker = ImagePicker();
  int _selectedColorIndex = 0;
  Color _themeColor = Colors.white;

  final List<Color> pastelColors = [
    Colors.white, const Color(0xFFF8F8F8), const Color(0xFFF0F0F0),
    const Color(0xFFEAEAEA), const Color(0xFFDCDCDC), const Color(0xFFC0C0C0),
    const Color(0xFFA9A9A9), const Color(0xFFFFF5F7), const Color(0xFFFFE8ED),
    const Color(0xFFFFD3DC), const Color(0xFFFFB7C7), const Color(0xFFFF9BB3),
    const Color(0xFFFF86A5), const Color(0xFFFF6F91), const Color(0xFFFFFEF2),
    const Color(0xFFFFF9DB), const Color(0xFFFFF1B8), const Color(0xFFFFE590),
    const Color(0xFFFFD86E), const Color(0xFFFFCD59), const Color(0xFFFFC240),
    const Color(0xFFF1FFF8), const Color(0xFFE0FFF0), const Color(0xFFC9FBE3),
    const Color(0xFFB0F3D4), const Color(0xFF97E7C2), const Color(0xFF7ED9B0),
    const Color(0xFF64CB9F), const Color(0xFFF0F8FF), const Color(0xFFDDF0FF),
    const Color(0xFFC3E5FF), const Color(0xFFA4D6FF), const Color(0xFF86C7FF),
    const Color(0xFF6AB8FF), const Color(0xFF4CA9FF), const Color(0xFFFBF7FF),
    const Color(0xFFF1E6FF), const Color(0xFFE1CEFF), const Color(0xFFCBAEFF),
    const Color(0xFFB291FF), const Color(0xFFA07EFF), const Color(0xFF8D6BE8),
  ];

  final List<String> defaultFortunes = [
    "오늘은 당신의 마음이 제일 빛나는 날이에요 ✨",
    "작은 일에도 감사함을 느껴보세요 🌿",
    "실패는 넘어짐이 아니라, 더 나은 방향으로 가는 계단이에요 🚶‍♀️",
    "당신의 미소가 누군가의 하루를 밝혀줄 거예요 😊",
    "기적은 조용히 다가와요 🍀",
    "완벽하지 않아도 괜찮아요 💛",
    "행복은 지금 여기에서 느끼는 거예요 🌸",
    "새로운 시작을 위한 완벽한 날입니다. 🚀",
    "예상치 못한 기쁜 소식이 당신을 찾아올 거예요. 📬",
    "가끔은 쉬어가도 괜찮아요. 구름처럼 여유롭게 ☁️",
    "당신의 친절이 누군가에게 큰 힘이 될 거예요. 🤗",
    "가장 어두운 밤도 결국엔 아침을 맞이해요. 🌅",
    "오늘, 당신의 직감을 믿어보세요. 🧭",
    "작은 변화가 큰 행운을 가져다줄 수 있어요. 🦋",
    "오래된 친구에게서 반가운 연락이 올지도 몰라요. 📞",
    "당신의 열정이 새로운 문을 열어줄 거예요. 🔥",
    "걱정은 잠시 내려놓고, 현재를 즐겨보세요. 🎶",
    "스스로를 믿는 것이 가장 큰 힘이에요. 💪",
    "웃음은 최고의 보약! 오늘 하루 많이 웃으세요. 😄",
    "새로운 것을 배울 기회가 생길 거예요. 📚",
    "당신의 노력이 곧 결실을 맺을 거예요. 🏆",
    "따뜻한 차 한 잔이 오늘 하루에 평화를 가져다줄 거예요. 🍵",
    "넘어져도 괜찮아요. 툭툭 털고 일어나면 그만! 툴툴",
    "주변을 둘러보면 당신을 응원하는 사람들이 많아요. 💖",
    "오늘은 평소보다 조금 더 용기를 내보세요. 🦁",
    "뜻밖의 장소에서 새로운 영감을 얻게 될 거예요. 💡",
    "당신의 독창성이 빛을 발하는 날입니다. 🎨",
    "작은 씨앗이 거대한 나무가 되듯, 당신의 가능성은 무한해요. 🌳",
    "고민하던 문제가 의외로 쉽게 풀릴 수 있어요. 🔑",
    "오늘은 스마트폰을 잠시 멀리하고 하늘을 올려다보세요. 🌌",
    "당신이 가는 길이 정답이에요. 자신 있게 나아가세요. 🌟",
    "감사의 마음을 표현하면 더 큰 감사가 돌아와요. 🙏",
    "달콤한 디저트가 당신의 하루를 더 행복하게 만들 거예요. 🍰",
    "오랫동안 바라던 일이 이루어질 조짐이 보여요. 🌠",
    "망설이지 말고 지금 바로 시작하세요! 👟",
    "당신의 따뜻한 말이 누군가의 하루를 구원할 수 있어요. 💬",
    "가벼운 산책이 복잡한 생각을 정리해 줄 거예요. 🏞️",
    "긍정적인 생각이 긍정적인 현실을 만들어요. 😊",
    "오늘은 나 자신에게 작은 선물을 해보는 건 어떨까요? 🎁",
    "잊고 있던 소중한 추억을 떠올리게 될 거예요. 📷",
    "다른 사람의 시선보다 당신의 마음을 중요하게 생각하세요. 💖",
    "조금 돌아가도 괜찮아요. 그 길에서만 볼 수 있는 풍경이 있으니까요. 🗺️",
    "당신의 인내심이 곧 보상받을 거예요. ⏳",
    "좋은 음악이 당신의 기분을 한껏 높여줄 거예요. 🎵",
    "가장 중요한 것은 속도가 아니라 방향이에요. 🧭",
    "세상은 당신이 생각하는 것보다 훨씬 더 당신 편이에요. 🌍",
    "오늘 만나는 사람들에게 밝은 인사를 건네보세요. 👋",
    "작은 성공들이 모여 큰 성공을 이룹니다. 🏅",
    "당신은 스스로 생각하는 것보다 훨씬 더 강한 사람이에요. 💎",
    "가끔은 아무것도 하지 않을 자유를 스스로에게 허락하세요. 🛌",
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadData();
    _loadFortune();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_getPrefKey(KEY_THEME_COLOR)) ?? 0;
    final backgroundUrl = prefs.getString(_getPrefKey(KEY_BACKGROUND_URL));

    setState(() {
      _selectedColorIndex = index;
      _themeColor = pastelColors[index];
      _customBackgroundUrl = backgroundUrl;
    });
  }

  Future<void> _loadData() async {
    if (_uid == null) return;
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('diaries')
          .get();
      _emotions.clear();
      _favorites.clear();
      for (final doc in snapshot.docs) {
        final dateKey = doc.id;
        final data = doc.data();
        final emotion = data['emotion'] as String?;
        final isFavorite = data['isFavorite'] as bool?;
        if (emotion != null) {
          _emotions[dateKey] = emotion;
        }
        if (isFavorite == true) {
          _favorites.add(dateKey);
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      print("❌ Calendar _loadData 오류: $e");
    }
  }

  Future<void> _loadFortune() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey =
        "fortune_${DateFormat('yyyy-MM-dd').format(DateTime.now())}";
    setState(() => _todayFortune = prefs.getString(todayKey));
  }

  Color _getTextColor(int index) {
    int column = index % 7;
    return column <= 3 ? Colors.black : Colors.white;
  }

  Color _darkerColor(Color color, [double amount = .15]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  String? _emoji(String? emotion) {
    const map = {
      "기쁨": "😁", "슬픔": "😢", "화남": "😡", "짜증": "😒", "무기력": "🥱",
      "불안": "😨", "평온": "😌", "사랑": "😍", "놀람": "😲", "감사": "🤗",
      "좌절": "😤", "자신감": "😎", "후회": "😔", "혼란": "🤔", "피곤": "😴",
      "당황": "😕", "외로움": "😭", "만족": "😇", "스트레스": "🤯", "기대": "🤞",
      "뿌듯": "👏", "긴장": "😬", "충격": "😱", "희망": "🌈", "공허": "🥀",
      "질투": "🧐", "열정": "🔥", "차분": "🧘", "즐거움": "🎉", "부끄러움": "😳",
      "실망": "🙁", "설렘": "💓", "존경": "🙏", "분노": "💢", "의욕": "💪",
      "안정": "🛡️", "환희": "🥳", "초조": "😰", "우울": "😞", "용기": "🦸",
      "감동": "🥹", "무서움": "👻", "반가움": "😊", "후련": "😮‍💨", "평화": "🕊️",
      "포기": "😞", "기적": "✨", "낭만": "🌹"
    };
    return map[emotion];
  }

  Future<void> _getTodayFortune() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey =
        "fortune_${DateFormat('yyyy-MM-dd').format(DateTime.now())}";
    final saved = prefs.getString(todayKey);
    if (saved != null) {
      _showFortuneDialog(saved);
      return;
    }
    final emotion =
        _emotions[DateFormat('yyyy-MM-dd').format(DateTime.now())] ?? "평온";

    try {
      final res = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $openAIApiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": "너는 따뜻한 감정 코치야. 포춘 쿠키 문장을 1~2문장으로 만들어줘."},
            {"role": "user", "content": "오늘의 감정은 '$emotion'이야."},
          ],
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final aiFortune = data["choices"]?[0]?["message"]?["content"]?.trim();
        final result = (aiFortune != null && aiFortune.isNotEmpty)
            ? aiFortune
            : (defaultFortunes..shuffle()).first;
        await prefs.setString(todayKey, result);
        if (!mounted) return;
        _showFortuneDialog(result);
      }
    } catch (e) {
      debugPrint("❌ 포춘 생성 오류: $e");
    }
  }

  void _showFortuneDialog(String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("오늘의 포춘 쿠키 🍀"),
        content: Text(text, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("닫기")),
        ],
      ),
    );
  }

  void _openSettingsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SettingsPage(
            onThemeChanged: widget.onThemeChanged!,
          )
      ),
    );
  }

  // ✅ [수정] 개별 고정 FAB 스타일 위젯 (크기 통일)
  Widget _buildFixedFab(IconData icon, VoidCallback onPressed, {String? tag}) {
    final color = _getTextColor(_selectedColorIndex);

    // 크기를 56x56으로 통일합니다.
    const double size = 56.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: size,
      height: size,
      child: FloatingActionButton(
        heroTag: tag,
        // mini 플래그를 false (기본 크기)로 통일
        mini: false,
        backgroundColor: _darkerColor(_themeColor),
        foregroundColor: color,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onPressed: onPressed,
        // 아이콘 크기를 28로 통일
        child: Icon(icon, size: 28),
      ),
    );
  }

  // 친구 아이콘 빌더
  Widget _buildFriendIcon(BuildContext context, Color textColor) {
    final baseIcon = IconButton(
        icon: const Icon(Icons.people_alt_outlined),
        tooltip: '친구 목록',
        color: textColor,
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FriendFeedPage())
        )
    );

    if (_uid == null) return baseIcon;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(_uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .where('type', whereIn: ['dm', 'friend_request'])
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Stack(
          alignment: Alignment.center,
          children: [
            baseIcon,
            if (hasUnread)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: _themeColor, width: 1.5),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // 알림 아이콘 빌더
  Widget _buildNotificationIcon(BuildContext context, Color textColor) {
    final baseIcon = IconButton(
        icon: const Icon(Icons.notifications_outlined),
        tooltip: '알림 내역',
        color: textColor,
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const NotificationHistoryPage())
        )
    );

    if (_uid == null) return baseIcon;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(_uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Stack(
          alignment: Alignment.center,
          children: [
            baseIcon,
            if (hasUnread)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: _themeColor, width: 1.5),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final textColor = _getTextColor(_selectedColorIndex);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _themeColor,
        title: Text("Ailgi Calendar", style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          // 1. 친구 목록
          _buildFriendIcon(context, textColor),

          // 2. 통계
          IconButton(
              icon: const Icon(Icons.bar_chart_outlined),
              tooltip: '월간 통계',
              color: textColor,
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          StatisticsPage(initialMonth: _focusedDay)))),

          // 3. 즐겨찾기
          IconButton(
              icon: const Icon(Icons.star_border),
              tooltip: '즐겨찾기',
              color: textColor,
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FavoritePage()))),

          // 4. 감정 검색
          IconButton(
              icon: const Icon(Icons.search_outlined),
              tooltip: '감정으로 일기 검색',
              color: textColor,
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SearchPage()))),

          // 5. 알림 기록
          _buildNotificationIcon(context, textColor),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_customBackgroundUrl != null)
            Image.network(_customBackgroundUrl!, fit: BoxFit.cover)
          else
            Container(color: _themeColor),

          if (_customBackgroundUrl != null)
            Container(color: Colors.black.withOpacity(0.25)),

          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle:
              TextStyle(color: textColor, fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
              rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: textColor),
              weekendTextStyle: TextStyle(color: textColor),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final key = DateFormat('yyyy-MM-dd').format(day);
                final e = _emotions[key];
                if (e != null) {
                  return Center(
                      child: Text(_emoji(e)!, style: const TextStyle(fontSize: 26)));
                }
                if (_favorites.contains(key)) {
                  return const Center(
                      child: Text("⭐", style: TextStyle(fontSize: 22)));
                }
                return null;
              },
            ),
            onDaySelected: (selectedDay, focusedDay) async {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    selectedDay: selectedDay,
                    onEmotionAnalyzed: (_) => _loadData(),
                  ),
                ),
              );
              if (result == true) await _loadData();
            },
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. 일기 쓰기 (Icons.edit_calendar_outlined)
          _buildFixedFab(
            Icons.edit_calendar_outlined,
                () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    selectedDay: today,
                    onEmotionAnalyzed: (_) => _loadData(),
                  ),
                ),
              );
              if (result == true) await _loadData();
            },
            tag: "diaryFab",
          ),

          // 2. 오늘의 포춘 쿠키 (Icons.auto_awesome_outlined로 원복)
          _buildFixedFab(
            Icons.auto_awesome_outlined, // ✅ [수정] 다시 반짝이는 별 모양으로 원복
            _getTodayFortune,
            tag: "fortuneFab",
          ),

          // 3. 환경 설정 (Icons.settings_outlined)
          _buildFixedFab(
            Icons.settings_outlined,
            _openSettingsPage,
            tag: "settingsFab",
          ),
        ],
      ),
    );
  }
}