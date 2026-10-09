import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/home_models.dart';
import 'package:warding/repository/home/home_api_sources.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/home/component/home_solo_cheer.dart';
import 'package:warding/screens/home/component/home_solo_rank_section.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/viewmodel/home/home_viewmodel.dart';

import 'home_test_harness.dart';

class _FakeCheer implements CheerSource {
  final List<(int, int)> calls = [];
  int total = 1284;

  @override
  Future<CheerResult> send(int playerId, int count) async {
    calls.add((playerId, count));
    total += count;
    return CheerResult(total: total, mine: count);
  }
}

/// 솔랭 카드 응원 영역 — 탭 낙관적 증가, 묶음 전송, 끝난 경기 칩 합계.
void main() {
  Widget section(HomeViewModel vm) =>
      HomeSoloRankSection(viewModel: vm, scale: 1);

  testWidgets('응원하기를 누르면 숫자·+N 이 바로 오르고, 전송은 1초 뒤 한 번에 묶는다', (tester) async {
    final server = setUpHomeApi(loggedIn: true);
    server.subscriptions = [subscriptionJson('Faker', 'T1')];
    final cheer = _FakeCheer();
    await pumpHomeSection(
      tester,
      solo: const SoloRankSnapshot(
        live: [
          HomeLiveSoloPlayer(
            name: 'Faker',
            teamCode: 'T1',
            champion: '',
            elapsedSeconds: 600,
            cheerTotal: 1284,
            cheerMine: 2,
          ),
        ],
        finished: [],
      ),
      cheer: cheer,
      section: section,
    );

    final total = find.byKey(SoloCheerCard.totalKey('Faker'));
    final mine = find.byKey(SoloCheerCard.mineKey('Faker'));
    expect(tester.widget<Text>(total).data, '1,284');
    expect(tester.widget<Text>(mine).data, '+2');
    expect(find.text('이 판 응원'), findsOneWidget);

    final button = find.byKey(SoloCheerCard.buttonKey('Faker'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.widget<Text>(total).data, '1,287');
    expect(tester.widget<Text>(mine).data, '+5');
    expect(find.text('+1'), findsWidgets); // 떠오르는 효과
    expect(cheer.calls, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    expect(cheer.calls, [("Faker".hashCode, 3)]);

    // 효과·식는 타이머가 끝나게 둔다.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('모션 줄이기 설정이면 +1·불꽃 효과를 그리지 않는다', (tester) async {
    final server = setUpHomeApi(loggedIn: true);
    server.subscriptions = [subscriptionJson('Faker', 'T1')];
    await pumpHomeSection(
      tester,
      solo: SoloRankSnapshot(live: [livePlayer('Faker', 60)], finished: []),
      cheer: _FakeCheer(),
      section: (vm) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: section(vm),
      ),
    );

    await tester.tap(find.byKey(SoloCheerCard.buttonKey('Faker')));
    await tester.pump(const Duration(milliseconds: 100));
    // '+1' 은 내가 보탠 수(+N) 하나뿐이다 — 떠오르는 효과는 없다.
    expect(find.text('+1'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(SoloCheerCard.mineKey('Faker'))).data,
      '+1',
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('끝난 경기 칩에는 불꽃 + 응원 합계만 붙고, 0 이면 안 붙는다', (tester) async {
    final server = setUpHomeApi(loggedIn: true);
    server.subscriptions = [
      subscriptionJson('Oner', 'T1'),
      subscriptionJson('Ruler', 'HLE'),
    ];
    await pumpHomeSection(
      tester,
      solo: SoloRankSnapshot(
        live: const [],
        finished: [
          const HomeFinishedSoloPlayer(
            name: 'Oner',
            teamCode: 'T1',
            won: true,
            minutesAgo: 12,
            cheerTotal: 1871,
          ),
          finishedPlayer('Ruler', 40),
        ],
      ),
      section: section,
    );

    expect(
      tester
          .widget<Text>(
            find.byKey(HomeSoloRankSection.finishedCheerKey('Oner')),
          )
          .data,
      '1,871',
    );
    expect(
      find.byKey(HomeSoloRankSection.finishedCheerKey('Ruler')),
      findsNothing,
    );
  });

  test('솔랭 응답의 cheerTotal·cheerMine 을 파싱하고, 없으면 0 이다', () async {
    final server = setUpHomeApi(loggedIn: true);
    api.setApiClientForTesting(
      MockClient((req) async {
        return http.Response(
          jsonEncode({
            'live': [
              {
                'playerName': 'Faker',
                'teamCode': 'T1',
                'cheerTotal': 12,
                'cheerMine': 3,
              },
              {'playerName': 'Chovy', 'teamCode': 'GEN'},
            ],
            'finished': [
              {
                'playerName': 'Oner',
                'teamCode': 'T1',
                'win': true,
                'cheerTotal': 40,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    expect(server, isNotNull);
    final snap = await ApiSoloRankSource().fetch();
    expect(snap.live[0].cheerTotal, 12);
    expect(snap.live[0].cheerMine, 3);
    expect(snap.live[1].cheerTotal, 0);
    expect(snap.live[1].cheerMine, 0);
    expect(snap.finished.single.cheerTotal, 40);
  });
}
