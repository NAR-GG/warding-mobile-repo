import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../repository/auth/auth_service.dart';
import '../styles/app_colors.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signIn(String registrationId) async {
    if (_isLoading) return;

    if (registrationId != 'kakao') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('준비중입니다')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthService.instance.signInWithKakao();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => result.isOnboarded
              ? const HomeScreen()
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
              const SizedBox(width: 316, child: _EasyLoginDivider()),
              const SizedBox(height: 24),
              _SocialLoginButton(
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
              _SocialLoginButton(
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
              _SocialLoginButton(
                backgroundColor: AppColors.googleBg,
                foregroundColor: AppColors.gary100,
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
                onPressed: _isLoading ? null : () {},
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

class _EasyLoginDivider extends StatelessWidget {
  const _EasyLoginDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.narLine2, thickness: 1, height: 1),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 11.5),
          child: Text(
            '간편 로그인',
            style: TextStyle(color: AppColors.narText, fontSize: 16),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.narLine2, thickness: 1, height: 1),
        ),
      ],
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 316,
      height: 48,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
