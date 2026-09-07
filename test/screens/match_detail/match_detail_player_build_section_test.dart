import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/match_champion_pick.dart';
import 'package:warding/screens/match_detail/component/match_detail_player_build_section.dart';

/// "Player Builds" 섹션 — 선택된 선수 정보가 보이고, 반대팀 포지션 아이콘을
/// 탭하면 [onSelect] 로 그 선수가 통지된다(스크롤·상태는 호출부 책임).
void main() {
  List<ChampionPick> picksFor(String teamPrefix) => List.generate(
    5,
    (i) => ChampionPick(
      position: const ['top', 'jungle', 'mid', 'adc', 'support'][i],
      championName: 'Champ$teamPrefix$i',
      playerName: '$teamPrefix$i',
      level: 10 + i,
      kills: i,
      deaths: i,
      assists: i,
      creepScore: 100 + i,
      totalGoldEarned: 10000 + i,
      killParticipation: 0.5,
      championDamageShare: 0.2,
      coreItemImageUrls: const ['a', 'b'],
      runes: const PlayerRunes(
        primary: RuneStyle(
          styleName: '결의',
          runes: [RuneEntry(name: '착취의 손아귀'), RuneEntry(name: '보호막 강타')],
        ),
        sub: RuneStyle(styleName: '영감', runes: [RuneEntry(name: '비스킷 배달')]),
        shards: [RuneShard(name: '적응형 능력치', label: '+9')],
      ),
    ),
  );

  testWidgets('선택된 선수 정보가 보이고, 반대팀 아이콘을 탭하면 onSelect 가 호출된다', (
    tester,
  ) async {
    final bluePicks = picksFor('Blue');
    final redPicks = picksFor('Red');
    (bool, int)? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MatchDetailPlayerBuildSection(
              bluePicks: bluePicks,
              redPicks: redPicks,
              blueTeamCode: 'GEN',
              redTeamCode: 'T1',
              selectedBlueSide: true,
              selectedIndex: 0,
              onSelect: (blue, i) => selected = (blue, i),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GEN'), findsOneWidget);
    expect(find.text('Blue0'), findsOneWidget);
    expect(find.text('적응형 능력치 +9'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player_build_lane_red_0')));
    await tester.pumpAndSettle();

    expect(selected, (false, 0));
    expect(tester.takeException(), isNull);
  });
}
