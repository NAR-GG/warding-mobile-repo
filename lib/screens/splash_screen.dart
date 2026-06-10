import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../repository/auth/auth_service.dart';
import '../repository/fcm/fcm_service.dart';
import '../styles/app_colors.dart';
import 'login/login_screen.dart';
import 'schedule/schedule_screen.dart';

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
    // 이미 로그인된 상태면 앱 시작 시에도 FCM 토큰을 갱신·등록한다.
    if (jwt != null) unawaited(FcmService.instance.registerToken());
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            jwt == null ? const LoginScreen() : const ScheduleScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 뒤에 깔리는 blur 글로우 레이어 (opacity로 빛 세기 조절)
            Opacity(
              opacity: 0.5,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 14.5, sigmaY: 14.5),
                child: SvgPicture.asset(
                  'assets/images/warding.svg',
                  width: 240,
                  height: 48,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            // 앞의 선명한 로고
            SvgPicture.asset(
              'assets/images/warding.svg',
              width: 240,
              height: 48,
            ),
          ],
        ),
      ),
    );
  }
}
