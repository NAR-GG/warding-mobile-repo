import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/dashed_border.dart';
import 'package:warding/model/home_models.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/home/component/home_community_section.dart';
import 'package:warding/screens/home/component/home_content_section.dart';
import 'package:warding/screens/home/component/home_review_section.dart';
import 'package:warding/viewmodel/home/home_viewmodel.dart';

import 'home_test_harness.dart';

/// [HomeSectionHeader] 의 제목+부제는 RichText(대문자, Text.rich 아님)라
/// find.text()/find.textContaining() 이 못 찾는다 — 평문으로 변환해 비교한다.
Finder _richTextContaining(String text) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(text),
);

/// 콘텐츠(뉴스·쇼츠), 커뮤니티(글), 평점(한줄평) — spec "결정"의 기본 탭과
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

    testWidgets('쇼츠 "내 팀" 필터는 응원팀이 없으면 설정 안내와 전체 보기', (tester) async {
      final server = setUpHomeApi();
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
      expect(find.text('내 선수'), findsNothing);

      await tester.tap(find.text('응원 팀'));
      await tester.pumpAndSettle();
      final empty = find.byKey(HomeContentSection.shortsEmptyKey);
      expect(empty, findsOneWidget);
      expect(
        find.descendant(of: empty, matching: find.byType(DashedBorder)),
        findsOneWidget,
      );
      expect(find.textContaining('응원팀을 설정하면'), findsOneWidget);
      expect(find.text('젠지 하이라이트'), findsNothing);

      await tester.tap(find.text('전체 보기'));
      await tester.pumpAndSettle();
      expect(find.text('젠지 하이라이트'), findsOneWidget);
    });
  });

  group('커뮤니티', () {
    testWidgets('정렬 칩 없이 헤더 부제로 현재 정렬만 보여준다 — 기본은 최신순', (tester) async {
      setUpHomeApi();
      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeCommunitySection(viewModel: vm, scale: 1),
      );

      expect(vm.communitySort, HomeCommunitySort.latest);
      expect(find.text('글-latest'), findsOneWidget);
      expect(_richTextContaining('최신순'), findsOneWidget);
      expect(_richTextContaining('인기순'), findsNothing);
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

  group('평점', () {
    testWidgets('ReviewSource 의 한줄평을 독립 섹션으로 보여준다', (tester) async {
      setUpHomeApi();
      await pumpHomeSection(
        tester,
        section: (vm) => HomeReviewSection(viewModel: vm, scale: 1),
      );

      expect(find.text(MockReviewSource.reviews.first.comment), findsOneWidget);
      expect(_richTextContaining('평점 한줄평'), findsOneWidget);
      expect(_richTextContaining('최신순'), findsOneWidget);
    });

    testWidgets('한줄평이 비면(빈 소스) 섹션 전체가 사라진다', (tester) async {
      setUpHomeApi();
      await pumpHomeSection(
        tester,
        reviews: const EmptyReviewSource(),
        section: (vm) => HomeReviewSection(viewModel: vm, scale: 1),
      );

      expect(_richTextContaining('평점 한줄평'), findsNothing);
      expect(find.byType(HomeReviewSection), findsOneWidget);
    });

    testWidgets('탭하면 onTapReview 로 그 한줄평을 넘긴다', (tester) async {
      setUpHomeApi();
      HomeReviewItem? tapped;
      await pumpHomeSection(
        tester,
        section: (vm) => HomeReviewSection(
          viewModel: vm,
          scale: 1,
          onTapReview: (review) => tapped = review,
        ),
      );

      await tester.tap(find.text(MockReviewSource.reviews.first.comment));
      await tester.pump();

      expect(tapped?.comment, MockReviewSource.reviews.first.comment);
    });
  });
}
