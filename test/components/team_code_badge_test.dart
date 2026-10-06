import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/team_code_badge.dart';
import 'package:warding/repository/team/team_logo_directory.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('imageUrl 이 있으면 로고를 그린다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TeamCodeBadge(
          teamCode: 'T1',
          size: 20,
          imageUrl: 'https://img/t1.png',
          directory: TeamLogoDirectory(load: () async => const []),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('imageUrl 이 없으면 팀 코드로 찾고, 찾기 전에는 빈 원', (tester) async {
    final dir = TeamLogoDirectory(
      load: () async => const [TeamLogoEntry('T1', 'https://img/t1.png')],
    );

    await tester.pumpWidget(
      _wrap(TeamCodeBadge(teamCode: 'T1', size: 20, directory: dir)),
    );
    expect(find.text('T1'), findsNothing);
    expect(find.byType(CachedNetworkImage), findsNothing);

    await tester.pump();
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('로고가 없는 팀은 빈 원으로 대신한다(텍스트 없음)', (tester) async {
    final dir = TeamLogoDirectory(
      load: () async => const [TeamLogoEntry('T1', 'https://img/t1.png')],
    );

    await tester.pumpWidget(
      _wrap(TeamCodeBadge(teamCode: 'LoL', size: 20, directory: dir)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('LoL'), findsNothing);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  // ASIAN_GAMES 국가대표처럼 사전(온보딩 팀 목록)에 없는 코드를 위한 경로.
  testWidgets('fallbackImageUrl 은 사전에 코드가 없을 때만 쓴다', (tester) async {
    final dir = TeamLogoDirectory(
      load: () async => const [TeamLogoEntry('T1', 'https://img/t1.png')],
    );

    await tester.pumpWidget(
      _wrap(
        TeamCodeBadge(
          teamCode: 'KOR',
          size: 20,
          fallbackImageUrl: 'https://img/flags/kor.png',
          directory: dir,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://img/flags/kor.png');
  });

  testWidgets('사전에 코드가 있으면 fallbackImageUrl 보다 사전이 이긴다', (tester) async {
    final dir = TeamLogoDirectory(
      load: () async => const [TeamLogoEntry('T1', 'https://img/t1.png')],
    );

    await tester.pumpWidget(
      _wrap(
        TeamCodeBadge(
          teamCode: 'T1',
          size: 20,
          fallbackImageUrl: 'https://img/other-t1.png',
          directory: dir,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://img/t1.png');
  });

  // 사전이 비기 전(로드 중)에도 폴백이 보여야 한다 — 국기는 사전과 무관하다.
  testWidgets('사전 로드 전에도 fallbackImageUrl 로 먼저 그린다', (tester) async {
    final dir = TeamLogoDirectory(load: () async => const []);

    await tester.pumpWidget(
      _wrap(
        TeamCodeBadge(
          teamCode: 'KOR',
          size: 20,
          fallbackImageUrl: 'https://img/flags/kor.png',
          directory: dir,
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });
}
