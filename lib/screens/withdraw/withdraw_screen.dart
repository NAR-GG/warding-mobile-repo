import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/common_button.dart';
import '../../components/nar_detail_header.dart';
import '../../l10n/app_localizations.dart';
import '../../repository/auth/auth_service.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/mypage/mypage_viewmodel.dart';
import '../login/login_screen.dart';
import '../mypage/component/mypage_card_section.dart';

/// 회원 탈퇴 화면. 계정 설정의 '회원탈퇴' 진입점.
///
/// 헤더는 공용 [NarDetailHeader] 로 chevron-left 뒤로가기 + 가운데 타이틀.
/// 본문은 탈퇴 안내와 고객센터 유도, 하단 '와딩 회원 탈퇴하기' 버튼은 누르는
/// 즉시 `DELETE /api/auth/me` 로 계정을 삭제한다(별도 확인 없음).
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final MypageViewModel _viewModel = MypageViewModel();

  /// 탈퇴 요청 중. 완료 버튼 연타를 막는다.
  bool _isWithdrawing = false;

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// 고객센터/문의 — 마이페이지와 같은 문의 폼을 연다.
  Future<void> _openCustomerService() async {
    await launchUrl(
      Uri.parse(
        'https://docs.google.com/forms/d/e/1FAIpQLSf66NkvON3YrFR0n_CSbnzyjXlEEfO8eiIc9W_2TBYulvihMA/viewform',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  /// 탈퇴 실행 — 안내를 이미 화면에서 했으므로 별도 확인 없이 즉시 탈퇴한다.
  Future<void> _withdraw() async {
    if (_isWithdrawing) return;
    setState(() => _isWithdrawing = true);
    final l = AppLocalizations.of(context)!;
    try {
      await AuthService.instance.withdraw();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isWithdrawing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.withdrawFailed)));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NarDetailHeader(
              title: l.withdrawTitle,
              backIconAsset: 'assets/icons/chevron-left.svg',
              scale: scale,
            ),
            // 안내 문구 — 길면 이 영역만 스크롤된다.
            Expanded(
              child: SingleChildScrollView(
                // 본문은 양옆 20 여백.
                padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListenableBuilder(
                      listenable: _viewModel,
                      builder: (context, _) => Text(
                        l.withdrawHeadline(
                          _viewModel.nickname.isEmpty
                              ? l.nicknamePlaceholder
                              : _viewModel.nickname,
                        ),
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          fontSize: 18 * scale,
                          height: 1.45,
                          letterSpacing: 0.21 * scale,
                          color: AppColors.narText,
                        ),
                      ),
                    ),
                    SizedBox(height: 9 * scale),
                    _WarningRow(text: l.withdrawWarningData, scale: scale),
                    SizedBox(height: 9 * scale),
                    _WarningRow(text: l.withdrawWarningImmediate, scale: scale),
                    SizedBox(height: 32 * scale),
                  ],
                ),
              ),
            ),
            // 피드백 유도 + 고객센터 진입 — 안내 글 길이와 무관하게
            // 탈퇴 버튼 바로 위에 붙는다.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.withdrawFeedback,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                      fontSize: 16 * scale,
                      height: 1.45,
                      letterSpacing: 0.21 * scale,
                      color: AppColors.narText,
                    ),
                  ),
                  SizedBox(height: 20 * scale),
                  MypageCardValueRow(
                    scale: scale,
                    label: l.customerService,
                    showChevron: true,
                    emphasizeLabel: true,
                    onTap: _openCustomerService,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24 * scale),
            // 와딩 회원 탈퇴하기 — 누르는 즉시 탈퇴된다. 항상 활성.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: CommonButton(
                label: l.withdrawSubmit,
                variant: CommonButtonVariant.light,
                scale: scale,
                onPressed: _isWithdrawing ? null : _withdraw,
              ),
            ),
            SizedBox(height: 32 * scale),
          ],
        ),
      ),
    );
  }
}

/// 경고 한 줄 — triangle-alert 아이콘(18) + gap 9 + 문구(14/400).
class _WarningRow extends StatelessWidget {
  const _WarningRow({required this.text, required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          'assets/icons/triangle-alert.svg',
          width: 18 * scale,
          height: 18 * scale,
        ),
        SizedBox(width: 9 * scale),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 14 * scale,
              height: 1.45,
              letterSpacing: 0.21 * scale,
              color: AppColors.narText,
            ),
          ),
        ),
      ],
    );
  }
}
