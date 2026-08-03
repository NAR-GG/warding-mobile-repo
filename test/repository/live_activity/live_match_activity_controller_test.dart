import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/live_match_activity.dart';
import 'package:warding/model/match_game.dart';
import 'package:warding/model/schedule_match.dart';
import 'package:warding/repository/live_activity/live_match_activity_controller.dart';

/// 세트 목록 → Live Activity 상태 판정 로직 검증.
///
/// 실제 API 응답(`/api/mobile/matches/{id}/games`) 구조를 그대로 써서,
/// 경기 진행 국면·표시 세트·세트 스코어가 의도대로 나오는지 확인한다.
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

  /// TH vs VIT 대진. 스코어 판정은 teamCode 매칭에 의존한다.
  ScheduleMatch match() {
    return ScheduleMatch.fromJson({
      'matchId': '115548681803406115',
      'teamA': {
        'teamName': 'Team Heretics',
        'teamCode': 'TH',
        'teamImageUrl': '',
      },
      'teamB': {
        'teamName': 'Team Vitality',
        'teamCode': 'VIT',
        'teamImageUrl': '',
      },
      'leagueInfo': 'LEC',
      'matchTitle': 'Group Stage | TH vs VIT',
      'matchStatus': 'completed',
      'scheduledTime': '18:00',
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

    test('세트 데이터가 전혀 없으면(과거 경기 등) 진행 중으로 보지 않는다', () {
      expect(controller.resolvePhase(const []), isNot(LiveMatchPhase.playing));
    });

    test('세트가 모두 SCHEDULED 면(시작 직전) 진행 중으로 본다', () {
      final games = [game(1, 'SCHEDULED'), game(2, 'SCHEDULED')];
      expect(controller.resolvePhase(games), LiveMatchPhase.playing);
    });
  });

  group('resolveSetNumber', () {
    test('LIVE 세트가 있으면 그 세트 번호', () {
      final games = [
        game(1, 'ENDED', winner: 'TH'),
        game(2, 'LIVE'),
        game(3, 'SCHEDULED'),
      ];
      expect(controller.resolveSetNumber(games), 2);
    });

    test('LIVE 가 없으면 마지막으로 끝난 세트 번호', () {
      final games = [
        game(1, 'ENDED', winner: 'VIT'),
        game(2, 'ENDED', winner: 'VIT'),
      ];
      expect(controller.resolveSetNumber(games), 2);
    });
  });

  group('resolveScore', () {
    test('세트 승자 코드로 양 팀 승수를 센다', () {
      // 실제 경기 결과: VIT 2 : 0 TH (teamA=TH, teamB=VIT)
      final games = [
        game(1, 'ENDED', winner: 'VIT'),
        game(2, 'ENDED', winner: 'VIT'),
      ];
      expect(controller.resolveScore(match(), games), (0, 2));
    });

    test('진행 중인 세트는 승자가 없어 스코어에 반영되지 않는다', () {
      final games = [
        game(1, 'ENDED', winner: 'TH'),
        game(2, 'LIVE'),
      ];
      expect(controller.resolveScore(match(), games), (1, 0));
    });

    test('대진에 없는 팀 코드는 무시한다', () {
      final games = [game(1, 'ENDED', winner: 'GEN')];
      expect(controller.resolveScore(match(), games), (0, 0));
    });
  });
}
