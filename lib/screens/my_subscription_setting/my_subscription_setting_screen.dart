import 'package:flutter/material.dart';

import '../../components/common_button.dart';
import '../../components/nar_setting_header.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/subscription/team_alarm_viewmodel.dart';
import '../subscription/subscription_settings_screen.dart';
import 'component/subscription_alarm_section.dart';
import 'component/subscription_manage_entry.dart';

/// 마이 구독 설정 화면. 마이페이지 '화면 설정' 섹션의 '마이 구독' 진입점.
///
/// 헤더는 설정 상세 공용 [NarSettingHeader] 를 쓴다.
///
/// 마이페이지 섹션과 달리 토글이 즉시 서버로 가지 않는다.
/// [TeamAlarmViewModel.deferSave] 로 변경을 모아 두고 하단 '완료' 버튼에서
/// 한 번에 저장한다. 저장할 게 없으면 버튼은 비활성이다.
class MySubscriptionSettingScreen extends StatefulWidget {
  const MySubscriptionSettingScreen({super.key});

  @override
  State<MySubscriptionSettingScreen> createState() =>
      _MySubscriptionSettingScreenState();
}

class _MySubscriptionSettingScreenState
    extends State<MySubscriptionSettingScreen> {
  final TeamAlarmViewModel _viewModel = TeamAlarmViewModel(deferSave: true);

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// 구독 관리 화면으로 이동. 돌아오면 팀 구독이 바뀌었을 수 있으니
  /// 목록을 다시 불러오되, 저장 전 토글 변경은 그대로 살려 둔다.
  Future<void> _goToSubscriptionSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SubscriptionSettingsScreen(),
      ),
    );
    await _viewModel.load(keepUnsaved: true);
  }

  /// 변경분을 저장하고 성공하면 화면을 닫는다.
  /// 실패하면 화면에 남아 에러를 보여 준다(입력을 잃지 않게).
  Future<void> _save() async {
    final ok = await _viewModel.save();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    final error = _viewModel.error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
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
                NarSettingHeader(
                  title: l.mySubscriptionSetting,
                  scale: scale,
                ),
                SizedBox(height: 17 * scale),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SubscriptionManageEntry(
                          scale: scale,
                          onTap: _goToSubscriptionSettings,
                        ),
                        // 두 섹션 사이 간격 17. 세부 설정 섹션이 라벨 위쪽에
                        // 자체 패딩 10 을 갖고 있어 나머지 7 만 여기서 준다.
                        SizedBox(height: 7 * scale),
                        SubscriptionAlarmSection(
                          scale: scale,
                          viewModel: _viewModel,
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
                  onPressed: _viewModel.isDirty && !_viewModel.isSaving
                      ? _save
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
