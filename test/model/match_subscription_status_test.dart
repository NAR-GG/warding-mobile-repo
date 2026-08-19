import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/match_subscription_status.dart';

void main() {
  test('fromJson: 구독 중인 경기의 토글 상태를 읽는다', () {
    final s = MatchSubscriptionStatus.fromJson({
      'matchId': '113990000000000001',
      'subscribed': true,
      'setStartEnabled': true,
      'setEndEnabled': true,
      'liveEventEnabled': true,
      'killEnabled': false,
      'baronEnabled': true,
      'dragonEnabled': true,
      'towerEnabled': false,
      'inhibitorEnabled': true,
    });

    expect(s.matchId, '113990000000000001');
    expect(s.subscribed, isTrue);
    expect(s.killEnabled, isFalse);
    expect(s.towerEnabled, isFalse);
    expect(s.baronEnabled, isTrue);
  });

  test('fromJson: 구독 중이 아니면 subscribed=false 와 기본값', () {
    final s = MatchSubscriptionStatus.fromJson({
      'matchId': 'm-2',
      'subscribed': false,
      'setStartEnabled': true,
      'setEndEnabled': true,
      'liveEventEnabled': true,
      'killEnabled': true,
      'baronEnabled': true,
      'dragonEnabled': true,
      'towerEnabled': true,
      'inhibitorEnabled': true,
    });

    expect(s.subscribed, isFalse);
    expect(s.liveEventEnabled, isTrue);
  });

  test('fromJson: 누락 필드는 켜짐(서버 기본값)으로, subscribed 만 false 로 본다', () {
    final s = MatchSubscriptionStatus.fromJson({'matchId': 'm-3'});

    expect(s.subscribed, isFalse);
    expect(s.setStartEnabled, isTrue);
    expect(s.killEnabled, isTrue);
    expect(s.inhibitorEnabled, isTrue);
  });
}
