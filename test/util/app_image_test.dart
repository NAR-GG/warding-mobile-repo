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

  group('cloudinaryScaled', () {
    const original =
        'https://res.cloudinary.com/dvvurdffw/image/upload/v1788008914/community/12/abc.jpg';

    test('업로드 URL 에 변환을 끼운다', () {
      expect(
        cloudinaryScaled(original, targetPixelWidth: 780),
        'https://res.cloudinary.com/dvvurdffw/image/upload/'
        'f_webp,q_auto,w_800,c_limit/v1788008914/community/12/abc.jpg',
      );
    });

    test('폭은 버킷으로 반올림된다 — 파생 에셋이 기기마다 늘어나면 변환 쿼터를 태운다', () {
      String widthOf(int px) =>
          RegExp(r'w_(\d+)').firstMatch(cloudinaryScaled(original, targetPixelWidth: px)!)!.group(1)!;

      expect(widthOf(120), '200');
      expect(widthOf(390), '400');
      expect(widthOf(401), '800');
      expect(widthOf(9999), '1200'); // 버킷을 넘으면 최대치로 자른다
    });

    test('이미 변환이 붙은 URL 은 두 번 건드리지 않는다', () {
      final once = cloudinaryScaled(original, targetPixelWidth: 400)!;
      expect(cloudinaryScaled(once, targetPixelWidth: 800), once);
    });

    test('Cloudinary 업로드 URL 이 아니면 그대로 둔다', () {
      // 서버가 이미 변환을 붙여주는 fetch URL (팀 로고 등)
      const fetched =
          'https://res.cloudinary.com/dvvurdffw/image/fetch/f_webp,q_auto,w_200,c_limit/https://static.lolesports.com/x.png';
      expect(cloudinaryScaled(fetched, targetPixelWidth: 400), fetched);

      const other = 'https://example.com/a.jpg';
      expect(cloudinaryScaled(other, targetPixelWidth: 400), other);
    });

    test('null·빈 문자열은 그대로', () {
      expect(cloudinaryScaled(null, targetPixelWidth: 400), isNull);
      expect(cloudinaryScaled('', targetPixelWidth: 400), '');
    });
  });
}
