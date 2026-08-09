import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/live_match_activity.dart';
import 'package:warding/model/match_game.dart';
import 'package:warding/repository/live_activity/live_match_activity_controller.dart';

/// 세트 목록 → 경기 국면 판정 로직 검증.
///
/// 카드 정리(dismissStaleCards)가 "아직 카드를 유지해야 하는 경기"를
/// 잘못 판정해 멀쩡한 카드를 내리지 않도록, 실제 API 응답
/// (`/api/mobile/matches/{id}/games`) 구조 그대로 확인한다.
void main() {
  late LiveMatchActivityController controller;

  setUp(() {
    controller = LiveMatchActivityController();
  });

  /// 실제 응답과 같은 형태로 세트 하나를 만든다.
  MatchGame game(int order, String status, {String? winner}) {
    return MatchGame.fromJson({
      'gameOrder': order,
      'gameId': '11554868180340611$order',
      'status': status,
      'vodUrl': null,
      'winnerTeamCode': winner,
    });
  }

  group('resolvePhase', () {
    test('LIVE 세트가 있으면 진행 중', () {
      final games = [
        game(1, 'ENDED', winner: 'VIT'),
        game(2, 'LIVE'),
      ];
      expect(controller.resolvePhase(games), LiveMatchPhase.playing);
    });

    test('모든 세트가 끝났으면 경기 종료', () {
      // 실제 응답(115548681803406115): 2세트 모두 ENDED, VIT 2승.
      final games = [
        game(1, 'ENDED', winner: 'VIT'),
        game(2, 'ENDED', winner: 'VIT'),
      ];
      expect(controller.resolvePhase(games), LiveMatchPhase.matchEnded);
    });

    test('끝난 세트는 있고 진행 중인 세트가 없으면 세트 종료(세트 간 휴식)', () {
      final games = [
        game(1, 'ENDED', winner: 'VIT'),
        game(2, 'SCHEDULED'),
      ];
      expect(controller.resolvePhase(games), LiveMatchPhase.setEnded);
    });

    test('세트가 하나도 없으면 시작 전이라 null', () {
      // 경기 시작 전에는 세트 목록이 비어 내려온다.
      expect(controller.resolvePhase(const []), isNull);
    });

    test('세트가 전부 예정이면 시작 전이라 null', () {
      final games = [
        game(1, 'SCHEDULED'),
        game(2, 'SCHEDULED'),
      ];
      expect(controller.resolvePhase(games), isNull);
    });
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

    test('진행·종료·빈 값이면 false (세트 데이터 판정에 맡긴다)', () {
      for (final s in const ['LIVE', 'in_progress', 'completed', 'ENDED', '']) {
        expect(controller.isScheduledStatus(s), isFalse, reason: s);
      }
    });
  });
}
