import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/profile_avatar.dart';

/// 이 위젯의 존재 이유가 "URL 이 없을 때 기본 이미지" 하나라서 거기만 본다.
void main() {
  Future<void> pump(WidgetTester tester, String? url) => tester.pumpWidget(
    MaterialApp(home: ProfileAvatar(url: url, size: 40)),
  );

  testWidgets('URL 이 없으면 기본 프로필 이미지로 떨어진다', (tester) async {
    for (final url in [null, '']) {
      await pump(tester, url);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/images/person.png');
    }
  });
}
