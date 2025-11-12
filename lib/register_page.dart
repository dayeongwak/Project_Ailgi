// lib/register_page.dart (아이디 기반 회원가입)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isLoading = false;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  // --- 아이디 유효성 및 중복 검사 ---
  Future<bool> _isUsernameUnique(String username) async {
    if (username.isEmpty) return false;
    // ✅ 누락되었던 쿼리 로직 복원
    final snapshot = await _firestore.collection('users')
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return snapshot.docs.isEmpty; // 문서가 없으면 고유함
  }

  // --- 회원가입 시도 ---
  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final username = _usernameController.text.trim().toLowerCase();

    setState(() => _isLoading = true);

    if (!await _isUsernameUnique(username)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미 사용 중인 아이디입니다.')));
      setState(() => _isLoading = false);
      return;
    }

    try {
      final email = '$username@ailgi.app';

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'username': username,
          'nickname': username,
          'email': email,
          'profileUrl': null,
          'friends': [],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원가입 성공! 로그인됩니다.')));
        Navigator.of(context).pop();
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = "회원가입 실패: ${e.message ?? '알 수 없는 오류'}";
        if (e.code == 'email-already-in-use') {
          errorMessage = '이미 사용 중인 아이디입니다. (내부 검사 실패)';
        } else if (e.code == 'weak-password') {
          errorMessage = '비밀번호는 6자 이상이어야 합니다.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Ailgi 계정 만들기', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: '아이디 (4~15자)', border: OutlineInputBorder(), prefixText: '@'),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.length < 4 || value.length > 15) {
                        return '아이디는 4자 이상 15자 이내여야 합니다.';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                        return '아이디는 영문과 숫자만 사용할 수 있습니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: '비밀번호 (6자 이상)', border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () { setState(() => _isPasswordObscured = !_isPasswordObscured); },
                      ),
                    ),
                    obscureText: _isPasswordObscured,
                    obscuringCharacter: '*',
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.length < 6) { return '비밀번호는 6자 이상이어야 합니다.'; }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: '비밀번호 확인', border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_isConfirmPasswordObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () { setState(() => _isConfirmPasswordObscured = !_isConfirmPasswordObscured); },
                      ),
                    ),
                    obscureText: _isConfirmPasswordObscured,
                    obscuringCharacter: '*',
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value == null || value != _passwordController.text) { return '비밀번호가 일치하지 않습니다.'; }
                      return null;
                    },
                    onFieldSubmitted: (_) => _registerWithEmail(),
                  ),
                  const SizedBox(height: 24),

                  // ✅ 누락되었던 onPressed 인수 복원
                  ElevatedButton(
                    onPressed: _registerWithEmail,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('가입 완료'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}