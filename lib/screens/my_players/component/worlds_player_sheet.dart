import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../components/nar_live_dot.dart';
import '../../../components/nar_toggle.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/home_models.dart';
import '../../../repository/auth/auth_service.dart';
import '../../../repository/home/home_sources.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../util/live_elapsed.dart';
import '../../../util/rating_mapping.dart';
import '../../../viewmodel/my_players/my_players_viewmodel.dart';
import '../../login/login_screen.dart';
import 'my_player_tile.dart';

/// 선수 구독 시트 — 지금 상태와 솔랭 알림 토글, 구독/해제. 월즈 솔랭 벨과
/// 선수 페이지 벨이 같은 시트를 쓴다([PlayerSheetSource]).
///
/// 구독 전이면 토글은 "구독하면 이렇게 받는다" 는 미리 고르기라 시트 안에서만
/// 바뀌고 구독할 때 함께 보낸다. 구독 중이면 바로 서버에 반영한다.
Future<void> showWorldsPlayerSheet(
  BuildContext context, {
  required PlayerSheetSource viewModel,
  required int playerId,
  required double scale,
}) {
  return showAppBottomSheet<void>(
    context: context,
    child: WorldsPlayerSheet(
      viewModel: viewModel,
      playerId: playerId,
      scale: scale,
    ),
  );
}

class WorldsPlayerSheet extends StatefulWidget {
  const WorldsPlayerSheet({
    super.key,
    required this.viewModel,
    required this.playerId,
    required this.scale,
  });

  final PlayerSheetSource viewModel;
  final int playerId;
  final double scale;

  static const Key subscribeKey = ValueKey('worldsSheetSubscribe');

  @override
  State<WorldsPlayerSheet> createState() => _WorldsPlayerSheetState();
}

class _WorldsPlayerSheetState extends State<WorldsPlayerSheet> {
  // 구독 전 미리 고른 토글. 월즈는 시작·종료 둘 다 ON 으로 시작한다(서버 기본값은 종료 OFF).
  bool _start = true;
  bool _end = true;

  /// 진행 중인 판의 경과 시간을 매초 올리는 틱. 바뀌는 건 배너의 시간
  /// 텍스트 하나라 시트 전체를 다시 그리지 않는다.
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    // 시트는 진행 중인 판을 보여줄 때만 열려 있는 동안 돌면 된다.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _tick.value++;
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _tick.dispose();
    super.dispose();
  }

  MyPlayerEntry? _entry() => widget.viewModel.sheetEntry(widget.playerId);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scale = widget.scale;
    final vm = widget.viewModel;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final entry = _entry();
        if (entry == null) return const SizedBox.shrink();
        final player = entry.player;
        final live = entry.live;
        final record = vm.todayRecord(player.playerId);
        final subscribed = player.subscribed;
        final start = subscribed ? player.startEnabled : _start;
        final end = subscribed ? player.endEnabled : _end;
        final role = positionFromRole(player.role);
        final sub = [
          if (player.teamCode.isNotEmpty) player.teamCode,
          if (role.isNotEmpty) role,
        ].join(' · ');

        void setAlarm({bool? startValue, bool? endValue}) {
          final s = startValue ?? start;
          final e = endValue ?? end;
          if (subscribed) {
            vm.setAlarms(player.playerId, startEnabled: s, endEnabled: e);
          } else {
            setState(() {
              _start = s;
              _end = e;
            });
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(4 * scale, 12 * scale, 4 * scale, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  MyPlayerAvatar(
                    name: player.playerName,
                    imageUrl: player.playerImageUrl,
                    teamCode: player.teamCode,
                    teamImageUrl: player.teamImageUrl,
                    scale: scale,
                    diameter: 56,
                  ),
                  SizedBox(width: 14 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.playerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            fontSize: 22 * scale,
                            height: 1.1,
                            color: AppColors.narText,
                          ),
                        ),
                        if (sub.isNotEmpty) ...[
                          SizedBox(height: 3 * scale),
                          Text(
                            sub,
                            style: TextStyle(
                              fontFamily: 'Open Sans',
                              fontSize: 13 * scale,
                              color: AppColors.narText2,
                            ),
                          ),
                        ],
                        // 진행 중이면 아래 배너가 같은 내용을 크게 보여준다.
                        if (live == null) ...[
                          SizedBox(height: 6 * scale),
                          MyPlayerStatusLine(entry: entry, scale: scale),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (live != null) ...[
                SizedBox(height: 16 * scale),
                _LiveBanner(live: live, scale: scale, tick: _tick),
              ],
              if (record != null) ...[
                SizedBox(height: 12 * scale),
                _TodayStats(record: record, scale: scale),
              ],
              SizedBox(height: 18 * scale),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.narBgTertiary,
                  borderRadius: BorderRadius.circular(12 * scale),
                  border: Border.all(color: AppColors.narLine),
                ),
                child: Column(
                  children: [
                    _ToggleRow(
                      label: l.soloRankStartAlarm,
                      value: start,
                      scale: scale,
                      onChanged: (v) => setAlarm(startValue: v),
                    ),
                    Container(
                      height: 1,
                      margin: EdgeInsets.symmetric(horizontal: 14 * scale),
                      color: AppColors.narLine,
                    ),
                    _ToggleRow(
                      label: l.soloRankEndAlarm,
                      value: end,
                      scale: scale,
                      onChanged: (v) => setAlarm(endValue: v),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16 * scale),
              _SubscribeButton(
                key: WorldsPlayerSheet.subscribeKey,
                label: subscribed
                    ? l.worldsSoloUnsubscribe
                    : l.worldsSoloSubscribe,
                filled: !subscribed,
                scale: scale,
                onTap: () async {
                  final navigator = Navigator.of(context)..pop();
                  // 비회원이면 구독 대신 로그인으로 보낸다.
                  if (!await _loggedIn()) {
                    unawaited(
                      navigator.push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      ),
                    );
                    return;
                  }
                  unawaited(
                    vm.setSubscribed(
                      player.playerId,
                      !subscribed,
                      startEnabled: start,
                      endEnabled: end,
                    ),
                  );
                },
              ),
              SizedBox(height: 10 * scale),
              Text(
                l.worldsSoloSheetHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12 * scale,
                  color: AppColors.narDark200,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<bool> _loggedIn() async {
  try {
    return await AuthService.instance.jwt != null;
  } catch (_) {
    return true; // Keychain 을 못 읽은 건 로그아웃이 아니다.
  }
}

/// 진행 중인 판 — 챔피언 스플래시 위에 "솔로 랭크 진행 중", 경과 시간·챔피언·지역.
class _LiveBanner extends StatelessWidget {
  const _LiveBanner({
    required this.live,
    required this.scale,
    required this.tick,
  });

  final ValueListenable<int> tick;

  final HomeLiveSoloPlayer live;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // 홈 라이브 카드와 같은 순서 — 가로형 스플래시, 없으면 서버 이미지.
    final fromServer = resolveImageUrl(live.championImageUrl);
    final splashUrl =
        championSplashUrl(live.champion) ??
        ((fromServer != null && fromServer.isNotEmpty) ? fromServer : null);
    final region = live.overseasRegion;

    return Container(
      height: 104 * scale,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.narSoloHeroBg,
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (splashUrl != null)
            CachedNetworkImage(
              imageUrl: splashUrl,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.3),
              fadeInDuration: const Duration(milliseconds: 150),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.narPlayedChampOverlay,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              14 * scale,
              12 * scale,
              14 * scale,
              12 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 24 * scale,
                  padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                  decoration: BoxDecoration(
                    gradient: AppColors.narSoloTint,
                    borderRadius: BorderRadius.circular(12 * scale),
                    border: Border.all(color: AppColors.narSoloLine),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NarLiveDot(
                        scale: scale,
                        size: 6,
                        color: AppColors.narSoloDot,
                      ),
                      SizedBox(width: 6 * scale),
                      Text(
                        l.worldsSoloSheetLive,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          fontSize: 13 * scale,
                          color: AppColors.narSoloText,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ElapsedClock(
                      live: live,
                      tick: tick,
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 24 * scale,
                        height: 1.1,
                        color: AppColors.narText,
                      ),
                    ),
                    if (live.champion.isNotEmpty) ...[
                      SizedBox(width: 10 * scale),
                      Flexible(
                        child: Text(
                          live.champion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            fontSize: 15 * scale,
                            color: AppColors.narText,
                          ),
                        ),
                      ),
                    ],
                    if (region != null) ...[
                      SizedBox(width: 8 * scale),
                      RegionChip(region: region, scale: scale),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 진행 중인 판의 경과 시간. 서버의 `elapsedSeconds` 는 조회 시점
/// 스냅샷이라 `startedAt` 으로 매초 다시 계산한다.
class _ElapsedClock extends StatelessWidget {
  const _ElapsedClock({
    required this.live,
    required this.tick,
    required this.style,
  });

  final HomeLiveSoloPlayer live;
  final ValueListenable<int> tick;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: tick,
    builder: (_, _, _) => Text(
      formatElapsed(
        liveElapsedSeconds(
          snapshotSeconds: live.elapsedSeconds,
          startedAt: live.startedAt,
        ),
      ),
      style: style,
    ),
  );
}

/// "오늘 솔랭 N판 · 오늘 전적 N승 N패" 두 칸.
class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.record, required this.scale});

  final WorldsTodayRecord record;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    TextStyle value(Color color) => TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w700,
      fontSize: 20 * scale,
      color: color,
    );
    TextStyle unit = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w600,
      fontSize: 15 * scale,
      color: AppColors.narText,
    );

    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: l.worldsSoloTodayGames,
            scale: scale,
            value: Text(
              l.worldsSoloTodayGamesCount(record.games),
              style: value(AppColors.narText),
            ),
          ),
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: _StatBox(
            label: l.worldsSoloTodayRecord,
            scale: scale,
            value: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${record.wins}',
                    style: value(AppColors.scoreWin),
                  ),
                  TextSpan(text: l.homeSoloWin, style: unit),
                  TextSpan(text: ' '),
                  TextSpan(
                    text: '${record.losses}',
                    style: value(AppColors.narText),
                  ),
                  TextSpan(text: l.homeSoloLoss, style: unit),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.scale,
  });

  final String label;
  final Widget value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14 * scale,
        12 * scale,
        14 * scale,
        12 * scale,
      ),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13 * scale,
              color: AppColors.narText2,
            ),
          ),
          SizedBox(height: 6 * scale),
          value,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.scale,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final double scale;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52 * scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14 * scale),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  fontSize: 15 * scale,
                  color: AppColors.narTextTertiary,
                ),
              ),
            ),
            NarToggle(value: value, onChanged: onChanged, scale: scale),
          ],
        ),
      ),
    );
  }
}

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({
    super.key,
    required this.label,
    required this.filled,
    required this.scale,
    required this.onTap,
  });

  final String label;

  /// true 면 브랜드 그라데이션(구독하기), false 면 회색(구독 해제).
  final bool filled;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10 * scale);
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 52 * scale,
        decoration: BoxDecoration(
          gradient: filled ? AppColors.narBg : null,
          color: filled ? null : AppColors.narButton2Bg,
          borderRadius: radius,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 16 * scale,
                color: filled ? AppColors.narText : AppColors.narButton2Text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
