import 'package:flutter_test/flutter_test.dart';
import 'package:warding/config/api_config.dart';
import 'package:warding/util/app_image.dart';

/// 원격 이미지 URL 정규화.
///
/// 선수 이미지는 백엔드가 `http://static.lolesports.com/...` 로 내려준다
/// (팀 로고는 https 다). iOS 는 ATS 로 평문 HTTP 를 막고, 지금은 호스트가
/// 301 로 https 에 넘겨줘서 겨우 살아 있는데 — 그 리다이렉트가 이미지 한
/// 장마다 왕복 한 번이라 목록에서는 그만큼 그대로 지연이 된다.
void main() {
  group('resolveImageUrl', () {
    test('상대경로에는 API 호스트를 붙인다', () {
      expect(
        resolveImageUrl('/images/players/Zeus.webp'),
        '${ApiConfig.host}/images/players/Zeus.webp',
      );
    });

    test('평문 http 는 https 로 올린다 — 리다이렉트 왕복을 없앤다', () {
      expect(
        resolveImageUrl(
          'http://static.lolesports.com/players/1769091238011_Casting.png',
        ),
        'https://static.lolesports.com/players/1769091238011_Casting.png',
      );
    });

    test('이미 https 면 그대로 둔다', () {
      const url = 'https://static.lolesports.com/teams/1726801573959_T1.png';

      expect(resolveImageUrl(url), url);
    });

    test('호스트 뒤 경로는 건드리지 않는다', () {
      // 경로에 http 가 들어가도 앞부분만 바꾼다.
      expect(
        resolveImageUrl('http://cdn.example.com/a/http-logo.png'),
        'https://cdn.example.com/a/http-logo.png',
      );
    });

    test('null·빈 문자열은 그대로 돌려준다', () {
      expect(resolveImageUrl(null), isNull);
      expect(resolveImageUrl(''), '');
    });
  });

  group('championSplashUrl', () {
    test('영문 키로 스플래시 URL 을 만든다', () {
      expect(
        championSplashUrl('Vayne'),
        'https://ddragon.leagueoflegends.com/cdn/img/champion/splash/Vayne_0.jpg',
      );
    });

    test('이름이 비면 null', () {
      expect(championSplashUrl(''), isNull);
    });
  });
}
