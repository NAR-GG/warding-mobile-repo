import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/player_detail.dart';
import '../../../styles/app_colors.dart';
import '../../../util/rating_mapping.dart';
import '../../../viewmodel/player/player_viewmodel.dart';
import '../../home/component/home_solo_cheer.dart' show formatCheerCount;
import 'player_parts.dart';

/// 월즈 탭 — 성적 지표·경기별 기록·솔랭 vs 월즈 챔피언·팬 평점.
///
/// 상류 CSV 가 늦게 들어와 경기 기록이 비어 있으면 "경기 기록 집계 중".
class PlayerWorldsTab extends StatelessWidget {
  const PlayerWorldsTab({
    super.key,
    required this.viewModel,
    required this.scale,
    this.onOpenReview,
  });

  final PlayerViewModel viewModel;
  final double scale;

  /// 한줄평 탭 — 그 판 평점 상세로.
  final ValueChanged<PlayerReview>? onOpenReview;

  static const Key reviewsAllKey = ValueKey('playerReviewsAll');
  static Key reviewKey(int index) => ValueKey('playerReview-$index');

  static const Key pendingKey = ValueKey('playerWorldsPending');
  static const int _championPreview = 5;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vm = viewModel;
    final w = vm.worlds;
    final champions = vm.sortedChampions;
    final shownChampions = vm.championsExpanded
        ? champions
        : champions.take(_championPreview).toList();
    final rating = w?.rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSectionTitle(
          title: l.playerWorldsRecord,
          sub: w == null
              ? null
              : l.playerWorldsRecordSub(w.games, w.wins, w.losses),
          scale: scale,
        ),
        if (w == null || w.matches.isEmpty)
          PlayerCard(
            key: pendingKey,
            scale: scale,
            child: SizedBox(
              height: 120 * scale,
              child: Center(
                child: Text(
                  l.playerWorldsPending,
                  style: playerText(scale, size: 13, color: AppColors.narText2),
                ),
              ),
            ),
          )
        else ...[
          if (w.stats.isNotEmpty)
            _StatGrid(
              stats: w.stats,
              position: positionFromRole(vm.detail?.role ?? ''),
              scale: scale,
            ),
          PlayerSectionTitle(title: l.playerWorldsGames, scale: scale),
          PlayerCard(
            scale: scale,
            child: Column(
              children: [
                for (var i = 0; i < w.matches.length; i++)
                  _GameRow(game: w.matches[i], first: i == 0, scale: scale),
              ],
            ),
          ),
        ],
        if (champions.isNotEmpty) ...[
          PlayerSectionTitle(title: l.playerChampions, scale: scale),
          Row(
            children: [
              _SortChip(
                label: l.playerSortSolo,
                selected: vm.championSort == PlayerChampionSort.solo,
                onTap: () => vm.setChampionSort(PlayerChampionSort.solo),
                scale: scale,
              ),
              SizedBox(width: 6 * scale),
              _SortChip(
                label: l.playerSortWorlds,
                selected: vm.championSort == PlayerChampionSort.worlds,
                onTap: () => vm.setChampionSort(PlayerChampionSort.worlds),
                scale: scale,
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          PlayerCard(
            scale: scale,
            child: Column(
              children: [
                _ChampionRow.header(l, scale),
                for (final c in shownChampions)
                  _ChampionRow(champion: c, scale: scale),
              ],
            ),
          ),
          if (!vm.championsExpanded && champions.length > _championPreview)
            PlayerMoreButton(
              label: l.playerSeeAllCount(champions.length),
              scale: scale,
              onTap: vm.expandChampions,
            ),
        ],
        if (rating != null) ...[
          PlayerSectionTitle(
            title: l.playerFanRating,
            sub: l.playerRatingSub(w!.games, formatCheerCount(rating.count)),
            scale: scale,
          ),
          _RatingCard(
            rating: rating,
            reviews: vm.allReviews ?? rating.reviews,
            onOpenReview: onOpenReview,
            scale: scale,
          ),
          if (vm.reviewsLoading)
            Padding(
              padding: EdgeInsets.only(top: 14 * scale),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.narChipActive,
                ),
              ),
            )
          else if (vm.allReviews == null
              ? rating.reviewCount > rating.reviews.length
              : vm.reviewsHasNext)
            PlayerMoreButton(
              key: reviewsAllKey,
              label: vm.allReviews == null
                  ? l.playerReviewsAll(rating.reviewCount)
                  : l.playerReviewsMore,
              scale: scale,
              onTap: vm.loadMoreReviews,
            ),
        ],
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.stats,
    required this.position,
    required this.scale,
  });

  final List<PlayerWorldsStat> stats;
  final String position;
  final double scale;

  static String label(AppLocalizations l, String key) => switch (key) {
    'KDA' => l.playerStatKda,
    'KP' => l.playerStatKp,
    'DPM' => l.playerStatDpm,
    'CSPM' => l.playerStatCspm,
    'GD15' => l.playerStatGd15,
    'VSPM' => l.playerStatVspm,
    _ => key,
  };

  static String value(String key, double v) => switch (key) {
    'KP' => '${v.round()}%',
    'DPM' => '${v.round()}',
    'GD15' => '${v >= 0 ? '+' : ''}${v.round()}',
    _ => oneDecimal(v),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // 시안대로 3열. 순서는 서버 순서 그대로.
    final rows = [
      for (var i = 0; i < stats.length; i += 3)
        stats.sublist(i, i + 3 > stats.length ? stats.length : i + 3),
    ];
    return PlayerCard(
      scale: scale,
      padding: EdgeInsets.fromLTRB(16 * scale, 14 * scale, 16 * scale, 0),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: EdgeInsets.only(bottom: 14 * scale),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: i < row.length
                          ? _cell(l, row[i])
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(AppLocalizations l, PlayerWorldsStat s) {
    final rank = s.positionRank;
    final avg = s.positionAvg;
    final sub = rank != null && position.isNotEmpty
        ? l.playerStatRank(position, rank)
        : avg != null
        ? l.playerStatAvg(_StatGrid.value(s.key, avg))
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label(l, s.key),
          style: playerText(scale, size: 11, color: AppColors.narText2),
        ),
        SizedBox(height: 3 * scale),
        Text(
          value(s.key, s.value),
          style: playerText(
            scale,
            size: 17,
            weight: FontWeight.w700,
            family: 'Open Sans',
          ),
        ),
        if (sub != null)
          Text(
            sub,
            style: playerText(
              scale,
              size: 10.5,
              // 포지션 3위 안이면 강조.
              color: rank != null && rank <= 3
                  ? AppColors.narTextRed
                  : AppColors.narDark200,
            ),
          ),
      ],
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.game,
    required this.first,
    required this.scale,
  });

  final PlayerWorldsGame game;
  final bool first;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final rating = game.rating;
    final playedAt = game.playedAt?.toLocal();
    final locale = Localizations.localeOf(context).toString();
    final hasLogo =
        game.opponentTeamCode.isNotEmpty ||
        (game.opponentTeamImageUrl?.isNotEmpty ?? false);
    return PlayerResultRow(
      win: game.win,
      divider: !first,
      scale: scale,
      child: Row(
        children: [
          ChampionIcon(
            name: game.championName,
            url: game.championImageUrl,
            size: 34,
            scale: scale,
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      game.win ? l.playerWin : l.playerLoss,
                      style: playerText(
                        scale,
                        size: 13,
                        weight: FontWeight.w700,
                        color: game.win
                            ? AppColors.scoreWin
                            : AppColors.narText2,
                      ),
                    ),
                    Text(
                      ' · vs ',
                      style: playerText(
                        scale,
                        size: 12,
                        color: AppColors.narText2,
                      ),
                    ),
                    if (hasLogo) ...[
                      TeamCodeBadge(
                        teamCode: game.opponentTeamCode,
                        size: 14 * scale,
                        imageUrl: game.opponentTeamImageUrl,
                      ),
                      SizedBox(width: 3 * scale),
                    ],
                    // 날짜도 같은 줄에 두되, 좁으면 함께 말줄임된다.
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          text: [
                            game.opponentLabel,
                            game.stage,
                          ].where((t) => t.isNotEmpty).join('  '),
                          children: [
                            if (playedAt != null)
                              TextSpan(
                                text:
                                    '  ${DateFormat.MMMd(locale).format(playedAt)}',
                                style: playerText(
                                  scale,
                                  size: 11,
                                  color: AppColors.narText2,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: playerText(
                          scale,
                          size: 12,
                          weight: FontWeight.w600,
                          color: AppColors.narGray400,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3 * scale),
                Text.rich(
                  TextSpan(
                    children: [
                      kdaSpan(game.kills, game.deaths, game.assists),
                      TextSpan(
                        text:
                            '  ${l.playerGameCsDamage(game.cs, compactNumber(context, game.damage))}',
                        style: const TextStyle(color: AppColors.narText2),
                      ),
                    ],
                  ),
                  style: playerText(scale, size: 12),
                ),
              ],
            ),
          ),
          if (rating != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: oneDecimal(rating.average)),
                      TextSpan(
                        text: '/5',
                        style: playerText(
                          scale,
                          size: 10,
                          color: AppColors.narText2,
                        ),
                      ),
                    ],
                  ),
                  style: playerText(
                    scale,
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.narGuideAccent,
                    family: 'Open Sans',
                  ),
                ),
                Text(
                  l.playerFanRating,
                  style: playerText(
                    scale,
                    size: 10,
                    color: AppColors.narDark200,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scale,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 30 * scale,
        padding: EdgeInsets.symmetric(horizontal: 12 * scale),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.narChipSelectedBg
              : AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(15 * scale),
          border: Border.all(
            color: selected ? AppColors.narChipActive : AppColors.narLine,
          ),
        ),
        child: Text(
          label,
          style: playerText(
            scale,
            size: 12,
            weight: FontWeight.w600,
            color: selected ? AppColors.narText : AppColors.narText2,
          ),
        ),
      ),
    );
  }
}

class _ChampionRow extends StatelessWidget {
  const _ChampionRow({required this.champion, required this.scale})
    : _header = null;

  const _ChampionRow.header(AppLocalizations l, this.scale)
    : champion = null,
      _header = l;

  final PlayerChampionRecord? champion;
  final AppLocalizations? _header;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final h = _header;
    final c = champion;
    final small = playerText(scale, size: 11, color: AppColors.narDark200);

    return Container(
      decoration: BoxDecoration(
        border: h != null
            ? null
            : const Border(top: BorderSide(color: AppColors.narLine)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: (h != null ? 9 : 8) * scale,
      ),
      child: Row(
        children: [
          Expanded(
            child: h != null
                ? Text(h.playerChampionHeader, style: small)
                : Row(
                    children: [
                      ChampionIcon(
                        name: c!.championName,
                        url: c.championImageUrl,
                        size: 28,
                        scale: scale,
                      ),
                      SizedBox(width: 10 * scale),
                      Flexible(
                        child: Text(
                          c.championName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: playerText(
                            scale,
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(
            width: 72 * scale,
            child: Align(
              alignment: Alignment.centerRight,
              child: h != null
                  ? Text(h.playerTabSolo, style: small)
                  : _WinLoss(
                      wins: c!.soloWins,
                      losses: c.soloLosses,
                      scale: scale,
                    ),
            ),
          ),
          SizedBox(
            width: 72 * scale,
            child: Align(
              alignment: Alignment.centerRight,
              child: h != null
                  ? Text(h.playerTabWorlds, style: small)
                  : _WinLoss(
                      wins: c!.worldsWins,
                      losses: c.worldsLosses,
                      scale: scale,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "5승 2패" — 승 빨강, 패 회색. 0판이면 "—".
class _WinLoss extends StatelessWidget {
  const _WinLoss({
    required this.wins,
    required this.losses,
    required this.scale,
  });

  final int wins;
  final int losses;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (wins + losses == 0) {
      return Text(
        '—',
        style: playerText(scale, size: 12, color: AppColors.narDark300),
      );
    }
    final text = l.playerWinLoss(wins, losses);
    final split = text.indexOf(' ');
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: split < 0 ? text : text.substring(0, split),
            style: const TextStyle(color: AppColors.scoreWin),
          ),
          if (split >= 0) TextSpan(text: text.substring(split)),
        ],
      ),
      style: playerText(
        scale,
        size: 12,
        weight: FontWeight.w600,
        color: AppColors.narText2,
      ),
    );
  }
}

/// 팬 평점 카드(시안 ⑧ 하단) — 왼쪽 큰 평균, 오른쪽 5점·4점·3점 이하 막대,
/// 그 아래 한줄평 목록(점수 배지 · 본문 · "vs IG · 스위스 3라운드").
class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.rating,
    required this.reviews,
    required this.scale,
    this.onOpenReview,
  });

  final PlayerWorldsRating rating;
  final List<PlayerReview> reviews;
  final double scale;
  final ValueChanged<PlayerReview>? onOpenReview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final d = rating.distribution;
    final bars = [
      (l.playerRatingScore(5), d[5] ?? 0),
      (l.playerRatingScore(4), d[4] ?? 0),
      (l.playerRatingThreeOrLess, (d[3] ?? 0) + (d[2] ?? 0) + (d[1] ?? 0)),
    ];
    final divider = Container(height: 1, color: AppColors.narLine);
    return PlayerCard(
      scale: scale,
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        14 * scale,
        16 * scale,
        4 * scale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64 * scale,
                child: Column(
                  children: [
                    Text(
                      oneDecimal(rating.average),
                      style: playerText(
                        scale,
                        size: 34,
                        weight: FontWeight.w800,
                        color: AppColors.narGuideAccent,
                        family: 'Open Sans',
                      ).copyWith(height: 1.05),
                    ),
                    Text(
                      '/ 5',
                      style: playerText(
                        scale,
                        size: 11,
                        color: AppColors.narText2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14 * scale),
              Expanded(
                child: Column(
                  children: [
                    for (final (label, pct) in bars)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4 * scale),
                        child: Row(
                          children: [
                            // "3점 이하" 도 한 줄로 둔다. 영어 등 긴 라벨은 줄여서 맞춘다.
                            SizedBox(
                              width: 44 * scale,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  style: playerText(
                                    scale,
                                    size: 10.5,
                                    color: AppColors.narText2,
                                  ).copyWith(height: 1.3),
                                ),
                              ),
                            ),
                            SizedBox(width: 6 * scale),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2 * scale),
                                child: LinearProgressIndicator(
                                  value: (pct / 100).clamp(0, 1).toDouble(),
                                  minHeight: 4 * scale,
                                  backgroundColor: AppColors.narDark500,
                                  color: AppColors.narViolet3,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 38 * scale,
                              child: Text(
                                '${pct.round()}%',
                                textAlign: TextAlign.right,
                                style: playerText(
                                  scale,
                                  size: 10.5,
                                  color: AppColors.narText2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          for (var i = 0; i < reviews.length; i++) ...[
            divider,
            _ReviewRow(
              key: PlayerWorldsTab.reviewKey(i),
              review: reviews[i],
              scale: scale,
              onTap: onOpenReview == null || !reviews[i].canOpen
                  ? null
                  : () => onOpenReview!(reviews[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    super.key,
    required this.review,
    required this.scale,
    this.onTap,
  });

  final PlayerReview review;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = review;
    final meta = [
      if (r.opponentTeamCode.isNotEmpty) 'vs ${r.opponentTeamCode}',
      if (r.stage.isNotEmpty) r.stage,
    ].join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 13 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 33 * scale,
              height: 21 * scale,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.narChipBadgeBg,
                borderRadius: BorderRadius.circular(4 * scale),
              ),
              child: Text(
                '${r.rating}',
                style: playerText(
                  scale,
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.narViolet3,
                  family: 'Open Sans',
                ),
              ),
            ),
            SizedBox(width: 11 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.comment,
                    style: playerText(
                      scale,
                      size: 14,
                      weight: FontWeight.w600,
                    ).copyWith(height: 1.45),
                  ),
                  if (meta.isNotEmpty) ...[
                    SizedBox(height: 4 * scale),
                    Text(
                      meta,
                      style: playerText(
                        scale,
                        size: 11,
                        color: AppColors.narDark200,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
