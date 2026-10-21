import 'package:flutter_test/flutter_test.dart';
import 'package:warding/util/live_elapsed.dart';

void main() {
  group('liveElapsedSeconds', () {
    test('startedAt 이 없으면 서버 스냅샷을 그대로 쓴다', () {
      expect(liveElapsedSeconds(snapshotSeconds: 725), 725);
    });

    test('startedAt 이 있으면 기기 시계로 다시 계산한다', () {
      final started = DateTime.now().subtract(const Duration(minutes: 20));
      // 서버 스냅샷은 조회 시점(10분 전) 값이라 이미 낡았다.
      final seconds = liveElapsedSeconds(
        snapshotSeconds: 600,
        startedAt: started,
      );
      expect(seconds, greaterThanOrEqualTo(1200));
    });

    test('기기 시계가 뒤처져 있으면 스냅샷을 지킨다', () {
      // 시작 시각이 방금이면 계산값은 0 에 가까운데, 스냅샷이 더 크다.
      // 이때 계산값을 쓰면 화면에서 시간이 거꾸로 간다.
      final seconds = liveElapsedSeconds(
        snapshotSeconds: 725,
        startedAt: DateTime.now(),
      );
      expect(seconds, 725);
    });
  });

  group('formatElapsed', () {
    test('1시간 미만은 m:ss', () {
      expect(formatElapsed(0), '0:00');
      expect(formatElapsed(65), '1:05');
      expect(formatElapsed(725), '12:05');
      expect(formatElapsed(3599), '59:59');
    });

    test('1시간 이상은 h:mm:ss', () {
      expect(formatElapsed(3600), '1:00:00');
      expect(formatElapsed(3725), '1:02:05');
    });
  });
}
