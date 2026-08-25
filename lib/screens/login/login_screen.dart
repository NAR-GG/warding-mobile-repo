import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../repository/auth/auth_service.dart';
import '../../repository/fcm/fcm_service.dart';
import '../../repository/onboarding/onboarding_sync_service.dart';
import '../../styles/app_colors.dart';
import '../onboarding/onboarding_screen.dart';
import 'component/login_consent_notice.dart';
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
        'apple' => await AuthService.instance.signInWithApple(),
        _ => await AuthService.instance.signInWithKakao(),
      };
      // 로그인 성공 직후 FCM 토큰을 백엔드에 등록한다 (실패해도 흐름은 계속).
      unawaited(FcmService.instance.registerToken());
      // 비회원 시절 로컬에 저장한 온보딩 선택값이 있으면 서버로 동기화한다.
      final onboarded =
          await OnboardingSyncService.instance.syncOnLogin(result);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              onboarded ? const ScheduleScreen() : const OnboardingScreen(),
        ),
        (route) => false,
      );
    } on AuthCancelledException {
      // 사용자가 로그인을 취소함 — 별도 알림 없이 종료
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Login] 로그인 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.loginFailed)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
              if (Platform.isIOS) ...[
                SocialLoginButton(
                  backgroundColor: AppColors.appleBg,
                  foregroundColor: AppColors.gray100,
                  icon: const Icon(
                    Icons.apple,
                    size: 20,
                    color: AppColors.gray100,
                  ),
                  label: l.appleLogin,
                  onTap: () => _signIn('apple'),
                ),
                const SizedBox(height: 16),
              ],
              SocialLoginButton(
                backgroundColor: AppColors.kakaoBg,
                foregroundColor: AppColors.kakaoText,
                icon: SvgPicture.asset(
                  'assets/icons/kakao.svg',
                  width: 18,
                  height: 18,
                ),
                label: l.kakaoLogin,
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
                label: l.naverLogin,
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
                label: l.googleLogin,
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
                child: Text(
                  l.guestStart,
                  style: const TextStyle(color: AppColors.narText2, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              // 비회원으로 시작하는 경로도 커뮤니티를 읽으므로, 두 버튼을
              // 모두 아래에 두고 화면 하단에 한 번만 깐다.
              const LoginConsentNotice(),
              const Spacer(flex: 48),
            ],
          ),
        ),
      ),
    );
  }
}
