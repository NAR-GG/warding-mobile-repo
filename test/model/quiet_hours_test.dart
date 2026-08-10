import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/quiet_hours.dart';

void main() {
  test('fromJson: "HH:mm" 를 TimeOfDay 로 파싱', () {
    final q = QuietHours.fromJson({
      'enabled': true,
      'startTime': '23:30',
      'endTime': '08:00',
    });

    expect(q.enabled, isTrue);
    expect(q.start, const TimeOfDay(hour: 23, minute: 30));
    expect(q.end, const TimeOfDay(hour: 8, minute: 0));
  });

  test('fromJson: 시각이 없거나 형식이 깨지면 기본값으로 떨어진다', () {
    // 화면이 빈 채로 남거나 예외로 죽는 대신 서버 기본값(01:00~08:00)을 보여 준다.
    final missing = QuietHours.fromJson({'enabled': false});
    expect(missing.start, QuietHours.initial.start);
    expect(missing.end, QuietHours.initial.end);

    final broken = QuietHours.fromJson({'startTime': '1시', 'endTime': '25:00'});
    expect(broken.start, QuietHours.initial.start);
    expect(broken.end, QuietHours.initial.end);
  });

  test('toJson: 서버가 요구하는 세 필드를 항상 싣고 시각은 0 패딩한다', () {
    const q = QuietHours(
      enabled: true,
      start: TimeOfDay(hour: 1, minute: 5),
      end: TimeOfDay(hour: 8, minute: 0),
    );

    expect(q.toJson(), {
      'enabled': true,
      'startTime': '01:05',
      'endTime': '08:00',
    });
  });

  test('isSameTime: 시작 == 종료면 true — 서버가 400 을 주는 조건', () {
    const same = QuietHours(
      enabled: true,
      start: TimeOfDay(hour: 1, minute: 0),
      end: TimeOfDay(hour: 1, minute: 0),
    );
    const different = QuietHours(
      enabled: true,
      start: TimeOfDay(hour: 1, minute: 0),
      end: TimeOfDay(hour: 1, minute: 5),
    );

    expect(same.isSameTime, isTrue);
    expect(different.isSameTime, isFalse);
  });

  test('자정을 넘는 구간도 그대로 왕복한다', () {
    // 판정은 서버가 하므로 앱은 값을 훼손하지 않는 것만 보장하면 된다.
    final round = QuietHours.fromJson(const QuietHours(
      enabled: true,
      start: TimeOfDay(hour: 23, minute: 0),
      end: TimeOfDay(hour: 8, minute: 0),
    ).toJson());

    expect(round.start, const TimeOfDay(hour: 23, minute: 0));
    expect(round.end, const TimeOfDay(hour: 8, minute: 0));
  });
}
