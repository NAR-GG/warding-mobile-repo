import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../repository/auth/auth_service.dart';
import '../../repository/fcm/fcm_service.dart';
import '../../styles/app_colors.dart';
import '../onboarding/onboarding_screen.dart';
import '../schedule/schedule_screen.dart';
import 'component/easy_login_divider.dart';
import 'component/social_login_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signIn(String registrationId) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final result = switch (registrationId) {
        'naver' => await AuthService.instance.signInWithNaver(),
        'google' => await AuthService.instance.signInWithGoogle(),
        _ => await AuthService.instance.signInWithKakao(),
      };
      // 로그인 성공 직후 FCM 토큰을 백엔드에 등록한다 (실패해도 흐름은 계속).
      unawaited(FcmService.instance.registerToken());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => result.isOnboarded
              ? const ScheduleScreen()
              : const OnboardingScreen(),
        ),
        (route) => false,
      );
    } on AuthCancelledException {
      // 사용자가 로그인을 취소함 — 별도 알림 없이 종료
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그인에 실패했습니다: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 199),
              SvgPicture.asset(
                'assets/images/warding.svg',
                width: 220,
                height: 44,
              ),
              const Spacer(flex: 140),
              const SizedBox(width: 316, child: EasyLoginDivider()),
              const SizedBox(height: 24),
              SocialLoginButton(
                backgroundColor: AppColors.kakaoBg,
                foregroundColor: AppColors.kakaoText,
                icon: SvgPicture.asset(
                  'assets/icons/kakao.svg',
                  width: 18,
                  height: 18,
                ),
                label: '카카오 로그인',
                onTap: () => _signIn('kakao'),
              ),
              const SizedBox(height: 16),
              SocialLoginButton(
                backgroundColor: AppColors.naverBg,
                foregroundColor: AppColors.naverText,
                icon: SvgPicture.asset(
                  'assets/icons/naver.svg',
                  width: 16,
                  height: 16,
                ),
                label: '네이버 로그인',
                onTap: () => _signIn('naver'),
              ),
              const SizedBox(height: 16),
              SocialLoginButton(
                backgroundColor: AppColors.googleBg,
                foregroundColor: AppColors.gray100,
                icon: SvgPicture.asset(
                  'assets/icons/google.svg',
                  width: 20,
                  height: 20,
                ),
                label: 'Google 로그인',
                onTap: () => _signIn('google'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(),
                        ),
                      ),
                child: const Text(
                  '비회원으로 시작하기',
                  style: TextStyle(color: AppColors.narText2, fontSize: 16),
                ),
              ),
              const Spacer(flex: 48),
            ],
          ),
        ),
      ),
    );
  }
}
