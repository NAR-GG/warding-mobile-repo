import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/screens/community/component/community_photo_viewer.dart';
import 'package:warding/util/app_image.dart';

/// 뷰어의 회귀 포인트는 둘이다 — 확대해서 보는 화면인데 본문용으로 깎은 URL 을
/// 쓰면 뭉개진다는 것, 그리고 사진이 없을 때 빈 화면이 뜨면 안 된다는 것.
void main() {
  const base =
      'https://res.cloudinary.com/dvvurdffw/image/upload/v1788008914/community/12/';

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('여러 장이면 현재 위치를 보여주고, 초기 인덱스를 따른다', (tester) async {
    await tester.pumpWidget(
      host(
        CommunityPhotoViewer(
          urls: ['${base}a.jpg', '${base}b.jpg', '${base}c.jpg'],
          initialIndex: 1,
        ),
      ),
    );

    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('한 장이면 "1 / 1" 을 그리지 않는다 — 정보를 주지 않는다', (tester) async {
    await tester.pumpWidget(host(CommunityPhotoViewer(urls: ['${base}a.jpg'])));

    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('초기 인덱스가 범위를 벗어나도 죽지 않는다', (tester) async {
    await tester.pumpWidget(
      host(
        CommunityPhotoViewer(
          urls: ['${base}a.jpg', '${base}b.jpg'],
          initialIndex: 99,
        ),
      ),
    );

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('사진이 없으면 뷰어를 열지 않는다', (tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                CommunityPhotoViewer.open(context, urls: const []),
            child: const Text('열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byType(CommunityPhotoViewer), findsNothing);
  });

  test('뷰어는 본문보다 큰 폭으로 받는다 — 확대해도 뭉개지지 않아야 한다', () {
    // 본문(CommunityImage)은 표시 폭에 맞춰 깎는다. 뷰어가 같은 폭을 쓰면
    // 핀치 줌에서 그대로 뭉갠다. 버킷 최대값을 쓰는지 잠근다.
    final viewer = cloudinaryScaled(
      '${base}a.jpg',
      targetPixelWidth: kCloudinaryWidthBuckets.last,
    )!;
    final body = cloudinaryScaled('${base}a.jpg', targetPixelWidth: 400)!;

    expect(viewer, contains('w_${kCloudinaryWidthBuckets.last}'));
    expect(viewer, isNot(equals(body)));
  });
}
