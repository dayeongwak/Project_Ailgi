// lib/favorite_page.dart (괄호 오류 수정)

import 'dart:convert'; // ✅ 'dart:convert'가 있는지 확인
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_page.dart';

// ✅ 1. Firebase 패키지 임포트
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final Map<String, String> _emotions = {};
  final List<String> _favorites = [];
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
    _loadData(); // ✅ _loadFavorites에서 _loadData로 이름 변경
  }

  /// 🎨 테마 불러오기 (SharedPreferences 유지 - 변경 없음)
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

  /// ✅ 3. (수정) Firestore에서 즐겨찾기 데이터 로드
  Future<void> _loadData() async {
    if (_uid == null) return;

    final newFavorites = <String>[];
    final newEmotions = <String, String>{};

    try {
      // 'users/{uid}/diaries' 컬렉션에서 'isFavorite'가 true인 문서만 쿼리
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('diaries')
          .where('isFavorite', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final dateKey = doc.id; // "2025-10-28"
        final data = doc.data();
        final emotion = data['emotion'] as String?;

        newFavorites.add(dateKey);
        if (emotion != null) {
          newEmotions[dateKey] = emotion;
        }
      }

      // 날짜순으로 정렬 (최신순)
      newFavorites.sort((a, b) => b.compareTo(a));

      if (mounted) {
        setState(() {
          _favorites.clear();
          _favorites.addAll(newFavorites);
          _emotions.clear();
          _emotions.addAll(newEmotions);
        });
      }

    } catch (e) {
      print("❌ FavoritePage _loadData 오류: $e");
    }
  }


  /// 😁 감정 → 이모지 (변경 없음)
  String _emoji(String? e) {
    const map = {
      "기쁨": "😁", "슬픔": "😢", "화남": "😡", "짜증": "😒", "무기력": "🥱", "불안": "😨",
      "평온": "😌", "사랑": "😍", "놀람": "😲", "감사": "🤗", "좌절": "😤", "자신감": "😎",
      "후회": "😔", "혼란": "🤔", "피곤": "😴", "당황": "😕", "외로움": "😭", "만족": "😇",
      "스트레스": "🤯", "기대": "🤞", "뿌듯": "👏", "긴장": "😬", "충격": "😱", "희망": "🌈",
      "공허": "🥀", "질투": "🧐", "열정": "🔥", "차분": "🧘", "즐거움": "🎉", "부끄러움": "😳",
      "실망": "🙁", "설렘": "💓", "존경": "🙏", "분노": "💢", "의욕": "💪", "안정": "🛡️",
      "환희": "🥳", "동경": "🌠", "초조": "😰", "허무": "😶", "분주": "🏃", "열망": "⚡",
      "차가움": "🥶", "경악": "🤯", "우울": "😞", "존중": "🤝", "열광": "⚡", "용기": "🦸",
      "감동": "🥹", "불편": "😣", "무서움": "👻", "반가움": "😊", "후련": "😮‍💨",
      "평화": "🕊️", "포기": "😞", "기적": "✨", "낭만": "🌹",
    };
    return map[e] ?? "⭐"; // 즐겨찾기인데 감정이 없으면 별표
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _themeColor,
        title: Text("⭐ 즐겨찾기", style: TextStyle(color: _textColor)),
        iconTheme: IconThemeData(color: _textColor),
      ),
      // ✅ 4. (수정) 배경색 적용
      body: Container( // 👈 Container 시작
        color: _themeColor.withOpacity(0.5), // 은은한 배경색
        child: _favorites.isEmpty
            ? Center(
          child: Text(
            "즐겨찾기한 날짜가 없습니다.",
            style: TextStyle(
              color: _textColor.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        )
            : ListView.builder( // 👈 ListView.builder 시작
          itemCount: _favorites.length,
          itemBuilder: (context, i) {
            final dateKey = _favorites[i];
            final e = _emotions[dateKey];
            final date = DateFormat('yyyy-MM-dd').parse(dateKey);

            return Card(
              color: _themeColor.withOpacity(0.8), // 카드 배경색
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Text(_emoji(e), style: const TextStyle(fontSize: 28)),
                title: Text(
                  DateFormat('yyyy년 MM월 dd일').format(date),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                subtitle: e != null
                    ? Text("감정: $e",
                    style: TextStyle(color: _textColor.withOpacity(0.8)))
                    : Text("감정 분석 없음",
                    style: TextStyle(color: _textColor.withOpacity(0.6))),
                trailing: Icon(Icons.chevron_right, color: _textColor),
                onTap: () async {
                  // ✅ 5. (수정) _loadData() 호출
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        selectedDay: date,
                        onEmotionAnalyzed: (_) {}, // ChatPage가 알아서 Firestore에 씀
                      ),
                    ),
                  );

                  // ✅ ChatPage에서 돌아오면 항상 새로고침
                  // (즐겨찾기가 해제되었거나, 감정이 바뀌었을 수 있으므로)
                  await _loadData();
                },
              ), // ListTile 끝
            ); // Card 끝
          },
        ), // ListView.builder 끝
      ), // ✅✅✅ 괄호 오류가 있던 198 라인이 여기입니다. Container 끝
    ); // Scaffold 끝
  }
}