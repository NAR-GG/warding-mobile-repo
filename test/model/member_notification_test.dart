import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/member_notification.dart';

import '../support/l10n_test_setup.dart';

void main() {
  test('fromJson: 솔랭 항목 타입·data 접근자 파싱', () {
    final n = MemberNotification.fromJson({
      'id': 7,
      'type': 'PLAYER_SOLO_RANK_STARTED',
      'title': 'Faker 선수 랭크 시작 감지!',
      'body': '지금 Faker 선수가 Galio로 솔로 랭크를 시작했습니다',
      'data': {
        'type': 'PLAYER_SOLO_RANK_STARTED',
        'playerId': '42',
        'playerName': 'Faker',
        'championName': 'Galio',
        'queueType': '솔로 랭크',
        'deepLink': 'nar://players/42',
        'opggUrl': 'https://op.gg/faker',
      },
      'read': false,
      'createdAt': '2026-06-24T19:18:21',
    });

    expect(n.id, 7);
    expect(n.type, MemberNotificationType.playerSoloRank);
    expect(n.read, isFalse);
    expect(n.playerName, 'Faker');
    expect(n.championName, 'Galio');
    expect(n.deepLink, 'nar://players/42');
    expect(n.opggUrl, 'https://op.gg/faker');
    expect(n.matchId, isNull);
    expect(n.createdAt, DateTime(2026, 6, 24, 19, 18, 21));
  });

  // playerName 의 기본값이 appStrings 를 거치므로 로케일 호스트가 필요하다.
  testWidgets('fromJson: 팀 이벤트는 matchId 만, 알 수 없는 타입은 unknown', (
    WidgetTester tester,
  ) async {
    await pumpAppStringsHost(tester);

    final setEnd = MemberNotification.fromJson({
      'id': 1,
      'type': 'SET_END',
      'title': 'T1 세트 종료',
      'body': 'T1 vs GEN · 2세트 종료',
      'data': {'type': 'SET_END', 'matchId': 'm-1', 'setNumber': '2'},
      'read': true,
      'createdAt': '2026-06-24T20:00:00',
    });
    expect(setEnd.type, MemberNotificationType.setEnd);
    expect(setEnd.matchId, 'm-1');
    expect(setEnd.read, isTrue);
    // 솔랭 전용 접근자는 기본값을 돌려준다.
    expect(setEnd.playerName, '선수');

    final weird = MemberNotification.fromJson({'id': 2, 'type': 'WAT'});
    expect(weird.type, MemberNotificationType.unknown);
    expect(weird.data, isEmpty);
  });

  test('솔랭 종료: eventType/win/kda 를 읽는다', () {
    final n = MemberNotification.fromJson({
      'id': 8,
      // 시작·종료 모두 같은 type 이라 eventType 으로만 갈린다.
      'type': 'PLAYER_SOLO_RANK_STARTED',
      'title': 'Pyosik 선수가 솔랭 한 판을 마쳤어요',
      'body': '리 신으로 승리 · 18/1/11',
      'data': {
        'type': 'PLAYER_SOLO_RANK_STARTED',
        'eventType': 'END',
        'win': 'true',
        'kda': '18/1/11',
        'playerName': 'Pyosik',
        'championName': '리 신',
      },
      'createdAt': '2026-08-19T16:27:00',
    });

    expect(n.type, MemberNotificationType.playerSoloRank);
    expect(n.isSoloRankEnd, isTrue);
    expect(n.soloRankWin, isTrue);
    expect(n.kda, '18/1/11');
  });

  test('솔랭 종료: 패배는 win=false', () {
    final n = MemberNotification.fromJson({
      'id': 9,
      'type': 'PLAYER_SOLO_RANK_STARTED',
      'data': {'eventType': 'END', 'win': 'false', 'kda': '2/9/3'},
      'createdAt': '2026-08-19T16:27:00',
    });
    expect(n.soloRankWin, isFalse);
  });

  test('솔랭 종료: match-v5 결과를 못 읽으면 win·kda 가 없다', () {
    final n = MemberNotification.fromJson({
      'id': 10,
      'type': 'PLAYER_SOLO_RANK_STARTED',
      'data': {'eventType': 'END', 'championName': '리 신'},
      'createdAt': '2026-08-19T16:27:00',
    });
    expect(n.isSoloRankEnd, isTrue);
    expect(n.soloRankWin, isNull);
    expect(n.kda, isNull);
  });

  test('솔랭 종료: gameDurationSeconds 를 읽는다', () {
    final n = MemberNotification.fromJson({
      'id': 12,
      'type': 'PLAYER_SOLO_RANK_STARTED',
      'data': {'eventType': 'END', 'gameDurationSeconds': '1694'},
      'createdAt': '2026-08-19T16:27:00',
    });
    expect(n.gameDurationSeconds, 1694);
  });

  // 서버가 진행 중 매치·시계 이상이면 키를 뺀다. 구버전 서버도 키가 없다.
  test('솔랭 종료: 경기 길이 키가 없거나 깨지면 null', () {
    final noKey = MemberNotification.fromJson({
      'id': 13,
      'type': 'PLAYER_SOLO_RANK_STARTED',
      'data': {'eventType': 'END'},
      'createdAt': '2026-08-19T16:27:00',
    });
    final empty = MemberNotification.fromJson({
      'id': 14,
      'type': 'PLAYER_SOLO_RANK_STARTED',
      'data': {'eventType': 'END', 'gameDurationSeconds': ''},
      'createdAt': '2026-08-19T16:27:00',
    });
    final broken = MemberNotification.fromJson({
      'id': 15,
      'type': 'PLAYER_SOLO_RANK_STARTED',
      'data': {'eventType': 'END', 'gameDurationSeconds': 'abc'},
      'createdAt': '2026-08-19T16:27:00',
    });
    expect(noKey.gameDurationSeconds, isNull);
    expect(empty.gameDurationSeconds, isNull);
    expect(broken.gameDurationSeconds, isNull);
  });

  test('솔랭 시작: eventType=START 는 종료가 아니다', () {
    final n = MemberNotification.fromJson({
      'id': 11,
      'type': 'PLAYER_SOLO_RANK_STARTED',
      'data': {'eventType': 'START', 'championName': '리 신'},
      'createdAt': '2026-08-19T16:00:00',
    });
    expect(n.isSoloRankEnd, isFalse);
    expect(n.soloRankWin, isNull);
    expect(n.kda, isNull);
  });

  test('MemberNotificationPage.fromJson: 미읽음 수·페이지 파싱', () {
    final page = MemberNotificationPage.fromJson({
      'notifications': [
        {'id': 1, 'type': 'SET_START', 'createdAt': '2026-06-24T10:00:00'},
      ],
      'unreadCount': 3,
      'page': 0,
      'size': 20,
      'totalElements': 21,
      'totalPages': 2,
    });
    expect(page.notifications, hasLength(1));
    expect(page.unreadCount, 3);
    expect(page.hasMore, isTrue); // page 0 / totalPages 2
  });

  test('copyWith: read 만 바꾼다', () {
    final n = MemberNotification.fromJson({
      'id': 9,
      'type': 'SET_START',
      'read': false,
      'createdAt': '2026-06-24T10:00:00',
    });
    final read = n.copyWith(read: true);
    expect(read.read, isTrue);
    expect(read.id, 9);
    expect(n.read, isFalse); // 원본 불변
  });
}
