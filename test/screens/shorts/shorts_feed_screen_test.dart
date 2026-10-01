import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/story_video.dart';
import 'package:warding/repository/shorts/shorts_repository.dart';
import 'package:warding/screens/shorts/shorts_feed_screen.dart';
import 'package:warding/viewmodel/shorts/shorts_feed_viewmodel.dart';

StoryVideo _v(int id) => StoryVideo(
  videoId: id,
  youtubeVideoId: 'yt$id',
  title: '영상 $id',
  videoUrl: 'https://www.youtube.com/shorts/yt$id',
  thumbnailUrl: '',
  channelName: '채널$id',
  viewCount: 100 * id,
);

class _EmptyRepo implements ShortsRepository {
  @override
  Future<ShortsPage> fetchShortsPage({
    String sort = 'latest',
    int size = 20,
    int page = 0,
    String? teamCode,
  }) async => const ShortsPage(items: [], isLast: true);

  @override
  Future<List<StoryVideo>> fetchShorts({
    String sort = 'latest',
    int size = 20,
    String? teamCode,
  }) async => const [];
}

/// WebView 없이 영상 ID 만 그리는 가짜 임베드. 만들어진 ID 를 기록한다.
final List<String> _built = [];

Widget _fakeEmbed(
  BuildContext context, {
  required String videoId,
  required bool active,
  required VoidCallback onPlaying,
  required VoidCallback onEnded,
  required void Function(Object code) onError,
}) {
  _built.add(videoId);
  return Center(child: Text('embed:$videoId:${active ? 'on' : 'off'}'));
}

Future<void> _pump(
  WidgetTester tester, {
  required List<StoryVideo> videos,
  int startIndex = 0,
  Future<String?> Function()? team,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: ShortsFeedScreen(
        initialVideos: videos,
        startIndex: startIndex,
        initialPageSize: 10,
        resolveTeamCode: team ?? () async => null,
        repository: _EmptyRepo(),
        embedBuilder: _fakeEmbed,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(_built.clear);

  testWidgets('탭한 영상부터 시작하고 채널·제목·조회수·유튜브 링크를 아래에 보인다', (tester) async {
    await _pump(
      tester,
      videos: [for (var i = 1; i <= 5; i++) _v(i)],
      startIndex: 2,
    );

    expect(find.text('embed:yt3:on'), findsOneWidget);
    expect(find.text('채널3'), findsOneWidget);
    expect(find.text('영상 3'), findsOneWidget);
    expect(find.text('조회 300'), findsOneWidget);
    expect(find.text('유튜브에서 보기'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('응원 팀'), findsOneWidget);
  });

  testWidgets('플레이어는 현재 ±1 페이지만 만든다(WebView 최대 3개)', (tester) async {
    await _pump(
      tester,
      videos: [for (var i = 1; i <= 8; i++) _v(i)],
      startIndex: 3,
    );

    // 현재(yt4)와 이웃(yt3·yt5)만 — 그 밖의 영상은 WebView 를 만들지 않는다.
    expect(_built.toSet().difference({'yt3', 'yt4', 'yt5'}), isEmpty);
    expect(find.text('embed:yt4:on'), findsOneWidget);
  });

  testWidgets('마지막 페이지를 지나면 "다 봤어요"가 나온다', (tester) async {
    // 끝 근처에서 열면 미리 이어 받고, 저장소가 빈 마지막 페이지를 주므로 끝 상태가 된다.
    await _pump(tester, videos: [_v(1), _v(2)], startIndex: 1);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.byKey(ShortsFeedScreen.endKey), findsOneWidget);
    expect(find.text('다 봤어요'), findsOneWidget);
  });

  testWidgets('내 팀을 눌렀는데 응원팀이 없으면 설정 안내와 전체 보기', (tester) async {
    await _pump(tester, videos: [_v(1), _v(2)]);

    await tester.tap(find.text('응원 팀'));
    await tester.pumpAndSettle();

    expect(find.byKey(ShortsFeedScreen.emptyKey), findsOneWidget);
    expect(find.textContaining('응원팀을 설정하면'), findsOneWidget);

    // 전체로 돌아가면 응원팀 안내는 사라진다(가짜 저장소가 비어 있어 일반 빈 문구).
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('응원팀을 설정하면'), findsNothing);
    expect(find.text('조건에 맞는 쇼츠가 아직 없어요'), findsOneWidget);
  });

  test('필터 enum 은 전체·내 팀뿐이다', () {
    expect(ShortsFeedFilter.values, [
      ShortsFeedFilter.all,
      ShortsFeedFilter.team,
    ]);
  });
}
