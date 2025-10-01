import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_page.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final Map<String, String> _favorites = {}; // 날짜별 감정 저장

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  /// ✅ SharedPreferences에서 즐겨찾기 기록 불러오기
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    _favorites.clear();

    for (final key in keys) {
      if (key.startsWith("favorite_") && prefs.getBool(key) == true) {
        final dateKey = key.replaceFirst("favorite_", "");
        final chatRaw = prefs.getString("chat_$dateKey");

        if (chatRaw != null) {
          final data = jsonDecode(chatRaw);
          if (data["emotion"] != null) {
            _favorites[dateKey] = data["emotion"];
          }
        }
      }
    }
    setState(() {});
  }

  /// ✅ 즐겨찾기 해제
  Future<void> _removeFavorite(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("favorite_$dateKey");

    setState(() {
      _favorites.remove(dateKey);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$dateKey 즐겨찾기가 해제되었습니다.")),
    );
  }

  /// ✅ 감정 → 이모지 변환
  String _getEmotionEmoji(String emotion) {
    switch (emotion) {
      case "기쁨": return "😁";
      case "슬픔": return "😢";
      case "화남": return "😡";
      case "짜증": return "😒";
      case "무기력": return "🥱";
      case "즐거움": return "🎉";
      default: return "⭐";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("즐겨찾기 모음")),
      body: _favorites.isEmpty
          ? const Center(
        child: Text("즐겨찾기한 날짜가 없습니다."),
      )
          : ListView(
        children: _favorites.entries.map((entry) {
          final dateKey = entry.key;
          final emotion = entry.value;

          return Card(
            child: ListTile(
              leading: Text(
                _getEmotionEmoji(emotion),
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(dateKey),
              subtitle: Text("감정: $emotion"),
              onTap: () {
                final date = DateFormat('yyyy-MM-dd').parse(dateKey);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      selectedDay: date,
                      onEmotionAnalyzed: (_) => _loadFavorites(),
                    ),
                  ),
                );
              },
              // ✅ 즐겨찾기 해제 버튼
              trailing: IconButton(
                icon: const Icon(Icons.star, color: Colors.amber),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("즐겨찾기 해제"),
                      content: Text("$dateKey 날짜의 즐겨찾기를 해제하시겠습니까?"),
                      actions: [
                        TextButton(
                          child: const Text("취소"),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        TextButton(
                          child: const Text("해제"),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    _removeFavorite(dateKey);
                  }
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
