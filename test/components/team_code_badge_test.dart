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

  testWidgets('imageUrl 이 없으면 팀 코드로 찾고, 찾기 전에는 팀 코드 텍스트', (tester) async {
    final dir = TeamLogoDirectory(
      load: () async => const [TeamLogoEntry('T1', 'https://img/t1.png')],
    );

    await tester.pumpWidget(
      _wrap(TeamCodeBadge(teamCode: 'T1', size: 20, directory: dir)),
    );
    expect(find.text('T1'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);

    await tester.pump();
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('로고가 없는 팀은 팀 코드 텍스트로 대신한다', (tester) async {
    final dir = TeamLogoDirectory(
      load: () async => const [TeamLogoEntry('T1', 'https://img/t1.png')],
    );

    await tester.pumpWidget(
      _wrap(TeamCodeBadge(teamCode: 'LoL', size: 20, directory: dir)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('LoL'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}
