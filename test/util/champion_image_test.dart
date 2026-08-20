import 'package:flutter_test/flutter_test.dart';
import 'package:warding/util/champion_image.dart';

/// 챔피언 이미지 URL 해석.
///
/// 서버가 Cloudinary 를 거쳐 카드 비율(400×600)로 잘린 이미지를 내려주므로,
/// 앱은 URL 을 손대지 않고 그대로 쓴다. 예전에 하던 `/splash-art/centered`
/// → `/portrait` 치환은 Cloudinary 에 캐시되지 않은 변형을 만들어 오히려
/// 더 크고 느려서 걷어냈다.
void main() {
  group('resolve — 서버가 준 URL 을 그대로 쓴다', () {
    test('Cloudinary 변환이 붙은 URL 을 건드리지 않는다', () {
      const url =
          'https://res.cloudinary.com/dvvurdffw/image/fetch/'
          'f_webp,q_auto,w_400,h_600,c_fill,g_auto/'
          'https://cdn.communitydragon.org/latest/champion/64/splash-art/centered';

      expect(
        ChampionImage.resolve(url, 'LeeSin'),
        url,
        reason: '경로를 갈아끼우면 캐시 안 된 변형이 돼 더 크고 느려진다',
      );
    });

    test('CommunityDragon 원본 URL 도 그대로 둔다', () {
      const url =
          'https://cdn.communitydragon.org/latest/champion/2/splash-art/centered';

      expect(ChampionImage.resolve(url, 'Olaf'), url);
    });

    test('형태가 다른 URL 은 건드리지 않는다 — 서버가 바꿔도 안전하다', () {
      const url =
          'https://ddragon.leagueoflegends.com/cdn/16.13.1/img/champion/Olaf.png';

      expect(ChampionImage.resolve(url, 'Olaf'), url);
    });
  });

  group('resolve — 폴백', () {
    test('URL 이 없으면 챔피언명으로 Data Dragon 아이콘을 만든다', () {
      expect(
        ChampionImage.resolve(null, 'Rumble'),
        contains('/img/champion/Rumble.png'),
      );
    });

    test('빈 문자열도 폴백으로 간다', () {
      expect(
        ChampionImage.resolve('', 'Ahri'),
        contains('/img/champion/Ahri.png'),
      );
    });

    test('둘 다 없으면 null', () {
      expect(ChampionImage.resolve(null, null), isNull);
    });

    test('Data Dragon 키 예외를 따른다', () {
      expect(ChampionImage.resolve(null, "Kai'Sa"), contains('Kaisa.png'));
      expect(ChampionImage.resolve(null, 'Wukong'), contains('MonkeyKing.png'));
    });
  });
}
