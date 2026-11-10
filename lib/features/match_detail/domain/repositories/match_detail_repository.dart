import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/domain/schedule_match.dart';
import 'package:warding/features/match_detail/domain/match_champion_pick.dart';
import 'package:warding/features/match_detail/domain/match_game.dart';
import 'package:warding/features/match_detail/domain/match_live_event.dart';

/// 경기 상세 조회 (인증 불필요).
abstract interface class MatchDetailRepository {
  /// 단일 경기 정보. **실패하면 null 이다.**
  ///
  /// [Either] 를 쓰지 않는 이유는 호출부 둘 다 실패와 "경기가 없음" 을 같게
  /// 다루기 때문이다 — 라이브 카드 컨트롤러는 null 이면 "진행 중이 아니다" 로
  /// 보고, 상세 화면은 games 응답이 채운 팀 정보를 그대로 쓴다. 실패 종류를
  /// 알아도 할 일이 없다.
  Future<ScheduleMatch?> fetchMatch(String matchId);

  /// 경기의 세트별 게임 목록. 세트 순서 → gameId 해석에 쓴다.
  ///
  /// 응답 최상위에 팀 정보(teamA/blueTeam)가 있으면 [ScheduleMatch] 도 파싱해
  /// 함께 돌려준다.
  Future<Either<Failure, (List<MatchGame>, ScheduleMatch?)>> fetchGames(
    String matchId,
  );

  /// 세트의 챔피언 픽.
  Future<Either<Failure, MatchChampionPick>> fetchChampionPick(String gameId);

  /// 세트의 라이브 이벤트(킬·오브젝트 등).
  Future<Either<Failure, MatchLiveEvents>> fetchLiveEvents(String gameId);
}
