// lib/chat_input.dart (사진 첨부 아이콘 및 기능 추가)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart'; // ✅ [추가] 이미지 피커

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(String) onSendImage; // ✅ [추가] 이미지 전송 콜백
  final Color themeColor;
  final Color textColor;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    required this.onSendImage, // ✅ [추가]
    required this.themeColor,
    required this.textColor,
  });

  @override
  State<ChatInput> createState() => ChatInputState();
}

class ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ImagePicker _picker = ImagePicker(); // ✅ [추가] 이미지 피커 인스턴스

  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) => print('Speech error: $error'),
      onStatus: (status) {
        if (status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() {});
  }

  /// 텍스트 전송 버튼 (내부 사용)
  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    widget.onSendMessage(text);
    _controller.clear();
  }

  // ▼▼▼▼▼ [신규] 이미지 선택 함수 ▼▼▼▼▼
  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // 사진 품질 압축 (저장 용량 및 속도)
      );

      if (image != null) {
        // 이미지를 선택했으면 chat_page로 파일 경로를 전달
        widget.onSendImage(image.path);
      }
    } catch (e) {
      print("❌ Image picking error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("사진을 불러오는데 실패했습니다.")),
        );
      }
    }
  }
  // ▲▲▲▲▲ [신규] 이미지 선택 함수 ▲▲▲▲▲


  /// (Public) 외부에서 마이크를 켤 때 호출 (AI가 호출)
  Future<void> startListening() async {
    if (_isListening) return;
    if (!_speechAvailable) return;

    HapticFeedback.lightImpact();
    await _speech.listen(
      localeId: 'ko_KR',
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
        if (result.finalResult && _controller.text.isNotEmpty) {
          _sendMessage();
        }
      },
    );
    setState(() => _isListening = true);
  }

  /// (Private) 사용자가 마이크 아이콘을 직접 탭할 때 호출
  Future<void> _toggleListeningByUser() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("음성 인식이 현재 지원되지 않습니다.")),
      );
      return;
    }

    if (!_isListening) {
      await startListening();
    } else {
      await _speech.stop();
      setState(() => _isListening = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.themeColor,
        border: Border(
          top: BorderSide(
            color: widget.textColor == Colors.black
                ? Colors.black.withAlpha(51) // 0.2
                : Colors.white.withAlpha(128), // 0.5
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // ▼▼▼ [신규] 사진 첨부 버튼 🏞️ ▼▼▼
            IconButton(
              icon: Icon(
                Icons.photo_library_outlined,
                color: widget.textColor.withAlpha(204),
              ),
              onPressed: _pickImage,
            ),
            // ▲▲▲ [신규] 사진 첨부 버튼 🏞️ ▲▲▲

            // 마이크 버튼 🎤
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.redAccent : widget.textColor.withAlpha(204),
              ),
              onPressed: _toggleListeningByUser,
            ),

            // 텍스트 입력창
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.textColor == Colors.black
                      ? Colors.black.withAlpha(15) // 0.06
                      : Colors.white.withAlpha(40), // 0.15
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  style: TextStyle(color: widget.textColor),
                  decoration: InputDecoration(
                    hintText: "메시지를 입력하거나 말하세요...",
                    hintStyle: TextStyle(color: widget.textColor.withAlpha(153)), // 0.6
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),

            // 전송 버튼 📩
            IconButton(
              icon: Icon(Icons.send, color: widget.textColor.withAlpha(204)),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}