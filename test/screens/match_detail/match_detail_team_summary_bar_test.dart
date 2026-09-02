import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/match_champion_pick.dart';
import 'package:warding/screens/match_detail/component/match_detail_team_summary_section.dart';
import 'package:warding/styles/app_colors.dart';

/// Team Summary 의 비율 막대바 — 전체 배경은 항상 narLine2(트랙), 그 위에
/// 비율이 더 높은 쪽만 둥근 알약 모양의 narBg 그라데이션 바가 얹힌다.
///
/// 리포트 이력:
/// 1) Row 기본 cross-axis loose 제약으로 막대 높이가 0 — 안 보임 (수정됨)
/// 2) Stack 이 non-positioned 자식(오버레이) 크기로 스스로 줄어들어 트랙까지
///    항상 절반폭으로 렌더 — 비율 무시 (수정됨, Row+Expanded 로 교체)
/// 3) 이번 요구사항: 전체 배경은 항상 narLine2 로 꽉 채우고, 그 위에 비율만큼만
///    둥근 그라데이션 바를 얹는 디자인으로 다시 변경.
void main() {
  testWidgets('트랙은 항상 전체 폭, 그라데이션은 비율만큼만 둥글게 렌더된다', (tester) async {
    // blueGold(51100) < redGold(58200) → 오른쪽(레드)이 더 높은 비율(53.3%).
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MatchDetailTeamSummarySection(
            blueSummary: TeamStatsSummary(totalGoldEarned: 51100),
            redSummary: TeamStatsSummary(totalGoldEarned: 58200),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tracks = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          (w.decoration as BoxDecoration).color == AppColors.narLine2,
    );
    final gradients = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          (w.decoration as BoxDecoration).gradient == AppColors.narBg,
    );

    expect(tracks, findsNWidgets(3));
    expect(gradients, findsNWidgets(3));

    // 둘 다 알약 모양(완전히 둥근) 이어야 한다.
    for (final finder in [tracks, gradients]) {
      for (final el in finder.evaluate()) {
        final decoration = (el.widget as DecoratedBox).decoration as BoxDecoration;
        expect(
          decoration.borderRadius,
          BorderRadius.circular(999),
          reason: '트랙/그라데이션 바가 둥근 알약 모양이 아니다',
        );
      }
    }

    // Gold 줄: 트랙은 항상 전체 폭, 그라데이션(비율 53.3%)은 트랙보다 좁아야 한다.
    final trackWidth = tester.getSize(tracks.first).width;
    final gradientWidth = tester.getSize(gradients.first).width;
    expect(gradientWidth, greaterThan(0));
    expect(
      gradientWidth,
      lessThan(trackWidth),
      reason: '그라데이션이 트랙 전체를 덮음 — 비율이 반영 안 됨',
    );

    // 그라데이션이 더 높은 쪽(오른쪽=레드)에 붙어 있어야 한다.
    final trackTopLeft = tester.getTopLeft(tracks.first);
    final trackTopRight = tester.getTopRight(tracks.first);
    final gradientTopRight = tester.getTopRight(gradients.first);
    expect(
      (gradientTopRight.dx - trackTopRight.dx).abs(),
      lessThan(1),
      reason: '그라데이션 오른쪽 끝이 트랙 오른쪽 끝에 붙어있지 않다(반대쪽에 있는 듯)',
    );
    expect(trackTopLeft.dx, lessThan(gradientTopRight.dx - gradientWidth + 1));

    expect(tester.takeException(), isNull);
  });
}
