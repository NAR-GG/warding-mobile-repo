import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/match_game.dart';
import 'package:warding/model/match_live_event.dart';
import 'package:warding/model/schedule_match.dart';
import 'package:warding/viewmodel/match_detail/match_detail_viewmodel.dart';

import '../../support/fake_rating_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatchDetailRepository match;
  late MockRatingRepository rating;

  const teamA = MatchTeam(
    teamName: 'T1',
    teamCode: 'T1',
    teamImageUrl: 'https://example.com/t1.png',
    score: 1,
  );
  const teamB = MatchTeam(
    teamName: 'Gen.G',
    teamCode: 'GEN',
    teamImageUrl: 'https://example.com/gen.png',
    score: 0,
  );
  const scheduleMatch = ScheduleMatch(
    matchId: 'm-1',
    scheduledTime: '2026-08-07T18:00:00',
    leagueInfo: 'LCK',
    matchTitle: 'T1 vs Gen.G',
    matchStatus: 'ENDED',
    isSynced: true,
    teamA: teamA,
    teamB: teamB,
  );

  setUp(() {
    match = MockMatchDetailRepository();
    rating = MockRatingRepository();
    when(() => match.fetchChampionPick(any())).thenThrow(Exception('skip'));
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenThrow(Exception('skip'));
  });

  MatchDetailViewModel vmFor({
    required List<MatchGame> games,
    required MatchLiveEvents liveEvents,
    required ScheduleMatch? initialMatch,
  }) {
    when(() => match.fetchGames('m-1')).thenAnswer((_) async => (games, null));
    when(() => match.fetchLiveEvents(any())).thenAnswer((_) async => liveEvents);
    return MatchDetailViewModel(
      matchId: 'm-1',
      initialMatch: initialMatch,
      initialTabIndex: 1, // 라이브 이벤트 탭 — load() 가 곧바로 이벤트를 불러오게 한다.
      repository: match,
      ratingRepository: rating,
    );
  }

  test('세트 종료 + 승자(Blue) 확정이면 넥서스 이벤트가 맨 앞에 붙는다', () async {
    final vm = vmFor(
      games: const [
        MatchGame(
          gameId: 'g1',
          gameOrder: 1,
          status: 'ENDED',
          winnerTeamCode: 'T1',
        ),
      ],
      liveEvents: const MatchLiveEvents(
        blueTeamImageUrl: 'https://example.com/t1.png',
        redTeamImageUrl: 'https://example.com/gen.png',
        events: [
          MatchLiveEvent(
            type: LiveEventType.baron,
            gameTime: '25:10',
            gameTimeSeconds: 1510,
            teamSide: 'Blue',
            teamName: 'T1',
          ),
        ],
      ),
      initialMatch: scheduleMatch,
    );
    await vm.load();

    final events = vm.liveEvents;

    expect(events, hasLength(2));
    expect(events.first.type, LiveEventType.nexus);
    expect(events.first.teamSide, 'Blue');
    expect(events.first.teamName, 'T1');
    expect(events.first.gameTime, '25:10');
    expect(events.first.gameTimeSeconds, 1510);
    expect(events[1].type, LiveEventType.baron);
  });

  test('실제 이벤트가 하나도 없어도(빈 배열, 조회는 성공) 넥서스 이벤트만 단독으로 나온다', () async {
    final vm = vmFor(
      games: const [
        MatchGame(
          gameId: 'g1',
          gameOrder: 1,
          status: 'ENDED',
          winnerTeamCode: 'GEN',
        ),
      ],
      liveEvents: const MatchLiveEvents(events: []),
      initialMatch: scheduleMatch,
    );
    await vm.load();

    final events = vm.liveEvents;

    expect(events, hasLength(1));
    expect(events.first.type, LiveEventType.nexus);
    expect(events.first.teamSide, 'Red');
    expect(events.first.teamName, 'Gen.G');
    expect(events.first.gameTime, '');
    expect(events.first.gameTimeSeconds, 0);
  });

  test('세트가 LIVE 면 넥서스 이벤트를 붙이지 않는다', () async {
    final vm = vmFor(
      games: const [
        MatchGame(gameId: 'g1', gameOrder: 1, status: 'LIVE'),
      ],
      liveEvents: const MatchLiveEvents(events: []),
      initialMatch: scheduleMatch,
    );
    await vm.load();

    expect(vm.liveEvents, isEmpty);
  });

  test('승자 teamCode 가 teamA/teamB 어느 쪽과도 안 맞으면 붙이지 않는다', () async {
    final vm = vmFor(
      games: const [
        MatchGame(
          gameId: 'g1',
          gameOrder: 1,
          status: 'ENDED',
          winnerTeamCode: 'DK',
        ),
      ],
      liveEvents: const MatchLiveEvents(events: []),
      initialMatch: scheduleMatch,
    );
    await vm.load();

    expect(vm.liveEvents, isEmpty);
  });

  test('matchInfo 가 없으면(팀 코드 매칭 불가) 붙이지 않는다', () async {
    when(() => match.fetchMatch(any())).thenThrow(Exception('skip'));
    final vm = vmFor(
      games: const [
        MatchGame(
          gameId: 'g1',
          gameOrder: 1,
          status: 'ENDED',
          winnerTeamCode: 'T1',
        ),
      ],
      liveEvents: const MatchLiveEvents(events: []),
      initialMatch: null,
    );
    await vm.load();

    expect(vm.liveEvents, isEmpty);
  });

  test('라이브 이벤트 조회 자체가 실패했으면(liveEventsData 없음) 붙이지 않는다', () async {
    when(() => match.fetchGames('m-1')).thenAnswer(
      (_) async => (
        const [
          MatchGame(
            gameId: 'g1',
            gameOrder: 1,
            status: 'ENDED',
            winnerTeamCode: 'T1',
          ),
        ],
        null,
      ),
    );
    when(() => match.fetchLiveEvents(any())).thenThrow(Exception('network'));
    final vm = MatchDetailViewModel(
      matchId: 'm-1',
      initialMatch: scheduleMatch,
      initialTabIndex: 1,
      repository: match,
      ratingRepository: rating,
    );
    await vm.load();

    expect(vm.liveEvents, isEmpty);
  });
}
