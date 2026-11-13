import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:warding/features/community/data/community_repository.dart';
import 'package:warding/features/community/domain/community_remote_post.dart';
import 'package:warding/features/community/presentation/viewmodels/community_summary_viewmodel.dart';

class _MockRepo extends Mock implements CommunityRepository {}

CommunityRemotePost _post(int id, String title) =>
    CommunityRemotePost.fromJson({
      'id': id,
      'boardTeamId': null,
      'title': title,
      'bodyPreview': '본문',
      'author': const {'memberId': 1, 'nickname': '작성자#0001'},
      'viewCount': 0,
      'likeCount': 0,
      'commentCount': 0,
      'edited': false,
      'createdAt': '2026-11-13T12:00:00',
    });

CommunityRemotePostPage _page(List<CommunityRemotePost> posts) =>
    CommunityRemotePostPage(posts: posts);

void main() {
  late _MockRepo repo;
  late CommunitySummaryViewModel vm;

  setUp(() {
    repo = _MockRepo();
    vm = CommunitySummaryViewModel(repository: repo, postCount: 2);
  });

  test('생성만으로는 조회하지 않는다 — 시점은 쓰는 쪽이 정한다', () {
    verifyNever(
      () => repo.fetchPosts(
        boardTeamId: any(named: 'boardTeamId'),
        cursor: any(named: 'cursor'),
        size: any(named: 'size'),
        sort: any(named: 'sort'),
      ),
    );
    expect(vm.loading, isTrue);
    expect(vm.posts, isEmpty);
  });

  test('load 는 postCount·정렬을 그대로 요청에 싣는다', () async {
    when(() => repo.fetchPosts(size: 2, sort: 'latest'))
        .thenAnswer((_) async => _page([_post(1, '글A')]));

    await vm.load();

    expect(vm.posts.single.title, '글A');
    expect(vm.loading, isFalse);
    verify(() => repo.fetchPosts(size: 2, sort: 'latest')).called(1);
  });

  test('조회 실패해도 마지막 목록을 유지하고 로딩만 끝낸다', () async {
    when(() => repo.fetchPosts(size: 2, sort: 'latest'))
        .thenAnswer((_) async => _page([_post(1, '글A')]));
    await vm.load();

    when(() => repo.fetchPosts(size: 2, sort: 'latest'))
        .thenThrow(Exception('500'));
    await vm.load();

    expect(vm.posts.single.title, '글A');
    expect(vm.loading, isFalse);
  });

  test('칩에서 뺀 정렬(hot)로는 바뀌지 않는다', () async {
    expect(vm.availableSorts, isNot(contains(CommunitySummarySort.hot)));

    vm.setSort(CommunitySummarySort.hot);

    expect(vm.sort, CommunitySummarySort.latest);
  });

  test('removePost 는 그 글만 빼고 통지한다', () async {
    when(() => repo.fetchPosts(size: 2, sort: 'latest'))
        .thenAnswer((_) async => _page([_post(1, '글A'), _post(2, '글B')]));
    await vm.load();

    var notified = 0;
    vm.addListener(() => notified++);
    vm.removePost(1);

    expect(vm.posts.single.id, 2);
    expect(notified, 1);
    // 없는 글은 통지하지 않는다.
    vm.removePost(999);
    expect(notified, 1);
  });

  test('applyPostUpdate 는 같은 id 를 갈아끼운다', () async {
    when(() => repo.fetchPosts(size: 2, sort: 'latest'))
        .thenAnswer((_) async => _page([_post(1, '옛 제목')]));
    await vm.load();

    vm.applyPostUpdate(_post(1, '새 제목'));

    expect(vm.posts.single.title, '새 제목');
  });
}
