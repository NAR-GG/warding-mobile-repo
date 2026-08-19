import 'package:flutter_test/flutter_test.dart';
import 'package:warding/util/champion_image.dart';

/// 챔피언 이미지 URL 해석.
///
/// 서버는 픽·밴 이미지를 CommunityDragon 스플래시 아트(`splash-art/centered`,
/// 약 99KB)로 내려주는데, 앱에서 그 이미지가 놓이는 자리는 60×101 픽 카드와
/// 36.4 정사각 밴 칸이다. 전신 일러스트는 그 크기에서 얼굴이 너무 작고,
/// 확대해서 키우려 해도 인물 위치가 챔피언마다 달라 일부는 얼굴이 잘린다 —
/// 얼굴 중앙 구도가 보장된 `square`(약 25KB) 로 바꿔 받는다.
void main() {
  group('resolve — CommunityDragon 스플래시를 얼굴 중앙 변형으로', () {
    test('splash-art/centered 를 square 로 바꾼다', () {
      expect(
        ChampionImage.resolve(
          'https://cdn.communitydragon.org/latest/champion/2/splash-art/centered',
          'Olaf',
        ),
        'https://cdn.communitydragon.org/latest/champion/2/square',
      );
    });

    test('centered 가 없는 splash-art 도 square 로 바꾼다', () {
      expect(
        ChampionImage.resolve(
          'https://cdn.communitydragon.org/latest/champion/64/splash-art',
          'LeeSin',
        ),
        'https://cdn.communitydragon.org/latest/champion/64/square',
      );
    });

    test('이미 square 면 그대로 둔다', () {
      const url = 'https://cdn.communitydragon.org/latest/champion/2/square';

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
