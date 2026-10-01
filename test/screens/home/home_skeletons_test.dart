import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/model/home_models.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/home/component/home_community_section.dart';
import 'package:warding/screens/home/component/home_content_section.dart';
import 'package:warding/screens/home/component/home_review_section.dart';
import 'package:warding/screens/home/component/home_skeletons.dart';
import 'package:warding/screens/home/component/home_solo_rank_section.dart';
import 'package:warding/screens/home/component/home_standings_section.dart';
import 'package:warding/screens/home/component/home_today_matches_section.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/home/home_viewmodel.dart';

import '../../support/l10n_test_setup.dart';
import 'home_test_harness.dart';

/// [gate] 가 열릴 때까지 응답을 붙잡는다. [fail] 이면 열린 뒤 500 을 돌려준다.
class _GatedReviews implements ReviewSource {
  _GatedReviews(this.gate, this.items);
  final Future<void> gate;
  final List<HomeReviewItem> items;
  @override
  Future<List<HomeReviewItem>> fetchRecent() async {
    await gate;
    return items;
  }
}

class _GatedNews implements NewsSource {
  _GatedNews(this.gate, this.items);
  final Future<void> gate;
  final List<HomeNewsArticle> items;
  @override
  Future<List<HomeNewsArticle>> fetchTop() async {
    await gate;
    return items;
  }
}

class _GatedSolo implements SoloRankSource {
  _GatedSolo(this.gate);
  final Future<void> gate;
  @override
  Future<SoloRankSnapshot> fetch() async {
    await gate;
    return emptySolo;
  }
}

void main() {
  late Completer<void> gate;
  late HomeFakeApi server;
  var fail = false;

  setUp(() {
    gate = Completer<void>();
    fail = false;
    server = setUpHomeApi(loggedIn: true);
    // 하네스의 가짜 서버 앞에 문을 하나 둔다.
    api.setApiClientForTesting(
      MockClient((request) async {
        await gate.future;
        if (fail) return http.Response('{"message":"fail"}', 500);
        return server.client.get(request.url);
      }),
    );
  });

  HomeViewModel build() {
    final vm = HomeViewModel(
      soloRank: _GatedSolo(gate.future),
      reviews: _GatedReviews(gate.future, const [
        HomeReviewItem(
          playerName: 'Faker',
          champion: '아리',
          stars: 4,
          comment: '좋았다',
          nickname: '팬#1',
          teamCode: 'T1',
          minutesAgo: 5,
        ),
      ]),
      news: _GatedNews(gate.future, const [
        HomeNewsArticle(title: '뉴스 제목', office: '매체', minutesAgo: 3),
      ]),
    );
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> pumpAll(WidgetTester tester, HomeViewModel vm) async {
    tester.view.physicalSize = const Size(375, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithL10n(
        SingleChildScrollView(
          child: ListenableBuilder(
            listenable: vm,
            builder: (context, _) => Column(
              children: [
                HomeSoloRankSection(viewModel: vm, scale: 1),
                if (vm.todayMatchesSorted.isNotEmpty || vm.todayMatchesLoading)
                  HomeTodayMatchesSection(viewModel: vm, scale: 1),
                HomeStandingsSection(viewModel: vm, scale: 1),
                HomeCommunitySection(viewModel: vm, scale: 1),
                if (vm.reviews.isNotEmpty || vm.reviewsLoading)
                  HomeReviewSection(viewModel: vm, scale: 1),
                HomeContentSection(viewModel: vm, scale: 1),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('첫 응답이 오기 전에는 섹션마다 스켈레톤을 그린다', (tester) async {
    late HomeViewModel vm;
    await tester.runAsync(() async => vm = build());
    await pumpAll(tester, vm);

    expect(find.byType(HomeFinishedSoloSkeleton), findsOneWidget);
    expect(find.byType(HomeTodayMatchesSkeleton), findsOneWidget);
    expect(find.byType(HomeStandingsSkeleton), findsOneWidget);
    expect(find.byType(HomeNewsSkeleton), findsOneWidget);
    // 커뮤니티 + 평점 한줄평
    expect(find.byType(HomeListSkeleton), findsNWidgets(2));

    // 붙잡아 둔 요청을 풀어 타임아웃 타이머가 남지 않게 한다.
    gate.complete();
    await tester.runAsync(() => pumpEventQueue());
  });

  testWidgets('데이터가 오면 스켈레톤이 사라지고 실제 내용이 나온다', (tester) async {
    late HomeViewModel vm;
    await tester.runAsync(() async {
      vm = build();
      gate.complete();
      await vm.refreshAll();
    });
    await pumpAll(tester, vm);

    expect(find.byType(HomeFinishedSoloSkeleton), findsNothing);
    expect(find.byType(HomeTodayMatchesSkeleton), findsNothing);
    expect(find.byType(HomeStandingsSkeleton), findsNothing);
    expect(find.byType(HomeNewsSkeleton), findsNothing);
    expect(find.byType(HomeListSkeleton), findsNothing);
    expect(find.text('뉴스 제목'), findsOneWidget);
    expect(find.text('글-latest'), findsOneWidget);
  });

  testWidgets('조회가 실패해도 스켈레톤이 영원히 남지 않는다', (tester) async {
    late HomeViewModel vm;
    await tester.runAsync(() async {
      fail = true;
      vm = build();
      gate.complete();
      await vm.refreshAll();
    });
    await pumpAll(tester, vm);

    expect(find.byType(HomeTodayMatchesSkeleton), findsNothing);
    expect(find.byType(HomeStandingsSkeleton), findsNothing);
    expect(vm.communityLoading, isFalse);
    expect(vm.todayMatchesLoading, isFalse);
    expect(vm.standingsLoading, isFalse);
  });

  testWidgets('한 번 로드된 뒤 새로고침해도 스켈레톤을 다시 띄우지 않는다', (tester) async {
    late HomeViewModel vm;
    await tester.runAsync(() async {
      vm = build();
      gate.complete();
      await vm.refreshAll();
    });
    expect(vm.standingsLoading, isFalse);

    await tester.runAsync(() async {
      final refresh = vm.refreshAll();
      // 새로고침이 진행 중이어도 이미 한 번 로드된 섹션은 스켈레톤으로 돌아가지 않는다.
      expect(vm.standingsLoading, isFalse);
      expect(vm.todayMatchesLoading, isFalse);
      expect(vm.communityLoading, isFalse);
      expect(vm.newsLoading, isFalse);
      expect(vm.reviewsLoading, isFalse);
      await refresh;
    });
  });

  test('뉴스를 기다리는 동안은 뉴스 탭이 있다가, 비면 쇼츠만 남는다', () async {
    final newsGate = Completer<void>();
    final vm = HomeViewModel(
      soloRank: _GatedSolo(Future.value()),
      reviews: _GatedReviews(Future.value(), const []),
      news: _GatedNews(newsGate.future, const []),
    );
    addTearDown(vm.dispose);
    expect(vm.availableContentTabs, contains(HomeContentTab.news));

    newsGate.complete();
    await pumpEventQueue();
    expect(vm.newsLoading, isFalse);
    expect(vm.availableContentTabs, [HomeContentTab.shorts]);
  });
}
