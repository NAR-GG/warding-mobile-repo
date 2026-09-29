import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/dashed_border.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/home/component/home_community_section.dart';
import 'package:warding/screens/home/component/home_content_section.dart';
import 'package:warding/viewmodel/home/home_viewmodel.dart';

import 'home_test_harness.dart';

/// [HomeSectionHeader] 의 제목+부제는 RichText(대문자, Text.rich 아님)라
/// find.text()/find.textContaining() 이 못 찾는다 — 평문으로 변환해 비교한다.
Finder _richTextContaining(String text) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(text),
);

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
    testWidgets('정렬 칩 없이 헤더 부제로 현재 정렬만 보여준다 — 기본은 평점 한줄평', (tester) async {
      setUpHomeApi();
      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeCommunitySection(viewModel: vm, scale: 1),
      );

      expect(vm.communitySort, HomeCommunitySort.review);
      expect(find.text(MockReviewSource.reviews.first.comment), findsOneWidget);
      expect(_richTextContaining('평점 한줄평'), findsOneWidget);
      expect(_richTextContaining('인기순'), findsNothing);
      // 부제 텍스트일 뿐 탭이 아니다 — 눌러도 정렬이 안 바뀐다.
      await tester.tap(_richTextContaining('평점 한줄평'));
      await tester.pump();
      expect(vm.communitySort, HomeCommunitySort.review);
    });

    testWidgets('한줄평이 비면(빈 소스) 최신순으로 자동 전환되고 글이 보인다', (tester) async {
      setUpHomeApi();
      final vm = await pumpHomeSection(
        tester,
        reviews: const EmptyReviewSource(),
        section: (vm) => HomeCommunitySection(viewModel: vm, scale: 1),
      );

      expect(vm.communitySort, HomeCommunitySort.latest);
      expect(_richTextContaining('최신순'), findsOneWidget);
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
  });
}
