import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/nar_toggle.dart';
import '../../../model/team_notification_subscription.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../viewmodel/subscription/team_alarm_viewmodel.dart';

/// 마이페이지 — 구독 팀 알림 설정 섹션 (양옆 20 패딩).
///
/// 상단: '구독 팀 알림 설정' 타이틀 + '구독 관리' 액션.
/// 하단: narDark600 카드 안에 팀별 블록(로고/팀명 + 알림 토글 3개).
/// 구독중인 팀과 알림 설정은 `notification-subscriptions` API 로 받고,
/// 토글하면 `PUT` 으로 서버에 반영한다.
class SubscriptionAlarmSection extends StatefulWidget {
  const SubscriptionAlarmSection({
    super.key,
    this.scale = 1,
    this.onManageTap,
  });

  final double scale;
  final VoidCallback? onManageTap;

  @override
  State<SubscriptionAlarmSection> createState() =>
      SubscriptionAlarmSectionState();
}

class SubscriptionAlarmSectionState extends State<SubscriptionAlarmSection> {
  final TeamAlarmViewModel _viewModel = TeamAlarmViewModel();

  /// 구독 팀 알림 목록을 다시 불러온다.
  /// 구독 관리 화면에서 팀 구독을 변경하고 돌아왔을 때 호출한다.
  Future<void> reload() => _viewModel.load();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        // 비회원(JWT 없음)이면 섹션을 통째로 숨긴다.
        if (!_viewModel.loggedIn) return const SizedBox.shrink();
        return _buildSection(scale);
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
          // 헤더: 타이틀 + 구독 관리.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l.subscriptionTeamAlarmSettings,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 17 * scale,
                  height: 25 / 17,
                  color: AppColors.narText,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onManageTap,
                child: Text(
                  l.subscriptionManage,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500,
                    fontSize: 14 * scale,
                    height: 1.55,
                    color: AppColors.narTextTertiary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          _buildCard(scale),
        ],
      ),
    );
  }

  /// 구독중인 팀 알림 카드. 로딩/빈 상태/목록을 그린다.
  Widget _buildCard(double scale) {
    final l = AppLocalizations.of(context)!;
    final teams = _viewModel.teams;
    return Container(
      padding: EdgeInsets.only(top: 10 * scale, bottom: 20 * scale),
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_viewModel.isLoading && teams.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24 * scale),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (teams.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20 * scale,
                vertical: 16 * scale,
              ),
              child: Text(
                l.noSubscribedTeam,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  fontSize: 14 * scale,
                  color: AppColors.narTextTertiarySub,
                ),
              ),
            )
          else
            for (var i = 0; i < teams.length; i++) ...[
              if (i > 0) SizedBox(height: 8 * scale),
              _TeamAlarmBlock(
                team: teams[i],
                viewModel: _viewModel,
                scale: scale,
              ),
            ],
        ],
      ),
    );
  }
}

/// 팀 한 블록: 팀 헤더(로고+팀명) + 알림 토글 3행.
class _TeamAlarmBlock extends StatelessWidget {
  const _TeamAlarmBlock({
    required this.team,
    required this.viewModel,
    required this.scale,
  });

  final TeamNotificationSubscription team;
  final TeamAlarmViewModel viewModel;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 팀 헤더 (padding 8/20).
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20 * scale,
            vertical: 8 * scale,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TeamLogo(url: team.teamImageUrl, scale: scale),
              SizedBox(width: 8 * scale),
              Text(
                team.teamName,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 16 * scale,
                  height: 19 / 16,
                  letterSpacing: 0.21 * scale,
                  color: AppColors.narText,
                ),
              ),
            ],
          ),
        ),
        // 알림 토글 3행.
        _AlarmRow(
          label: l.setStartAlarm,
          value: team.setStartEnabled,
          onChanged: (v) => viewModel.setSetStart(team.teamId, v),
          scale: scale,
        ),
        _AlarmRow(
          label: l.setEndAlarm,
          value: team.setEndEnabled,
          onChanged: (v) => viewModel.setSetEnd(team.teamId, v),
          scale: scale,
        ),
        _AlarmRow(
          label: l.liveEventAlarm,
          value: team.liveEventEnabled,
          onChanged: (v) => viewModel.setLiveEvent(team.teamId, v),
          scale: scale,
        ),
      ],
    );
  }
}

/// 팀 로고 33×33 원형. URL 없으면 회색 원 placeholder.
class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.url, required this.scale});

  final String url;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 33 * scale;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.narDark200,
        shape: BoxShape.circle,
      ),
    );
    if (url.isEmpty) return placeholder;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: resolveImageUrl(url)!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

/// 알림 토글 한 행: 라벨 + [NarToggle] (padding 2/20/2/60).
class _AlarmRow extends StatelessWidget {
  const _AlarmRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.scale,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(60 * scale, 2 * scale, 20 * scale, 2 * scale),
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
          NarToggle(value: value, onChanged: onChanged, scale: scale),
        ],
      ),
    );
  }
}
