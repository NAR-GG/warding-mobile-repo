import 'package:flutter_test/flutter_test.dart';

import 'package:warding/core/ui/webview/external_link.dart';

/// 외부 링크 판정.
///
/// **왜 테스트가 필요한가.** 규칙이 틀려도 빌드는 통과하고, 잘못되면 증상이
/// 둘 중 하나다 — 외부 사이트가 웹뷰 안에 열려 **돌아올 길이 없거나**(갇힘),
/// 웹 화면 이동이 바깥 브라우저로 튄다. 둘 다 기기에서 눌러 봐야 드러난다.
void main() {
  const prod = 'https://m.nar.kr';
  const local = 'http://localhost:3100';

  group('우리 웹이면 안에서 연다', () {
    test('같은 호스트의 다른 경로', () {
      expect(
        shouldOpenInWebView('https://m.nar.kr/community/post/1', webHost: prod),
        isTrue,
      );
    });

    test('로컬 개발 호스트', () {
      expect(
        shouldOpenInWebView('http://localhost:3100/notice', webHost: local),
        isTrue,
      );
    });

    test('상대 경로', () {
      expect(shouldOpenInWebView('/community', webHost: prod), isTrue);
    });

    test('쿼리·프래그먼트가 붙어도 같다', () {
      expect(
        shouldOpenInWebView('https://m.nar.kr/notice?page=2#top', webHost: prod),
        isTrue,
      );
    });
  });

  group('외부면 바깥으로 보낸다', () {
    test('구글폼 — 광고 안내의 신청 버튼이 이 경로다', () {
      expect(
        shouldOpenInWebView(
          'https://docs.google.com/forms/d/e/abc/viewform',
          webHost: prod,
        ),
        isFalse,
      );
    });

    test('http·https 가 아닌 스킴', () {
      expect(shouldOpenInWebView('mailto:a@b.com', webHost: prod), isFalse);
      expect(shouldOpenInWebView('tel:01012345678', webHost: prod), isFalse);
    });

    test('같은 호스트라도 포트가 다르면 외부다', () {
      // 로컬에서 다른 포트의 서버는 우리 웹이 아니다.
      expect(
        shouldOpenInWebView('http://localhost:9999/', webHost: local),
        isFalse,
      );
    });

    test('서브도메인이 달라도 외부다', () {
      expect(
        shouldOpenInWebView('https://api.nar.kr/docs', webHost: prod),
        isFalse,
      );
    });
  });

  test('운영 호스트에서 로컬 주소는 외부다', () {
    // 운영 빌드가 개발 주소를 웹뷰 안에서 열 이유가 없다.
    expect(
      shouldOpenInWebView('http://localhost:3100/notice', webHost: prod),
      isFalse,
    );
  });
}
