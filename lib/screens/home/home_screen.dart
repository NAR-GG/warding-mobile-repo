import 'package:flutter/material.dart';

import '../../repository/auth/auth_service.dart';
import '../../styles/app_colors.dart';
import '../login/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Home] 로그아웃 에러: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그아웃에 실패했습니다. 잠시 후 다시 시도해주세요.')));
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.narDark800,
      appBar: AppBar(
        backgroundColor: AppColors.narDark800,
        title: const Text('Warding', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _isSigningOut ? null : _signOut,
          ),
        ],
      ),
      body: const Center(
        child: Text(
          '메인 화면 (작업 예정)',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
