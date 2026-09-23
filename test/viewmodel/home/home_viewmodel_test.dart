import 'package:flutter_test/flutter_test.dart';
import 'package:warding/viewmodel/home/home_viewmodel.dart';

void main() {
  test('배너를 닫으면 다시 보이지 않는다', () {
    final vm = HomeViewModel();

    expect(vm.bannerVisible, isTrue);
    vm.dismissBanner();
    expect(vm.bannerVisible, isFalse);
  });

  test('순위표 리그 칩 — live 가 아닌 리그는 선택되지 않는다', () {
    final vm = HomeViewModel();

    expect(vm.selectedLeague, 'LCK');
    vm.selectLeague('LPL');
    expect(vm.selectedLeague, 'LCK');
  });

  test('순위표 라이즈 그룹 펼치기/접기 토글', () {
    final vm = HomeViewModel();

    expect(vm.standingsExpanded, isFalse);
    vm.toggleStandingsExpanded();
    expect(vm.standingsExpanded, isTrue);
    vm.toggleStandingsExpanded();
    expect(vm.standingsExpanded, isFalse);
  });

  test('커뮤니티 정렬 — 인기순은 likeCount*3+commentCount*2+viewCount 기준 내림차순', () {
    final vm = HomeViewModel();

    vm.setCommunitySort(HomeCommunitySort.hot);
    final sorted = vm.communityPostsSorted;

    int score(int i) {
      final p = sorted[i];
      return p.likeCount * 3 + p.commentCount * 2 + p.viewCount;
    }

    for (var i = 0; i < sorted.length - 1; i++) {
      expect(score(i), greaterThanOrEqualTo(score(i + 1)));
    }
  });

  test('커뮤니티 정렬 — 최신순은 createdAt 내림차순', () {
    final vm = HomeViewModel();

    vm.setCommunitySort(HomeCommunitySort.latest);
    final sorted = vm.communityPostsSorted;

    for (var i = 0; i < sorted.length - 1; i++) {
      expect(
        sorted[i].createdAt!.isAfter(sorted[i + 1].createdAt!) ||
            sorted[i].createdAt!.isAtSameMomentAs(sorted[i + 1].createdAt!),
        isTrue,
      );
    }
  });

  test('오늘 경기 정렬 — 진행 중인 경기가 앞으로 온다', () {
    final vm = HomeViewModel();

    final sorted = vm.todayMatchesSorted;
    expect(sorted.first.matchStatus, 'inProgress');
  });

  test('쇼츠 필터 — 내 선수 필터는 매칭된 선수가 있는 영상만 남긴다', () {
    final vm = HomeViewModel();

    vm.setShortsFilter(HomeShortsFilter.player);
    final filtered = vm.shortsFiltered;

    expect(filtered, isNotEmpty);
    expect(filtered.every((v) => v.matchedPlayer != null), isTrue);
  });

  test('쇼츠 필터 — 내 팀(T1) 필터는 T1 영상만 남긴다', () {
    final vm = HomeViewModel();

    vm.setShortsFilter(HomeShortsFilter.team);
    final filtered = vm.shortsFiltered;

    expect(filtered, isNotEmpty);
    expect(filtered.every((v) => v.teamCode == 'T1'), isTrue);
  });

  test('콘텐츠 탭 전환', () {
    final vm = HomeViewModel();

    expect(vm.contentTab, HomeContentTab.news);
    vm.setContentTab(HomeContentTab.shorts);
    expect(vm.contentTab, HomeContentTab.shorts);
  });

  test('솔랭 히든 카운트 — 구독 총원에서 진행 중·완료 표시분을 뺀 값', () {
    final vm = HomeViewModel();

    expect(
      vm.soloHiddenCount,
      HomeViewModel.mockSubscribedTotal -
          HomeViewModel.mockLiveNow.length -
          HomeViewModel.mockFinishedToday.length,
    );
  });
}
