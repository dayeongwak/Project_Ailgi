import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'api_key.dart'; // ✅ API 키 분리

class ChatPage extends StatefulWidget {
  final DateTime selectedDay;
  final Function(String emotion) onEmotionAnalyzed;

  const ChatPage({
    super.key,
    required this.selectedDay,
    required this.onEmotionAnalyzed,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<types.Message> _messages = [];
  final _user = const types.User(id: 'user');

  bool _isFavorite = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceText = "";

  final ImagePicker _picker = ImagePicker();

  String get _dateKey =>
      DateFormat('yyyy-MM-dd').format(widget.selectedDay);

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadFavorite();
    });
  }

  /// ✅ 즐겨찾기 불러오기
  Future<void> _loadFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFavorite = prefs.getBool("favorite_$_dateKey") ?? false;
    });
  }

  /// ✅ 즐겨찾기 토글
  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFavorite = !_isFavorite;
    });
    if (_isFavorite) {
      await prefs.setBool("favorite_$_dateKey", true);
    } else {
      await prefs.remove("favorite_$_dateKey");
    }
  }

  /// ✅ 데이터 불러오기
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("chat_$_dateKey");
    if (raw != null) {
      final data = jsonDecode(raw);
      final savedMessages = (data["messages"] as List).map((m) {
        return types.TextMessage(
          id: m["id"],
          text: m["text"],
          author: m["author"] == "user" ? _user : const types.User(id: "bot"),
          createdAt: (m["createdAt"] as num).toInt(),
        );
      }).toList();
      setState(() {
        _messages.clear();
        _messages.addAll(savedMessages);
      });
      if (data["emotion"] != null) {
        widget.onEmotionAnalyzed(data["emotion"]);
      }
    }
  }

  Future<String?> _loadEmotion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("chat_$_dateKey");
    if (raw != null) {
      final data = jsonDecode(raw);
      return data["emotion"];
    }
    return null;
  }

  Future<void> _saveData({String? emotion}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _messages.whereType<types.TextMessage>().map((m) => {
      "id": m.id,
      "text": m.text,
      "author": m.author.id,
      "createdAt": m.createdAt,
    }).toList();

    final data = {
      "messages": jsonList,
      "emotion": emotion ?? (await _loadEmotion()),
    };
    await prefs.setString("chat_$_dateKey", jsonEncode(data));
  }

  /// ✅ GPT 일반 대화
  Future<String> getChatReply(String text) async {
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer $openAIApiKey", // ✅ 분리된 키 사용
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {
            "role": "system",
            "content":
            "너는 사용자의 일기 친구야. 사용자의 말투와 감정을 반영해서 짧고 다정하게 대답해."
          },
          {"role": "user", "content": text}
        ],
      }),
    );
    final data = jsonDecode(response.body);
    return data["choices"][0]["message"]["content"] ?? "";
  }

  /// ✅ 감정 분석 (50개)
  Future<String> analyzeEmotion(String text) async {
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer $openAIApiKey", // ✅ 분리된 키 사용
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {
            "role": "system",
            "content":
            "너는 감정 분석기야. 텍스트를 보고 반드시 아래 리스트 중 하나만 출력해. 설명은 하지 말고 감정 단어 하나만 출력:\n"
                "기쁨, 슬픔, 화남, 짜증, 무기력, 짜릿, 불안, 평온, 사랑, 놀람, 좌절, 자신감, 후회, 혼란, 피곤, 감사, 당황, 외로움, 만족, 스트레스, 기대, 뿌듯, 긴장, 충격, 희망, 공허, 질투, 열정, 차분, 즐거움, 부끄러움, 실망, 설렘, 존경, 분노, 의욕, 안정, 환희, 동경, 초조, 허무, 만족감, 분주, 열망, 차가움, 경악, 우울, 피로, 존중, 열광"
          },
          {"role": "user", "content": text}
        ],
      }),
    );
    final data = jsonDecode(response.body);
    return data["choices"][0]["message"]["content"] ?? "알 수 없음";
  }

// ... (나머지 코드 동일: 메시지 추가, 음성 입력, 이미지 업로드 등)
}
