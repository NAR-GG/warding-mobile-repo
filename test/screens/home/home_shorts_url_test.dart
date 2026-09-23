import 'package:flutter_test/flutter_test.dart';
import 'package:warding/screens/home/component/home_content_section.dart';

/// 쇼츠 카드는 https 주소만 외부로 연다 — 서버가 준 임의 스킴(javascript:,
/// intent:, file: 등)이나 깨진 주소는 열지 않는다.
void main() {
  test('https 주소만 통과한다', () {
    expect(
      shortsLaunchUri('https://www.youtube.com/shorts/xyz'),
      Uri.parse('https://www.youtube.com/shorts/xyz'),
    );
    expect(shortsLaunchUri('HTTPS://youtu.be/abc')?.host, 'youtu.be');
  });

  test('https 가 아니거나 비었거나 깨진 주소는 null', () {
    expect(shortsLaunchUri(''), isNull);
    expect(shortsLaunchUri('http://youtu.be/abc'), isNull);
    expect(shortsLaunchUri('javascript:alert(1)'), isNull);
    expect(shortsLaunchUri('intent://x#Intent;end'), isNull);
    expect(shortsLaunchUri('file:///etc/passwd'), isNull);
    expect(shortsLaunchUri('youtube.com/shorts/xyz'), isNull);
    expect(shortsLaunchUri('https://'), isNull);
    expect(shortsLaunchUri('http://[::1'), isNull);
  });
}
