import 'package:flutter_test/flutter_test.dart';
import 'package:warding/repository/live_activity/live_match_activity_controller.dart';

/// 서버 matchStatus → "카드를 유지할 경기인가" 판정 검증.
///
/// 카드 정리(dismissStaleCards)가 진행 중인 경기를 종료로 오판해 멀쩡한 카드를
/// 내리지 않도록, `GET /api/mobile/matches/{id}` 의 실제 matchStatus 값으로 확인한다.
///
/// 예전엔 세트 목록(`/matches/{id}/games`)에서 국면을 추론했는데, 그 API 는 아직
/// 치르지 않은 세트를 내려주지 않아 세트 사이에는 목록이 항상 "전부 ENDED" 였다
/// (실측: bo3 2:0 종료 경기 응답이 2세트뿐). 그래서 세트 사이에 앱을 열면 카드가
/// 지워졌다. 판정 근거를 서버 상태로 옮겼으므로 추론 테스트도 함께 사라졌다.
void main() {
  late LiveMatchActivityController controller;

  setUp(() {
    controller = LiveMatchActivityController();
  });

  group('isScheduledStatus', () {
    test('실제 서버가 시작 전 경기에 쓰는 unstarted 를 걸러낸다', () {
      // GET /api/mobile/matches/{id} 응답의 matchStatus 실제 값.
      // 이 값이 빠져서 시작 전 경기에 카드가 떴다.
      expect(controller.isScheduledStatus('unstarted'), isTrue);
    });

    test('예정을 뜻하는 값이면 true', () {
      for (final s in const [
        'unstarted',
        'SCHEDULED',
        'scheduled',
        'UPCOMING',
        'NOT_STARTED',
        'pending',
        '경기 예정',
        '대기중',
      ]) {
        expect(controller.isScheduledStatus(s), isTrue, reason: s);
      }
    });

    test('진행·종료·빈 값이면 false', () {
      for (final s in const ['LIVE', 'in_progress', 'inProgress', 'completed', '']) {
        expect(controller.isScheduledStatus(s), isFalse, reason: s);
      }
    });
  });

  group('isFinishedStatus', () {
    test('실제 서버가 끝난 경기에 쓰는 completed 를 잡는다', () {
      expect(controller.isFinishedStatus('completed'), isTrue);
    });

    test('종료를 뜻하는 값이면 true', () {
      for (final s in const ['completed', 'COMPLETED', 'finished', 'ENDED', '경기 종료']) {
        expect(controller.isFinishedStatus(s), isTrue, reason: s);
      }
    });

    test('진행 중이면 false — 세트 사이에도 카드를 유지해야 한다', () {
      // inProgress 는 세트 진행 중과 세트 간 휴식을 구분하지 않는다. 두 경우 다 유지.
      for (final s in const ['inProgress', 'in_progress', 'LIVE', '']) {
        expect(controller.isFinishedStatus(s), isFalse, reason: s);
      }
    });

    test('예정 상태를 종료로 오인하지 않는다', () {
      for (final s in const ['unstarted', 'SCHEDULED', '경기 예정']) {
        expect(controller.isFinishedStatus(s), isFalse, reason: s);
      }
    });
  });
}
