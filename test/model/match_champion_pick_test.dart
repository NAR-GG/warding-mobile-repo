import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/match_champion_pick.dart';

void main() {
  group('MatchChampionPick.fromJson', () {
    test('frameTimestampUtc 를 파싱한다', () {
      final pick = MatchChampionPick.fromJson({
        'gameId': '115570814727903842',
        'frameTimestampUtc': '2026-07-31T12:11:23.157',
        'blueTeam': <String, dynamic>{'teamName': 'A'},
        'redTeam': <String, dynamic>{'teamName': 'B'},
        'objectives': <String, dynamic>{},
      });

      expect(pick.frameTimestampUtc, '2026-07-31T12:11:23.157');
    });

    test('frameTimestampUtc 가 없으면 null', () {
      final pick = MatchChampionPick.fromJson({
        'gameId': 'g1',
        'blueTeam': <String, dynamic>{'teamName': 'A'},
        'redTeam': <String, dynamic>{'teamName': 'B'},
        'objectives': <String, dynamic>{},
      });

      expect(pick.frameTimestampUtc, isNull);
    });
  });

  group('ChampionPick.fromJson — 아이템', () {
    test(
      'coreItemImageUrls·questItemImageUrl·trinketItemImageUrl·consumableItemImageUrls 를 파싱한다',
      () {
        final pick = ChampionPick.fromJson({
          'position': 'mid',
          'championName': 'Cassiopeia',
          'playerName': 'GAM Gloryy',
          'coreItemImageUrls': ['…/6657.png', '…/3111.png', '…/6653.png'],
          'questItemImageUrl': null,
          'trinketItemImageUrl': '…/3363.png',
          'consumableItemImageUrls': ['…/2055.png'],
        });

        expect(pick.coreItemImageUrls, [
          '…/6657.png',
          '…/3111.png',
          '…/6653.png',
        ]);
        expect(pick.questItemImageUrl, isNull);
        expect(pick.trinketItemImageUrl, '…/3363.png');
        expect(pick.consumableItemImageUrls, ['…/2055.png']);
      },
    );

    test('아이템 필드가 없으면 빈 리스트·null 로 폴백한다', () {
      final pick = ChampionPick.fromJson({
        'position': 'mid',
        'championName': 'Cassiopeia',
        'playerName': 'GAM Gloryy',
      });

      expect(pick.coreItemImageUrls, isEmpty);
      expect(pick.questItemImageUrl, isNull);
      expect(pick.trinketItemImageUrl, isNull);
      expect(pick.consumableItemImageUrls, isEmpty);
    });
  });

  group('ChampionPick.fromJson — runes', () {
    test('runes 가 null 이면 파싱 결과도 null', () {
      final pick = ChampionPick.fromJson({
        'position': 'mid',
        'championName': 'Cassiopeia',
        'playerName': 'GAM Gloryy',
        'runes': null,
      });

      expect(pick.runes, isNull);
    });

    test('runes 가 없으면(키 자체 없음) null', () {
      final pick = ChampionPick.fromJson({
        'position': 'mid',
        'championName': 'Cassiopeia',
        'playerName': 'GAM Gloryy',
      });

      expect(pick.runes, isNull);
    });

    test('primary·sub·shards 전체를 파싱한다', () {
      final pick = ChampionPick.fromJson({
        'position': 'mid',
        'championName': 'Cassiopeia',
        'playerName': 'GAM Gloryy',
        'runes': {
          'primary': {
            'styleName': '마법',
            'styleIconUrl': '…/7202_Sorcery.png',
            'runes': [
              {
                'name': '죽음불꽃 손길',
                'iconUrl': '…/DEATHFIRE_TOUCH_KEYSTONE.png',
                'description': '챔피언에게 스킬로 피해를 입히면 지속적으로 화상 적용',
              },
              {
                'name': '마나순환 팔찌',
                'iconUrl': '…/ManaflowBand.png',
                'description': '적 챔피언에게 스킬을 적중하면…',
              },
            ],
          },
          'sub': {
            'styleName': '정밀',
            'styleIconUrl': '…/7201_Precision.png',
            'runes': [
              {
                'name': '전설: 가속',
                'iconUrl': '…/LegendHaste.png',
                'description': '적 챔피언 처치 관여 시…',
              },
            ],
          },
          'shards': [
            {
              'name': '적응형 능력치',
              'iconUrl': '…/adaptiveforce.png',
              'label': '+9',
            },
            {'name': '이동 속도', 'iconUrl': '…/movementspeed.png', 'label': '+2%'},
          ],
        },
      });

      final runes = pick.runes;
      expect(runes, isNotNull);
      expect(runes!.primary.styleName, '마법');
      expect(runes.primary.styleIconUrl, '…/7202_Sorcery.png');
      expect(runes.primary.runes, hasLength(2));
      expect(runes.primary.runes.first.name, '죽음불꽃 손길');
      expect(
        runes.primary.runes.first.description,
        '챔피언에게 스킬로 피해를 입히면 지속적으로 화상 적용',
      );
      expect(runes.sub.styleName, '정밀');
      expect(runes.sub.runes, hasLength(1));
      expect(runes.shards, hasLength(2));
      expect(runes.shards.first.name, '적응형 능력치');
      expect(runes.shards.first.label, '+9');
    });

    test('shard label 이 null 이어도 파싱된다(옛 파편)', () {
      final pick = ChampionPick.fromJson({
        'position': 'mid',
        'championName': 'Cassiopeia',
        'playerName': 'GAM Gloryy',
        'runes': {
          'primary': {'styleName': '마법', 'styleIconUrl': null, 'runes': []},
          'sub': {'styleName': '정밀', 'styleIconUrl': null, 'runes': []},
          'shards': [
            {'name': '체력', 'iconUrl': '…/health.png', 'label': null},
          ],
        },
      });

      expect(pick.runes!.shards.first.label, isNull);
    });
  });
}
