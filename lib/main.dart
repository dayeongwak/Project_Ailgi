// lib/main.dart (FCM 초기화 및 토큰 저장 로직 추가)

import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'auth_check_screen.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// ✅ [FCM 추가] Firebase Messaging 및 Firestore 임포트
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


// ✅ [FCM 추가] 앱이 백그라운드/종료 상태일 때 메시지를 처리하기 위한 최상위 함수
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 격리(isolate)에서 실행되므로 Firebase를 다시 초기화해야 합니다.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("🔔 [FCM] Handling a background message: ${message.messageId}");
  // (참고: 여기서는 data-only 메시지 처리에 유용합니다.
  //  notification 페이로드는 FCM이 자동으로 표시합니다.)
}


const String FONT_FAMILY_KEY = '_app_font_family';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ [FCM 추가] 백그라운드 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  await NotificationService().init(); // 로컬 알림 서비스 초기화
  final micStatus = await Permission.microphone.request();
  if (micStatus.isDenied) {
    debugPrint("⚠️ 마이크 권한이 거부되었습니다. 음성 인식이 제한됩니다.");
  }

  runApp(const AilgiApp());
}

class AilgiApp extends StatefulWidget {
  const AilgiApp({super.key});

  @override
  State<AilgiApp> createState() => _AilgiAppState();
}

class _AilgiAppState extends State<AilgiApp> {
  Color _themeColor = const Color(0xFFF0F8FF);
  String _appFontFamily = 'SystemDefault';

  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges(); // 로그인 상태 변경 구독 시작
  }

  // ✅ [수정됨] 로그인 상태 변경 시 FCM 초기화 호출
  void _listenToAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      final newUid = user?.uid;

      if (newUid != _currentUid) {
        _currentUid = newUid;
        _loadFontFamily(); // 폰트 설정을 새로 로드

        // ✅ [FCM 추가] 사용자가 로그인하면(newUid != null) FCM 초기화 및 토큰 저장
        if (newUid != null) {
          _initFCM();
        }
      }
    });
  }

  // ▼▼▼ [FCM 신규] FCM 초기화 (권한 요청, 포그라운드 리스너, 토큰) ▼▼▼
  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;
    final firestore = FirebaseFirestore.instance;

    // 1. (iOS, Android 13+) 푸시 알림 권한 요청
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print('🔔 [FCM] User granted permission: ${settings.authorizationStatus}');

    // 2. 앱이 켜져있을 때(포그라운드) 알림 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 [FCM] Got a message whilst in the foreground!');

      if (message.notification != null) {
        print('🔔 [FCM] Notification: ${message.notification?.title} / ${message.notification?.body}');

        // (선택사항) 앱이 켜져 있을 때도 로컬 알림으로 띄우기
        // (현재 로컬 알림 서비스가 설정되어 있으므로 이를 활용합니다)
        NotificationService().showSimpleNotification(
          title: message.notification?.title ?? "새 알림",
          body: message.notification?.body ?? "",
        );
      }
    });

    // 3. 토큰 저장 및 갱신 리스너 등록
    _getAndSaveToken(); // 앱 시작 시 토큰 저장
    messaging.onTokenRefresh.listen(_getAndSaveToken); // 토큰 갱신 시 저장
  }

  // ▼▼▼ [FCM 신규] FCM 토큰을 가져와 Firestore에 저장 ▼▼▼
  Future<void> _getAndSaveToken([String? token]) async {
    if (_currentUid == null) {
      print("🔔 [FCM] User not logged in. Token save skipped.");
      return; // 로그인이 안 되어있으면 저장 안 함
    }

    final fcmToken = token ?? await FirebaseMessaging.instance.getToken();

    if (fcmToken == null) {
      print("🔔 [FCM] Unable to get FCM token.");
      return;
    }

    print("🔔 [FCM] Token: $fcmToken");

    try {
      // 'users' 컬렉션의 내 문서에 fcmToken 필드를 업데이트(또는 생성)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .set({
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("🔔 [FCM] Token saved to Firestore for user: $_currentUid");
    } catch (e) {
      print("🔔 [FCM] Error saving token to Firestore: $e");
    }
  }
  // ▲▲▲ [FCM 신규] FCM 토큰 저장 로직 ▲▲▲


  void _updateTheme(Color newColor) {
    setState(() => _themeColor = newColor);
    _loadFontFamily();
  }

  Future<void> _loadFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    final key = "${_currentUid ?? 'GUEST'}$FONT_FAMILY_KEY";

    if (mounted) {
      setState(() {
        _appFontFamily = prefs.getString(key) ?? 'SystemDefault';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final font = _appFontFamily == 'SystemDefault' ? null : _appFontFamily;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ailgi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _themeColor,
          brightness: Brightness.light,
        ),
        fontFamily: font,
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: _themeColor,
          foregroundColor: _themeColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _themeColor.computeLuminance() > 0.5 ? Colors.grey.shade800 : _themeColor,
          foregroundColor: _themeColor.computeLuminance() > 0.5 ? Colors.white : Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _themeColor.computeLuminance() > 0.5 ? Colors.grey.shade800 : _themeColor,
            foregroundColor: _themeColor.computeLuminance() > 0.5 ? Colors.white : Colors.black,
          ),
        ),
        useMaterial3: true,
      ),
      home: AuthCheckScreen(onThemeChanged: _updateTheme),
    );
  }
}