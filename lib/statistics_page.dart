import 'dart:convert';
import 'package:flutter/material.dart'; // 👈 이 import가 핵심입니다
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ 1. Firebase 패키지 임포트
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatisticsPage extends StatefulWidget {
  final DateTime initialMonth;
  const StatisticsPage({super.key, required this.initialMonth});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  Map<String, String> _emotions = {};
  bool _isLoading = true;
  Color _themeColor = Colors.white;
  Color _textColor = Colors.black;

  // ✅ 2. Firebase 인스턴스
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? get _uid => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadData(); // ✅ Firestore에서 읽도록 수정됨
  }

  /// 테마 색상 로드 (SharedPreferences 유지 - 변경 없음)
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
    // 🎨 computeLuminance()가 더 정확합니다.
    final textColor = color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    setState(() {
      _themeColor = color;
      _textColor = textColor;
    });
  }

  /// ✅ 3. (수정) Firestore에서 감정 데이터 로드
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
      print("❌ StatisticsPage _loadData 오류: $e");
      setState(() => _isLoading = false);
    }
  }


  /// 감정 → 카테고리 변환 (변경 없음)
  String _emotionToCategory(String emotion) {
    const positive = [
      "기쁨","사랑","희망","감사","만족","열정","자신감","뿌듯","환희","즐거움",
      "설렘", "용기", "감동", "반가움", "평화", "기적", "낭만"
    ];
    const negative = [
      "슬픔","화남","짜증","무기력","불안","좌절","후회","피곤","우울","분노",
      "외로움", "스트레스", "긴장", "공허", "질투", "실망", "분노", "초조",
      "무서움", "포기"
    ];
    // (위 리스트에 없는 '평온', '놀람' 등은 '중립'으로 처리됨)
    if (positive.contains(emotion)) return "긍정";
    if (negative.contains(emotion)) return "부정";
    return "중립";
  }

  /// 카테고리별 개수 집계 (변경 없음)
  Map<String, int> _countEmotionCategories() {
    final monthKey = DateFormat('yyyy-MM').format(widget.initialMonth);
    // _emotions 맵의 key (e.g., "2025-10-28")가 monthKey("2025-10")로 시작하는지 확인
    final monthData = _emotions.entries
        .where((e) => e.key.startsWith(monthKey))
        .toList();

    final counts = {"긍정": 0, "중립": 0, "부정": 0};
    for (final e in monthData) {
      counts[_emotionToCategory(e.value)] =
          (counts[_emotionToCategory(e.value)] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat('yyyy년 MM월').format(widget.initialMonth);
    final counts = _countEmotionCategories();
    final total = counts.values.reduce((a, b) => a + b);

    final sections = [
      PieChartSectionData(
        value: counts["긍정"]!.toDouble(),
        color: Colors.pinkAccent,
        title: total == 0
            ? ""
            : "${((counts["긍정"]! / total) * 100).toStringAsFixed(1)}%",
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        radius: 140,
        titlePositionPercentageOffset: 0.6,
      ),
      PieChartSectionData(
        value: counts["중립"]!.toDouble(),
        color: Colors.grey,
        title: total == 0
            ? ""
            : "${((counts["중립"]! / total) * 100).toStringAsFixed(1)}%",
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        radius: 140,
        titlePositionPercentageOffset: 0.6,
      ),
      PieChartSectionData(
        value: counts["부정"]!.toDouble(),
        color: Colors.deepPurpleAccent,
        title: total == 0
            ? ""
            : "${((counts["부정"]! / total) * 100).toStringAsFixed(1)}%",
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        radius: 140,
        titlePositionPercentageOffset: 0.6,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _themeColor,
        title: Text("📊 $monthTitle 감정 통계", style: TextStyle(color: _textColor)),
        iconTheme: IconThemeData(color: _textColor),
      ),
      // ✅ 4. (수정) 배경색 적용
      body: Container(
        color: _themeColor.withOpacity(0.5), // 은은한 배경색
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : total == 0
            ? Center(
          child: Text(
            "이 달에는 감정 데이터가 없습니다 🕓",
            style: TextStyle(fontSize: 16, color: _textColor),
          ),
        )
            : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 400,
                height: 400,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 25,
                    sectionsSpace: 0,
                    startDegreeOffset: -90,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildLegend(),
            ],
          ),
        ),
      ),
    );
  }

  /// 범례 (변경 없음)
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: Colors.pinkAccent, label: "긍정", textColor: _textColor),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.grey, label: "중립", textColor: _textColor),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.deepPurpleAccent, label: "부정", textColor: _textColor),
      ],
    );
  }
}

/// ✅ 범례 아이템 (수정됨 - textColor)
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;
  const _LegendItem({required this.color, required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black12, width: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          // ✅ 배경색이 어두울 때 글씨가 안보이는 문제 해결
          style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.9)),
        ),
      ],
    );
  }
}