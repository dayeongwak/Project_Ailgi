// lib/login_page.dart (구글 로그인 시 Firestore에 이메일 저장 기능 추가)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Firestore 임포트
import 'register_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'find_account_page.dart';

const String KEY_SAVED_USERNAME = 'saved_username';
const String KEY_REMEMBER_ME = 'remember_me';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance; // ✅ Firestore 인스턴스
  bool _isPasswordObscured = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedUsername();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString(KEY_SAVED_USERNAME);
    final rememberMe = prefs.getBool(KEY_REMEMBER_ME) ?? false;

    if (rememberMe && savedUsername != null) {
      _usernameController.text = savedUsername;
    }
    setState(() { _rememberMe = rememberMe; });
  }

  Future<void> _saveLoginInfo(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_REMEMBER_ME, _rememberMe);
    if (_rememberMe) {
      await prefs.setString(KEY_SAVED_USERNAME, username);
    } else {
      await prefs.remove(KEY_SAVED_USERNAME);
    }
  }

  // 이메일/비밀번호 로그인 로직 (완성)
  Future<void> _signInWithUsername() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final email = username;

    if (email.isEmpty || password.isEmpty) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('아이디와 비밀번호를 입력해주세요.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (mounted) {
        await _saveLoginInfo(email);
      }

    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = '등록되지 않은 아이디입니다.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = '잘못된 아이디 또는 비밀번호입니다.';
      } else {
        message = '로그인 오류: ${e.message}';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그인 중 알 수 없는 오류가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 구글 로그인 로직 (수정됨)
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() { _isLoading = false; });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 1. Firebase 로그인
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // 2. ✅ Firestore에 이메일 정보 저장 (SetOptions(merge: true)로 덮어쓰지 않음)
        await _firestore.collection('users').doc(user.uid).set(
            { 'email': user.email }, // 구글 계정의 이메일을 저장
            SetOptions(merge: true)
        );
      }

      if (mounted) {
        await _saveLoginInfo(googleUser.email ?? 'GoogleUser');
      }

    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'account-exists-with-different-credential') {
        message = '이미 다른 방식으로 등록된 이메일입니다. 기존 방식으로 로그인해 주세요.';
      } else {
        message = 'Google 로그인 실패: ${e.message}';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그인 중 알 수 없는 오류가 발생했습니다: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 아이디/비밀번호 찾기 함수
  void _findAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FindAccountPage()),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 앱 제목/로고
                const Text(
                  'Ailgi',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                const SizedBox(height: 50),

                // 2. 아이디 입력 칸
                TextField(
                  controller: _usernameController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: '아이디',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // 3. 비밀번호 입력 칸
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () { setState(() => _isPasswordObscured = !_isPasswordObscured); },
                    ),
                  ),
                  obscureText: _isPasswordObscured,
                  obscuringCharacter: '*',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signInWithUsername(),
                ),
                const SizedBox(height: 10),

                // 4. 로그인 정보 저장 체크박스 & 아이디/비밀번호 찾기
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row( // 체크박스 그룹
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (bool? newValue) {
                            setState(() {
                              _rememberMe = newValue ?? false;
                            });
                          },
                        ),
                        const Text('로그인 정보 저장'),
                      ],
                    ),

                    TextButton(
                      onPressed: _findAccount,
                      child: const Text('아이디/비밀번호 찾기', style: TextStyle(fontWeight: FontWeight.normal, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 5. 로그인 버튼
                ElevatedButton(
                  onPressed: _signInWithUsername,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('로그인', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 20),

                const Divider(height: 40),

                // 6. 구글 로그인 버튼
                ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: Image.asset('assets/google_logo.png', height: 24),
                  label: const Text('Google 계정으로 로그인', style: TextStyle(fontSize: 18, color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 40),

                // 7. 회원가입 버튼/텍스트
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('아직 계정이 없으신가요?'),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterPage()),
                        );
                      },
                      child: const Text('회원가입', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}