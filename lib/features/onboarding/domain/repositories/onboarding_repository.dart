import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/domain/team.dart';
import 'package:warding/features/onboarding/domain/league.dart';
import 'package:warding/features/onboarding/domain/player.dart';

/// 온보딩 선택지(리그·팀·선수) 조회와 완료 저장.
///
/// 팀 목록은 온보딩 밖에서도 널리 쓰인다 — 홈·일정·마이페이지·커뮤니티가 응원팀
/// 로고·이름을 여기서 얻는다. 그래서 이 repository 는 온보딩 전용이 아니라
/// **팀 기준 데이터의 출처**에 가깝다.
abstract interface class OnboardingRepository {
  /// 선호 리그 선택지.
  Future<Either<Failure, List<League>>> fetchLeagues();

  /// 팀 목록. 같은 조회가 이미 떠 있으면 합류하고, 받은 뒤에는 캐시를 쓴다.
  Future<Either<Failure, List<Team>>> fetchTeams();

  /// 선호 선수 선택지. [teamId] 가 있으면 그 팀만.
  Future<Either<Failure, List<Player>>> fetchPlayers({
    required int year,
    int? teamId,
  });

  /// 온보딩 완료 — 선호 리그·팀·선수를 서버에 저장한다 (인증 필요).
  Future<Either<Failure, Unit>> completeOnboarding({
    String? favoriteLeagueName,
    required int favoriteTeamId,
    List<int> favoritePlayerIds,
    required String jwt,
  });
}
