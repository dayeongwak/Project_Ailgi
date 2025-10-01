import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_page.dart';
import 'favorite_page.dart';
import 'statistics_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<String, String> _emotions = {};
  final Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// ✅ 감정 + 즐겨찾기 불러오기
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    _emotions.clear();
    _favorites.clear();

    for (final key in keys) {
      if (key.startsWith("chat_")) {
        final raw = prefs.getString(key);
        if (raw != null) {
          final data = jsonDecode(raw);
          if (data["emotion"] != null) {
            final dateKey = key.replaceFirst("chat_", "");
            _emotions[dateKey] = data["emotion"];
          }
        }
      }
      if (key.startsWith("favorite_")) {
        final dateKey = key.replaceFirst("favorite_", "");
        if (prefs.getBool(key) == true) {
          _favorites.add(dateKey);
        }
      }
    }
    setState(() {});
  }

  /// ✅ 감정 → 이모지 (50개 지원)
  String? _getEmotionEmoji(String? emotion) {
    switch (emotion) {
      case "기쁨": return "😁";
      case "슬픔": return "😢";
      case "화남": return "😡";
      case "짜증": return "😒";
      case "무기력": return "🥱";
      case "짜릿": return "🤩";
      case "불안": return "😨";
      case "평온": return "😌";
      case "사랑": return "😍";
      case "놀람": return "😲";
      case "좌절": return "😤";
      case "자신감": return "😎";
      case "후회": return "😔";
      case "혼란": return "🤔";
      case "피곤": return "😴";
      case "감사": return "🤗";
      case "당황": return "😕";
      case "외로움": return "😭";
      case "만족": return "😇";
      case "스트레스": return "🤯";
      case "기대": return "🤞";
      case "뿌듯": return "👏";
      case "긴장": return "😬";
      case "충격": return "😱";
      case "희망": return "🌈";
      case "공허": return "🥀";
      case "질투": return "🧐";
      case "열정": return "🔥";
      case "차분": return "🧘";
      case "즐거움": return "🎉";
      case "부끄러움": return "😳";
      case "실망": return "🙁";
      case "설렘": return "💓";
      case "존경": return "🙏";
      case "분노": return "💢";
      case "의욕": return "💪";
      case "안정": return "🛡️";
      case "환희": return "🥳";
      case "동경": return "🌠";
      case "초조": return "😰";
      case "허무": return "😶";
      case "만족감": return "😌";
      case "분주": return "🏃";
      case "열망": return "🔥";
      case "차가움": return "🥶";
      case "경악": return "🤯";
      case "우울": return "😞";
      case "피로": return "🥱";
      case "존중": return "🤝";
      case "열광": return "⚡";
      default: return null;
    }
  }

  /// ✅ 감정 업데이트 (즉시 반영)
  void _updateEmotion(DateTime day, String? emotion) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    setState(() {
      if (emotion == null || emotion.isEmpty) {
        _emotions.remove(key);
      } else {
        _emotions[key] = emotion;
      }
    });
  }

  /// ✅ 즐겨찾기 토글
  Future<void> _toggleFavorite(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = DateFormat('yyyy-MM-dd').format(day);

    setState(() {
      if (_favorites.contains(key)) {
        _favorites.remove(key);
        prefs.remove("favorite_$key");
      } else {
        _favorites.add(key);
        prefs.setBool("favorite_$key", true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateFormat('yyyy-MM').format(_focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ailgi Calendar"),
        actions: [
          // 📊 통계 페이지
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StatisticsPage(initialMonth: _focusedDay),
                ),
              );
            },
          ),
          // ⭐ 즐겨찾기 페이지
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritePage()),
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final key = DateFormat('yyyy-MM-dd').format(day);
                final emoji = _getEmotionEmoji(_emotions[key]);

                if (emoji != null) {
                  return Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 26), // ✅ 크게 표시
                    ),
                  );
                }

                if (_favorites.contains(key)) {
                  return const Center(
                    child: Text("⭐", style: TextStyle(fontSize: 22)),
                  );
                }

                return null;
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    selectedDay: selectedDay,
                    onEmotionAnalyzed: (emotion) {
                      _updateEmotion(selectedDay, emotion);
                    },
                  ),
                ),
              ).then((_) => _loadData());
            },
          ),

          // ✅ 월별 통계 바로가기 버튼
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.analytics),
              label: Text("$currentMonth 통계 보기"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StatisticsPage(initialMonth: _focusedDay),
                  ),
                );
              },
            ),
          ),

          // ⭐ 선택한 날짜 즐겨찾기 버튼
          if (_selectedDay != null)
            IconButton(
              icon: Icon(
                _favorites.contains(DateFormat('yyyy-MM-dd').format(_selectedDay!))
                    ? Icons.star
                    : Icons.star_border,
              ),
              onPressed: () => _toggleFavorite(_selectedDay!),
            ),
        ],
      ),
    );
  }
}
