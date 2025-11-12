// lib/auth_check_screen.dart (최종 전체 코드)

import 'package:flutter/material.dart'; // ✅ 이 임포트가 정상적으로 인식되어야 합니다.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:passcode_screen/passcode_screen.dart';
import 'package:passcode_screen/circle.dart';
import 'package:passcode_screen/keyboard.dart';
import 'dart:async'; // StreamController를 위해 추가

import 'package:google_sign_in/google_sign_in.dart';

import 'calendar_page.dart';
import 'login_page.dart';

// SharedPreferences 키 정의 (settings_page.dart와 동일)
const String storedPinKey = '_my_diary_pin_code';
const String passcodeEnabledKey = '_passcode_enabled';
const String passcodeLengthKey = '_passcode_length';

class AuthCheckScreen extends StatelessWidget {
  final void Function(Color) onThemeChanged;

  const AuthCheckScreen({
    super.key,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Firebase 로그인 상태를 먼저 확인합니다.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. Firebase에 로그인 되어 있는 경우 (hasData == true)
        if (snapshot.hasData && snapshot.data != null) {
          // 3. 앱 비밀번호(PIN) 잠금 게이트를 통과하도록 합니다.
          return _PinLockGate(onThemeChanged: onThemeChanged);
        }

        // 4. Firebase에 로그인 되어 있지 않은 경우
        return const LoginPage(); // 로그인 페이지를 보여줍니다.
      },
    );
  }
}

// ✅ 이 위젯은 사용자가 Firebase에 *로그인*한 상태에서만 실행됩니다.
class _PinLockGate extends StatefulWidget {
  final void Function(Color) onThemeChanged;
  const _PinLockGate({required this.onThemeChanged});

  @override
  State<_PinLockGate> createState() => _PinLockGateState();
}

class _PinLockGateState extends State<_PinLockGate> with WidgetsBindingObserver {
  bool _isCheckingStatus = true; // PIN 설정 확인 중인지
  bool _isLocked = true; // 앱이 잠겨있는지 (기본값: 잠김)

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String _getPrefKey(String suffix) {
    return "${_uid ?? 'GUEST'}$suffix";
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 앱 상태 감지기 등록
    _checkPasscodeStatusAndShow(); // 앱 시작 시 PIN 확인
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱이 백그라운드 -> 포그라운드로 돌아올 때 (resumed) 다시 잠금
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPasscodeStatusAndShow();
    }
  }

  Future<void> _checkPasscodeStatusAndShow() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_getPrefKey(passcodeEnabledKey)) ?? false;

    if (isEnabled) {
      // PIN 기능이 켜져 있으면
      if (mounted) {
        setState(() {
          _isLocked = true; // 잠금 상태로
          _isCheckingStatus = false; // 확인 완료
        });
        _showPasscodeScreen(prefs); // PIN 화면 띄우기
      }
    } else {
      // PIN 기능이 꺼져 있으면
      if (mounted) {
        setState(() {
          _isLocked = false; // 잠금 해제
          _isCheckingStatus = false; // 확인 완료
        });
      }
    }
  }

  // --- ⬇️ 이 함수가 수정되었습니다 ⬇️ ---
  void _showPasscodeScreen(SharedPreferences prefs) async {
    final storedPin = prefs.getString(_getPrefKey(storedPinKey)) ?? '';
    final pinLength = prefs.getInt(_getPrefKey(passcodeLengthKey)) ?? 6;
    final StreamController<bool> _verificationNotifier = StreamController<bool>.broadcast();

    // ✅ (수정) cancelCallback에서 현재 uid를 참조할 수 있도록 변수로 미리 선언
    final currentUid = _uid;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false, // 배경이 비치도록
        pageBuilder: (context, animation, secondaryAnimation) => PasscodeScreen(
          title: const Text('앱 잠금 해제', style: TextStyle(color: Colors.white, fontSize: 18)),
          circleUIConfig: const CircleUIConfig(borderColor: Colors.blue, fillColor: Colors.blue),
          keyboardUIConfig: const KeyboardUIConfig(primaryColor: Colors.white, digitTextStyle: TextStyle(color: Colors.white, fontSize: 20)),

          passwordEnteredCallback: (enteredPasscode) {
            bool isValid = (enteredPasscode == storedPin);
            if (isValid) {
              setState(() { _isLocked = false; }); // ✅ 잠금 해제
              Navigator.pop(context);
            } else {
              _verificationNotifier.add(false); // PIN 틀림 알림
            }
          },

          cancelButton: const Icon(Icons.logout, color: Colors.white),
          deleteButton: const Text('삭제', style: TextStyle(color: Colors.white, fontSize: 16)),
          shouldTriggerVerification: _verificationNotifier.stream,

          backgroundColor: Colors.black.withOpacity(0.9),

          // --- ⬇️ 이 부분이 수정되었습니다 ⬇️ ---
          cancelCallback: () async {
            // '취소' (로그아웃 아이콘) 누르면

            // ✅ 1. 로컬 PIN 정보 먼저 삭제
            if (currentUid != null) {
              final String pinKey = "${currentUid}$storedPinKey";
              final String enableKey = "${currentUid}$passcodeEnabledKey";
              final String lengthKey = "${currentUid}$passcodeLengthKey";

              // SharedPreferences 인스턴스는 'prefs' 변수로 이미 가지고 있습니다.
              await prefs.remove(pinKey);
              await prefs.setBool(enableKey, false); // 비활성화 상태로 명시적 저장
              await prefs.remove(lengthKey);
            }

            // ✅ 2. Firebase 및 Google 로그아웃
            await GoogleSignIn().signOut();
            await FirebaseAuth.instance.signOut();

            // (로그아웃되면 AuthCheckScreen의 StreamBuilder가 자동으로 LoginPage로 보냄)
          },
          // --- ⬆️ 이 부분이 수정되었습니다 ⬆️ ---

          passwordDigits: pinLength,
        ),
      ),
    );
  }
  // --- ⬆️ 이 함수가 수정되었습니다 ⬆️ ---

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus) {
      // 1. PIN 설정 여부 확인 중 (로딩)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLocked) {
      // 2. PIN이 켜져 있고, 아직 잠금 해제 안 됨 (배경만 표시)
      // (PasscodeScreen이 이 위를 덮고 있음)
      return const Scaffold(
        body: Center(child: Text("앱이 잠겨 있습니다...")),
      );
    }

    // 3. PIN 기능이 꺼져 있거나, 잠금 해제 성공
    return CalendarPage(onThemeChanged: widget.onThemeChanged);
  }
}