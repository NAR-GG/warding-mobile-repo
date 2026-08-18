import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/nar_toggle.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/player_subscription.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../viewmodel/subscription/player_alarm_viewmodel.dart';

/// 구독중인 선수 알림 카드 ('선수' 탭 내용).
///
/// narDark600 카드 안에 선수별 블록(아바타/이름 + 솔랭 시작·종료 토글 2개)을 쌓는다.
/// 팀 카드와 같은 골격이되 헤더 높이(45)와 토글 개수(2)만 다르다.
class PlayerAlarmCard extends StatelessWidget {
  const PlayerAlarmCard({
    super.key,
    required this.viewModel,
    this.scale = 1,
  });

  final PlayerAlarmViewModel viewModel;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final players = viewModel.players;

    return Container(
      padding: EdgeInsets.only(top: 10 * scale, bottom: 20 * scale),
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (viewModel.isLoading && players.isEmpty)
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) SizedBox(height: 8 * scale),
              _PlayerAlarmBlockSkeleton(scale: scale),
            ]
          else if (players.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20 * scale,
                vertical: 16 * scale,
              ),
              child: Text(
                l.noSubscribedPlayer,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  fontSize: 14 * scale,
                  color: AppColors.narTextTertiarySub,
                ),
              ),
            )
          else
            for (var i = 0; i < players.length; i++) ...[
              if (i > 0) SizedBox(height: 8 * scale),
              _PlayerAlarmBlock(
                player: players[i],
                viewModel: viewModel,
                scale: scale,
              ),
            ],
        ],
      ),
    );
  }
}

/// 선수 한 블록: 선수 헤더(아바타+팀코드 이름) + 솔랭 알림 토글 2행.
class _PlayerAlarmBlock extends StatelessWidget {
  const _PlayerAlarmBlock({
    required this.player,
    required this.viewModel,
    required this.scale,
  });

  final PlayerSubscription player;
  final PlayerAlarmViewModel viewModel;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // 시안 표기는 'T1 Faker' — 팀 코드가 비어 있으면 이름만 쓴다.
    final label = player.teamCode.isEmpty
        ? player.playerName
        : '${player.teamCode} ${player.playerName}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 선수 헤더 (padding 8/20, 높이 45).
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20 * scale,
            vertical: 8 * scale,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _PlayerAvatar(url: player.playerImageUrl, scale: scale),
              SizedBox(width: 8 * scale),
              Text(
                label,
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
        // 솔랭 알림 토글 2행.
        _PlayerAlarmRow(
          label: l.soloRankStartAlarm,
          value: player.startEnabled,
          onChanged: (v) => viewModel.setSoloRankStart(player.playerId, v),
          scale: scale,
        ),
        _PlayerAlarmRow(
          label: l.soloRankEndAlarm,
          value: player.endEnabled,
          onChanged: (v) => viewModel.setSoloRankEnd(player.playerId, v),
          scale: scale,
        ),
      ],
    );
  }
}

/// 선수 아바타. 팀 로고와 달리 원형으로 자르지 않는다(시안 비율 유지).
///
/// 시안 값은 29 인데 실물에서 너무 작아 보여 [_avatarSize] 로 키웠다.
/// 헤더가 그만큼 높아지지만 토글 행 위치는 그대로다.
class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.url, required this.scale});

  /// 아바타 한 변 크기(디자인 기준 폭 375).
  static const double _avatarSize = 36;

  final String url;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = _avatarSize * scale;
    if (url.isEmpty) return SizedBox(width: size, height: size);
    return SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: resolveImageUrl(url)!,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// 솔랭 알림 토글 한 행: 라벨 + [NarToggle] (padding 2/20/2/60, 행 높이 38).
class _PlayerAlarmRow extends StatelessWidget {
  const _PlayerAlarmRow({
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
              height: 34 / 14,
              color: AppColors.narText,
            ),
          ),
          NarToggle(value: value, onChanged: onChanged, scale: scale),
        ],
      ),
    );
  }
}

/// 선수 알림 목록 최초 로딩 중 표시할 스켈레톤 블록.
/// [_PlayerAlarmBlock] 과 동일한 레이아웃(아바타+이름 헤더 + 토글 2행)에 회색 박스를
/// 깔고 opacity 를 펄스시킨다.
class _PlayerAlarmBlockSkeleton extends StatefulWidget {
  const _PlayerAlarmBlockSkeleton({this.scale = 1});

  final double scale;

  @override
  State<_PlayerAlarmBlockSkeleton> createState() =>
      _PlayerAlarmBlockSkeletonState();
}

class _PlayerAlarmBlockSkeletonState extends State<_PlayerAlarmBlockSkeleton>
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
              EdgeInsets.fromLTRB(60 * scale, 2 * scale, 20 * scale, 2 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              box(w: 80 * scale, h: 14 * scale), // 라벨
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 아바타 — 실제 블록과 같은 크기.
                  box(
                    w: _PlayerAvatar._avatarSize * scale,
                    h: _PlayerAvatar._avatarSize * scale,
                  ),
                  SizedBox(width: 8 * scale),
                  box(w: 64 * scale, h: 16 * scale), // 이름
                ],
              ),
            ),
            alarmRow(),
            alarmRow(),
          ],
        );
      },
    );
  }
}
