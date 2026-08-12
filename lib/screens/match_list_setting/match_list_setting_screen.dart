import 'package:flutter/material.dart';

import '../../components/common_button.dart';
import '../../components/nar_setting_header.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/match_list_setting/match_list_setting_viewmodel.dart';
import '../mypage/component/mypage_card_section.dart';

/// 경기리스트 설정 화면. 마이페이지 '화면 설정' 섹션의 '경기 리스트' 진입점.
///
/// 헤더는 설정 상세 공용 [NarSettingHeader] 를 쓰고, 하단에는 마이 구독 설정과
/// 같은 '완료' 버튼을 둔다. 버튼은 바뀐 값이 있을 때만 활성이다.
///
/// 경기 리스트·경기 일정 화면의 스포방지 토글과 달리 토글이 즉시 저장되지
/// 않는다. 변경을 모아 두고 '완료' 버튼에서 저장한다.
class MatchListSettingScreen extends StatefulWidget {
  const MatchListSettingScreen({super.key});

  @override
  State<MatchListSettingScreen> createState() => _MatchListSettingScreenState();
}

class _MatchListSettingScreenState extends State<MatchListSettingScreen> {
  final MatchListSettingViewModel _viewModel = MatchListSettingViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// 변경분을 저장하고 화면을 닫는다.
  Future<void> _save() async {
    await _viewModel.save();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NarSettingHeader(title: l.matchListSetting, scale: scale),
                SizedBox(height: 17 * scale),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 스포 방지 카드 — 라벨 없는 카드 하나.
                        ListenableBuilder(
                          listenable: _viewModel,
                          builder: (context, _) => MypageCardSection(
                            scale: scale,
                            horizontalPadding: 16,
                            children: [
                              MypageCardToggleRow(
                                scale: scale,
                                title: l.spoilerCard,
                                description: l.spoilerCardDescription,
                                value: _viewModel.spoilerEnabled,
                                onChanged: _viewModel.setSpoilerEnabled,
                              ),
                            ],
                          ),
                        ),
                        // 하단 고정 버튼에 가리지 않도록 여백.
                        SizedBox(height: 114 * scale),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 완료 — 바뀐 값이 없으면 비활성.
            Positioned(
              left: 24 * scale,
              right: 24 * scale,
              bottom: 32 * scale,
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) => CommonButton(
                  label: l.done,
                  variant: CommonButtonVariant.light,
                  scale: scale,
                  onPressed: _viewModel.isDirty ? _save : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
