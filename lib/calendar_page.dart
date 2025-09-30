import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<String, String> _emotions = {};

  /// SharedPreferences에서 감정 불러오기
  Future<void> _loadEmotions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

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
    }
    setState(() {});
  }

  /// 감정 → 이모지 변환
  String? _getEmotionEmoji(String? emotion) {
    switch (emotion) {
      case "기쁨":
        return "😁";
      case "슬픔":
        return "😢";
      case "화남":
        return "😡";
      case "짜증":
        return "😒";
      case "무기력":
        return "🥱";
      case "짜릿":
        return "🤩";
      case "불안":
        return "😨";
      case "평온":
        return "😌";
      case "사랑":
        return "😍";
      case "놀람":
        return "😲";
      case "좌절":
        return "😤";
      case "자신감":
        return "😎";
      case "후회":
        return "😔";
      case "혼란":
        return "🤔";
      case "피곤":
        return "😴";
      case "감사":
        return "🤗";
      case "당황":
        return "😕";
      case "외로움":
        return "😭";
      case "만족":
        return "😇";
      case "스트레스":
        return "🤯";
      default:
        return null;
    }
  }

  void _updateEmotion(DateTime day, String emotion) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    setState(() {
      _emotions[key] = emotion;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadEmotions(); // 앱 시작 시 불러오기
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ailgi Calendar")),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final key = DateFormat('yyyy-MM-dd').format(day);
                final emoji = _getEmotionEmoji(_emotions[key]);
                if (emoji != null) {
                  return Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
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
              ).then((_) => _loadEmotions());
            },
          ),
        ],
      ),
    );
  }
}
