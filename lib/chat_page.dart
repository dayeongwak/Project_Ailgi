import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String get _dateKey =>
      DateFormat('yyyy-MM-dd').format(widget.selectedDay);

  /// ✅ 항상 저장 (메시지 + 감정)
  Future<void> _saveData({String? emotion}) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = _messages
        .whereType<types.TextMessage>()
        .map((m) => {
      "id": m.id,
      "text": m.text,
      "author": m.author.id,
      "createdAt": m.createdAt,
    })
        .toList();

    final data = {
      "messages": jsonList,
      "emotion": emotion ?? (await _loadEmotion()),
    };

    await prefs.setString("chat_$_dateKey", jsonEncode(data));
  }

  /// ✅ 불러오기
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("chat_$_dateKey");

    if (raw != null) {
      final data = jsonDecode(raw);
      final savedMessages = (data["messages"] as List).map((m) {
        return types.TextMessage(
          id: m["id"],
          text: m["text"],
          author: m["author"] == "user"
              ? _user
              : const types.User(id: "bot"),
          createdAt: m["createdAt"],
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  /// OpenAI 대화
  Future<String> getChatReply(String text) async {
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        // ⚠️ 여기에 직접 키를 적지 마세요!
        "Authorization": "Bearer YOUR_API_KEY",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {"role": "system", "content": "너는 친절한 일기 친구야."},
          {"role": "user", "content": text}
        ],
      }),
    );

    final data = jsonDecode(response.body);
    return data["choices"][0]["message"]["content"];
  }

  /// 감정 분석
  Future<String> analyzeEmotion(String text) async {
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        // ⚠️ 여기에 직접 키를 적지 마세요!
        "Authorization": "Bearer YOUR_API_KEY",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {
            "role": "system",
            "content":
            "너는 감정 분석기야. 기쁨, 슬픔, 화남, 짜증, 무기력, 짜릿, 불안, 평온, 사랑, 놀람, 좌절, 자신감, 후회, 혼란, 피곤, 감사, 당황, 외로움, 만족, 스트레스 중 하나만 답해."
          },
          {"role": "user", "content": text}
        ],
      }),
    );

    final data = jsonDecode(response.body);
    return data["choices"][0]["message"]["content"];
  }

  /// ✅ 메시지 추가 → 항상 저장
  Future<void> _addMessage(types.TextMessage message,
      {String? emotion}) async {
    setState(() => _messages.insert(0, message));
    await _saveData(emotion: emotion);
  }

  void _onSendPressed(types.PartialText message) async {
    final userMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: DateTime.now().toString(),
      text: message.text,
    );

    await _addMessage(userMessage);

    // AI 응답
    final reply = await getChatReply(message.text);
    final botMessage = types.TextMessage(
      author: const types.User(id: 'bot'),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: 'bot_${DateTime.now()}',
      text: reply,
    );

    await _addMessage(botMessage);

    // 끝내자는 말이면 감정 분석
    if (message.text.contains("끝") || message.text.contains("마쳐")) {
      final allText = _messages
          .whereType<types.TextMessage>()
          .map((m) => m.text)
          .join("\n");
      final emotion = await analyzeEmotion(allText);

      widget.onEmotionAnalyzed(emotion);
      final emotionMessage = types.TextMessage(
        author: const types.User(id: 'system'),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: 'emotion_${DateTime.now()}',
        text: "오늘 하루 감정 분석 👉 $emotion",
      );

      await _addMessage(emotionMessage, emotion: emotion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(widget.selectedDay);
    return Scaffold(
      appBar: AppBar(title: Text("$formattedDate 일기")),
      body: Chat(
        messages: _messages,
        onSendPressed: _onSendPressed,
        user: _user,
      ),
    );
  }
}
