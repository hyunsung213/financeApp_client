import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('로그인', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 8),
              Text('이메일로 간편하게 시작하세요.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: '이메일'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_emailController.text.isNotEmpty) {
                    ref.read(authProvider.notifier).login(_emailController.text);
                  }
                },
                child: const Text('시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
