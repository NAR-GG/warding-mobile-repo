import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/story_video.dart';
import 'package:warding/repository/shorts/shorts_repository.dart';
import 'package:warding/viewmodel/shorts/shorts_feed_viewmodel.dart';

StoryVideo _v(int id, {String team = ''}) => StoryVideo(
  videoId: id,
  youtubeVideoId: 'yt$id',
  title: '영상 $id',
  videoUrl: '',
  thumbnailUrl: '',
  channelName: 'ch',
  viewCount: 0,
  teamCode: team,
);

/// 페이지 번호로 미리 정해 둔 응답을 돌려주는 가짜 저장소.
class _FakeRepo implements ShortsRepository {
  final Map<int, ShortsPage> pages = {};
  final List<({int page, int size, String? teamCode})> calls = [];
  bool fail = false;

  @override
  Future<ShortsPage> fetchShortsPage({
    String sort = 'latest',
    int size = 20,
    int page = 0,
    String? teamCode,
  }) async {
    calls.add((page: page, size: size, teamCode: teamCode));
    if (fail) throw Exception('network');
    return pages[page] ?? const ShortsPage(items: [], isLast: true);
  }

  @override
  Future<List<StoryVideo>> fetchShorts({
    String sort = 'latest',
    int size = 20,
    String? teamCode,
  }) async => (await fetchShortsPage(size: size, teamCode: teamCode)).items;
}

void main() {
  late _FakeRepo repo;
  String? teamCode;

  ShortsFeedViewModel build({
    List<StoryVideo>? initial,
    int startIndex = 0,
    ShortsFeedFilter filter = ShortsFeedFilter.all,
  }) {
    final vm = ShortsFeedViewModel(
      initialVideos: initial ?? [for (var i = 0; i < 10; i++) _v(i)],
      startIndex: startIndex,
      filter: filter,
      initialPageSize: 10,
      resolveTeamCode: () async => teamCode,
      repository: repo,
    );
    addTearDown(vm.dispose);
    return vm;
  }

  setUp(() {
    repo = _FakeRepo();
    teamCode = 'T1';
  });

  test('탭한 영상부터 시작하고, 첫 요청은 홈이 받은 다음 페이지(1)다', () async {
    repo.pages[1] = ShortsPage(
      items: [for (var i = 10; i < 20; i++) _v(i)],
      isLast: false,
    );
    final vm = build(startIndex: 4);
    expect(vm.index, 4);
    expect(repo.calls, isEmpty, reason: '시작만으로는 요청하지 않는다');

    vm.onPageChanged(8); // 끝에서 3개 안쪽 → 미리 요청
    await pumpEventQueue();

    expect(repo.calls.single.page, 1);
    expect(repo.calls.single.size, 10, reason: '홈과 같은 크기로 이어 받는다');
    expect(vm.videos.length, 20);
  });

  test('이미 있는 영상은 다음 페이지에서 중복으로 붙이지 않는다', () async {
    repo.pages[1] = ShortsPage(items: [_v(9), _v(10)], isLast: false);
    final vm = build();
    vm.onPageChanged(9);
    await pumpEventQueue();

    expect(vm.videos.map((v) => v.videoId).toList(), [
      for (var i = 0; i < 11; i++) i,
    ]);
  });

  test('마지막 페이지를 받으면 끝 화면 한 장이 붙는다', () async {
    repo.pages[1] = ShortsPage(items: [_v(10)], isLast: true);
    final vm = build();
    expect(vm.isEnd, isFalse);
    vm.onPageChanged(9);
    await pumpEventQueue();

    expect(vm.isEnd, isTrue);
    expect(vm.pageCount, vm.videos.length + 1);
  });

  test('임베드 오류면 다음 영상으로 스킵하고, 재생이 시작되면 실패 수를 끊는다', () async {
    final vm = build();
    final jumps = <int>[];
    vm.onJumpTo = jumps.add;

    vm.reportError(0, code: 101);
    expect(jumps, [1]);
    expect(vm.unavailable, isFalse);

    vm.onPageChanged(1);
    vm.reportPlaying(1);
    vm.onPageChanged(2);
    vm.reportError(2, code: 150);
    vm.onPageChanged(3);
    vm.reportError(3, code: 150);
    expect(vm.unavailable, isFalse, reason: '성공 사이에 끊겨 연속 2건');
  });

  test('연속 3건 실패하면 스킵을 멈추고 unavailable', () async {
    final vm = build();
    final jumps = <int>[];
    vm.onJumpTo = jumps.add;

    vm.reportError(0);
    vm.onPageChanged(1);
    vm.reportError(1);
    vm.onPageChanged(2);
    vm.reportError(2);

    expect(vm.unavailable, isTrue);
    expect(jumps, [1, 2], reason: '세 번째는 넘어가지 않는다');

    vm.retry();
    expect(vm.unavailable, isFalse);
  });

  test('현재 페이지가 아닌 영상의 오류·종료는 무시한다', () async {
    final vm = build();
    final jumps = <int>[];
    vm.onJumpTo = jumps.add;

    vm.reportError(1); // 미리 로드된 다음 영상의 오류
    vm.reportEnded(1);
    expect(jumps, isEmpty);
    expect(vm.unavailable, isFalse);
  });

  test('영상이 끝나면 다음으로 넘긴다', () async {
    final vm = build();
    final jumps = <int>[];
    vm.onJumpTo = jumps.add;
    vm.reportEnded(0);
    expect(jumps, [1]);
  });

  test('마지막 영상에서 끝나면 다음 페이지를 받은 뒤 넘어간다', () async {
    repo.pages[1] = ShortsPage(items: [_v(10)], isLast: true);
    final vm = build(initial: [_v(0), _v(1)], startIndex: 1);
    final jumps = <int>[];
    vm.onJumpTo = jumps.add;

    vm.reportEnded(1);
    await pumpEventQueue();

    expect(jumps, [2]);
    expect(vm.videos.length, 3);
  });

  test('다음 페이지 조회가 실패해도 목록·현재 영상은 그대로다', () async {
    repo.fail = true;
    final vm = build();
    vm.onPageChanged(9);
    await pumpEventQueue();

    expect(vm.videos.length, 10);
    expect(vm.index, 9);
    expect(vm.isEnd, isFalse, reason: '실패는 끝이 아니다 — 다시 시도할 수 있다');
  });

  test('내 팀으로 바꾸면 피드를 새로 받는다(응원팀 코드로, 0페이지부터)', () async {
    repo.pages[0] = ShortsPage(
      items: [
        _v(100, team: 'T1'),
        _v(101, team: 'GEN'),
        _v(102, team: 'T1'),
      ],
      isLast: true,
    );
    final vm = build(startIndex: 5);

    await vm.setFilter(ShortsFeedFilter.team);

    expect(repo.calls.single.page, 0);
    expect(repo.calls.single.size, ShortsFeedViewModel.defaultPageSize);
    expect(repo.calls.single.teamCode, 'T1');
    expect(vm.index, 0);
    expect(
      vm.videos.map((v) => v.videoId),
      [100, 102],
      reason: '서버가 팀을 안 거르는 동안에도 응답의 teamCode 로 한 번 더 거른다',
    );
  });

  test('응원팀이 없으면 내 팀은 요청 없이 안내 상태', () async {
    teamCode = null;
    final vm = build();

    await vm.setFilter(ShortsFeedFilter.team);

    expect(vm.teamUnset, isTrue);
    expect(vm.videos, isEmpty);
    expect(repo.calls, isEmpty);

    await vm.setFilter(ShortsFeedFilter.all);
    expect(vm.teamUnset, isFalse);
  });

  test('처음부터 비어 있으면(내 팀 진입 등) 스스로 받아 온다', () async {
    repo.pages[0] = ShortsPage(items: [_v(1), _v(2)], isLast: true);
    final vm = build(initial: const []);
    await pumpEventQueue();

    expect(vm.videos.length, 2);
    expect(repo.calls.single.page, 0);
  });
}
