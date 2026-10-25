import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/player_detail.dart';
import '../../../styles/app_colors.dart';
import 'player_parts.dart';

/// 남은 날짜 — 달력 날짜 기준. 지난 경기면 null.
int? daysUntil(DateTime at, DateTime now) {
  final a = DateTime(at.year, at.month, at.day);
  final b = DateTime(now.year, now.month, now.day);
  final d = a.difference(b).inDays;
  return d < 0 ? null : d;
}

/// "이기면 8강 진출" — 첫 어절 뒤를 굵게.
InlineSpan stakeSpan(String label) {
  final i = label.indexOf(' ');
  if (i < 0) return TextSpan(text: label);
  return TextSpan(
    children: [
      TextSpan(text: label.substring(0, i + 1)),
      TextSpan(
        text: label.substring(i + 1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

/// 다음 경기 카드 — 대진·일정·"이기면 …"·경기 알림 버튼.
class PlayerNextMatchCard extends StatelessWidget {
  const PlayerNextMatchCard({
    super.key,
    required this.match,
    required this.alarmOn,
    required this.onAlarm,
    required this.scale,
  });

  final PlayerNextMatch match;
  final bool alarmOn;
  final VoidCallback onAlarm;
  final double scale;

  static const Key alarmKey = ValueKey('playerMatchAlarm');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final at = match.scheduledAt?.toLocal();
    final days = at == null ? null : daysUntil(at, DateTime.now());
    final stake = match.stakeLabel;

    return PlayerCard(
      scale: scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16 * scale, 14 * scale, 14 * scale, 0),
            child: Row(
              children: [
                if (match.isWorlds) ...[
                  Image.asset(
                    'assets/icons/leagues/worlds.png',
                    width: 18 * scale,
                    height: 18 * scale,
                  ),
                  SizedBox(width: 6 * scale),
                ],
                Expanded(
                  child: Text(
                    match.stage.isEmpty
                        ? l.playerNextMatchNoStage
                        : l.playerNextMatch(match.stage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: playerText(
                      scale,
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.narGray400,
                    ),
                  ),
                ),
                if (days != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 * scale,
                      vertical: 3 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.narRedOpacity25,
                      borderRadius: BorderRadius.circular(10 * scale),
                    ),
                    child: Text(
                      days == 0 ? l.playerDdayToday : l.playerDday(days),
                      style: playerText(
                        scale,
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppColors.narTextRed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 14 * scale),
            child: Row(
              children: [
                Expanded(
                  child: _Team(team: match.team, scale: scale),
                ),
                Column(
                  children: [
                    if (at != null) ...[
                      Text(
                        DateFormat.MMMEd(locale).format(at),
                        style: playerText(
                          scale,
                          size: 12,
                          color: AppColors.narText2,
                        ),
                      ),
                      SizedBox(height: 2 * scale),
                      Text(
                        DateFormat('HH:mm').format(at),
                        style: playerText(
                          scale,
                          size: 26,
                          weight: FontWeight.w700,
                          family: 'Open Sans',
                        ),
                      ),
                    ],
                    SizedBox(height: 2 * scale),
                    Text(
                      match.bestOf <= 1
                          ? l.playerSingleGame
                          : l.playerBestOf(match.bestOf, match.bestOf ~/ 2 + 1),
                      style: playerText(
                        scale,
                        size: 11,
                        color: AppColors.narText2,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: _Team(team: match.opponent, scale: scale),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.narLine)),
            ),
            padding: EdgeInsets.fromLTRB(
              16 * scale,
              10 * scale,
              12 * scale,
              10 * scale,
            ),
            child: Row(
              children: [
                Expanded(
                  child: stake == null
                      ? const SizedBox.shrink()
                      : Text.rich(
                          stakeSpan(stake),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: playerText(scale, size: 13),
                        ),
                ),
                GestureDetector(
                  key: alarmKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onAlarm,
                  child: Container(
                    height: 34 * scale,
                    padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                    decoration: BoxDecoration(
                      gradient: alarmOn ? null : AppColors.narBg,
                      color: alarmOn ? AppColors.narDark500 : null,
                      borderRadius: BorderRadius.circular(9 * scale),
                      border: alarmOn
                          ? Border.all(color: AppColors.narLine2)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          alarmOn
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none_rounded,
                          size: 16 * scale,
                          color: AppColors.narText,
                        ),
                        SizedBox(width: 4 * scale),
                        Text(
                          alarmOn ? l.playerMatchAlarmOn : l.playerMatchAlarm,
                          style: playerText(
                            scale,
                            size: 13,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
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
}

class _Team extends StatelessWidget {
  const _Team({required this.team, required this.scale});

  final PlayerMatchTeam team;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          width: 48 * scale,
          height: 48 * scale,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.narDark500,
            shape: BoxShape.circle,
          ),
          child: TeamCodeBadge(
            teamCode: team.teamCode,
            size: 30 * scale,
            imageUrl: team.teamImageUrl,
          ),
        ),
        SizedBox(height: 6 * scale),
        Text(
          team.teamCode.isNotEmpty ? team.teamCode : team.teamName,
          style: playerText(
            scale,
            size: 14,
            weight: FontWeight.w700,
            family: 'Open Sans',
          ),
        ),
        Text(
          l.playerWinLoss(team.wins, team.losses),
          style: playerText(scale, size: 11, color: AppColors.narText2),
        ),
      ],
    );
  }
}
