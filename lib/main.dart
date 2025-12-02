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

// FCM
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("🔔 [FCM] Handling a background message: ${message.messageId}");
}

const String FONT_FAMILY_KEY = '_app_font_family';
const String KEY_THEME_COLOR = '_theme_color_index'; // ✅ [추가] 테마 키

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  await NotificationService().init();

  final micStatus = await Permission.microphone.request();
  if (micStatus.isDenied) {
    debugPrint("⚠️ 마이크 권한이 거부되었습니다.");
  }

  runApp(const AilgiApp());
}

class AilgiApp extends StatefulWidget {
  const AilgiApp({super.key});

  @override
  State<AilgiApp> createState() => _AilgiAppState();
}

class _AilgiAppState extends State<AilgiApp> {
  Color _themeColor = Colors.white; // 기본값
  String _appFontFamily = 'SystemDefault';
  String? _currentUid;

  // ✅ [추가] SettingsPage와 동일한 색상 리스트 (저장된 번호로 색상을 찾기 위해 필요)
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

  @override
  void initState() {
    super.initState();
    _loadSavedTheme(); // ✅ [중요] 앱 시작 시 저장된 테마 로드
    _listenToAuthChanges();
  }

  // ✅ [신규] 저장된 테마(색상, 폰트)를 불러오는 함수
  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // 1. 폰트 로드
    final fontKey = "${uid ?? 'GUEST'}$FONT_FAMILY_KEY";
    final savedFont = prefs.getString(fontKey) ?? 'SystemDefault';

    // 2. 색상 로드 (인덱스 번호로 저장됨)
    final themeKey = "${uid ?? 'GUEST'}$KEY_THEME_COLOR";
    final savedColorIndex = prefs.getInt(themeKey) ?? 0;

    if (mounted) {
      setState(() {
        _appFontFamily = savedFont;
        // 저장된 번호가 유효하면 색상 적용
        if (savedColorIndex >= 0 && savedColorIndex < pastelColors.length) {
          _themeColor = pastelColors[savedColorIndex];
        }
      });
    }
  }

  void _listenToAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      final newUid = user?.uid;
      if (newUid != _currentUid) {
        _currentUid = newUid;
        _loadSavedTheme(); // ✅ 로그인 사용자 변경 시 해당 사용자의 테마 로드
        if (newUid != null) {
          _initFCM();
        }
      }
    });
  }

  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        NotificationService().showSimpleNotification(
          title: message.notification?.title ?? "새 알림",
          body: message.notification?.body ?? "",
          uid: _currentUid, // 알림 기록 저장을 위해 UID 전달
        );
      }
    });

    _getAndSaveToken();
    messaging.onTokenRefresh.listen(_getAndSaveToken);
  }

  Future<void> _getAndSaveToken([String? token]) async {
    if (_currentUid == null) return;
    final fcmToken = token ?? await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUid).set({
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving token: $e");
    }
  }

  // SettingsPage에서 색상을 바꿨을 때 호출됨
  void _updateTheme(Color newColor) {
    setState(() => _themeColor = newColor);
    _loadSavedTheme(); // 폰트 등 다른 설정도 확실하게 동기화
  }

  @override
  Widget build(BuildContext context) {
    final font = _appFontFamily == 'SystemDefault' ? null : _appFontFamily;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ailgi',
      theme: ThemeData(
        // ✅ [핵심] 앱 전체의 기본 색상과 배경색을 강제로 지정하여 통일감 부여
        colorScheme: ColorScheme.fromSeed(
          seedColor: _themeColor,
          brightness: Brightness.light,
          primary: _themeColor,
          surface: _themeColor,
          background: _themeColor,
        ),
        scaffoldBackgroundColor: _themeColor, // 모든 페이지 배경색 통일
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
        useMaterial3: true,
      ),
      home: AuthCheckScreen(onThemeChanged: _updateTheme),
    );
  }
}