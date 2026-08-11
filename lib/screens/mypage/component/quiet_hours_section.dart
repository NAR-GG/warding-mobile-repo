import 'package:flutter/material.dart';

import '../../../components/nar_toggle.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/mypage/quiet_hours_viewmodel.dart';
import 'quiet_hours_time_sheet.dart';

/// 마이페이지 — 알림 잠자기 섹션 (양옆 20 패딩).
///
/// 구독 팀 알림 설정 **아래**에 온다.
class QuietHoursSection extends StatefulWidget {
  const QuietHoursSection({super.key, this.scale = 1});

  final double scale;

  @override
  State<QuietHoursSection> createState() => _QuietHoursSectionState();
}

class _QuietHoursSectionState extends State<QuietHoursSection> {
  final QuietHoursViewModel _viewModel = QuietHoursViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// 시각 선택 시트를 띄우고 고른 값을 저장한다.
  Future<void> _pickTime({required bool isStart}) async {
    if (_viewModel.isSaving) return;
    final l = AppLocalizations.of(context)!;
    final settings = _viewModel.settings;
    final picked = await showQuietHoursTimeSheet(
      context: context,
      title: isStart ? l.quietHoursStartSheetTitle : l.quietHoursEndSheetTitle,
      initial: isStart ? settings.start : settings.end,
    );
    if (picked == null || !mounted) return;
    if (isStart) {
      await _viewModel.setStart(picked);
    } else {
      await _viewModel.setEnd(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        // 비회원(JWT 없음)이면 섹션을 통째로 숨긴다. 설정을 서버에 저장하므로 로그인 필수다.
        if (!_viewModel.loggedIn) return const SizedBox.shrink();
        return _buildSection(widget.scale);
      },
    );
  }

  Widget _buildSection(double scale) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.quietHours,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 17 * scale,
              height: 25 / 17,
              color: AppColors.narText,
            ),
          ),
          SizedBox(height: 16 * scale),
          _buildCard(scale, l),
        ],
      ),
    );
  }

  Widget _buildCard(double scale, AppLocalizations l) {
    final settings = _viewModel.settings;
    final error = _viewModel.errorMessage;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10 * scale),
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            label: l.quietHoursUse,
            scale: scale,
            trailing: NarToggle(
              value: settings.enabled,
              onChanged: _viewModel.isSaving
                  ? null
                  : (v) => _viewModel.setEnabled(v),
              scale: scale,
            ),
          ),
          if (settings.enabled) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20 * scale,
                vertical: 6 * scale,
              ),
              child: Container(height: 1, color: AppColors.narLine),
            ),
            _Row(
              label: l.quietHoursStart,
              scale: scale,
              onTap: () => _pickTime(isStart: true),
              trailing: _TimeValue(label: _label(l, settings.start), scale: scale),
            ),
            _Row(
              label: l.quietHoursEnd,
              scale: scale,
              onTap: () => _pickTime(isStart: false),
              trailing: _TimeValue(label: _label(l, settings.end), scale: scale),
            ),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(20 * scale, 6 * scale, 20 * scale, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // "무음으로 쌓인다"는 동작이 눈에 보이지 않아 유저가 껐다고 착각하기 쉽다.
                  // 그래서 ON 안내에 실제 설정 시각을 넣는다.
                  settings.enabled
                      ? l.quietHoursOnHint(
                          _label(l, settings.start),
                          _label(l, settings.end),
                        )
                      : l.quietHoursOffHint,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    fontSize: 12 * scale,
                    height: 1.5,
                    color: AppColors.narTextTertiarySub,
                  ),
                ),
                // 에러는 안내를 대체하지 않고 아래에 덧붙인다. 대체하면 유저가
                // 이 기능이 무엇인지 설명을 잃는다.
                if (error != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4 * scale),
                    child: Text(
                      error,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                        fontSize: 12 * scale,
                        height: 1.5,
                        color: AppColors.narTextRed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 시각 표기 — `오전 1:00`. 시트가 오전/오후로 고르게 하므로 칩·안내 모두 12시간제로 맞춘다.
  String _label(AppLocalizations l, TimeOfDay time) {
    final period = time.hour < 12 ? l.quietHoursAm : l.quietHoursPm;
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$period $hour:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// 라벨 + 우측 위젯 한 행. 팀 알림 행의 좌측 들여쓰기(60)는 팀 로고 정렬용이라
/// 여기선 쓰지 않고 좌우 20으로 맞춘다.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.trailing,
    required this.scale,
    this.onTap,
  });

  final String label;
  final Widget trailing;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 5 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
              fontSize: 14 * scale,
              color: AppColors.narText,
            ),
          ),
          trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

/// 시각 값 + chevron.
class _TimeValue extends StatelessWidget {
  const _TimeValue({required this.label, required this.scale});

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        border: Border.all(color: AppColors.narLine),
        borderRadius: BorderRadius.circular(6 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 14 * scale,
              color: AppColors.narTextTertiary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(width: 4 * scale),
          Icon(
            Icons.chevron_right,
            size: 16 * scale,
            color: AppColors.narText2,
          ),
        ],
      ),
    );
  }
}
