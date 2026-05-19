import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../repository/auth/auth_service.dart';
import '../styles/app_colors.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      Future<void>.delayed(const Duration(seconds: 2)),
      AuthService.instance.jwt,
    ]);
    if (!mounted) return;

    final jwt = results[1] as String?;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => jwt == null ? const LoginScreen() : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: Center(
        child: SvgPicture.asset(
          'assets/images/warding.svg',
          width: 206,
          height: 41,
        ),
      ),
    );
  }
}
