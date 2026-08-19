import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/match_champion_pick.dart';
import 'package:warding/model/match_game.dart';
import 'package:warding/model/schedule_match.dart';
import 'package:warding/viewmodel/match_detail/match_detail_viewmodel.dart';

import '../../support/fake_rating_repository.dart';

/// 경기 상세 당겨서 새로고침([MatchDetailViewModel.refresh]).
///
/// 핵심은 "다시 받되 보고 있던 자리는 그대로 둔다" 이다. [load] 를 다시 부르면
/// 세트가 기본 선택으로 튕기고(3세트 보다가 LIVE 로), 경기 정보는 이미 값이
/// 있으면 아예 갱신되지 않는다 — 새로고침에서 가장 보고 싶은 스코어인데도.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatchDetailRepository match;
  late MockRatingRepository rating;

  ScheduleMatch matchWithScore(int a, int b) => ScheduleMatch.fromJson({
        'matchId': 'm-1',
        'matchStatus': 'live',
        'matchTitle': '12주 차 | GEN vs T1',
        'blueTeam': {'teamName': 'Gen.g', 'teamCode': 'GEN', 'score': a},
        'redTeam': {'teamName': 'T1', 'teamCode': 'T1', 'score': b},
      });

  const threeSets = [
    MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
    MatchGame(gameId: 'g2', gameOrder: 2, status: 'ENDED'),
    MatchGame(gameId: 'g3', gameOrder: 3, status: 'LIVE'),
  ];

  setUp(() {
    match = MockMatchDetailRepository();
    rating = MockRatingRepository();
    when(() => match.fetchLiveEvents(any())).thenThrow(Exception('skip'));
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenThrow(Exception('skip'));
    when(() => match.fetchChampionPick(any())).thenAnswer(
      (_) async => MatchChampionPick.fromJson(const {
        'gameId': 'g1',
        'blueTeam': {'teamName': 'Gen.g'},
        'redTeam': {'teamName': 'T1'},
      }),
    );
  });

  MatchDetailViewModel vm({ScheduleMatch? initialMatch}) => MatchDetailViewModel(
        matchId: 'm-1',
        initialMatch: initialMatch,
        repository: match,
        ratingRepository: rating,
      );

  test('보고 있던 세트를 유지한다 — 기본 선택으로 되돌리지 않는다', () async {
    when(() => match.fetchGames('m-1'))
        .thenAnswer((_) async => (threeSets, null));
    when(() => match.fetchMatch('m-1')).thenAnswer((_) async => null);

    final model = vm();
    await model.load();
    expect(model.currentSet, 3, reason: '진입 기본값은 LIVE 세트');

    await model.selectSet(1); // 사용자가 1세트를 골라 보고 있다
    await model.refresh();

    expect(
      model.currentSet,
      1,
      reason: '새로고침이 세트를 바꾸면 보던 자리를 잃는다',
    );
  });

  test('보던 세트가 사라졌으면 기본 선택으로 되돌린다', () async {
    when(() => match.fetchGames('m-1'))
        .thenAnswer((_) async => (threeSets, null));
    when(() => match.fetchMatch('m-1')).thenAnswer((_) async => null);

    final model = vm();
    await model.load();
    await model.selectSet(3);

    // 서버에서 3세트가 없어진 응답(취소·정정 등).
    when(() => match.fetchGames('m-1')).thenAnswer(
      (_) async => (threeSets.sublist(0, 2), null),
    );
    await model.refresh();

    expect(model.currentSet, 2, reason: '남은 세트 중 기본 선택 규칙');
  });

  test('스코어를 다시 받는다 — 이미 값이 있어도 갱신한다', () async {
    when(() => match.fetchGames('m-1'))
        .thenAnswer((_) async => (threeSets, null));
    // 진입 시 이미 경기 정보를 들고 들어온 경우(경기 목록에서 카드 탭).
    final model = vm(initialMatch: matchWithScore(1, 0));
    await model.load();
    expect(model.matchInfo?.teamA.score, 1);

    when(() => match.fetchMatch('m-1'))
        .thenAnswer((_) async => matchWithScore(2, 0));
    await model.refresh();

    expect(
      model.matchInfo?.teamA.score,
      2,
      reason: 'load() 는 matchInfo 가 있으면 안 받는다 — refresh 는 받아야 한다',
    );
  });

  test('활성 탭 데이터를 다시 받는다', () async {
    when(() => match.fetchGames('m-1'))
        .thenAnswer((_) async => (threeSets, null));
    when(() => match.fetchMatch('m-1')).thenAnswer((_) async => null);

    final model = vm();
    await model.load();
    // 진입 시 챔피언 픽 탭(기본)이 한 번 로드된다.
    verify(() => match.fetchChampionPick(any())).called(1);

    await model.refresh();

    verify(() => match.fetchChampionPick(any())).called(1);
  });

  test('보지 않은 탭은 새로고침이 미리 받지 않는다 — 지연 로딩 유지', () async {
    when(() => match.fetchGames('m-1'))
        .thenAnswer((_) async => (threeSets, null));
    when(() => match.fetchMatch('m-1')).thenAnswer((_) async => null);

    final model = vm();
    await model.load();
    await model.refresh();

    // 라이브 이벤트 탭으로 전환한 적이 없으므로 요청도 없어야 한다.
    verifyNever(() => match.fetchLiveEvents(any()));
  });

  test('조회가 실패해도 예외를 밖으로 던지지 않는다 — 인디케이터가 멈추지 않게', () async {
    when(() => match.fetchGames('m-1')).thenThrow(Exception('network'));
    when(() => match.fetchMatch('m-1')).thenThrow(Exception('network'));

    final model = vm();
    await model.load();

    await expectLater(model.refresh(), completes);
  });
}
