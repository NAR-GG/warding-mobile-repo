import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/dashed_border.dart';
import 'package:warding/components/nar_chip.dart';
import 'package:warding/components/team_code_badge.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/home/component/home_standings_section.dart';
import 'package:warding/styles/app_colors.dart';
import 'package:warding/viewmodel/home/home_viewmodel.dart';

import 'home_test_harness.dart';

/// 순위표 — 데이터 없는 리그(LPL·LEC·LCS)와 월즈(출시 보류 — 스위스 전적·
/// 토너먼트 대진 카드는 구현돼 있지만 칩은 비활성)는 점선 칩이고 누를 수
/// 없다. 1위 순위 숫자만 메인 보라색으로 강조한다(2026-09-29 결정 — 팀
/// 이름 줄 등 나머지는 다른 행과 동일). 로딩·에러는 그리지 않는다.
void main() {
  // 리그 칩 — 라벨 텍스트를 품은 NarChip.
  Finder chip(String code) =>
      find.ancestor(of: find.text(code), matching: find.byType(NarChip));

  testWidgets('LPL·LEC·LCS·월즈 칩은 점선이고 눌러도 리그가 바뀌지 않는다', (tester) async {
    final server = setUpHomeApi();
    final vm = await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    // 리그 칩 줄은 가로 스크롤이라 맨 끝 '월즈' 칩은 기본 화면 밖이다.
    final chipScroller = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    await tester.dragUntilVisible(
      chip('월즈'),
      chipScroller,
      const Offset(-50, 0),
    );

    for (final code in ['LPL', 'LEC', 'LCS', '월즈']) {
      expect(
        find.descendant(of: chip(code), matching: find.byType(DashedBorder)),
        findsOneWidget,
        reason: '$code 칩은 점선',
      );
      // 탭을 받는 위젯 자체가 없다.
      expect(
        find.descendant(of: chip(code), matching: find.byType(GestureDetector)),
        findsNothing,
        reason: '$code 칩은 누를 수 없다',
      );
      await tester.tap(chip(code), warnIfMissed: false);
      await tester.pump();
      expect(vm.selectedLeague, 'LCK');
    }
    expect(
      server
          .requestsTo('standings')
          .where((u) => u.queryParameters['league'] != 'LCK'),
      isEmpty,
    );

    // LCK 는 실선 칩.
    expect(
      find.descendant(of: chip('LCK'), matching: find.byType(DashedBorder)),
      findsNothing,
    );
  });

  testWidgets('"전체 경기"는 리그와 무관하게 항상 보이고 누르면 콜백을 넘긴다', (tester) async {
    setUpHomeApi();
    var tapped = 0;
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(
        viewModel: vm,
        scale: 1,
        onSeeAllBracket: () => tapped++,
      ),
    );

    expect(find.text('전체 경기'), findsOneWidget);
    await tester.tap(find.text('전체 경기'));
    expect(tapped, 1);
  });

  testWidgets('1위 순위 숫자만 메인 보라색이고 나머지 줄은 다른 행과 같은 스타일이다', (tester) async {
    setUpHomeApi();
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    final first = tester.widget<Text>(
      find.byKey(HomeStandingsSection.rankKey(1)),
    );
    final second = tester.widget<Text>(
      find.byKey(HomeStandingsSection.rankKey(2)),
    );
    expect(first.style?.color, AppColors.narChipActive);
    expect(second.style?.color, isNot(AppColors.narChipActive));

    // 팀 이름 줄은 같다(팀 코드는 로고 대체 글자와 겹쳐 이름으로 비교).
    Text teamText(String name) => tester.widget<Text>(find.text(name));
    expect(teamText('젠지').style, teamText('한화생명e스포츠').style);
  });

  testWidgets('순위 데이터가 없어도 스피너·에러를 그리지 않는다', (tester) async {
    final server = setUpHomeApi();
    server.standingsRows = const [];
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('다시 시도'), findsNothing);
    expect(find.textContaining('불러오는 중'), findsNothing);
  });

  testWidgets('"더보기" 라벨은 숨은 그룹 이름을 서버 응답에서 가져온다', (tester) async {
    final server = setUpHomeApi();
    server.standingsGroups = [
      {
        'name': '그룹 A',
        'rows': [standingRow(1, 'GEN', '젠지', 19, 7, 22)],
      },
      {
        'name': '그룹 B',
        'rows': [
          standingRow(1, 'T1', 'T1', 18, 8, 17),
          standingRow(2, 'DK', '디플러스 기아', 15, 11, 5),
        ],
      },
    ];
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    // 숨은 그룹이 하나 — 하드코딩된 "라이즈 그룹"이 아니라 서버 이름.
    expect(find.text('그룹 B 2팀 더보기'), findsOneWidget);
    expect(find.textContaining('라이즈'), findsNothing);

    // 펼치면 그룹 헤더도 서버 이름으로 뜨고 라벨은 "접기"가 된다.
    await tester.tap(find.text('그룹 B 2팀 더보기'));
    await tester.pump();
    expect(find.text('그룹 B'), findsOneWidget);
    expect(find.text('접기'), findsOneWidget);
  });

  testWidgets('숨은 그룹이 둘 이상이면 이름 대신 그룹 개수로 줄인다', (tester) async {
    final server = setUpHomeApi();
    server.standingsGroups = [
      {
        'name': '그룹 A',
        'rows': [standingRow(1, 'GEN', '젠지', 19, 7, 22)],
      },
      {
        'name': '그룹 B',
        'rows': [standingRow(1, 'T1', 'T1', 18, 8, 17)],
      },
      {
        'name': '그룹 C',
        'rows': [standingRow(1, 'DK', '디플러스 기아', 15, 11, 5)],
      },
    ];
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    expect(find.text('2개 그룹 2팀 더보기'), findsOneWidget);
  });

  testWidgets('서버가 그룹 이름을 비워 보내면 "라이즈 그룹"으로 대신한다', (tester) async {
    final server = setUpHomeApi();
    server.standingsGroups = [
      {
        'name': '',
        'rows': [standingRow(1, 'GEN', '젠지', 19, 7, 22)],
      },
      {
        'name': '',
        'rows': [standingRow(1, 'T1', 'T1', 18, 8, 17)],
      },
    ];
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    expect(find.text('라이즈 그룹 1팀 더보기'), findsOneWidget);
  });

  // 서버는 표시 문구가 아니라 코드를 준다(실측: LCK `LEGEND`·`RISE`,
  // ASIAN_GAMES `A`·`B`). 그대로 그리면 "LEGEND"·"B 1팀 더보기" 가 뜬다.
  testWidgets('LCK 서버 코드(LEGEND·RISE)를 한국어 그룹명으로 바꿔 보여준다', (tester) async {
    final server = setUpHomeApi();
    server.standingsGroups = [
      {
        'name': 'LEGEND',
        'rows': [standingRow(1, 'GEN', '젠지', 19, 7, 22)],
      },
      {
        'name': 'RISE',
        'rows': [standingRow(1, 'T1', 'T1', 18, 8, 17)],
      },
    ];
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    expect(find.text('레전드 그룹'), findsOneWidget);
    expect(find.text('라이즈 그룹 1팀 더보기'), findsOneWidget);
    expect(find.textContaining('LEGEND'), findsNothing);
    expect(find.textContaining('RISE'), findsNothing);
  });

  testWidgets('아시안게임 그룹 기호(A·B)에는 "그룹"을 붙인다', (tester) async {
    final server = setUpHomeApi();
    server.standingsGroups = [
      {
        'name': 'A',
        'rows': [standingRow(1, 'VIE', '베트남', 3, 0, 3)],
      },
      {
        'name': 'B',
        'rows': [standingRow(1, 'KOR', '대한민국', 3, 0, 3)],
      },
    ];
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    expect(find.text('그룹 A'), findsOneWidget);
    expect(find.text('그룹 B 1팀 더보기'), findsOneWidget);
  });

  // ASIAN_GAMES 는 국가대표라 팀 로고 사전(온보딩 **팀** 목록)에 코드가 없다.
  // 국기는 응답 imageUrl 에만 있어서, 사전만 보면 배지가 빈 원이 된다.
  testWidgets('사전에 없는 팀 코드는 응답 imageUrl 로 로고를 그린다', (tester) async {
    final server = setUpHomeApi();
    server.standingsGroups = [
      {
        'name': 'A',
        'rows': [
          {
            ...standingRow(1, 'KOR', '대한민국', 3, 0, 3),
            'imageUrl': 'https://api.nar.kr/images/flags/kor.png',
          },
        ],
      },
    ];
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    final badges = tester
        .widgetList<TeamCodeBadge>(find.byType(TeamCodeBadge))
        .where((b) => b.teamCode == 'KOR')
        .toList();
    expect(badges, hasLength(1));
    // 사전이 비어 있으면(테스트 환경) 이 URL 이 그대로 쓰인다 — 프로팀처럼
    // 사전에 코드가 있으면 사전 값이 이긴다(imageUrl 로 넘기지 않는 이유).
    expect(badges.single.imageUrl, isNull);
    expect(
      badges.single.fallbackImageUrl,
      'https://api.nar.kr/images/flags/kor.png',
    );
  });

  testWidgets('그룹이 하나뿐이면 "더보기" 버튼이 없다', (tester) async {
    setUpHomeApi();
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    expect(find.textContaining('더보기'), findsNothing);
    expect(find.text('접기'), findsNothing);
  });

  // 표인지 대진인지는 리그 코드가 아니라 응답(`reason: BRACKET_ONLY`)이 정한다.
  // 그래서 월즈가 아닌 리그도 대진 카드를 그릴 수 있어야 한다 — ASIAN_GAMES 가
  // 녹아웃에 들어가면 이 경로를 탄다.
  group('대진 포맷 분기(응답 기반)', () {
    Map<String, dynamic> bracketPayload({
      List<Map<String, dynamic>> swiss = const [],
      List<Map<String, dynamic>> rounds = const [],
    }) => {'swiss': swiss, 'rounds': rounds};

    Map<String, dynamic> match({
      required String a,
      required String b,
      String status = 'done',
      bool isFinal = false,
      int? aWins,
      int? bWins,
    }) => {
      'status': status,
      'isFinal': isFinal,
      'teamA': {
        'teamCode': a,
        'imageUrl': 'https://api.nar.kr/images/flags/${a.toLowerCase()}.png',
        'gameWins': aWins,
        'won': aWins != null && bWins != null ? aWins > bWins : null,
      },
      'teamB': {
        'teamCode': b,
        'imageUrl': 'https://api.nar.kr/images/flags/${b.toLowerCase()}.png',
        'gameWins': bWins,
        'won': aWins != null && bWins != null ? bWins > aWins : null,
      },
    };

    // 서버 메타로 ASIAN_GAMES 를 선택 가능한 칩으로 만든다.
    void useAsianGames(HomeFakeApi server) {
      server.leagueMeta = [
        {'code': 'LCK', 'name': 'LCK', 'standings': true, 'alarm': true},
        {
          'code': 'ASIAN_GAMES',
          'name': 'ASIAN_GAMES',
          'standings': true,
          'alarm': true,
        },
      ];
    }

    testWidgets('ASIAN_GAMES 가 BRACKET_ONLY 면 녹아웃 대진을 그린다', (tester) async {
      final server = setUpHomeApi();
      useAsianGames(server);
      server.standingsBracketLeagues = {
        'ASIAN_GAMES': bracketPayload(
          rounds: [
            {
              'name': '4강',
              'matches': [
                match(a: 'KOR', b: 'VIE', aWins: 2, bWins: 0),
                match(a: 'TPE', b: 'HKG', aWins: 2, bWins: 1),
              ],
            },
            {
              'name': '결승',
              'matches': [
                match(a: 'KOR', b: 'TPE', status: 'upcoming', isFinal: true),
              ],
            },
          ],
        ),
      };

      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
      );
      vm.selectLeague('ASIAN_GAMES');
      await tester.pumpAndSettle();

      expect(vm.standingsIsBracket, isTrue);
      // 라운드 이름과 팀이 대진 카드로 그려진다.
      expect(find.text('4강'), findsOneWidget);
      expect(find.text('결승'), findsOneWidget);
      // 리그 테이블(그룹 헤더)은 안 그려진다.
      expect(find.text('레전드 그룹'), findsNothing);
      expect(find.textContaining('더보기'), findsNothing);
    });

    testWidgets('녹아웃만 있으면 스위스 전환 버튼을 숨긴다', (tester) async {
      final server = setUpHomeApi();
      useAsianGames(server);
      server.standingsBracketLeagues = {
        'ASIAN_GAMES': bracketPayload(
          rounds: [
            {
              'name': '결승',
              'matches': [match(a: 'KOR', b: 'TPE', isFinal: true)],
            },
          ],
        ),
      };

      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
      );
      vm.selectLeague('ASIAN_GAMES');
      await tester.pumpAndSettle();

      expect(vm.worldsHasBothViews, isFalse);
      expect(find.text('스위스 전적 보기'), findsNothing);
      expect(find.text('토너먼트 대진 보기'), findsNothing);
      expect(find.text('결승'), findsOneWidget);
    });

    testWidgets('스위스·녹아웃이 둘 다 있으면 전환 버튼이 있다', (tester) async {
      final server = setUpHomeApi();
      useAsianGames(server);
      server.standingsBracketLeagues = {
        'ASIAN_GAMES': bracketPayload(
          swiss: [
            {
              'record': '3-0',
              'teamCodes': ['KOR'],
              'advanced': true,
            },
          ],
          rounds: [
            {
              'name': '결승',
              'matches': [match(a: 'KOR', b: 'TPE', isFinal: true)],
            },
          ],
        ),
      };

      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
      );
      vm.selectLeague('ASIAN_GAMES');
      await tester.pumpAndSettle();

      expect(vm.worldsHasBothViews, isTrue);
      // 기본은 스위스 — 전적 버킷과 전환 버튼이 보인다.
      expect(find.text('3-0'), findsOneWidget);
      expect(find.text('토너먼트 대진 보기'), findsOneWidget);

      vm.toggleWorldsView();
      await tester.pumpAndSettle();
      expect(find.text('결승'), findsOneWidget);
    });

    // `reason` 이 아니라 데이터 유무로 판단한다 — 백엔드의 BRACKET_ONLY 는
    // 포맷 신호가 아니라 미등록 리그 전부에 붙는 기본값이라(nar-back-repo
    // `StandingsService.SCOPES`), 그걸 믿으면 LPL·EWC 같은 리그까지
    // 대진으로 오해한다.
    testWidgets('BRACKET_ONLY 라도 bracket 이 없으면 대진으로 안 간다', (tester) async {
      final server = setUpHomeApi();
      useAsianGames(server);
      // bracket 없이 BRACKET_ONLY 만 — 백엔드가 아직 안 내려주는 현재 상태.
      server.standingsBracketLeagues = {'ASIAN_GAMES': bracketPayload()};

      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
      );
      vm.selectLeague('ASIAN_GAMES');
      await tester.pumpAndSettle();

      expect(vm.standingsIsBracket, isFalse);
      expect(vm.worldsStandings, isNull);
      // 표도 대진도 없으니 자리를 비운다(기존 "데이터 없으면 안 그림" 규칙).
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // 노드 높이(_nodeHeight)가 연결선 좌표 계산에도 쓰이는 고정 상수라,
    // 팀 로우가 조금만 높아져도 조용히 넘친다(실제로 2px 넘쳤다).
    testWidgets('8강~결승 대진이 RenderFlex 오버플로우 없이 그려진다', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = original);

      final server = setUpHomeApi();
      useAsianGames(server);
      server.standingsBracketLeagues = {
        'ASIAN_GAMES': bracketPayload(
          rounds: [
            {
              'name': '8강',
              'matches': [
                match(a: 'KOR', b: 'VIE', aWins: 2, bWins: 0),
                match(a: 'TPE', b: 'HKG', aWins: 2, bWins: 1),
                match(a: 'KSA', b: 'UAE', aWins: 2, bWins: 1),
                match(a: 'MAS', b: 'IND', aWins: 2, bWins: 0),
              ],
            },
            {
              'name': '4강',
              'matches': [
                match(a: 'KOR', b: 'TPE', status: 'live'),
                match(a: 'KSA', b: 'MAS', status: 'upcoming'),
              ],
            },
            {
              'name': '결승',
              'matches': [
                match(a: 'KOR', b: 'KSA', status: 'upcoming', isFinal: true),
              ],
            },
          ],
        ),
      };

      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
      );
      vm.selectLeague('ASIAN_GAMES');
      await tester.pumpAndSettle();

      expect(
        errors.where((e) => e.exception.toString().contains('overflowed')),
        isEmpty,
        reason: '대진 카드 오버플로우: ${errors.map((e) => e.exception)}',
      );
      expect(find.text('8강'), findsOneWidget);
    });

    testWidgets('대진 리그에서 표 리그로 돌아오면 옛 대진이 남지 않는다', (tester) async {
      final server = setUpHomeApi();
      useAsianGames(server);
      server.standingsBracketLeagues = {
        'ASIAN_GAMES': bracketPayload(
          rounds: [
            {
              'name': '결승',
              'matches': [match(a: 'KOR', b: 'TPE', isFinal: true)],
            },
          ],
        ),
      };

      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
      );
      vm.selectLeague('ASIAN_GAMES');
      await tester.pumpAndSettle();
      expect(find.text('결승'), findsOneWidget);

      vm.selectLeague('LCK');
      await tester.pumpAndSettle();

      expect(vm.standingsIsBracket, isFalse);
      expect(find.text('결승'), findsNothing);
      expect(find.text('레전드 그룹'), findsOneWidget);
    });
  });

  // 월즈 칩이 다시 비활성(live:false)이라 selectLeague('WORLDS')가 무시돼
  // 이 경로로 도달 불가 — 칩을 다시 켜면 같이 되살린다.
  testWidgets(
    '월즈 카드(스위스 전적·토너먼트 대진) 둘 다 RenderFlex 오버플로우 없이 그려진다',
    skip: true,
    (tester) async {
      // HOME_MOCKS 가 꺼져 있으면 worldsStandings 가 null 이라 카드 자리가
      // 비어 이 테스트가 의미 없다 — --dart-define=HOME_MOCKS=true 로만 돈다.
      if (!kHomeMocks) {
        return;
      }
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = originalOnError);

      setUpHomeApi();
      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
      );
      vm.selectLeague('WORLDS');
      await tester.pumpAndSettle();

      // 기본은 스위스 전적.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        errors.where((e) => e.exception.toString().contains('RenderFlex')),
        isEmpty,
        reason: '스위스 전적 카드에서 오버플로우 발생: $errors',
      );

      vm.toggleWorldsView();
      expect(vm.worldsView, WorldsStandingsView.knockout);
      await tester.pumpAndSettle();

      expect(
        errors.where((e) => e.exception.toString().contains('RenderFlex')),
        isEmpty,
        reason: '토너먼트 대진 카드에서 오버플로우 발생: $errors',
      );
    },
  );
}
