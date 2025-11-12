// lib/settings_page.dart (FCM을 위해 알림 설정을 Firestore에도 저장)

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:passcode_screen/circle.dart';
import 'package:passcode_screen/keyboard.dart';
import 'package:passcode_screen/passcode_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'notification_service.dart';

// Firebase 및 Google 임포트
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_storage/firebase_storage.dart';

// 페이지 및 설정 임포트
import 'friend_feed_page.dart';
import 'font_config.dart';
import 'help_page.dart';
import 'hidden_friends_page.dart';

// SharedPreferences 키 정의
const String storedPinKey = '_my_diary_pin_code';
const String passcodeEnabledKey = '_passcode_enabled';
const String passcodeLengthKey = '_passcode_length';
const String FONT_FAMILY_KEY = '_app_font_family';
const String KEY_BACKGROUND_URL = '_app_background_image_url';
const String KEY_THEME_COLOR = '_theme_color_index';

// 알림 키 정의 (Firestore에서도 이 키를 그대로 사용)
const String KEY_ALL_NOTIFY_ENABLED = '_all_notify_enabled';
const String KEY_DAILY_NOTIFY_ENABLED = '_daily_push_notify_enabled';
const String KEY_NOTIFY_TIME = '_notify_time';
const String KEY_FRIEND_REQUEST_NOTIFY_ENABLED = '_friend_request_notify_enabled';
const String KEY_LIKE_NOTIFY_ENABLED = '_like_notify_enabled';
const String KEY_COMMENT_NOTIFY_ENABLED = '_comment_notify_enabled';

class SettingsPage extends StatefulWidget {
  final ValueChanged<Color> onThemeChanged;
  const SettingsPage({super.key, required this.onThemeChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- 상태 변수 ---
  bool _isPasscodeEnabled = false;
  int _currentPinLength = 6;
  final StreamController<bool> _verificationNotifier = StreamController<bool>.broadcast();

  bool _isAllNotifyEnabled = true;
  bool _isDailyNotifyEnabled = true;
  bool _isFriendRequestNotifyEnabled = true;
  bool _isLikeNotifyEnabled = true;
  bool _isCommentNotifyEnabled = true;

  String _notifyTimeString = '21:00';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 21, minute: 0);

  String _currentNickname = 'Guest';
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _statusMessageController = TextEditingController();

  String? _profileImageUrl;
  bool _isUploading = false;

  final List<String> _availableFonts = ['SystemDefault', 'MemomentKkuk'];
  String _selectedFontFamily = 'SystemDefault';
  String? _currentBackgroundImageUrl;
  int _selectedColorIndex = 0;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  String? get _uid => _auth.currentUser?.uid;
  String _getPrefKey(String suffix) {
    return "${_uid ?? 'GUEST'}$suffix";
  }

  // Pastel Colors 리스트
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
    _loadAllSettings();
    _loadProfileData();
    _loadFontSetting();
    _loadBackgroundImage();
  }

  @override
  void dispose() {
    _verificationNotifier.close();
    _nicknameController.dispose();
    _statusMessageController.dispose();
    super.dispose();
  }

  // --- 1. 설정 및 프로필 로드 함수 ---
  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPasscodeEnabled = prefs.getBool(_getPrefKey(passcodeEnabledKey)) ?? false;
      _currentPinLength = prefs.getInt(_getPrefKey(passcodeLengthKey)) ?? 6;
      _selectedColorIndex = prefs.getInt(_getPrefKey(KEY_THEME_COLOR)) ?? 0;

      // SharedPreferences에서 알림 설정을 읽어옴 (FCM 설정과 무관)
      _isAllNotifyEnabled = prefs.getBool(_getPrefKey(KEY_ALL_NOTIFY_ENABLED)) ?? true;
      _isDailyNotifyEnabled = prefs.getBool(_getPrefKey(KEY_DAILY_NOTIFY_ENABLED)) ?? true;
      _isFriendRequestNotifyEnabled = prefs.getBool(_getPrefKey(KEY_FRIEND_REQUEST_NOTIFY_ENABLED)) ?? true;
      _isLikeNotifyEnabled = prefs.getBool(_getPrefKey(KEY_LIKE_NOTIFY_ENABLED)) ?? true;
      _isCommentNotifyEnabled = prefs.getBool(_getPrefKey(KEY_COMMENT_NOTIFY_ENABLED)) ?? true;

      _notifyTimeString = prefs.getString(_getPrefKey(KEY_NOTIFY_TIME)) ?? '21:00';
      final parts = _notifyTimeString.split(':');
      _selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    });
  }

  Future<void> _loadProfileData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final nickname = data['nickname'] as String? ?? 'Guest';
        final profileUrl = data['profileUrl'] as String?;
        final statusMessage = data['statusMessage'] as String? ?? '';

        if (mounted) {
          setState(() {
            _currentNickname = nickname;
            _nicknameController.text = nickname;
            _statusMessageController.text = statusMessage;
            _profileImageUrl = profileUrl;
          });
        }
      }
    } catch (e) {
      print("❌ Profile Data Load Error: $e");
    }
  }

  Future<void> _loadFontSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if(mounted) {
      setState(() {
        _selectedFontFamily = prefs.getString(_getPrefKey(FONT_FAMILY_KEY)) ?? 'SystemDefault';
      });
    }
  }

  Future<void> _loadBackgroundImage() async {
    final prefs = await SharedPreferences.getInstance();
    if(mounted) {
      setState(() {
        _currentBackgroundImageUrl = prefs.getString(_getPrefKey(KEY_BACKGROUND_URL));
      });
    }
  }

// --- 2. 설정 저장 함수 ---

  // (SharedPreferences 전용 저장 함수)
  Future<void> _saveSingleSetting<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(_getPrefKey(key), value);
    } else if (value is String) {
      await prefs.setString(_getPrefKey(key), value);
    } else if (value is int) {
      await prefs.setInt(_getPrefKey(key), value);
    }
  }

  // ▼▼▼ [FCM 신규] 알림 설정을 SharedPreferences와 Firestore에 동시 저장 ▼▼▼
  Future<void> _saveNotificationSetting(String key, bool value) async {
    if (_uid == null) return; // 로그인 상태가 아니면 저장 안 함

    // 1. (휴대폰) SharedPreferences에 저장 (앱이 읽는 용도)
    await _saveSingleSetting(key, value);

    // 2. (서버) Firestore 'users' 문서에 저장 (서버가 읽는 용도)
    try {
      // (중요) Firestore에는 UID 접두사(_getPrefKey) 없이 원본 키(key)로 저장
      await _firestore.collection('users').doc(_uid).set(
        { key: value }, // 예: { '_all_notify_enabled': true }
        SetOptions(merge: true),
      );
    } catch (e) {
      print("❌ Firestore 알림 설정 저장 실패: $e");
    }
  }
  // ▲▲▲ [FCM 신규] 알림 설정을 SharedPreferences와 Firestore에 동시 저장 ▲▲▲

  Future<void> _saveFontSetting(String newFont) async {
    await _saveSingleSetting(FONT_FAMILY_KEY, newFont); // 폰트는 SP에만 저장
    if (mounted) {
      setState(() { _selectedFontFamily = newFont; });
      widget.onThemeChanged(Theme.of(context).primaryColor);
      Navigator.pop(context);
    }
  }

  Future<void> _saveNickname() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final newNickname = _nicknameController.text.trim();
    if (newNickname.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }
    try {
      final querySnapshot = await _firestore.collection('users').where('nickname', isEqualTo: newNickname).limit(1).get();
      if (querySnapshot.docs.isNotEmpty && querySnapshot.docs.first.id != uid) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미 사용 중인 닉네임입니다.')));
        return;
      }
      await _firestore.collection('users').doc(uid).set({'nickname': newNickname}, SetOptions(merge: true));
      if (mounted) {
        setState(() { _currentNickname = newNickname; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임이 저장되었습니다.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('닉네임 저장 오류: $e')));
    }
  }

  Future<void> _saveStatusMessage() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final newStatus = _statusMessageController.text.trim();
    try {
      await _firestore.collection('users').doc(uid).set({
        'statusMessage': newStatus,
      }, SetOptions(merge: true));
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('상태 메시지가 저장되었습니다.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 오류: $e')));
    }
  }

  Future<void> _uploadProfilePicture() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;
    setState(() => _isUploading = true);
    try {
      final file = File(image.path);
      final ref = _storage.ref().child('profiles/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      await _firestore.collection('users').doc(uid).set({'profileUrl': downloadUrl}, SetOptions(merge: true));
      if (mounted) {
        setState(() { _profileImageUrl = downloadUrl; _isUploading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필 사진이 업데이트되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사진 업로드 실패: $e')));
      }
    }
  }

  Future<void> _pickAndUploadBackground() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;
    setState(() => _isUploading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final file = File(image.path);
      final ref = _storage.ref().child('users/$uid/background/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      await _saveSingleSetting(KEY_BACKGROUND_URL, downloadUrl); // SP에만 저장
      if (mounted) {
        setState(() { _currentBackgroundImageUrl = downloadUrl; _isUploading = false; });
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('배경 이미지가 설정되었습니다. ✨')));
      }
      widget.onThemeChanged(Theme.of(context).primaryColor);
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('배경 설정 실패: $e')));
      }
    }
  }

  Future<void> _removeBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await prefs.remove(_getPrefKey(KEY_BACKGROUND_URL)); // SP에서만 제거
    if (mounted) {
      setState(() { _currentBackgroundImageUrl = null; });
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('배경 이미지가 제거되었습니다.')));
      widget.onThemeChanged(Theme.of(context).primaryColor);
    }
  }

  Future<void> _saveThemeSetting(int index) async {
    await _saveSingleSetting(KEY_THEME_COLOR, index); // SP에만 저장
    if (mounted) {
      setState(() { _selectedColorIndex = index; });
      widget.onThemeChanged(pastelColors[index]);
      Navigator.pop(context);
    }
  }

  // --- 4. 비밀번호 설정 함수들 (PIN 변경) ---
  _showSetPasscodeScreen({int? initialLength}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          int tempLength = initialLength ?? _currentPinLength;
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              void updateLength(int newLength) {
                setModalState(() {
                  tempLength = newLength;
                });
              }
              return PasscodeScreen(
                title: Text('새 비밀번호 설정 (${tempLength}자리)', style: const TextStyle(color: Colors.white, fontSize: 18)),
                circleUIConfig: const CircleUIConfig(borderColor: Colors.blue, fillColor: Colors.blue),
                keyboardUIConfig: const KeyboardUIConfig(primaryColor: Colors.white, digitTextStyle: TextStyle(color: Colors.white, fontSize: 20)),
                passwordEnteredCallback: (enteredPasscode) async {
                  await _saveSingleSetting(storedPinKey, enteredPasscode); // SP에만 저장
                  await _saveSingleSetting(passcodeEnabledKey, true); // SP에만 저장
                  await _saveSingleSetting(passcodeLengthKey, tempLength); // SP에만 저장

                  setState(() {
                    _isPasscodeEnabled = true;
                    _currentPinLength = tempLength;
                  });
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('비밀번호가 설정되었습니다.')),
                    );
                  }
                },
                cancelButton: const Icon(Icons.arrow_back, color: Colors.white),
                deleteButton: const Text('삭제', style: TextStyle(color: Colors.white, fontSize: 16)),
                shouldTriggerVerification: _verificationNotifier.stream,
                backgroundColor: Colors.black.withOpacity(0.8),
                cancelCallback: _onPasscodeCancelled,
                passwordDigits: tempLength,
                bottomWidget: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLengthButton(4, tempLength, updateLength),
                    const SizedBox(width: 20),
                    _buildLengthButton(6, tempLength, updateLength),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLengthButton(int length, int currentTempLength, Function(int) updateLength) {
    bool isSelected = length == currentTempLength;
    return TextButton(
      onPressed: () => updateLength(length),
      child: Text(
        '${length}자리',
        style: TextStyle(
          color: isSelected ? Colors.blueAccent : Colors.white,
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          decoration: isSelected ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
    );
  }

  void _onPasscodeCancelled() {
    Navigator.maybePop(context);
  }

  void _showChangePasscodeScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final String storedPin = prefs.getString(_getPrefKey(storedPinKey)) ?? '';
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => PasscodeScreen(
          title: const Text('기존 비밀번호 입력', style: TextStyle(color: Colors.white, fontSize: 18)),
          circleUIConfig: const CircleUIConfig(borderColor: Colors.blue, fillColor: Colors.blue),
          keyboardUIConfig: const KeyboardUIConfig(primaryColor: Colors.white, digitTextStyle: TextStyle(color: Colors.white, fontSize: 20)),
          passwordEnteredCallback: (enteredPin) {
            bool isValid = (enteredPin == storedPin);
            if (isValid) {
              Navigator.pop(context);
              _showSetPasscodeScreen(initialLength: _currentPinLength);
            } else {
              _verificationNotifier.add(false);
            }
          },
          cancelButton: const Icon(Icons.arrow_back, color: Colors.white),
          deleteButton: const Text('삭제', style: TextStyle(color: Colors.white, fontSize: 16)),
          shouldTriggerVerification: _verificationNotifier.stream,
          backgroundColor: Colors.black.withOpacity(0.8),
          cancelCallback: _onPasscodeCancelled,
          passwordDigits: _currentPinLength,
        ),
      ),
    );
  }


  // --- 5. 알림 함수들 ---

  // ▼▼▼ [수정됨] 모든 알림 핸들러가 _saveNotificationSetting 사용 ▼▼▼

  // (1) 마스터 스위치 핸들러
  Future<void> _onAllNotifySwitchChanged(bool v) async {
    setState(() => _isAllNotifyEnabled = v);
    await _saveNotificationSetting(KEY_ALL_NOTIFY_ENABLED, v); // ✅ Firestore 저장

    if (!v) {
      await NotificationService().cancelAllNotifications();
      setState(() => _isDailyNotifyEnabled = false);
      await _saveNotificationSetting(KEY_DAILY_NOTIFY_ENABLED, false); // ✅ Firestore 저장
    } else {
      if (_isDailyNotifyEnabled) {
        await NotificationService().rescheduleNotification(_uid);
      }
    }
  }

  // (2) 매일 알림 (푸시) 핸들러
  Future<void> _onDailyNotifySwitchChanged(bool v) async {
    setState(() => _isDailyNotifyEnabled = v);
    await _saveNotificationSetting(KEY_DAILY_NOTIFY_ENABLED, v); // ✅ Firestore 저장

    if (_isAllNotifyEnabled) {
      if (v) {
        await NotificationService().rescheduleNotification(_uid);
      } else {
        await NotificationService().cancelAllNotifications();
      }
    }
  }

  // (3) 친구 요청 (푸시) 핸들러
  Future<void> _onFriendRequestNotifySwitchChanged(bool v) async {
    setState(() => _isFriendRequestNotifyEnabled = v);
    await _saveNotificationSetting(KEY_FRIEND_REQUEST_NOTIFY_ENABLED, v); // ✅ Firestore 저장
  }

  // (4) 공감 (푸시) 핸들러
  Future<void> _onLikeNotifySwitchChanged(bool v) async {
    setState(() => _isLikeNotifyEnabled = v);
    await _saveNotificationSetting(KEY_LIKE_NOTIFY_ENABLED, v); // ✅ Firestore 저장
  }

  // (5) 댓글 (푸시) 핸들러
  Future<void> _onCommentNotifySwitchChanged(bool v) async {
    setState(() => _isCommentNotifyEnabled = v);
    await _saveNotificationSetting(KEY_COMMENT_NOTIFY_ENABLED, v); // ✅ Firestore 저장
  }
  // ▲▲▲ [수정됨] 모든 알림 핸들러가 _saveNotificationSetting 사용 ▲▲▲


  // (6) 알림 시간 설정
  Future<void> _onTimeTapped() async {
    final picked = await showTimePicker(
        context: context,
        initialTime: _selectedTime
    );
    if (picked != null) {
      final newTimeString = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      setState(() {
        _selectedTime = picked;
        _notifyTimeString = newTimeString;
      });
      // (알림 시간은 서버가 알 필요 없으므로 SP에만 저장)
      await _saveSingleSetting(KEY_NOTIFY_TIME, newTimeString);

      if (_isAllNotifyEnabled && _isDailyNotifyEnabled) {
        await NotificationService().rescheduleNotification(_uid);
      }
    }
  }


  // --- 6. 계정 연동/로그아웃 함수들 ---
  Future<void> _linkWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final User? user = _auth.currentUser;
      if (user == null) return;
      await user.linkWithCredential(credential);
      if (_currentNickname == 'Guest' && googleUser.displayName != null) {
        await _firestore.collection('users').doc(user.uid).set(
            {'nickname': googleUser.displayName, 'email': user.email},
            SetOptions(merge: true)
        );
        if(mounted) setState(() => _currentNickname = googleUser.displayName!);
      }
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google 계정이 연동되었습니다!')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'credential-already-in-use') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이 Google 계정은 이미 다른 사용자와 연결되어 있습니다.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('연동 실패: ${e.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연동 실패: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃 하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('확인', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final uid = _auth.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();

    // ▼▼▼ [FCM 수정] 로그아웃 시 토큰 제거 ▼▼▼
    if (uid != null) {
      // 서버에서 FCM 토큰 제거 (푸시 알림 중지)
      try {
        await _firestore.collection('users').doc(uid).set(
          { 'fcmToken': FieldValue.delete() },
          SetOptions(merge: true),
        );
      } catch (e) {
        print("❌ FCM 토큰 제거 실패: $e");
      }

      // 로컬 SP에서 PIN 정보 제거 (기존 로직)
      final String pinKey = "${uid}$storedPinKey";
      final String enableKey = "${uid}$passcodeEnabledKey";
      final String lengthKey = "${uid}$passcodeLengthKey";

      await prefs.remove(pinKey);
      await prefs.setBool(enableKey, false);
      await prefs.remove(lengthKey);
    }
    // ▲▲▲ [FCM 수정] 로그아웃 시 토큰 제거 ▲▲▲

    await GoogleSignIn().signOut();
    await _auth.signOut();

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // --- 7. UI 빌드 ---
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('환경설정'),
      ),
      body: ListView(
        children: [
          // --- 7-1. 프로필 섹션 ---
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 20),
            child: Center(child: Column(children: [
              GestureDetector(onTap: _uploadProfilePicture, child: Stack(children: [
                CircleAvatar(radius: 40, backgroundColor: Colors.blue.shade100, backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty ? NetworkImage(_profileImageUrl!) : null, child: _profileImageUrl == null || _profileImageUrl!.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.blue) : null,),
                if (_isUploading) const Positioned.fill(child: Center(child: CircularProgressIndicator(strokeWidth: 3)))
                else const Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Icon(Icons.camera_alt, size: 14, color: Colors.blue),),),
              ],),),
              const SizedBox(height: 8),
              Text(
                _currentNickname,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                user?.email ?? '이메일 없음',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],),),
          ),
          const Divider(height: 1),

          // --- 7-2. 계정 섹션 ---
          const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 10), child: Text('계정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),),
          if (user == null) const ListTile(title: Text("로드 중..."))
          else if (user.isAnonymous) Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ListTile(leading: const Icon(Icons.person, color: Colors.orange), title: const Text('게스트 계정'), subtitle: const Text('데이터를 안전하게 보관하려면 계정을 연동하세요.'), onTap: _linkWithGoogle,),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: ElevatedButton(onPressed: _linkWithGoogle, style: ElevatedButton.styleFrom(foregroundColor: Colors.black, backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12),), child: const Text('Google 계정으로 연동하기'),),),
          ],)
          else Column(children: [
              ListTile(leading: const Icon(Icons.person, color: Colors.green), title: Text(user.displayName ?? _currentNickname), subtitle: Text(user.email ?? '이메일 정보 없음'),),
              ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('로그아웃', style: TextStyle(color: Colors.red)), onTap: _signOut,),
            ],),
          const Divider(height: 30),

          // --- 7-3. 프로필 수정 (닉네임 + 상태 메시지) ---
          const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 10), child: Text('프로필 수정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),),

          // (1) 닉네임 변경
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Row(children: [
            Expanded(child: TextField(controller: _nicknameController, decoration: const InputDecoration(labelText: '닉네임 (검색용)', border: OutlineInputBorder(),),),),
            const SizedBox(width: 10),
            ElevatedButton(onPressed: _saveNickname, child: const Text('저장'),),
          ],),),

          // (2) 상태 메시지 변경
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Row(children: [
            Expanded(
              child: TextField(
                controller: _statusMessageController,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: '상태 메시지 (프로필에 표시)',
                  border: OutlineInputBorder(),
                  counterText: "",
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(onPressed: _saveStatusMessage, child: const Text('저장'),),
          ],),),
          const Divider(height: 30),

          // --- 7-4. 앱 꾸미기 섹션 ---
          const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 10), child: Text('앱 꾸미기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),),
          ListTile(leading: const Icon(Icons.palette), title: const Text('테마 색상 변경'), subtitle: const Text('캘린더 및 앱의 전반적인 색상을 변경합니다.'), onTap: _showThemeSelector,),
          ListTile(leading: const Icon(Icons.wallpaper), title: const Text('배경 이미지 설정 (갤러리)'), subtitle: _isUploading ? const Text('이미지 업로드 중...') : _currentBackgroundImageUrl != null ? const Text('현재 사용자 지정 배경이 적용됨') : const Text('기본 배경 사용 중'), trailing: _currentBackgroundImageUrl != null ? IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: _removeBackground,) : null, onTap: _isUploading ? null : _pickAndUploadBackground,),
          ListTile(leading: const Icon(Icons.font_download), title: const Text('앱 폰트 변경'), subtitle: Text('현재 폰트: $_selectedFontFamily'), onTap: () { _showFontSelector(); },),
          const Divider(height: 30),

          // --- 7-5. 친구 섹션 ---
          const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 10), child: Text('친구 관리', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),),
          ListTile(
            leading: const Icon(Icons.people_alt),
            title: const Text('친구 목록 및 추가'),
            subtitle: const Text('친구 목록 확인, 추가 및 공개된 감정 피드 보기'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendFeedPage()),);
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off),
            title: const Text('숨겨진 친구 관리'),
            subtitle: const Text('숨긴 친구 목록을 보거나 다시 표시합니다.'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HiddenFriendsPage()),
              );
            },
          ),
          const Divider(height: 30),

          // --- 7-6. 보안 섹션 ---
          const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 10), child: Text('보안', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),),
          SwitchListTile(title: const Text('비밀번호 잠금'), subtitle: const Text('앱 실행 시 4/6자리 비밀번호를 요구합니다.'), value: _isPasscodeEnabled, onChanged: (bool value) async {
            if (value) { _showSetPasscodeScreen(initialLength: _currentPinLength); }
            else {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_getPrefKey(storedPinKey));
              await prefs.setBool(_getPrefKey(passcodeEnabledKey), false);
              setState(() { _isPasscodeEnabled = false; });
              if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호 잠금이 해제되었습니다.')),); }
            }
          },),
          if (_isPasscodeEnabled) ListTile(title: const Text('비밀번호 변경'), leading: const Icon(Icons.password), onTap: _showChangePasscodeScreen,),
          const Divider(height: 30),


          // --- 7-7. 알림 섹션 ---
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text('알림', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          ),

          // (1) 마스터 스위치
          SwitchListTile(
            title: const Text("전체 푸시 알림"),
            subtitle: const Text("앱의 모든 휴대폰 푸시 알림을 켜거나 끕니다."),
            value: _isAllNotifyEnabled,
            onChanged: _onAllNotifySwitchChanged,
          ),

          // (2) 하위 알림 설정 (마스터가 켜져있을 때만 보임)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isAllNotifyEnabled ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            secondChild: Container(),
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // (2-1) 매일 푸시 알림
                SwitchListTile(
                  title: const Text("매일 알림 받기"),
                  subtitle: const Text("설정한 시간에 일기 작성을 위한 푸시 알림을 받습니다."),
                  value: _isDailyNotifyEnabled,
                  onChanged: _onDailyNotifySwitchChanged,
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text("알림 시간: $_notifyTimeString"),
                  onTap: _onTimeTapped,
                  enabled: _isDailyNotifyEnabled,
                ),

                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                      '소셜 푸시 알림 (알림 기록은 항상 저장됩니다)',
                      style: TextStyle(fontSize: 12, color: Colors.black54)
                  ),
                ),

                // (2-2) 친구 요청 알림
                SwitchListTile(
                  title: const Text("친구 요청 푸시 알림"),
                  subtitle: const Text("친구 요청 시 휴대폰 알림을 받습니다."),
                  value: _isFriendRequestNotifyEnabled,
                  onChanged: _onFriendRequestNotifySwitchChanged,
                ),

                // (2-3) 공감 알림
                SwitchListTile(
                  title: const Text("공감 푸시 알림"),
                  subtitle: const Text("내 글에 공감 시 휴대폰 알림을 받습니다."),
                  value: _isLikeNotifyEnabled,
                  onChanged: _onLikeNotifySwitchChanged,
                ),

                // (2-4) 댓글 알림
                SwitchListTile(
                  title: const Text("댓글 푸시 알림"),
                  subtitle: const Text("내 글에 댓글 시 휴대폰 알림을 받습니다."),
                  value: _isCommentNotifyEnabled,
                  onChanged: _onCommentNotifySwitchChanged,
                ),
              ],
            ),
          ),
          const Divider(height: 30),


          // --- 7-8. 도움말 섹션 ---
          const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 10), child: Text('지원', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),),
          ListTile(leading: const Icon(Icons.help_outline), title: const Text('도움말 및 기능 안내'), subtitle: const Text('AI 채팅, 친구 기능 등 앱 사용법 보기'), onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpPage()),); },),
        ],
      ),
    );
  }

  // 폰트 선택 모달
  void _showFontSelector() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('앱 폰트 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              ..._availableFonts.map((font) {
                return RadioListTile<String>(
                  title: Text(font == 'SystemDefault' ? '시스템 기본 폰트' : font, style: TextStyle(fontFamily: font == 'SystemDefault' ? null : font),),
                  value: font,
                  groupValue: _selectedFontFamily,
                  onChanged: (String? newValue) {
                    if (newValue != null) { _saveFontSetting(newValue); }
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // 테마 선택 모달
  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(pastelColors.length, (i) {
              final color = pastelColors[i];
              final isSelected = i == _selectedColorIndex;
              return GestureDetector(
                onTap: () async { await _saveThemeSetting(i); },
                child: Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade300, width: 3,),),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}