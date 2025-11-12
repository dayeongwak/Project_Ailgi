// lib/emotion_trend_page.dart (Firestore 연동 완료)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
// ❌ import 'package:shared_preferences/shared_preferences.dart'; // 더 이상 사용 안 함

// ✅ 1. Firebase 패키지 임포트
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 테마 로드용

class EmotionTrendPage extends StatefulWidget {
  final DateTime initialMonth;
  const EmotionTrendPage({super.key, required this.initialMonth});

  @override
  State<EmotionTrendPage> createState() => _EmotionTrendPageState();
}

class _EmotionTrendPageState extends State<EmotionTrendPage> {
  Map<String, String> _emotions = {};
  bool _isLoading = true;
  Color _themeColor = Colors.white; // 테마용
  Color _textColor = Colors.black; // 테마용

  // ✅ 2. Firebase 인스턴스
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? get _uid => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadTheme(); // ✅ 테마 로드 추가
    _loadData(); // ✅ Firestore에서 읽도록 수정됨
  }

  /// 🎨 테마 불러오기 (SharedPreferences 유지)
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt("calendar_color_index") ?? 0;

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

    final color = pastelColors[index % pastelColors.length];
    final textColor = color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    setState(() {
      _themeColor = color;
      _textColor = textColor;
    });
  }


  /// ✅ 3. (수정) Firestore에서 감정 데이터 불러오기
  Future<void> _loadData() async {
    if (_uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    final emotions = <String, String>{};

    try {
      // 'users/{uid}/diaries' 컬렉션 전체를 가져옴
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('diaries')
          .get();

      // 가져온 데이터로 _emotions 맵을 채움
      for (final doc in snapshot.docs) {
        final dateKey = doc.id; // "2025-10-28"
        final data = doc.data();
        final emotion = data['emotion'] as String?;

        if (emotion != null) {
          emotions[dateKey] = emotion;
        }
      }

      setState(() {
        _emotions = emotions;
        _isLoading = false;
      });

    } catch (e) {
      print("❌ EmotionTrendPage _loadData 오류: $e");
      setState(() => _isLoading = false);
    }
  }

  /// ✅ 감정 점수화 (감정 → 숫자) - (변경 없음)
  int _emotionToScore(String emotion) {
    const positive = [
      "기쁨","사랑","희망","감사","만족","열정","자신감","뿌듯","환희","즐거움",
      "설렘", "용기", "감동", "반가움", "평화", "기적", "낭만"
    ];
    const negative = [
      "슬픔","화남","짜증","무기력","불안","좌절","후회","피곤","우울","분노",
      "외로움", "스트레스", "긴장", "공허", "질투", "실망", "분노", "초조",
      "무서움", "포기"
    ];

    if (positive.contains(emotion)) return 2;
    if (negative.contains(emotion)) return -2;
    return 0; // 중립 (평온, 놀람 등)
  }

  /// ✅ 차트 데이터 생성 - (변경 없음)
  List<FlSpot> _buildChartData() {
    final monthKey = DateFormat('yyyy-MM').format(widget.initialMonth);
    final monthEmotions = _emotions.entries
        .where((e) => e.key.startsWith(monthKey))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key)); // 날짜순 정렬

    List<FlSpot> points = [];
    for (int i = 0; i < monthEmotions.length; i++) {
      final day = int.parse(monthEmotions[i].key.split('-')[2]);
      final score = _emotionToScore(monthEmotions[i].value);
      points.add(FlSpot(day.toDouble(), score.toDouble()));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat('yyyy년 MM월').format(widget.initialMonth);
    final spots = _buildChartData();

    return Scaffold(
      appBar: AppBar(
        title: Text("📈 $monthTitle 감정 추세"),
        backgroundColor: _themeColor, // ✅ 테마 적용
        iconTheme: IconThemeData(color: _textColor), // ✅ 테마 적용
        titleTextStyle: TextStyle(
            color: _textColor, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      // ✅ 테마 적용
      body: Container(
        color: _themeColor.withOpacity(0.5),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : spots.isEmpty
            ? Center(
          child: Text(
            "이 달에는 아직 감정 기록이 없어요 🕓",
            style: TextStyle(color: _textColor.withOpacity(0.7), fontSize: 16),
          ),
        )
            : Padding(
          padding: const EdgeInsets.all(20), // 패딩 증가
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "일별 감정 점수 변화",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _textColor),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: -2, // 최소 y
                    maxY: 2,  // 최대 y
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true, // 세로선
                      verticalInterval: 1, // 1일 간격
                      horizontalInterval: 1, // 1점 간격
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: _textColor.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: _textColor.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: _textColor.withOpacity(0.3)),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40, // 공간 확보
                          getTitlesWidget: (value, meta) {
                            String text = '';
                            if (value == 2) text = "긍정 😊";
                            if (value == 0) text = "중립 😐";
                            if (value == -2) text = "부정 😞";
                            return Text(text, style: TextStyle(color: _textColor, fontSize: 10));
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30, // 공간 확보
                          interval: 1, // 1일 간격
                          getTitlesWidget: (value, meta) {
                            // 5일 간격으로만 날짜 표시
                            if (value % 5 == 0 || value == 1) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${value.toInt()}일',
                                  style: TextStyle(color: _textColor, fontSize: 10),
                                ),
                              );
                            }
                            return const Text("");
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        color: _textColor == Colors.black ? Colors.deepPurple : Colors.white, // 테마색에 맞춰 라인 색 변경
                        barWidth: 4, // 굵기
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData( // 라인 아래 영역 색칠
                          show: true,
                          color: (_textColor == Colors.black ? Colors.deepPurple : Colors.white).withOpacity(0.2),
                        ),
                        spots: spots,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}