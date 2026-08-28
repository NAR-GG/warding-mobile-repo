import 'package:flutter/material.dart';

import '../../components/common_button.dart';
import '../../components/nar_alert_dialog.dart';
import '../../components/nar_setting_header.dart';
import '../../l10n/app_localizations.dart';
import '../../repository/auth/auth_service.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/mypage/mypage_viewmodel.dart';
import '../login/login_screen.dart';
import '../mypage/component/mypage_card_section.dart';
import '../withdraw/withdraw_screen.dart';

/// 계정 설정 화면. 마이페이지 '고객 지원' 섹션의 '계정' 진입점.
///
/// 헤더는 설정 상세 공용 [NarSettingHeader] 를 쓴다. 카드에 닉네임·이메일과
/// 회원탈퇴 진입을 두고, 그 아래에 로그아웃 버튼을 가운데 놓는다.
///
/// 로그아웃·회원탈퇴는 마이페이지와 같은 흐름이다. 값을 고치는 화면이 아니라
/// 하단 '완료' 버튼은 두지 않는다.
class AccountSettingScreen extends StatefulWidget {
  const AccountSettingScreen({super.key});

  @override
  State<AccountSettingScreen> createState() => _AccountSettingScreenState();
}

class _AccountSettingScreenState extends State<AccountSettingScreen> {
  final MypageViewModel _viewModel = MypageViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// 로그아웃 — 확인 다이얼로그 후 소셜·자체 토큰을 정리하고 로그인 화면으로.
  Future<void> _logout() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showNarConfirmDialog(
      context: context,
      title: l.logoutConfirmTitle,
      message: l.logoutConfirmMessage(_viewModel.email ?? ''),
      confirmLabel: l.logoutConfirmButton,
    );
    if (confirmed != true || !mounted) return;
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// 회원탈퇴 — 안내와 확인은 별도 화면에서 받는다.
  Future<void> _goToWithdraw() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const WithdrawScreen()));
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
            NarSettingHeader(title: l.accountSetting, scale: scale),
            SizedBox(height: 17 * scale),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 계정 정보 — 라벨 없는 카드 하나.
                    ListenableBuilder(
                      listenable: _viewModel,
                      builder: (context, _) => MypageCardSection(
                        scale: scale,
                        children: [
                          MypageCardValueRow(
                            scale: scale,
                            label: l.accountNickname,
                            value: _viewModel.nickname.isEmpty
                                ? l.nicknamePlaceholder
                                : _viewModel.nickname,
                          ),
                          MypageCardValueRow(
                            scale: scale,
                            label: l.accountEmail,
                            value: _viewModel.email ?? '',
                          ),
                          MypageCardValueRow(
                            scale: scale,
                            label: l.withdraw,
                            showChevron: true,
                            onTap: _goToWithdraw,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 17 * scale),
                    // 로그아웃 — 내용 폭 버튼을 가운데 정렬.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CommonButton(
                          label: l.logout,
                          variant: CommonButtonVariant.logout,
                          scale: scale,
                          onPressed: _logout,
                        ),
                      ],
                    ),
                    SizedBox(height: 32 * scale),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
