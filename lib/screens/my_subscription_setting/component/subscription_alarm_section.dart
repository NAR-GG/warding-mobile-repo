import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/nar_toggle.dart';
import '../../../model/team_notification_subscription.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../viewmodel/subscription/team_alarm_viewmodel.dart';

/// 구독 팀 알림 설정 섹션 (양옆 20 패딩).
///
/// 상단: '구독 팀 알림 설정' 타이틀 + '구독 관리' 액션.
/// 하단: narDark600 카드 안에 팀별 블록(로고/팀명 + 알림 토글 3개).
/// 구독중인 팀과 알림 설정은 `notification-subscriptions` API 로 받는다.
///
/// [viewModel] 을 주면 그 인스턴스를 쓰고(마이 구독 설정 화면처럼 '완료' 버튼과
/// 상태를 공유할 때), 없으면 내부에서 만들어 토글 즉시 서버에 반영한다.
class SubscriptionAlarmSection extends StatefulWidget {
  const SubscriptionAlarmSection({
    super.key,
    this.scale = 1,
    this.onManageTap,
    this.viewModel,
    this.showHeader = true,
  });

  final double scale;
  final VoidCallback? onManageTap;

  /// 외부에서 주입하는 ViewModel. null 이면 내부에서 생성·해제한다.
  final TeamAlarmViewModel? viewModel;

  /// false 면 '구독 팀 알림 설정' 타이틀 줄을 감춘다.
  /// 화면 헤더가 이미 같은 맥락을 알려 주는 경우에 쓴다.
  final bool showHeader;

  @override
  State<SubscriptionAlarmSection> createState() =>
      SubscriptionAlarmSectionState();
}

class SubscriptionAlarmSectionState extends State<SubscriptionAlarmSection> {
  /// 주입받지 않았을 때만 만드는 내부 ViewModel. dispose 책임도 여기에 있다.
  TeamAlarmViewModel? _owned;

  TeamAlarmViewModel get _viewModel =>
      widget.viewModel ?? (_owned ??= TeamAlarmViewModel());

  /// 구독 팀 알림 목록을 다시 불러온다.
  /// 구독 관리 화면에서 팀 구독을 변경하고 돌아왔을 때 호출한다.
  Future<void> reload() => _viewModel.load();

  @override
  void dispose() {
    // 주입받은 ViewModel 은 준 쪽이 해제한다.
    _owned?.dispose();
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
          if (widget.showHeader) ...[
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
          ],
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
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) SizedBox(height: 8 * scale),
              _TeamAlarmBlockSkeleton(scale: scale),
            ]
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

/// 알림 토글 한 행: 라벨 + [NarToggle] (padding 4/20/4/60).
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
      padding: EdgeInsets.fromLTRB(60 * scale, 4 * scale, 20 * scale, 4 * scale),
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

/// 팀 알림 목록 최초 로딩 중 표시할 스켈레톤 블록.
/// [_TeamAlarmBlock] 과 동일한 레이아웃(로고+팀명 헤더 + 토글 3행)에 회색 박스를
/// 깔고 opacity 를 펄스시킨다. [MatchCardSkeleton] 과 동일한 톤.
class _TeamAlarmBlockSkeleton extends StatefulWidget {
  const _TeamAlarmBlockSkeleton({this.scale = 1});

  final double scale;

  @override
  State<_TeamAlarmBlockSkeleton> createState() =>
      _TeamAlarmBlockSkeletonState();
}

class _TeamAlarmBlockSkeletonState extends State<_TeamAlarmBlockSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final opacity = 0.3 + (_ctrl.value * 0.3); // 0.3 ↔ 0.6 펄스
        Widget box({double? w, required double h, double r = 4}) => Opacity(
          opacity: opacity,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: AppColors.narLine2,
              borderRadius: BorderRadius.circular(r),
            ),
          ),
        );
        Widget alarmRow() => Padding(
          padding:
              EdgeInsets.fromLTRB(60 * scale, 4 * scale, 20 * scale, 4 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              box(w: 70 * scale, h: 14 * scale), // 라벨
              box(w: 34 * scale, h: 19 * scale, r: 9.5), // 토글
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20 * scale,
                vertical: 8 * scale,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  box(w: 33 * scale, h: 33 * scale, r: 33), // 로고
                  SizedBox(width: 8 * scale),
                  box(w: 80 * scale, h: 16 * scale), // 팀명
                ],
              ),
            ),
            alarmRow(),
            alarmRow(),
            alarmRow(),
          ],
        );
      },
    );
  }
}
