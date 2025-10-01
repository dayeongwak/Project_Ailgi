import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsPage extends StatefulWidget {
  final DateTime initialMonth;

  const StatisticsPage({super.key, required this.initialMonth});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  Map<String, int> emotionCounts = {};
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.initialMonth.year, widget.initialMonth.month);
    _loadStatistics();
  }

  /// ✅ 감정 데이터 불러오기
  Future<void> _loadStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final Map<String, int> counts = {};

    for (final key in keys) {
      if (key.startsWith("chat_")) {
        final raw = prefs.getString(key);
        if (raw != null) {
          final data = jsonDecode(raw);
          final emotion = data["emotion"];
          if (emotion != null && emotion.isNotEmpty) {
            final dateKey = key.replaceFirst("chat_", "");
            final date = DateTime.tryParse(dateKey);

            if (date != null &&
                date.year == _currentMonth.year &&
                date.month == _currentMonth.month) {
              counts[emotion] = (counts[emotion] ?? 0) + 1;
            }
          }
        }
      }
    }

    setState(() {
      emotionCounts = counts;
    });
  }

  /// ✅ 감정 색상 매핑 (고정 팔레트)
  Color _getEmotionColor(String emotion) {
    final colors = [
      Colors.red, Colors.blue, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.brown,
      Colors.indigo, Colors.cyan, Colors.amber, Colors.lime,
      Colors.deepOrange, Colors.deepPurple, Colors.lightBlue,
      Colors.lightGreen, Colors.blueGrey, Colors.yellow.shade700,
      Colors.grey, Colors.black54,
    ];
    return colors[emotion.hashCode % colors.length];
  }

  /// ✅ 파이차트 섹션 생성
  List<PieChartSectionData> _buildPieChartSections() {
    final total = emotionCounts.values.fold<int>(0, (a, b) => a + b);

    return emotionCounts.entries.map((entry) {
      final percent = (entry.value / total * 100).toStringAsFixed(1);
      return PieChartSectionData(
        color: _getEmotionColor(entry.key),
        value: entry.value.toDouble(),
        title: "${entry.key}\n$percent%",
        radius: 70,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      );
    }).toList();
  }

  /// ✅ 바차트 그룹 생성
  List<BarChartGroupData> _buildBarChartGroups() {
    int index = 0;
    return emotionCounts.entries.map((entry) {
      return BarChartGroupData(
        x: index++,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: _getEmotionColor(entry.key),
            width: 16,
          ),
        ],
      );
    }).toList();
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset);
    });
    _loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    final monthText = DateFormat('yyyy년 MM월').format(_currentMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text("월별 감정 통계"),
      ),
      body: Column(
        children: [
          // ✅ 월 이동 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                monthText,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Expanded(
            child: emotionCounts.isEmpty
                ? const Center(child: Text("이 달에는 감정 기록이 없습니다."))
                : ListView(
              children: [
                SizedBox(
                  height: 300,
                  child: PieChart(
                    PieChartData(
                      sections: _buildPieChartSections(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      barGroups: _buildBarChartGroups(),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final keys = emotionCounts.keys.toList();
                              if (value.toInt() < keys.length) {
                                return Text(
                                  keys[value.toInt()],
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const Text("");
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
