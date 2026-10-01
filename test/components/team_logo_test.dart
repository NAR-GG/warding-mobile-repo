import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/team_logo.dart';
import 'package:warding/repository/team/team_logo_directory.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('imageUrl 이 있으면 원 없이 로고만 그린다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TeamLogo(
          teamCode: 'GX',
          size: 24,
          imageUrl: 'https://img/gx.png',
          directory: TeamLogoDirectory(load: () async => const []),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
    final box = tester.getSize(find.byType(TeamLogo));
    expect(box, const Size(24, 24));
  });

  testWidgets('로고가 없으면 팀 코드를 둥근 네모에 적는다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TeamLogo(
          teamCode: 'TBD',
          size: 24,
          directory: TeamLogoDirectory(load: () async => const []),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TBD'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('imageUrl 이 없으면 팀 코드로 사전에서 찾는다', (tester) async {
    final dir = TeamLogoDirectory(
      load: () async => const [TeamLogoEntry('T1', 'https://img/t1.png')],
    );

    await tester.pumpWidget(
      _wrap(TeamLogo(teamCode: 'T1', size: 24, directory: dir)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });
}
