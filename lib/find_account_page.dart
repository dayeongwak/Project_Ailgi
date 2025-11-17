import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FindAccountPage extends StatefulWidget {
  const FindAccountPage({super.key});

  @override
  State<FindAccountPage> createState() => _FindAccountPageState();
}

class _FindAccountPageState extends State<FindAccountPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // 컨트롤러
  final _recoveryEmailController = TextEditingController(); // 아이디 찾기용 이메일 입력
  final _resetEmailController = TextEditingController();    // 비번 재설정용 이메일 입력

  bool _isLoading = false;
  String? _foundIdResult; // 찾은 아이디를 화면에 표시할 변수

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recoveryEmailController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  // 1. 아이디 찾기 로직 (이메일로 검색)
  // (주의: 현재 회원가입 로직엔 '실제 이메일' 필드가 없으므로, 구글 로그인 유저만 찾을 수 있음)
  Future<void> _findId() async {
    final email = _recoveryEmailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일을 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // users 컬렉션에서 email이 일치하는 문서 검색
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final username = data['username']; // 사용자 아이디
        final nickname = data['nickname'];

        setState(() {
          if (username != null) {
            _foundIdResult = "찾으시는 아이디는 '$username' 입니다.";
          } else {
            // 구글 로그인 등 username이 없는 경우 닉네임 표시
            _foundIdResult = "소셜 로그인 계정입니다. ('$nickname')";
          }
        });
      } else {
        setState(() {
          _foundIdResult = "해당 이메일로 가입된 계정을 찾을 수 없습니다.";
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. 비밀번호 재설정 이메일 발송
  Future<void> _sendPasswordResetEmail() async {
    final email = _resetEmailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('가입한 이메일(또는 아이디형 이메일)을 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Firebase Auth가 제공하는 비밀번호 재설정 메일 발송 기능
      await _auth.sendPasswordResetEmail(email: email);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('메일 발송 완료'),
            content: Text('$email 주소로 비밀번호 재설정 메일을 보냈습니다.\n메일함을 확인해주세요.\n(가상 이메일인 경우 수신이 불가능합니다)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = '메일 발송 실패: ${e.message}';
      if (e.code == 'user-not-found') {
        message = '등록되지 않은 이메일입니다.';
      } else if (e.code == 'invalid-email') {
        message = '이메일 형식이 올바르지 않습니다.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('계정 찾기'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: '아이디 찾기'),
            Tab(text: '비밀번호 재설정'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          // [탭 1] 아이디 찾기 화면
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '가입 시 등록한 이메일을 입력하시면\n아이디를 알려드립니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _recoveryEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '이메일 입력',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _findId,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('아이디 찾기', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 30),
                if (_foundIdResult != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      _foundIdResult!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // [탭 2] 비밀번호 재설정 화면
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '가입하신 계정의 이메일을 입력하시면\n비밀번호 재설정 링크를 보내드립니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                const Text(
                  '(주의: @ailgi.app 가상 이메일 사용자는 실제 메일을 받을 수 없습니다.)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '가입 이메일 입력',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _sendPasswordResetEmail,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('재설정 메일 보내기', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}