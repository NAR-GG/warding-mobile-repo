import 'package:flutter/material.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../components/nar_toggle.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../../../util/rating_mapping.dart';
import '../../../viewmodel/my_players/my_players_viewmodel.dart';
import 'my_player_tile.dart';

/// 월즈 솔랭에서 선수를 눌렀을 때 — 지금 상태와 솔랭 알림 토글, 구독/해제.
///
/// 구독 전이면 토글은 "구독하면 이렇게 받는다" 는 미리 고르기라 시트 안에서만
/// 바뀌고 구독할 때 함께 보낸다. 구독 중이면 바로 서버에 반영한다.
Future<void> showWorldsPlayerSheet(
  BuildContext context, {
  required MyPlayersViewModel viewModel,
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

  final MyPlayersViewModel viewModel;
  final int playerId;
  final double scale;

  static const Key subscribeKey = ValueKey('worldsSheetSubscribe');

  @override
  State<WorldsPlayerSheet> createState() => _WorldsPlayerSheetState();
}

class _WorldsPlayerSheetState extends State<WorldsPlayerSheet> {
  // 구독 전 미리 고른 토글. 서버 기본값과 같다(시작 ON·종료 OFF).
  bool _start = true;
  bool _end = false;

  MyPlayerEntry? _entry() {
    final vm = widget.viewModel;
    for (final e in [...vm.liveSolo, ...vm.playedToday, ...vm.quiet]) {
      if (e.player.playerId == widget.playerId) return e;
    }
    return null;
  }

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
                        SizedBox(height: 6 * scale),
                        MyPlayerStatusLine(entry: entry, scale: scale),
                      ],
                    ),
                  ),
                ],
              ),
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
                onTap: () {
                  vm.setSubscribed(
                    player.playerId,
                    !subscribed,
                    startEnabled: start,
                    endEnabled: end,
                  );
                  Navigator.of(context).pop();
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
