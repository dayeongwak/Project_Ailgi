import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? get _uid => _auth.currentUser?.uid;

  final TextEditingController _keywordController = TextEditingController(); // ✅ 키워드 검색 컨트롤러

  // 검색할 감정 목록
  final List<String> _emotions = [
    "기쁨", "슬픔", "화남", "평온", "사랑", "불안", "만족", "피곤", "기대", "감사",
  ];

  String? _selectedEmotion; // 사용자가 선택한 감정
  String _searchKeyword = ''; // 현재 입력된 키워드

  @override
  void initState() {
    super.initState();
    // 키워드 변경 리스너 추가
    _keywordController.addListener(_onKeywordChanged);
  }

  @override
  void dispose() {
    _keywordController.removeListener(_onKeywordChanged);
    _keywordController.dispose();
    super.dispose();
  }

  // 키워드 변경 시 상태 업데이트
  void _onKeywordChanged() {
    setState(() {
      _searchKeyword = _keywordController.text.trim();
    });
  }

  // 날짜 문자열(YYYY-MM-DD)을 DateTime 객체로 변환
  DateTime _parseDateKey(String dateKey) {
    try {
      return DateFormat('yyyy-MM-dd').parse(dateKey);
    } catch (e) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearchActive = _selectedEmotion != null || _searchKeyword.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('일기 통합 검색'), // ✅ [수정] 제목을 '일기 통합 검색'으로 변경
      ),
      body: Column(
        children: [
          // 1. 키워드 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _keywordController,
              decoration: InputDecoration(
                labelText: '일기 내용 검색 키워드',
                hintText: '행복, 친구, 여행 등...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchKeyword.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _keywordController.clear(),
                )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          // 2. 감정 선택 칩 (가로 스크롤)
          _buildEmotionChips(),

          // 3. 검색 결과 목록
          Expanded(
            child: isSearchActive
                ? _buildResultsList()
                : const Center(
              child: Text('검색할 감정 또는 키워드를 입력해주세요.'),
            ),
          ),
        ],
      ),
    );
  }

  /// 감정 칩을 그리는 위젯
  Widget _buildEmotionChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 8.0,
          children: _emotions.map((emotion) {
            final isSelected = _selectedEmotion == emotion;
            return ChoiceChip(
              label: Text(emotion),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedEmotion = selected ? emotion : null;
                });
              },
              selectedColor: Colors.blue.shade100,
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Firestore에서 검색 결과를 가져와 목록으로 보여주는 위젯
  Widget _buildResultsList() {
    if (_uid == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    // 쿼리 생성
    Query query = _firestore
        .collection('users')
        .doc(_uid)
        .collection('diaries')
        .orderBy('timestamp', descending: true);

    // 1. 감정 필터 적용
    if (_selectedEmotion != null) {
      query = query.where('emotion', isEqualTo: _selectedEmotion);
    }

    // 키워드 검색은 클라이언트에서 필터링
    final bool hasKeyword = _searchKeyword.isNotEmpty;


    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('오류 발생: ${snapshot.error}'));
        }

        // 2. 키워드 필터링 (클라이언트 측)
        List<QueryDocumentSnapshot> filteredDocs = snapshot.data!.docs;

        if (hasKeyword) {
          final lowerKeyword = _searchKeyword.toLowerCase();
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final summary = (data['summary'] ?? '').toLowerCase();
            final messages = (data['allText'] ?? '').toLowerCase(); // 'allText' 필드 사용

            // ✅ [수정] summary 또는 messages(allText)에 키워드가 포함되면 통과
            return summary.contains(lowerKeyword) || messages.contains(lowerKeyword);
          }).toList();
        }

        if (filteredDocs.isEmpty) {
          String message = _selectedEmotion != null
              ? "'$_selectedEmotion' 감정의 일기 중 키워드와 일치하는 내용이 없습니다."
              : "'$_searchKeyword' 키워드가 포함된 일기가 없습니다.";
          return Center(child: Text(message));
        }

        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            final String dateKey = doc.id;
            final String emotion = data['emotion'] ?? '';
            final String summary = data['summary'] ?? '요약 없음';
            final DateTime date = _parseDateKey(dateKey);

            return ListTile(
              leading: Text(emotion, style: const TextStyle(fontSize: 24)),
              title: Text(
                DateFormat('yyyy년 MM월 dd일').format(date),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // 해당 날짜의 ChatPage로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPage(
                      selectedDay: date,
                      onEmotionAnalyzed: (emotion) {}, // 검색 페이지에서 로드할 데이터는 없음
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}