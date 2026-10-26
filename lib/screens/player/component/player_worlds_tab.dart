import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/nar_card.dart';
import '../../../components/nar_chip_multi_select.dart';
import '../../../components/nar_more_button.dart';
import '../../../components/nar_star_rating.dart';
import '../../../components/team_code_badge.dart';
import '../../../components/win_loss_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/player_detail.dart';
import '../../../styles/app_colors.dart';
import '../../../util/rating_mapping.dart';
import '../../../viewmodel/player/player_viewmodel.dart';
import '../../home/component/home_solo_cheer.dart' show formatCheerCount;
import '../../player_rating/component/rating_distribution_section.dart';
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

  /// 경기별 기록 "N판 더 보기" 버튼의 키.
  static const Key gamesMoreKey = ValueKey('playerWorldsGamesMore');

  static const int _championPreview = 5;
  static const int _gamesPreview = 5;

  /// 한줄평 처음 보이는 개수. 그 뒤로는 바닥에 닿을 때마다 서버에서 이어 받는다.
  static const int reviewsPreview = 6;

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
    final games = w?.matches ?? const <PlayerWorldsGame>[];
    final shownGames = vm.worldsGamesExpanded
        ? games
        : games.take(_gamesPreview).toList();
    // 한줄평은 처음 6개만 보이고, 바닥에 닿으면 서버에서 20개씩 이어 받는다.
    final shownReviews =
        vm.allReviews ??
        (rating?.reviews ?? const <PlayerReview>[])
            .take(reviewsPreview)
            .toList();

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
          NarCard(
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
          NarCard(
            scale: scale,
            child: Column(
              children: [
                for (var i = 0; i < shownGames.length; i++)
                  _GameRow(game: shownGames[i], first: i == 0, scale: scale),
              ],
            ),
          ),
          if (!vm.worldsGamesExpanded && w.matches.length > _gamesPreview)
            NarMoreButton(
              key: gamesMoreKey,
              label: l.playerSoloMore(w.matches.length - _gamesPreview),
              scale: scale,
              onTap: vm.expandWorldsGames,
            ),
        ],
        if (champions.isNotEmpty) ...[
          PlayerSectionTitle(title: l.playerChampions, scale: scale),
          // 정렬 기준은 홈 리그 칩·내 선수 팀 칩과 같은 공용 칩 줄이다.
          // 카드와 좌우를 맞추려고 가로 패딩 0, 위아래는 섹션 제목이 이미
          // 띄워 둬서 아래쪽만 10 준다.
          NarChipMultiSelect.single(
            options: [for (final s in PlayerChampionSort.values) s.name],
            selected: vm.championSort.name,
            onSelected: (v) => vm.setChampionSort(
              PlayerChampionSort.values.firstWhere((s) => s.name == v),
            ),
            labelBuilder: (v) => v == PlayerChampionSort.solo.name
                ? l.playerSortSolo
                : l.playerSortWorlds,
            horizontalPadding: 0,
            verticalPadding: 0,
            scale: scale,
          ),
          SizedBox(height: 10 * scale),
          NarCard(
            scale: scale,
            child: Column(
              children: [
                _ChampionRow.header(l, scale),
                for (final c in shownChampions)
                  _ChampionRow(
                    champion: c,
                    soloLastPlayed: vm.championLastPlayed(
                      c.championName,
                      PlayerChampionSort.solo,
                    ),
                    worldsLastPlayed: vm.championLastPlayed(
                      c.championName,
                      PlayerChampionSort.worlds,
                    ),
                    scale: scale,
                  ),
              ],
            ),
          ),
          if (!vm.championsExpanded && champions.length > _championPreview)
            NarMoreButton(
              label: l.playerSeeAllCount(champions.length),
              scale: scale,
              onTap: vm.expandChampions,
            ),
        ],
        if (rating != null) ...[
          PlayerSectionTitle(
            title: l.playerWorldsRating,
            sub: l.playerRatingSub(w!.games, formatCheerCount(rating.count)),
            scale: scale,
          ),
          _RatingCard(
            rating: rating,
            reviews: shownReviews,
            onOpenReview: onOpenReview,
            scale: scale,
          ),
          // 한줄평은 버튼 없이 바닥까지 내리면 이어 받는다(화면이 스크롤을
          // 감시한다). 여기서는 더 받을 게 남았다는 표시만 둔다 — 자리를 비워
          // 두면 리스트가 바닥에 딱 맞아 더 내릴 수 없어 다음 장을 못 받는다.
          if (vm.reviewsLoading ||
              (vm.allReviews == null
                  ? rating.reviewCount > shownReviews.length
                  : vm.reviewsHasNext))
            Padding(
              key: reviewsAllKey,
              padding: EdgeInsets.only(top: 16 * scale, bottom: 8 * scale),
              child: Center(
                child: SizedBox(
                  width: 20 * scale,
                  height: 20 * scale,
                  child: CircularProgressIndicator(
                    strokeWidth: 2 * scale,
                    color: AppColors.narChipActive,
                  ),
                ),
              ),
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
    return NarCard(
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

class _ChampionRow extends StatelessWidget {
  const _ChampionRow({
    required this.champion,
    required this.soloLastPlayed,
    required this.worldsLastPlayed,
    required this.scale,
  }) : _header = null;

  const _ChampionRow.header(AppLocalizations l, this.scale)
    : champion = null,
      soloLastPlayed = null,
      worldsLastPlayed = null,
      _header = l;

  final PlayerChampionRecord? champion;

  /// 솔랭·월즈 각각 마지막으로 한 시각 — 그 열의 승패 아래 "2시간 전" 으로
  /// 보여 어느 쪽 기록인지 헷갈리지 않는다. 없으면 생략.
  final DateTime? soloLastPlayed;
  final DateTime? worldsLastPlayed;
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
                  : _WinLossWithDate(
                      wins: c!.soloWins,
                      losses: c.soloLosses,
                      lastPlayed: soloLastPlayed,
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
                  : _WinLossWithDate(
                      wins: c!.worldsWins,
                      losses: c.worldsLosses,
                      lastPlayed: worldsLastPlayed,
                      scale: scale,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 승패 아래 그 열의 마지막 플레이 시각. 시각이 없으면 승패만.
class _WinLossWithDate extends StatelessWidget {
  const _WinLossWithDate({
    required this.wins,
    required this.losses,
    required this.lastPlayed,
    required this.scale,
  });

  final int wins;
  final int losses;
  final DateTime? lastPlayed;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final at = lastPlayed;
    final winLoss = WinLossText(
      wins: wins,
      losses: losses,
      style: playerText(
        scale,
        size: 12,
        weight: FontWeight.w600,
        color: AppColors.narText2,
      ),
      emptyStyle: playerText(scale, size: 12, color: AppColors.narDark300),
    );
    if (at == null) return winLoss;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        winLoss,
        Text(
          ratingTimeAgo(at.toLocal()),
          maxLines: 1,
          style: playerText(scale, size: 10.5, color: AppColors.narText2),
        ),
      ],
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
    final d = rating.distribution;
    return NarCard(
      scale: scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 평균·별점·점수별 분포는 선수 평점 상세와 같은 공용 섹션을 쓴다.
          RatingDistributionSection(
            rating: rating.average,
            raterCount: rating.count,
            distribution: [
              for (var score = 5; score >= 1; score--) (d[score] ?? 0).round(),
            ],
            // 카드 안이라 시안(패딩 20)보다 좁게. 바는 남는 폭을 전부 쓴다.
            padding: EdgeInsets.all(16 * scale),
            // 별점과 분포가 붙어 보여 시안(14)보다 2 넓혔다.
            gap: 16,
            scale: scale,
          ),
          for (var i = 0; i < reviews.length; i++) ...[
            Container(height: 1, color: AppColors.narLine),
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
    // 선수 평점 상세의 코멘트 카드와 같은 구성(별점 → 본문)이다. 그 화면은
    // 작성자·시간을 머리에 두는데, 이 API 는 작성자를 안 내려주고 대신 어느
    // 경기인지(vs IG · 스위스 3라운드)를 주므로 그 자리에 경기 정보를 둔다.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 16 * scale,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NarStarRating(rating: r.rating.toDouble(), scale: scale),
                const Spacer(),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: playerText(
                      scale,
                      size: 11,
                      color: AppColors.narText2,
                    ),
                  ),
              ],
            ),
            if (r.comment.isNotEmpty) ...[
              SizedBox(height: 8 * scale),
              Text(
                r.comment,
                style: playerText(scale, size: 14).copyWith(height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
