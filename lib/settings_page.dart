import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:passcode_screen/circle.dart';
import 'package:passcode_screen/keyboard.dart';
import 'package:passcode_screen/passcode_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'notification_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'font_config.dart';
import 'help_page.dart';

const String storedPinKey = '_my_diary_pin_code';
const String passcodeEnabledKey = '_passcode_enabled';
const String passcodeLengthKey = '_passcode_length';
const String FONT_FAMILY_KEY = '_app_font_family';
const String KEY_BACKGROUND_URL = '_app_background_image_url';
const String KEY_THEME_COLOR = '_theme_color_index';

const String KEY_DAILY_NOTIFY_ENABLED = '_daily_push_notify_enabled';
const String KEY_NOTIFY_TIME = '_notify_time';

class SettingsPage extends StatefulWidget {
  final ValueChanged<Color> onThemeChanged;
  const SettingsPage({super.key, required this.onThemeChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isPasscodeEnabled = false;
  int _currentPinLength = 6;
  final StreamController<bool> _verificationNotifier = StreamController<bool>.broadcast();

  bool _isDailyNotifyEnabled = true;
  String _notifyTimeString = '21:00';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 21, minute: 0);

  String _currentNickname = 'Guest';
  final TextEditingController _nicknameController = TextEditingController();

  String? _profileImageUrl;
  bool _isUploading = false;

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
    super.dispose();
  }

  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPasscodeEnabled = prefs.getBool(_getPrefKey(passcodeEnabledKey)) ?? false;
      _currentPinLength = prefs.getInt(_getPrefKey(passcodeLengthKey)) ?? 6;
      _isDailyNotifyEnabled = prefs.getBool(_getPrefKey(KEY_DAILY_NOTIFY_ENABLED)) ?? true;
      _notifyTimeString = prefs.getString(_getPrefKey(KEY_NOTIFY_TIME)) ?? '21:00';
      final parts = _notifyTimeString.split(':');
      if (parts.length == 2) {
        _selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentColor = Theme.of(context).primaryColor;
      int index = pastelColors.indexWhere((c) => c.value == currentColor.value);
      if (index == -1) index = 0;
      if (mounted) setState(() => _selectedColorIndex = index);
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

        if (mounted) {
          setState(() {
            _currentNickname = nickname;
            _nicknameController.text = nickname;
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
    if (mounted) {
      setState(() {
        _selectedFontFamily = prefs.getString(_getPrefKey(FONT_FAMILY_KEY)) ?? 'SystemDefault';
      });
    }
  }

  Future<void> _loadBackgroundImage() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentBackgroundImageUrl = prefs.getString(_getPrefKey(KEY_BACKGROUND_URL));
      });
    }
  }

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

  Future<void> _saveNotificationSetting(String key, bool value) async {
    if (_uid == null) return;
    await _saveSingleSetting(key, value);
    try {
      await _firestore.collection('users').doc(_uid).set(
        {key: value},
        SetOptions(merge: true),
      );
    } catch (e) {
      print("❌ Firestore 알림 설정 저장 실패: $e");
    }
  }

  Future<void> _saveFontSetting(String newFont) async {
    await _saveSingleSetting(FONT_FAMILY_KEY, newFont);
    if (mounted) {
      setState(() { _selectedFontFamily = newFont; });
      widget.onThemeChanged(pastelColors[_selectedColorIndex]);
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
      await _firestore.collection('users').doc(uid).set({'nickname': newNickname}, SetOptions(merge: true));
      if (mounted) {
        setState(() { _currentNickname = newNickname; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임이 저장되었습니다.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('닉네임 저장 오류: $e')));
    }
  }

  void _showProfileOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('사진 선택'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadProfilePicture();
                },
              ),
              if (_profileImageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('기본 이미지로 변경', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteProfilePicture();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteProfilePicture() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'profileUrl': FieldValue.delete(),
      });
      if (mounted) {
        setState(() { _profileImageUrl = null; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기본 프로필로 변경되었습니다.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('변경 실패: $e')));
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
      await _saveSingleSetting(KEY_BACKGROUND_URL, downloadUrl);
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
    await prefs.remove(_getPrefKey(KEY_BACKGROUND_URL));
    if (mounted) {
      setState(() { _currentBackgroundImageUrl = null; });
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('배경 이미지가 제거되었습니다.')));
      widget.onThemeChanged(Theme.of(context).primaryColor);
    }
  }

  Future<void> _saveThemeSetting(int index) async {
    await _saveSingleSetting(KEY_THEME_COLOR, index);
    if (mounted) {
      setState(() { _selectedColorIndex = index; });
      widget.onThemeChanged(pastelColors[index]);
      Navigator.pop(context);
    }
  }

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
        if (mounted) setState(() => _currentNickname = googleUser.displayName!);
      }
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google 계정이 연동되었습니다!')));
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('연동 실패: ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('연동 실패: $e')));
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
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인', style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );

    if (confirm != true) return;

    final uid = _auth.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();

    if (uid != null) {
      try {
        await _firestore.collection('users').doc(uid).set(
          {'fcmToken': FieldValue.delete()},
          SetOptions(merge: true),
        );
      } catch (e) {
        print("❌ FCM 토큰 제거 실패: $e");
      }
      final String pinKey = "${uid}$storedPinKey";
      final String enableKey = "${uid}$passcodeEnabledKey";
      final String lengthKey = "${uid}$passcodeLengthKey";
      await prefs.remove(pinKey);
      await prefs.setBool(enableKey, false);
      await prefs.remove(lengthKey);
    }

    await GoogleSignIn().signOut();
    await _auth.signOut();

    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ✅ [수정됨] 회원 탈퇴 시 구글 연결 해제 실패(PlatformException) 무시하고 진행
  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('회원 탈퇴'),
          content: const Text('정말로 탈퇴하시겠습니까?\n작성한 모든 일기와 설정이 영구적으로 삭제되며, 복구할 수 없습니다.'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('탈퇴', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final user = _auth.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final diariesSnapshot = await _firestore.collection('users').doc(uid).collection('diaries').get();
      final notificationsSnapshot = await _firestore.collection('users').doc(uid).collection('notifications').get();

      final batch = _firestore.batch();
      for (var doc in diariesSnapshot.docs) batch.delete(doc.reference);
      for (var doc in notificationsSnapshot.docs) batch.delete(doc.reference);
      await batch.commit();

      await _firestore.collection('users').doc(uid).delete();

      final String pinKey = "${uid}$storedPinKey";
      final String enableKey = "${uid}$passcodeEnabledKey";
      final String lengthKey = "${uid}$passcodeLengthKey";
      await prefs.remove(pinKey);
      await prefs.setBool(enableKey, false);
      await prefs.remove(lengthKey);

      // ✅ [핵심] GoogleSignIn 연결 해제 시도 (실패해도 무시)
      try {
        await GoogleSignIn().disconnect();
      } catch (e) {
        print("Google disconnect ignored: $e");
      }

      // 계정 삭제
      await user?.delete();

      if (mounted) {
        Navigator.pop(context);
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        // 보안상 재로그인이 필요한 경우 처리
        if (e.toString().contains('requires-recent-login')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('보안을 위해 다시 로그인 후 시도해주세요.')));
          await _signOut();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('탈퇴 실패: $e')));
        }
      }
    }
  }

  void _showSetPasscodeScreen({int? initialLength}) {
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
                  await _saveSingleSetting(storedPinKey, enteredPasscode);
                  await _saveSingleSetting(passcodeEnabledKey, true);
                  await _saveSingleSetting(passcodeLengthKey, tempLength);

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

  void _onPasscodeCancelled() {
    Navigator.maybePop(context);
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

  Future<void> _onDailyNotifySwitchChanged(bool v) async {
    setState(() => _isDailyNotifyEnabled = v);
    await _saveNotificationSetting(KEY_DAILY_NOTIFY_ENABLED, v);

    if (v) {
      await NotificationService().rescheduleNotification(_uid);
    } else {
      await NotificationService().cancelAllNotifications();
    }
  }

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
      await _saveSingleSetting(KEY_NOTIFY_TIME, newTimeString);

      if (_isDailyNotifyEnabled) {
        await NotificationService().rescheduleNotification(_uid);
      }
    }
  }

  void _showFontSelector() {
    showModalBottomSheet(context: context, builder: (BuildContext context) {
      return Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('앱 폰트 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(),
        ...availableFontFamilies.map((font) {
          return RadioListTile<String>(
            title: Text(font == 'SystemDefault' ? '시스템 기본 폰트' : font, style: TextStyle(fontFamily: font == 'SystemDefault' ? null : font),),
            value: font,
            groupValue: _selectedFontFamily,
            onChanged: (String? newValue) { if (newValue != null) { _saveFontSetting(newValue); } },
          );
        }).toList(),
      ],),);
    },);
  }

  void _showThemeSelector() {
    showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) {
      return Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 10, runSpacing: 10, children: List.generate(pastelColors.length, (i) {
        final color = pastelColors[i];
        final isSelected = i == _selectedColorIndex;
        return GestureDetector(onTap: () async { await _saveThemeSetting(i); }, child: Container(width: 45, height: 45, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade300, width: 3,),),),);
      }),),);
    },);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('환경설정')),
      body: ListView(
        children: [
          // 1. 프로필 섹션
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 20),
            child: Center(child: Column(children: [
              GestureDetector(
                onTap: _showProfileOptions,
                child: Stack(children: [
                  CircleAvatar(radius: 40, backgroundColor: Colors.blue.shade100, backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty ? NetworkImage(_profileImageUrl!) : null, child: _profileImageUrl == null || _profileImageUrl!.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.blue) : null,),
                  if (_isUploading) const Positioned.fill(child: Center(child: CircularProgressIndicator(strokeWidth: 3)))
                  else const Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Icon(Icons.camera_alt, size: 14, color: Colors.blue),),),
                ],),),
              const SizedBox(height: 8),
              Text(_currentNickname, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(user?.email ?? '이메일 없음', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],),),
          ),
          const Divider(height: 1),

          // 2. 계정 섹션
          const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 10), child: Text('계정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),),
          if (user == null) const ListTile(title: Text("로드 중..."))
          else if (user.isAnonymous) Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ListTile(leading: const Icon(Icons.person, color: Colors.orange), title: const Text('게스트 계정'), subtitle: const Text('데이터를 안전하게 보관하려면 계정을 연동하세요.'), onTap: _linkWithGoogle,),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: ElevatedButton(onPressed: _linkWithGoogle, style: ElevatedButton.styleFrom(foregroundColor: Colors.black, backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12),), child: const Text('Google 계정으로 연동하기'),),),
          ],)
          else Column(children: [
              ListTile(leading: const Icon(Icons.person, color: Colors.green), title: Text(user.displayName ?? _currentNickname), subtitle: Text(user.email ?? '이메일 정보 없음')),
              ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('로그아웃', style: TextStyle(color: Colors.red)), onTap: _signOut,),
              ListTile(leading: const Icon(Icons.person_off, color: Colors.grey), title: const Text('회원 탈퇴', style: TextStyle(color: Colors.grey)), onTap: _deleteAccount,),
            ],),
          const Divider(height: 30),

          // 3. 프로필 수정
          const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 10), child: Text('프로필 수정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Row(children: [
            Expanded(child: TextField(controller: _nicknameController, decoration: const InputDecoration(labelText: '닉네임', border: OutlineInputBorder(),),),),
            const SizedBox(width: 10),
            // ✅ [수정됨] 저장 버튼 검은색 고정
            ElevatedButton(
              onPressed: _saveNickname,
              style: ElevatedButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('저장'),
            ),
          ],),),
          const Divider(height: 30),

          // 4. 앱 꾸미기
          const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 10), child: Text('앱 꾸미기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),),
          ListTile(leading: const Icon(Icons.palette), title: const Text('테마 색상 변경'), subtitle: const Text('캘린더 및 앱의 전반적인 색상을 변경합니다.'), onTap: _showThemeSelector,),
          ListTile(leading: const Icon(Icons.wallpaper), title: const Text('배경 이미지 설정 (갤러리)'), subtitle: _isUploading ? const Text('이미지 업로드 중...') : _currentBackgroundImageUrl != null ? const Text('현재 사용자 지정 배경이 적용됨') : const Text('기본 배경 사용 중'), trailing: _currentBackgroundImageUrl != null ? IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: _removeBackground,) : null, onTap: _isUploading ? null : _pickAndUploadBackground,),
          ListTile(leading: const Icon(Icons.font_download), title: const Text('앱 폰트 변경'), subtitle: Text('현재 폰트: $_selectedFontFamily'), onTap: () { _showFontSelector(); },),
          const Divider(height: 30),

          // 5. 보안
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

          // 6. 알림
          const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 10), child: Text('알림', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),),

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

          // 알림 테스트 버튼 (UID 전달)
          ListTile(
            leading: const Icon(Icons.notification_important, color: Colors.redAccent),
            title: const Text("알림 테스트 (즉시 발송)"),
            subtitle: const Text("누르면 3초 뒤에 알림이 옵니다."),
            onTap: () async {
              await NotificationService().init();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("3초 뒤 알림이 발송됩니다. 홈 화면으로 나가보세요!")),
                );
              }
              await Future.delayed(const Duration(seconds: 3));
              await NotificationService().showSimpleNotification(
                title: "테스트 알림 성공! 🎉",
                body: "알림 권한과 설정이 정상입니다.",
                uid: _uid,
              );
            },
          ),

          const Divider(height: 30),

          // 7. 지원
          const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 10), child: Text('지원', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),),
          ListTile(leading: const Icon(Icons.help_outline), title: const Text('도움말 및 기능 안내'), subtitle: const Text('AI 채팅 등 앱 사용법 보기'), onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpPage()),); },),
        ],
      ),
    );
  }
}