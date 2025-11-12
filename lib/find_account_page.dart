// lib/find_account_page.dart

import 'package:flutter/material.dart';

class FindAccountPage extends StatelessWidget {
  const FindAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('아이디/비밀번호 찾기')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '이 페이지에서 아이디/비밀번호를 찾을 수 있는 기능을 구현합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 20),
              // 실제 구현 시 이메일 입력 필드, 인증 로직 등이 들어갑니다.
            ],
          ),
        ),
      ),
    );
  }
}