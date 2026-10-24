import '../../model/player_detail.dart';
import 'player_repository.dart';

/// 선수 페이지 목업(`HOME_MOCKS=true` 일 때만 쓰인다). 실제 응답과 같은 JSON 을
/// fromJson 으로 통과시켜 파싱까지 함께 확인한다.
///
/// - 솔랭 중: 홈 목업의 라이브 선수(1 Faker, 2 Chovy, 101 Canyon, 102 ShowMaker).
///   나머지는 쉬는 중(⑧-2).
/// - 짝수 id 는 월즈 경기 기록이 아직 없는 상태("경기 기록 집계 중").
class MockPlayerSource implements PlayerSource {
  const MockPlayerSource();

  static const Map<int, (String, String, String)> _players = {
    1: ('Faker', 'T1', 'MID'),
    2: ('Chovy', 'GEN', 'MID'),
    11: ('Oner', 'T1', 'JUNGLE'),
    12: ('Ruler', 'HLE', 'BOTTOM'),
    101: ('Canyon', 'GEN', 'JUNGLE'),
    102: ('ShowMaker', 'DK', 'MID'),
    103: ('Kanavi', 'HLE', 'JUNGLE'),
    104: ('Doran', 'T1', 'TOP'),
  };
  static const Set<int> _liveIds = {1, 2, 101, 102};

  static String _iso(DateTime t) =>
      '${t.toUtc().add(const Duration(hours: 9)).toIso8601String().split('.').first}+09:00';

  @override
  Future<PlayerDetail> fetchDetail(int playerId) async {
    final (name, team, role) = _players[playerId] ?? ('Faker', 'T1', 'MID');
    final now = DateTime.now();
    final tomorrow22 = DateTime(now.year, now.month, now.day + 1, 22);
    return PlayerDetail.fromJson({
      'playerId': playerId,
      'playerName': name,
      'playerImageUrl': '',
      'role': role,
      'teamId': 1,
      'teamCode': team,
      'teamName': team,
      'teamImageUrl': '',
      // 홈 목업의 "구독 선수 솔랭 중"·끝난 경기 선수는 구독 중이어야 앞뒤가 맞는다.
      // 월즈 목업(101~)은 미구독(MockWorldsSoloSource 와 같다).
      'subscribed': playerId < 100,
      'startEnabled': true,
      'endEnabled': false,
      'live': _liveIds.contains(playerId)
          ? {
              'championName': '아리',
              'championImageUrl': '',
              'startedAt': _iso(now.subtract(const Duration(seconds: 1122))),
              'platform': 'NA1',
              'cheerTotal': 1284,
              'cheerMine': 0,
            }
          : null,
      'lastGame': {
        'championName': '아리',
        'championImageUrl': '',
        'win': true,
        'kills': 10,
        'deaths': 2,
        'assists': 5,
        'durationSeconds': 1920,
        'endedAt': _iso(now.subtract(const Duration(hours: 2))),
      },
      'nextMatch': {
        'matchId': '115660540726095015',
        'leagueName': 'WORLDS',
        'stage': '스위스 4라운드',
        'scheduledAt': _iso(tomorrow22),
        'bestOf': 1,
        'team': {
          'teamCode': team,
          'teamName': team,
          'teamImageUrl': '',
          'wins': 2,
          'losses': 1,
        },
        'opponent': {
          'teamCode': 'HLE',
          'teamName': 'HLE',
          'teamImageUrl': '',
          'wins': 2,
          'losses': 1,
        },
        'stakeLabel': '이기면 8강 진출',
      },
      'stats': {
        'subscriberCount': 12480,
        'cheers7d': 8214,
        'worldsRating': {'average': 4.6, 'count': 3912},
      },
    });
  }

  @override
  Future<PlayerWorlds> fetchWorlds(int playerId) async {
    final pending = playerId.isEven;
    Map<String, Object> stat(String key, num value, num avg, int rank) => {
      'key': key,
      'value': value,
      'positionAvg': avg,
      'positionRank': rank,
      'positionCount': 16,
    };
    Map<String, Object?> game(
      int id,
      bool win,
      String stage,
      String opp,
      String champ,
      List<int> kda,
      int cs,
      int damage,
      double? rating,
    ) => {
      'gameId': id,
      'playedAt': '2026-10-24T20:00:00+09:00',
      'win': win,
      'stage': stage,
      // 해외 팀은 코드·로고가 null 일 수 있다(prod 실측 LOS).
      'opponentTeamCode': opp == 'LOS' ? null : opp,
      'opponentTeamImageUrl': opp == 'LOS' ? null : '',
      'opponentTeamName': opp == 'LOS' ? 'LOS Grandes' : opp,
      'championName': champ,
      'championImageUrl': '',
      'kills': kda[0],
      'deaths': kda[1],
      'assists': kda[2],
      'cs': cs,
      'damage': damage,
      'rating': rating == null ? null : {'average': rating, 'count': 812},
    };
    Map<String, Object> champ(String name, int sw, int sl, int ww, int wl) => {
      'championName': name,
      'championImageUrl': '',
      'soloWins': sw,
      'soloLosses': sl,
      'worldsWins': ww,
      'worldsLosses': wl,
    };
    Map<String, Object> review(int r, String c, String opp, String stage) => {
      'ratingId': 9000 + r * 7 + c.length,
      'gameId': '117030752644841640',
      'participantId': 3,
      'teamSide': 'Blue',
      'rating': r,
      'comment': c,
      'opponentTeamCode': opp,
      'stage': stage,
      'createdAt': '2026-10-24T23:00:00+09:00',
    };
    return PlayerWorlds.fromJson({
      'record': {'games': 3, 'wins': 2, 'losses': 1},
      'stats': pending
          ? <Object>[]
          : [
              stat('KDA', 6.0, 4.1, 3),
              stat('KP', 71.0, 60.2, 1),
              stat('DPM', 612, 540, 4),
              stat('CSPM', 9.4, 8.9, 5),
              stat('GD15', 312, 40, 2),
              stat('VSPM', 1.6, 1.3, 2),
            ],
      'games': pending
          ? <Object>[]
          : [
              game(
                19901,
                true,
                '스위스 3라운드',
                'IG',
                '탈리야',
                [4, 1, 11],
                287,
                24000,
                4.6,
              ),
              game(
                19900,
                false,
                '스위스 2라운드',
                'G2',
                '사일러스',
                [2, 3, 5],
                301,
                18000,
                3.4,
              ),
              game(
                19899,
                true,
                '스위스 1라운드',
                'LOS',
                '아지르',
                [6, 0, 8],
                264,
                21000,
                null,
              ),
            ],
      'champions': [
        champ('오로라', 5, 2, 0, 0),
        champ('아리', 4, 2, 0, 0),
        champ('아지르', 4, 1, 1, 0),
        champ('탈리야', 3, 0, 1, 0),
        champ('사일러스', 1, 1, 0, 1),
        champ('오리아나', 1, 1, 0, 0),
        champ('요네', 0, 1, 0, 0),
        champ('갈리오', 1, 0, 0, 0),
      ],
      'rating': pending
          ? null
          : {
              'average': 4.6,
              'count': 3912,
              'distribution': [
                {'rating': 5, 'count': 2386, 'percentage': 61.0},
                {'rating': 4, 'count': 1056, 'percentage': 27.0},
                {'rating': 3, 'count': 313, 'percentage': 8.0},
                {'rating': 2, 'count': 117, 'percentage': 3.0},
                {'rating': 1, 'count': 40, 'percentage': 1.0},
              ],
              'reviews': [
                review(
                  5,
                  '탈리야 벽으로 바텀 다이브 끊은 장면이 오늘 경기 하이라이트',
                  'IG',
                  '스위스 3라운드',
                ),
                review(4, '라인전은 무난했는데 드래곤 한타 각을 먼저 본 게 컸다', 'IG', '스위스 3라운드'),
                review(5, '바론 앞 시야 싸움에서 먼저 와드 지운 게 승부처', 'IG', '스위스 3라운드'),
              ],
              'reviewCount': 412,
            },
    });
  }

  /// 한줄평 45개를 20개씩.
  @override
  Future<PlayerReviewPage> fetchWorldsReviews(
    int playerId, {
    required int page,
  }) async {
    const total = 45;
    const size = 20;
    final from = page * size;
    final to = (from + size).clamp(0, total);
    return PlayerReviewPage.fromJson({
      'reviews': [
        for (var i = from; i < to; i++)
          {
            'ratingId': 9100 + i,
            'gameId': '117030752644841640',
            'participantId': 3,
            'teamSide': i.isEven ? 'Blue' : 'Red',
            'rating': 5 - i % 3,
            'comment': '목업 한줄평 ${i + 1}번 — 한타 각이 좋았다',
            'opponentTeamCode': i.isEven ? 'IG' : 'G2',
            'stage': '스위스 ${3 - i % 3}라운드',
            'createdAt': '2026-10-24T23:00:00+09:00',
          },
      ],
      'totalCount': total,
      'hasNext': to < total,
    });
  }

  @override
  Future<PlayerSoloRank> fetchSoloRank(int playerId) async {
    final now = DateTime.now();
    final results = [
      true, true, false, true, true, false, true, true, false, true, //
      true, false, true, true, true, true, false, true, true, true,
    ];
    const champs = ['오로라', '탈리야', '아리', '오로라', '탈리야'];
    return PlayerSoloRank.fromJson({
      'accounts': [
        {
          'platform': 'NA1',
          'region': 'NA',
          'riotId': 'Hide in bush#NYKR',
          'tier': 'Challenger 1,204LP',
          'live': _liveIds.contains(playerId),
        },
        {
          'platform': 'KR',
          'region': 'KR',
          'riotId': 'Hide on bush#KR1',
          'tier': null,
          'live': false,
        },
      ],
      'recent': {
        'games': 20,
        'wins': 14,
        'losses': 6,
        'avgKills': 5.8,
        'avgDeaths': 2.6,
        'avgAssists': 7.6,
        'kda': 5.1,
        'gamesPerDay': 2.9,
        'avgDurationSeconds': 1740,
        'results': results,
      },
      'champions': [
        for (final (n, g, w, k) in [
          ('아리', 5, 4, 5.5),
          ('아지르', 4, 3, 7.1),
          ('오로라', 4, 3, 4.5),
          ('탈리야', 2, 2, 10.0),
          ('오리아나', 2, 1, 5.2),
        ])
          {
            'championName': n,
            'championImageUrl': '',
            'games': g,
            'wins': w,
            'kda': k,
          },
      ],
      'metPlayers': [
        {
          'playerId': 223,
          'playerName': 'Zeka',
          'playerImageUrl': '',
          'teamCode': 'HLE', // 목업 다음 경기 상대 — "다음 상대" 태그
          'teamImageUrl': '',
          'sameTeamGames': 0,
          'sameTeamWins': 0,
          'opponentGames': 2,
          'opponentWins': 2,
          'opponentLosses': 0,
          'lastMetAt': _iso(now.subtract(const Duration(days: 3))),
        },
        {
          'playerId': 2,
          'playerName': 'Chovy',
          'playerImageUrl': '',
          'teamCode': null,
          'teamImageUrl': null,
          'sameTeamGames': 1,
          'sameTeamWins': 1,
          'opponentGames': 3,
          'opponentWins': 1,
          'opponentLosses': 2,
          'lastMetAt': _iso(now.subtract(const Duration(hours: 2))),
        },
      ],
      'games': [
        for (var i = 0; i < 20; i++)
          {
            'gameId': 'NA1_${5000 - i}',
            'championName': champs[i % champs.length],
            'championImageUrl': '',
            'win': results[19 - i],
            'kills': 3 + i % 9,
            'deaths': 1 + i % 4,
            'assists': 4 + i % 8,
            'durationSeconds': 1500 + i * 37,
            'endedAt': _iso(now.subtract(Duration(minutes: 12 + i * 170))),
            'cheerTotal': i < 5 ? 1284 - i * 211 : 0,
          },
      ],
    });
  }
}
