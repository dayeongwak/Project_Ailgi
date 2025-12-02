import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'api_key.dart';
import 'chat_input.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';

// Firebase 패키지 임포트
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  final _user = const types.User(id: 'user');
  final _bot = const types.User(id: 'bot');

  bool _isAnalyzing = false;
  String? _backgroundImagePath; // 배경 이미지만 로컬 상태로 관리 (테마색은 부모에서 받음)

  late FlutterTts _flutterTts;
  bool _isVoiceMode = false;
  bool _isAiSpeaking = false;
  final GlobalKey<ChatInputState> _chatInputKey = GlobalKey<ChatInputState>();

  // Firebase 인스턴스
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  String get _dateKey => DateFormat('yyyy-MM-dd').format(widget.selectedDay);
  String? get _uid => _auth.currentUser?.uid;

  DocumentReference? get _diaryDocRef {
    if (_uid == null) return null;
    return _firestore.collection('users').doc(_uid).collection('diaries').doc(_dateKey);
  }

  CollectionReference? get _messagesColRef {
    return _diaryDocRef?.collection('messages');
  }

  final List<String> _initialGreetings = [
    "오늘 하루는 어땠나요? 당신의 이야기를 들려주세요 😊",
    "좋은 날씨였나요? 아니면 조금 힘든 하루였나요? 제가 옆에 있을게요. 🫂",
    "가장 먼저 기록하고 싶은 오늘의 특별한 순간이 있나요? ✍️",
    "무슨 일이 있었는지 궁금해요! 편하게 말해주세요. 저는 항상 당신의 편이에요.",
    "오늘의 당신의 기분은 어떤 색깔인가요? 이야기를 시작해볼까요? 🌈",
    "잠깐 들러줘서 고마워요. 오늘은 어떤 일들을 겪었나요? 천천히 이야기해봐요.",
  ];

  String _getRandomGreeting() {
    final random = Random();
    return _initialGreetings[random.nextInt(_initialGreetings.length)];
  }

  Future<void> _addInitialBotMessage() async {
    if (_messagesColRef != null) {
      final snapshot = await _messagesColRef!.limit(1).get();
      if (snapshot.docs.isEmpty) {
        final greeting = _getRandomGreeting();
        final botMsg = types.TextMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          author: _bot,
          text: greeting,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        Future.microtask(() async {
          await _messagesColRef!.doc(botMsg.id).set(botMsg.toJson());
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBackground(); // 배경 이미지만 따로 로드
    _initTts();
  }

  // 배경 이미지 로드 (테마 색상은 main.dart에서 받으므로 제거)
  Future<void> _loadBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final key = "${_uid ?? 'GUEST'}_app_background_image_url";
    if (mounted) {
      setState(() {
        _backgroundImagePath = prefs.getString(key);
      });
    }
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isAiSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isAiSpeaking = false);
      if (_isVoiceMode) {
        _chatInputKey.currentState?.startListening();
      }
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _isAiSpeaking = false);
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isAiSpeaking = false);
      print("TTS Error: $msg");
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> _toggleFavorite(bool currentIsFavorite) async {
    if (_diaryDocRef == null) return;
    HapticFeedback.lightImpact();
    await _diaryDocRef!.set(
      {'isFavorite': !currentIsFavorite},
      SetOptions(merge: true),
    );
    widget.onEmotionAnalyzed("");
  }

  Future<String> _getChatReply(String text) async {
    const systemPrompt = """
당신은 사용자의 하루를 기록하고 감정을 공유하는 친근하고 따뜻한 AI 친구입니다. 사용자의 의도는 항상 최우선입니다.
[역할]:
1. 사용자의 감정을 먼저 읽어주고 공감하며 대화하세요.
2. 답변은 2문장 이내로 작성하세요.
""";
    try {
      final res = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: { "Authorization": "Bearer $openAIApiKey", "Content-Type": "application/json", },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": text}
          ],
        }),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data["choices"]?[0]?["message"]?["content"] ?? "응답을 이해하지 못했어요 😅";
    } catch (_) { return "네트워크 오류가 발생했어요 ⚠️"; }
  }

  Future<String> _getChatReplyForImage(Uint8List imageBytes, String? mimeType) async {
    try {
      final String base64Image = base64Encode(imageBytes);
      final String dataUri = 'data:${mimeType ?? 'image/jpeg'};base64,$base64Image';
      const systemPrompt = "너는 사용자의 일기 친구야. 사용자가 방금 사진을 보냈어. 사진을 보고 느낀 점이나 질문을 포함하여 다정하게 짧게 한마디 해줘.";

      final res = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: { "Authorization": "Bearer $openAIApiKey", "Content-Type": "application/json", },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": systemPrompt},
            { "role": "user", "content": [
              { "type": "text", "text": "이 사진에 대해 일기 친구처럼 답변해줘." },
              { "type": "image_url", "image_url": { "url": dataUri } }
            ] }
          ], "max_tokens": 100
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return data["choices"]?[0]?["message"]?["content"] ?? "사진을 잘 받았어요! 🖼️";
      } else { return "사진을 받았는데, 지금은 잘 안 보이네요 😅"; }
    } catch (e) { return "사진 처리 중 오류가 발생했어요 ⚠️"; }
  }

  Future<String> _analyzeEmotion(String allText) async {
    const emotions = [
      "기쁨","슬픔","화남","짜증","무기력","불안","평온","사랑","놀람","감사",
      "좌절","자신감","후회","혼란","피곤","당황","외로움","만족","스트레스",
      "기대","뿌듯","긴장","충격","희망","공허","질투","열정","차분","즐거움",
      "부끄러움","실망","설렘","존경","분노","의욕","안정","환희","동경","초조",
      "허무","분주","열망","차가움","경악","우울","존중","열광","용기","감동",
      "불편","무서움","반가움","후련","평화","포기","기적","낭만"
    ];
    final analysisPrompt = """
당신은 최고 수준의 심리학자이자 감정 분석 전문가입니다. 
아래 '대화 전체 내용'을 분석하여 사용자의 '전반적인 핵심 감정'을 단 하나의 키워드로 확정하세요.
[분석 지침]:
1. 감정 목록 [${emotions.join(', ')}] 중에서 선택해야 합니다.
2. 최종 답변은 오직 가장 정확한 감정 키워드 하나여야 합니다.
""";
    try {
      final res = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: { "Authorization": "Bearer $openAIApiKey", "Content-Type": "application/json", },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            { "role": "system", "content": analysisPrompt },
            {"role": "user", "content": "대화 전체 내용: $allText"}
          ],
        }),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      String emotion = data["choices"]?[0]?["message"]?["content"]?.trim() ?? "평온";
      if (!emotions.contains(emotion)) { emotion = "평온"; }
      return emotion;
    } catch (e) { return "평온"; }
  }

  Future<String> _generateEmotionComment(String emotion) async {
    try {
      final res = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: { "Authorization": "Bearer $openAIApiKey", "Content-Type": "application/json", },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            { "role": "system", "content": "감정에 어울리는 한 줄 위로·칭찬 코멘트를 25자 이내로 한국어로 만들어. 이모지 한두 개 포함." },
            {"role": "user", "content": emotion}
          ],
        }),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data["choices"]?[0]?["message"]?["content"]?.trim() ?? "오늘도 수고했어요 💕";
    } catch (_) { return "오늘도 수고했어요 💕"; }
  }

  Future<String> _generateDiarySummary(String allText) async {
    const summaryPrompt = "사용자의 일기 내용을 바탕으로 100자 이내의 친근한 일기 요약 문장(프리뷰) 하나를 만들어주세요.";
    try {
      final res = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: { "Authorization": "Bearer $openAIApiKey", "Content-Type": "application/json", },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            { "role": "system", "content": summaryPrompt },
            {"role": "user", "content": "대화 전체 내용: $allText"}
          ],
        }),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data["choices"]?[0]?["message"]?["content"]?.trim() ?? "오늘도 소중한 하루를 기록했어요!";
    } catch (e) { return "오늘도 소중한 하루를 기록했어요!"; }
  }

  String _getEmojiForEmotion(String emotion) {
    const map = {
      "기쁨": "😁", "슬픔": "😢", "화남": "😡", "짜증": "😒", "무기력": "🥱",
      "불안": "😨", "평온": "😌", "사랑": "😍", "놀람": "😲", "감사": "🤗",
      "좌절": "😤", "자신감": "😎", "후회": "😔", "혼란": "🤔", "피곤": "😴",
      "당황": "😕", "외로움": "😭", "만족": "😇", "스트레스": "🤯", "기대": "🤞",
      "뿌듯": "👏", "긴장": "😬", "충격": "😱", "희망": "🌈", "공허": "🥀",
      "질투": "🧐", "열정": "🔥", "차분": "🧘", "즐거움": "🎉", "부끄러움": "😳",
      "실망": "🙁", "설렘": "💓", "존경": "🙏", "분노": "💢", "의욕": "💪",
      "안정": "🛡️", "환희": "🥳", "동경": "🌠", "초조": "😰", "허무": "😶",
      "분주": "🏃", "열망": "⚡", "차가움": "🥶", "경악": "🤯", "우울": "😞",
      "존중": "🤝", "열광": "⚡", "용기": "🦸", "감동": "🥹", "불편": "😣",
      "무서움": "👻", "반가움": "😊", "후련": "😮‍💨", "평화": "🕊️", "포기": "😞",
      "기적": "✨", "낭만": "🌹"
    };
    return map[emotion] ?? "✨";
  }

  Future<void> _endDiary(List<types.Message> currentMessages) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (_diaryDocRef == null || _messagesColRef == null) return;
    if (currentMessages.isEmpty) {
      scaffoldMessenger.showSnackBar( const SnackBar(content: Text("먼저 대화를 나눠보세요 💬")), );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final allText = currentMessages
          .whereType<types.TextMessage>()
          .where((m) => !m.text.startsWith("오늘의 감정은"))
          .map((m) => "${m.author.id == 'user' ? '사용자: ' : 'AI: '}${m.text}").join("\n");

      final emotion = allText.trim().isEmpty ? "평온" : await _analyzeEmotion(allText);
      final comment = await _generateEmotionComment(emotion);
      final summary = await _generateDiarySummary(allText);

      await _diaryDocRef!.set(
          {
            'emotion': emotion,
            'summary': summary,
            'allText': allText,
            'timestamp': widget.selectedDay,
          },
          SetOptions(merge: true)
      );

      final String emotionEmoji = _getEmojiForEmotion(emotion);
      final emotionMsg = types.TextMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        author: _bot,
        text: "오늘의 감정은 '$emotion' $emotionEmoji 이에요.\n$comment",
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _messagesColRef!.add(emotionMsg.toJson());

      setState(() => _isAnalyzing = false);
      widget.onEmotionAnalyzed(emotion);
      if (_isVoiceMode) { await _speak(emotionMsg.text); }
      scaffoldMessenger.showSnackBar( const SnackBar(content: Text("오늘 일기를 마무리했어요 📔")), );

    } catch (e) {
      setState(() => _isAnalyzing = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("일기 저장 실패: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmDeleteChat() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_diaryDocRef == null || _messagesColRef == null) return;
    if (_isVoiceMode) await _flutterTts.stop();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("채팅 삭제"),
        content: const Text("이 날짜의 모든 채팅, 감정 스티커, 즐겨찾기를 삭제하시겠어요?"),
        actions: [
          TextButton( onPressed: () => Navigator.pop(ctx, false), child: const Text("취소"), ),
          TextButton( onPressed: () => Navigator.pop(ctx, true), child: const Text("삭제", style: TextStyle(color: Colors.red)), ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final messagesSnapshot = await _messagesColRef!.get();
        final batch = _firestore.batch();
        for (final doc in messagesSnapshot.docs) { batch.delete(doc.reference); }
        batch.delete(_diaryDocRef!);
        await batch.commit();
        widget.onEmotionAnalyzed("");
        scaffoldMessenger.showSnackBar( const SnackBar(content: Text("일기와 즐겨찾기가 삭제되었어요 🧹")), );
        navigator.pop(true);
      } catch (e) { scaffoldMessenger.showSnackBar( SnackBar(content: Text("삭제 중 오류 발생: $e")), ); }
    }
  }

  void _handleSendPressed(String text) async {
    if (_messagesColRef == null) return;
    final userMsg = types.TextMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: _user, text: text, createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _messagesColRef!.add(userMsg.toJson());
    final lower = text.trim();
    const endKeywords = [ "끝","그만","이제 그만","오늘은 여기까지","잘래","자고 싶어", "끝내자","끝낼게","끝낼래","그만 쓸래","그만 쓸거야","일기 끝", "수고했어","오늘 기록 끝","이제 쉬자","이제 자야겠다" ];
    final isEndSignal = endKeywords.contains(lower);

    final reply = await _getChatReply(text);

    final botMsg = types.TextMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      author: _bot, text: reply, createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _messagesColRef!.doc(botMsg.id).set(botMsg.toJson());
    if (_isVoiceMode && !isEndSignal) { await _speak(reply); }
    if (isEndSignal) {
      final currentMessagesSnapshot = await _messagesColRef!.orderBy('createdAt', descending: true).get();
      final currentMessages = currentMessagesSnapshot.docs.map((doc) => types.Message.fromJson(doc.data() as Map<String, dynamic>)).toList();
      await _endDiary(currentMessages);
    }
  }

  Future<void> _handleSendImage(String path) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (_messagesColRef == null || _uid == null) return;

    if (_isVoiceMode) await _flutterTts.stop();

    final file = File(path);
    final String tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      final bytes = await file.readAsBytes();
      final image = await decodeImageFromList(bytes);

      final String xfileName = file.path.split('/').last;
      final double imgHeight = image.height.toDouble();
      final double imgWidth = image.width.toDouble();
      final int imgSize = bytes.length;
      final String? mimeType = "image/jpeg";

      final tempMessage = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        height: imgHeight,
        id: tempMessageId,
        name: xfileName,
        size: imgSize,
        uri: path,
        width: imgWidth,
        status: types.Status.sending,
      );
      await _messagesColRef!.doc(tempMessageId).set(tempMessage.toJson());

      final ref = _storage.ref('users/$_uid/images/${_dateKey}_$tempMessageId.jpg');
      final uploadTask = ref.putData(bytes, SettableMetadata(contentType: mimeType));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final finalMessage = tempMessage.copyWith(
        uri: downloadUrl,
        status: types.Status.sent,
      );
      await _messagesColRef!.doc(tempMessageId).update(finalMessage.toJson());

      final reply = await _getChatReplyForImage(bytes, mimeType);
      final botMsg = types.TextMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        author: _bot,
        text: reply,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _messagesColRef!.doc(botMsg.id).set(botMsg.toJson());

      if (_isVoiceMode) {
        await _speak(reply);
      }

    } catch (e) {
      await _messagesColRef!.doc(tempMessageId).update({'status': 'error'});
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("이미지 전송 실패: $e")),
      );
    }
  }

  // 색상을 더 어둡게 만드는 함수 (테마 적용을 위해 필요)
  Color _darkerColor(Color color, [double factor = 0.85]) {
    final HSLColor hsl = HSLColor.fromColor(color);
    final HSLColor darkerHsl = hsl.withLightness((hsl.lightness * factor).clamp(0.0, 1.0));
    return darkerHsl.toColor();
  }

  void _toggleVoiceMode() {
    setState(() => _isVoiceMode = !_isVoiceMode);
    if (_isVoiceMode) {
      HapticFeedback.lightImpact();
      if (!_isAiSpeaking) { _chatInputKey.currentState?.startListening(); }
    } else { _flutterTts.stop(); }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null || _diaryDocRef == null || _messagesColRef == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white),
        body: const Center( child: Text("로그인 정보가 없습니다."), ),
      );
    }

    // ✅ [핵심 수정] main.dart에서 설정한 전체 테마 색상을 가져옵니다.
    final themeColor = Theme.of(context).primaryColor;
    final isDark = themeColor.computeLuminance() < 0.5;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeColor,
        title: Text(
          DateFormat('yyyy/MM/dd').format(widget.selectedDay),
          style: TextStyle(color: textColor),
        ),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _diaryDocRef!.snapshots(),
            builder: (context, snapshot) {
              bool isFavorite = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                isFavorite = data['isFavorite'] ?? false;
              }
              return IconButton(
                tooltip: isFavorite ? '즐겨찾기 해제' : '즐겨찾기',
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? Colors.amber : textColor,
                ),
                onPressed: () => _toggleFavorite(isFavorite),
              );
            },
          ),
          IconButton(
            tooltip: '채팅 삭제',
            icon: Icon(Icons.delete, color: textColor),
            onPressed: _confirmDeleteChat,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_backgroundImagePath != null)
            Image.network(_backgroundImagePath!, fit: BoxFit.cover)
          else
            Container(color: themeColor),
          if (_backgroundImagePath != null)
            Container(color: Colors.black.withOpacity(0.3)),

          StreamBuilder<QuerySnapshot>(
            stream: _messagesColRef!.orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center( child: CircularProgressIndicator(color: textColor), );
              }

              final messages = snapshot.data?.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['createdAt'] is Timestamp) {
                  data['createdAt'] = (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
                }
                return types.Message.fromJson(data);
              }).toList() ?? [];

              if (messages.isEmpty && snapshot.connectionState == ConnectionState.active) {
                _addInitialBotMessage();
              }

              return Chat(
                messages: messages,
                onSendPressed: (types.PartialText message) { },
                user: _user,
                showUserAvatars: true,
                avatarBuilder: (authorId) => const SizedBox.shrink(),
                showUserNames: false,
                theme: DefaultChatTheme(
                  backgroundColor: Colors.transparent,
                  primaryColor: _darkerColor(themeColor, 0.9),
                  secondaryColor: Colors.white.withOpacity(0.9),
                  receivedMessageBodyTextStyle: const TextStyle( color: Colors.black87, fontWeight: FontWeight.w500, ),
                  sentMessageBodyTextStyle: TextStyle( color: textColor, fontWeight: FontWeight.w500, ),
                ),
                customBottomWidget: ChatInput(
                  key: _chatInputKey,
                  onSendMessage: _handleSendPressed,
                  onSendImage: _handleSendImage,
                  themeColor: _darkerColor(themeColor),
                  textColor: textColor,
                ),
              );
            },
          ),
          Positioned(
            top: 16, right: 16,
            child: FloatingActionButton.extended(
              backgroundColor: _darkerColor(themeColor),
              foregroundColor: textColor,
              elevation: 4,
              shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12), side: BorderSide( color: textColor == Colors.black ? Colors.black.withAlpha(64) : Colors.white.withAlpha(128), width: 1.2, ), ),
              label: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isAnalyzing
                    ? const Row( key: ValueKey('loading'), children: [ SizedBox( height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2), ), SizedBox(width: 10), Text("분석 중..."), ], )
                    : Row( key: const ValueKey('default'), children: [ const Icon(Icons.done_all), const SizedBox(width: 8), Text( "일기 마무리", style: TextStyle( color: textColor, fontWeight: FontWeight.bold, fontSize: 14.5, ), ), ], ),
              ),
              onPressed: _isAnalyzing ? null : () async {
                final snapshot = await _messagesColRef!.orderBy('createdAt', descending: true).get();
                final currentMessages = snapshot.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['createdAt'] is Timestamp) { data['createdAt'] = (data['createdAt'] as Timestamp).millisecondsSinceEpoch; }
                  return types.Message.fromJson(data);
                }).toList();
                await _endDiary(currentMessages);
              },
            ),
          ),
          Positioned(
            top: 80, right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: _darkerColor(themeColor),
              foregroundColor: _isVoiceMode ? Colors.blueAccent : textColor,
              elevation: 4,
              shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12), side: BorderSide( color: textColor == Colors.black ? Colors.black.withAlpha(64) : Colors.white.withAlpha(128), width: 1.2, ), ),
              onPressed: _toggleVoiceMode,
              tooltip: '음성 대화 모드',
              child: Icon( _isVoiceMode ? Icons.volume_up : Icons.volume_off_outlined, ),
            ),
          ),
        ],
      ),
    );
  }
}