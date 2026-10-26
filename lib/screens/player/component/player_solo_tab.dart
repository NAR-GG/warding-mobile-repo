import 'package:flutter/material.dart';

import '../../../components/nar_card.dart';
import '../../../components/nar_live_dot.dart';
import '../../../components/nar_more_button.dart';
import '../../../components/nar_progress_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/player_detail.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../util/rating_mapping.dart' show ratingTimeAgo;
import '../../../viewmodel/player/player_viewmodel.dart';
import '../../home/component/home_solo_cheer.dart' show formatCheerCount;
import '../../home/component/home_solo_rank_section.dart' show HomeSoloFace;
import '../../my_players/component/my_player_tile.dart' show RegionChip;
import 'player_parts.dart';

/// 솔랭 탭 — 계정 칩·최근 20판 요약·모스트 챔피언·솔랭에서 만난 선수·최근 솔랭.
///
/// "솔랭에서 만난 선수" 는 비어 있으면(옛 서버 포함) 섹션째 숨긴다.
class PlayerSoloTab extends StatelessWidget {
  const PlayerSoloTab({
    super.key,
    required this.viewModel,
    required this.scale,
    this.onOpenPlayer,
  });

  final PlayerViewModel viewModel;
  final double scale;

  /// 만난 선수 카드 — 그 선수의 선수 페이지로.
  final void Function(int playerId)? onOpenPlayer;

  static Key metKey(int playerId) => ValueKey('playerMet-$playerId');

  static const Key emptyKey = ValueKey('playerSoloEmpty');

  static const Key moreKey = ValueKey('playerSoloMore');
  static const int _gamesPreview = 5;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final solo = viewModel.solo;
    final recent = solo?.recent;
    final games = solo?.games ?? const <PlayerSoloGame>[];
    final shown = viewModel.soloGamesExpanded
        ? games
        : games.take(_gamesPreview).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (solo != null && solo.accounts.isNotEmpty) ...[
          SizedBox(height: 16 * scale),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final a in solo.accounts) ...[
                  _AccountChip(account: a, scale: scale),
                  SizedBox(width: 8 * scale),
                ],
              ],
            ),
          ),
        ],
        if (recent == null || recent.games == 0)
          Padding(
            key: emptyKey,
            padding: EdgeInsets.symmetric(vertical: 48 * scale),
            child: Center(
              child: Text(
                l.playerSoloEmpty,
                style: playerText(scale, size: 13, color: AppColors.narText2),
              ),
            ),
          )
        else ...[
          PlayerSectionTitle(
            title: l.playerSoloRecent(recent.games),
            sub: l.playerSoloRecent7d,
            scale: scale,
          ),
          _RecentCard(recent: recent, scale: scale),
          if (solo!.champions.isNotEmpty) ...[
            PlayerSectionTitle(
              title: l.playerSoloMost,
              sub: l.playerSoloRecent(recent.games),
              scale: scale,
            ),
            NarCard(
              scale: scale,
              child: Column(
                children: [
                  for (var i = 0; i < solo.champions.length; i++)
                    _MostRow(
                      champion: solo.champions[i],
                      first: i == 0,
                      scale: scale,
                    ),
                ],
              ),
            ),
          ],
          if (solo.metPlayers.isNotEmpty) ...[
            PlayerSectionTitle(
              title: l.playerMetTitle,
              sub: l.playerSoloRecent7d,
              scale: scale,
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              // 카드 높이를 가장 긴 카드에 맞춘다(같은 편·상대 줄 유무로 달라진다).
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final m in solo.metPlayers) ...[
                      _MetCard(
                        key: metKey(m.playerId),
                        met: m,
                        nextOpponent:
                            m.teamCode != null &&
                            m.teamCode ==
                                viewModel.detail?.nextMatch?.opponent.teamCode,
                        onTap: onOpenPlayer == null
                            ? null
                            : () => onOpenPlayer!(m.playerId),
                        scale: scale,
                      ),
                      SizedBox(width: 8 * scale),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (games.isNotEmpty) ...[
            PlayerSectionTitle(title: l.playerSoloGamesTitle, scale: scale),
            NarCard(
              scale: scale,
              child: Column(
                children: [
                  for (var i = 0; i < shown.length; i++)
                    _SoloGameRow(game: shown[i], first: i == 0, scale: scale),
                ],
              ),
            ),
            if (!viewModel.soloGamesExpanded && games.length > _gamesPreview)
              NarMoreButton(
                key: moreKey,
                label: l.playerSoloMore(games.length - _gamesPreview),
                scale: scale,
                onTap: viewModel.expandSoloGames,
              ),
          ],
        ],
      ],
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.account, required this.scale});

  final PlayerSoloAccount account;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final tier = account.tier;
    final crest = account.tierCrest;
    final tierStyle = playerText(
      scale,
      size: 12,
      weight: FontWeight.w700,
      color: AppColors.narGuideAccent,
    );
    return Container(
      height: 30 * scale,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Row(
        children: [
          if (account.live) ...[
            NarLiveDot(scale: scale, size: 6, color: AppColors.narSoloDot),
            SizedBox(width: 5 * scale),
          ],
          // 지역 칩은 홈 월즈 솔랭·내 선수와 같은 공용 칩을 쓴다.
          RegionChip(region: account.region, scale: scale),
          SizedBox(width: 6 * scale),
          Text(
            account.riotId,
            style: playerText(scale, size: 12, color: AppColors.narGray400),
          ),
          // 티어는 크롤링 값이라 없을 수 있다 — 없으면 생략.
          if (tier != null && tier.isNotEmpty) ...[
            SizedBox(width: 6 * scale),
            if (crest != null) ...[
              // 티어 엠블럼은 앱에 넣은 디자인 에셋이다(칩 높이 30 안에 18).
              // 엠블럼 위쪽에 투명 여백이 있어 가운데 정렬하면 글자보다 떠 보인다
              // — 2px 내려 옆 티어 글자와 눈높이를 맞춘다.
              Padding(
                padding: EdgeInsets.only(top: 2 * scale),
                child: Image.asset(
                  rankedCrestAsset(crest.$1),
                  width: 18 * scale,
                  height: 18 * scale,
                  fit: BoxFit.contain,
                  // 약어가 같이 붙어 있어 이미지가 없어도 티어는 읽힌다.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              SizedBox(width: 3 * scale),
              Text(crest.$2, style: tierStyle),
            ] else
              Text(tier, style: tierStyle),
          ],
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.recent, required this.scale});

  final PlayerSoloRecent recent;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final label = playerText(scale, size: 11, color: AppColors.narText2);
    final big = playerText(
      scale,
      size: 18,
      weight: FontWeight.w700,
      family: 'Open Sans',
    );
    final sub = playerText(scale, size: 11, color: AppColors.narText2);
    final winRate = recent.games == 0
        ? 0
        : (recent.wins * 100 / recent.games).round();

    Widget col(String title, Widget value, Widget foot) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: label),
          SizedBox(height: 4 * scale),
          value,
          SizedBox(height: 2 * scale),
          foot,
        ],
      ),
    );

    return NarCard(
      scale: scale,
      padding: EdgeInsets.all(16 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              col(
                l.playerSoloRecord,
                Text(l.playerWinLoss(recent.wins, recent.losses), style: big),
                Text(
                  l.playerSoloWinRate(winRate),
                  style: sub.copyWith(color: AppColors.scoreWin),
                ),
              ),
              col(
                l.playerSoloAvgKda,
                Text(oneDecimal(recent.kda), style: big),
                Text(
                  '${oneDecimal(recent.avgKills)} / ${oneDecimal(recent.avgDeaths)} / ${oneDecimal(recent.avgAssists)}',
                  style: sub,
                ),
              ),
              col(
                l.playerSoloPerDay,
                Text(
                  l.playerSoloGames(oneDecimal(recent.gamesPerDay)),
                  style: big,
                ),
                Text(
                  l.playerSoloAvgDuration(recent.avgDurationSeconds ~/ 60),
                  style: sub,
                ),
              ),
            ],
          ),
          if (recent.results.isNotEmpty) ...[
            SizedBox(height: 14 * scale),
            SizedBox(
              height: 26 * scale,
              // 승은 가득(26), 패는 절반(13)으로 낮춰 아래에 붙인다 — 색만으로
              // 구분하던 것보다 연승·연패 흐름이 한눈에 읽힌다.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < recent.results.length; i++) ...[
                    if (i > 0) SizedBox(width: 3 * scale),
                    Expanded(
                      child: Container(
                        height: (recent.results[i] ? 26 : 13) * scale,
                        decoration: BoxDecoration(
                          color: recent.results[i]
                              ? AppColors.scoreWin
                              : AppColors.narDark400,
                          borderRadius: BorderRadius.circular(2 * scale),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 6 * scale),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.playerSoloOldest(recent.results.length),
                  style: playerText(
                    scale,
                    size: 10,
                    color: AppColors.narDark300,
                  ),
                ),
                Text(
                  l.playerSoloLatest,
                  style: playerText(
                    scale,
                    size: 10,
                    color: AppColors.narDark300,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MostRow extends StatelessWidget {
  const _MostRow({
    required this.champion,
    required this.first,
    required this.scale,
  });

  final PlayerSoloChampion champion;
  final bool first;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = champion;
    final rate = c.games == 0 ? 0.0 : c.wins / c.games;
    return Container(
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(top: BorderSide(color: AppColors.narLine)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 10 * scale,
      ),
      child: Row(
        children: [
          ChampionIcon(
            name: c.championName,
            url: c.championImageUrl,
            size: 34,
            scale: scale,
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: c.championName),
                      TextSpan(
                        text: ' ${l.playerSoloGames('${c.games}')}',
                        style: playerText(
                          scale,
                          size: 11,
                          color: AppColors.narText2,
                        ),
                      ),
                    ],
                  ),
                  style: playerText(scale, size: 14, weight: FontWeight.w600),
                ),
                SizedBox(height: 6 * scale),
                NarProgressBar(
                  value: rate,
                  color: rate > 0.5 ? AppColors.scoreWin : AppColors.narDark200,
                  scale: scale,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 70 * scale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(rate * 100).round()}%',
                  style: playerText(
                    scale,
                    size: 14,
                    weight: FontWeight.w700,
                    color: rate > 0.5 ? AppColors.scoreWin : AppColors.narText2,
                    family: 'Open Sans',
                  ),
                ),
                Text(
                  'KDA ${oneDecimal(c.kda)}',
                  style: playerText(scale, size: 11, color: AppColors.narText2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoloGameRow extends StatelessWidget {
  const _SoloGameRow({
    required this.game,
    required this.first,
    required this.scale,
  });

  final PlayerSoloGame game;
  final bool first;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final g = game;
    return PlayerResultRow(
      win: g.win,
      divider: !first,
      scale: scale,
      child: Row(
        children: [
          ChampionIcon(
            name: g.championName,
            url: g.championImageUrl,
            size: 34,
            scale: scale,
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: g.win ? l.playerWin : l.playerLoss,
                        style: TextStyle(
                          color: g.win
                              ? AppColors.scoreWin
                              : AppColors.narText2,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' · ${g.championName} · ${l.homeSoloDuration(g.durationSeconds ~/ 60)}',
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: playerText(scale, size: 13, weight: FontWeight.w600),
                ),
                SizedBox(height: 3 * scale),
                Text.rich(
                  TextSpan(
                    children: [
                      kdaSpan(g.kills, g.deaths, g.assists),
                      TextSpan(
                        text:
                            '  KDA ${oneDecimal(gameKda(g.kills, g.deaths, g.assists))}',
                        style: const TextStyle(color: AppColors.narText2),
                      ),
                    ],
                  ),
                  style: playerText(scale, size: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ratingTimeAgo(g.endedAt),
                style: playerText(scale, size: 11, color: AppColors.narText2),
              ),
              if (g.cheerTotal > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 12 * scale,
                      color: AppColors.narGuideAccent,
                    ),
                    SizedBox(width: 2 * scale),
                    Text(
                      formatCheerCount(g.cheerTotal),
                      style: playerText(
                        scale,
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppColors.narGuideAccent,
                        family: 'Open Sans',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 솔랭에서 만난 선수 카드(⑧-1) — 이름·팀(+다음 상대), 같은 편·상대 전적, 마지막으로 만난 때.
class _MetCard extends StatelessWidget {
  const _MetCard({
    super.key,
    required this.met,
    required this.nextOpponent,
    required this.scale,
    this.onTap,
  });

  final PlayerMet met;
  final bool nextOpponent;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final m = met;
    final sub = playerText(scale, size: 11, color: AppColors.narText2);
    const win = TextStyle(
      color: AppColors.scoreWin,
      fontWeight: FontWeight.w600,
    );

    // "상대 3판 · 1승 2패" — 시안처럼 0패는 생략한다.
    Widget record(String label, int games, int wins, int losses) => Padding(
      padding: EdgeInsets.only(top: 3 * scale),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label  ${l.playerSoloGames('$games')} · '),
            TextSpan(text: l.playerWins(wins), style: win),
            if (losses > 0) TextSpan(text: ' ${l.playerLosses(losses)}'),
          ],
        ),
        style: sub,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 158 * scale,
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HomeSoloFace(
                  name: m.playerName,
                  url: resolveImageUrl(m.playerImageUrl),
                  size: 34 * scale,
                  scale: scale,
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.playerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: playerText(
                          scale,
                          size: 14,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          if (m.teamCode != null)
                            Flexible(
                              child: Text(
                                m.teamCode!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: sub,
                              ),
                            ),
                          if (nextOpponent) ...[
                            SizedBox(width: 4 * scale),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.narRedOpacity25,
                                borderRadius: BorderRadius.circular(3 * scale),
                              ),
                              child: Text(
                                l.playerMetNextOpponent,
                                style: playerText(
                                  scale,
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: AppColors.narTextRed,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * scale),
            if (m.sameTeamGames > 0)
              record(
                l.playerMetSameTeam,
                m.sameTeamGames,
                m.sameTeamWins,
                m.sameTeamGames - m.sameTeamWins,
              ),
            if (m.opponentGames > 0)
              record(
                l.playerMetOpponent,
                m.opponentGames,
                m.opponentWins,
                m.opponentLosses,
              ),
            if (m.lastMetAt != null)
              Padding(
                padding: EdgeInsets.only(top: 6 * scale),
                child: Text(
                  l.playerMetLast(ratingTimeAgo(m.lastMetAt)),
                  style: playerText(
                    scale,
                    size: 10.5,
                    color: AppColors.narDark200,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
