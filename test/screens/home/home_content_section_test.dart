import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/dashed_border.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/home/component/home_community_section.dart';
import 'package:warding/screens/home/component/home_content_section.dart';
import 'package:warding/viewmodel/home/home_viewmodel.dart';

import 'home_test_harness.dart';

/// 콘텐츠(뉴스·쇼츠)와 커뮤니티(글·평점 한줄평) — spec "결정"의 기본 탭과
/// 섹션 나눔, "상태" 표의 쇼츠 빈 박스를 확인한다.
void main() {
  group('콘텐츠', () {
    testWidgets('기본 탭은 뉴스이고 평점 탭은 없다', (tester) async {
      setUpHomeApi();
      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeContentSection(viewModel: vm, scale: 1),
      );

      expect(vm.contentTab, HomeContentTab.news);
      expect(find.text('뉴스'), findsOneWidget);
      expect(find.text('쇼츠'), findsOneWidget);
      expect(find.text(MockNewsSource.articles.first.title), findsOneWidget);
      expect(find.textContaining('평점'), findsNothing);
    });

    testWidgets('뉴스가 비면(릴리즈 빈 소스) 뉴스 탭 없이 쇼츠가 보인다', (tester) async {
      final server = setUpHomeApi();
      server.shorts = [shortsJson('LCK 하이라이트', channel: 'LCK')];
      await pumpHomeSection(
        tester,
        news: const EmptyNewsSource(),
        section: (vm) => HomeContentSection(viewModel: vm, scale: 1),
      );

      expect(find.text('뉴스'), findsNothing);
      expect(find.text('쇼츠'), findsOneWidget);
      expect(find.text('LCK 하이라이트'), findsOneWidget);
    });

    testWidgets('쇼츠 "내 선수" 필터가 0건이면 점선 박스', (tester) async {
      final server = setUpHomeApi(loggedIn: true);
      server.subscriptions = [subscriptionJson('Faker', 'T1')];
      // 구독 선수 이름이 안 들어간 쇼츠만 있다.
      server.shorts = [shortsJson('젠지 하이라이트', channel: 'LCK')];
      await pumpHomeSection(
        tester,
        section: (vm) => HomeContentSection(viewModel: vm, scale: 1),
      );

      await tester.tap(find.text('쇼츠'));
      await tester.pump();
      // 전체 필터에서는 카드가 보인다.
      expect(find.text('젠지 하이라이트'), findsOneWidget);
      expect(find.byKey(HomeContentSection.shortsEmptyKey), findsNothing);

      await tester.tap(find.text('내 선수'));
      await tester.pump();
      final empty = find.byKey(HomeContentSection.shortsEmptyKey);
      expect(empty, findsOneWidget);
      expect(
        find.descendant(of: empty, matching: find.byType(DashedBorder)),
        findsOneWidget,
      );
      expect(find.text('조건에 맞는 쇼츠가 아직 없어요'), findsOneWidget);
      expect(find.text('젠지 하이라이트'), findsNothing);
    });
  });

  group('커뮤니티', () {
    testWidgets('기본 탭은 최신순이고 평점 한줄평 탭이 여기 있다', (tester) async {
      setUpHomeApi();
      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeCommunitySection(viewModel: vm, scale: 1),
      );

      expect(vm.communitySort, HomeCommunitySort.latest);
      expect(find.text('글-latest'), findsOneWidget);
      expect(find.text('평점 한줄평'), findsOneWidget);

      await tester.tap(find.text('평점 한줄평'));
      await tester.pump();
      expect(find.text(MockReviewSource.reviews.first.comment), findsOneWidget);
    });

    testWidgets('한줄평이 비면(릴리즈 빈 소스) 평점 한줄평 탭이 없다', (tester) async {
      setUpHomeApi();
      await pumpHomeSection(
        tester,
        reviews: const EmptyReviewSource(),
        section: (vm) => HomeCommunitySection(viewModel: vm, scale: 1),
      );

      expect(find.text('최신순'), findsOneWidget);
      expect(find.text('인기순'), findsOneWidget);
      expect(find.text('평점 한줄평'), findsNothing);
      expect(find.text('글-latest'), findsOneWidget);
    });

    testWidgets('"커뮤니티 전체"는 콜백으로 넘긴다(탭 전환은 홈 화면 몫)', (tester) async {
      setUpHomeApi();
      var opened = 0;
      await pumpHomeSection(
        tester,
        section: (vm) => HomeCommunitySection(
          viewModel: vm,
          scale: 1,
          onSeeAllCommunity: () => opened++,
        ),
      );

      await tester.tap(find.text('커뮤니티 전체'));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('탭 순서는 선택과 무관하게 최신순 · 인기순 · 평점 한줄평', (tester) async {
      setUpHomeApi();
      await pumpHomeSection(
        tester,
        section: (vm) => HomeCommunitySection(viewModel: vm, scale: 1),
      );

      await tester.tap(find.text('평점 한줄평'));
      await tester.pump();
      final xs = [
        '최신순',
        '인기순',
        '평점 한줄평',
      ].map((t) => tester.getTopLeft(find.text(t)).dx).toList();
      expect(xs[0] < xs[1] && xs[1] < xs[2], isTrue, reason: '$xs');
    });
  });
}
