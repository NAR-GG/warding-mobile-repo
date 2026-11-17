import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:warding/core/error/failure.dart';
import 'package:warding/features/shorts/domain/entities/story_video.dart';
import 'package:warding/features/shorts/domain/repositories/shorts_repository.dart';
import 'package:warding/features/shorts/presentation/viewmodels/shorts_summary_viewmodel.dart';

class _MockRepo extends Mock implements ShortsRepository {}

StoryVideo _video(String id, {String teamCode = ''}) => StoryVideo(
  videoId: id.hashCode,
  youtubeVideoId: id,
  title: '영상 $id',
  videoUrl: '',
  thumbnailUrl: '',
  channelName: '채널',
  viewCount: 0,
  teamCode: teamCode,
);

void main() {
  late _MockRepo repo;
  String? team;

  ShortsSummaryViewModel build({int cardCount = 10}) => ShortsSummaryViewModel(
    repository: repo,
    resolveTeamCode: () async => team,
    cardCount: cardCount,
  );

  void stub(List<StoryVideo> items) {
    when(
      () => repo.fetchShortsPage(
        sort: any(named: 'sort'),
        size: any(named: 'size'),
        page: any(named: 'page'),
        teamCode: any(named: 'teamCode'),
      ),
    ).thenAnswer((_) async => Right(ShortsPage(items: items, isLast: true)));
  }

  setUp(() {
    repo = _MockRepo();
    team = null;
  });

  test('생성만으로는 조회하지 않는다', () {
    build();
    verifyNever(
      () => repo.fetchShortsPage(
        sort: any(named: 'sort'),
        size: any(named: 'size'),
        page: any(named: 'page'),
        teamCode: any(named: 'teamCode'),
      ),
    );
  });

  test('전체 필터는 cardCount 만큼 받고 팀 코드를 안 보낸다', () async {
    stub([_video('a'), _video('b')]);
    final vm = build(cardCount: 10);

    await vm.load();

    expect(vm.videos.length, 2);
    verify(
      () => repo.fetchShortsPage(sort: 'latest', size: 10, teamCode: null),
    ).called(1);
  });

  test('cardCount 를 넘으면 잘라낸다', () async {
    stub([for (var i = 0; i < 5; i++) _video('v$i')]);
    final vm = build(cardCount: 3);

    await vm.load();

    expect(vm.videos.length, 3);
  });

  test('내 팀 필터는 넉넉히 받아 클라이언트에서 다시 거른다', () async {
    team = 'T1';
    stub([
      _video('a', teamCode: 'T1'),
      _video('b', teamCode: 'GEN'),
      _video('c'), // LCK 공식 채널 — 팀 코드 없음
    ]);
    final vm = build();

    vm.setFilter(ShortsSummaryFilter.team);
    await vm.load();

    // 서버가 아직 팀을 안 거르므로 teamFetchSize 로 받는다.
    verify(
      () => repo.fetchShortsPage(
        sort: 'latest',
        size: ShortsSummaryViewModel.teamFetchSize,
        teamCode: 'T1',
      ),
    ).called(greaterThanOrEqualTo(1));
    // 팀 코드 없는 공식 채널은 "내 팀"에서 빠진다.
    expect(vm.videos.map((v) => v.youtubeVideoId).toList(), ['a']);
    expect(vm.hasTeam, isTrue);
    expect(vm.fetchSize, ShortsSummaryViewModel.teamFetchSize);
  });

  test('응원팀이 없으면 내 팀 목록은 비고 조회도 하지 않는다', () async {
    team = null;
    stub([_video('a')]);
    final vm = build();

    vm.setFilter(ShortsSummaryFilter.team);
    await vm.load();

    expect(vm.videos, isEmpty);
    expect(vm.hasTeam, isFalse);
    expect(vm.loading, isFalse);
  });

  test('필터를 바꾸면 조회가 끝날 때까지 loading — 한 프레임 깜빡임을 막는다', () async {
    team = 'T1';
    stub([_video('a', teamCode: 'T1')]);
    final vm = build();
    await vm.load();

    vm.setFilter(ShortsSummaryFilter.team);

    // 바로 확인 — 아직 응원팀·목록을 받기 전이다.
    expect(vm.loading, isTrue);

    await vm.load();
    expect(vm.loading, isFalse);
  });

  test('조회 실패하면 빈 목록으로 둔다', () async {
    when(
      () => repo.fetchShortsPage(
        sort: any(named: 'sort'),
        size: any(named: 'size'),
        page: any(named: 'page'),
        teamCode: any(named: 'teamCode'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure()));
    final vm = build();

    await vm.load();

    expect(vm.videos, isEmpty);
    expect(vm.loading, isFalse);
  });
}
