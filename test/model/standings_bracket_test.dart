import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/standing.dart';
import 'package:warding/model/worlds_standings.dart';

/// `/api/standings` 의 `bracket` 파싱 — warding-docs
/// `features/home/spec.md` "요청: 토너먼트 대진 응답" 에 올린 형식.
void main() {
  group('hasBracket — 데이터 유무로만 판단한다', () {
    // `reason` 으로 판단하지 않는 이유: 백엔드의 BRACKET_ONLY 는 포맷 신호가
    // 아니라 `StandingsService.SCOPES`(LCK·ASIAN_GAMES·DEMACIA_CUP)에 없는
    // 리그 전부에 붙는 기본값이다(nar-back-repo 소스 확인). LPL·LEC·EWC 처럼
    // 대진 UI 와 무관한 리그도 같은 값을 받는다.
    test('BRACKET_ONLY 여도 bracket 이 없으면 대진이 아니다', () {
      // 지금 prod 의 WORLDS·MSI 응답 모양 — bracket 은 아직 안 온다.
      final r = StandingsResult.fromJson({
        'league': 'WORLDS',
        'supported': false,
        'reason': 'BRACKET_ONLY',
        'groups': [],
      });
      expect(r.hasBracket, isFalse);
    });

    test('리그 테이블 응답은 대진이 아니다', () {
      final r = StandingsResult.fromJson({
        'league': 'LCK',
        'supported': true,
        'reason': null,
        'groups': [],
      });
      expect(r.hasBracket, isFalse);
    });

    test('reason 이 없어도 bracket 이 오면 대진이다', () {
      final r = StandingsResult.fromJson({
        'league': 'ASIAN_GAMES',
        'supported': false,
        'reason': null,
        'groups': [],
        'bracket': {
          'rounds': [
            {
              'name': '결승',
              'matches': [
                {
                  'teamA': {'teamCode': 'KOR'},
                  'teamB': {'teamCode': 'TPE'},
                },
              ],
            },
          ],
        },
      });
      expect(r.hasBracket, isTrue);
    });
  });

  test('bracket 을 WorldsStandings 로 옮긴다', () {
    final r = StandingsResult.fromJson(
      jsonDecode('''
      {
        "league": "ASIAN_GAMES",
        "supported": false,
        "reason": "BRACKET_ONLY",
        "scopeLabel": "녹아웃 스테이지",
        "groups": [],
        "bracket": {
          "swiss": [
            {"record": "3-0", "teamCodes": ["KOR", "TPE"], "advanced": true}
          ],
          "rounds": [
            {
              "name": "4강",
              "matches": [
                {
                  "matchId": "m1",
                  "status": "done",
                  "isFinal": false,
                  "teamA": {"teamCode": "KOR", "teamName": "대한민국",
                            "imageUrl": "https://api.nar.kr/images/flags/kor.png",
                            "gameWins": 2, "won": true},
                  "teamB": {"teamCode": "VIE", "gameWins": 0, "won": false}
                },
                {
                  "status": "upcoming",
                  "isFinal": true,
                  "teamA": {"teamCode": null},
                  "teamB": {"teamCode": "TPE"}
                }
              ]
            }
          ]
        }
      }
      ''') as Map<String, dynamic>,
    );

    expect(r.hasBracket, isTrue);
    expect(r.scopeLabel, '녹아웃 스테이지');

    final w = r.bracket!.toWorldsStandings();
    expect(w.bracket, hasLength(1));
    expect(w.bracket.first.record, '3-0');
    expect(w.bracket.first.teamCodes, ['KOR', 'TPE']);
    expect(w.bracket.first.advanced, isTrue);

    expect(w.knockout, hasLength(1));
    final round = w.knockout.first;
    expect(round.name, '4강');
    expect(round.matches, hasLength(2));

    final m1 = round.matches.first;
    expect(m1.status, WorldsMatchStatus.done);
    expect(m1.teamA.teamCode, 'KOR');
    // 국기 URL 이 대진 카드까지 전달돼야 한다(사전에 국가대표가 없다).
    expect(m1.teamA.imageUrl, 'https://api.nar.kr/images/flags/kor.png');
    expect(m1.teamA.won, isTrue);
    expect(m1.teamB.gameWins, 0);

    // teamCode 가 null 이면 TBD.
    final m2 = round.matches[1];
    expect(m2.teamA.isTbd, isTrue);
    expect(m2.teamB.isTbd, isFalse);
    expect(m2.isFinal, isTrue);
    expect(m2.status, WorldsMatchStatus.upcoming);
  });

  test('status live 는 진행 중으로 보고 시각을 뽑는다', () {
    final r = StandingsResult.fromJson({
      'league': 'ASIAN_GAMES',
      'reason': 'BRACKET_ONLY',
      'groups': [],
      'bracket': {
        'rounds': [
          {
            'name': '결승',
            'matches': [
              {
                'status': 'live',
                'scheduledTime': '2026-10-08T16:30:00+09:00',
                'teamA': {'teamCode': 'KOR'},
                'teamB': {'teamCode': 'TPE'},
              },
            ],
          },
        ],
      },
    });

    final m = r.bracket!.toWorldsStandings().knockout.first.matches.first;
    expect(m.status, WorldsMatchStatus.today);
    // 기기 로컬 시각으로 환산해 비교한다(KST 러너가 아닐 수 있다).
    final local = DateTime.parse('2026-10-08T16:30:00+09:00').toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    expect(m.todayTime, '$hh:$mm');
  });

  test('모르는 status·빈 bracket 도 터지지 않는다', () {
    final r = StandingsResult.fromJson({
      'league': 'X',
      'reason': 'BRACKET_ONLY',
      'groups': [],
      'bracket': {'swiss': [], 'rounds': []},
    });
    expect(r.hasBracket, isFalse, reason: '둘 다 비면 그릴 게 없다');

    final r2 = StandingsResult.fromJson({
      'league': 'X',
      'reason': 'BRACKET_ONLY',
      'groups': [],
      'bracket': {
        'rounds': [
          {
            'name': '8강',
            'matches': [
              {
                'status': '처음보는값',
                'teamA': {'teamCode': 'A'},
                'teamB': {'teamCode': 'B'},
              },
            ],
          },
        ],
      },
    });
    final m = r2.bracket!.toWorldsStandings().knockout.first.matches.first;
    expect(m.status, WorldsMatchStatus.upcoming);
    expect(m.todayTime, isNull);
  });
}
