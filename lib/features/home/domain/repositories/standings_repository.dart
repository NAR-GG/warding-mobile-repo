import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/features/home/domain/standing.dart';
import 'package:warding/features/home/domain/worlds_standings.dart';

/// 리그 순위표 조회.
abstract interface class StandingsRepository {
  Future<Either<Failure, StandingsResult>> fetchStandings(String league);

  /// 월즈 순위표(스위스 전적 버킷 + 토너먼트 대진).
  ///
  /// 리그 테이블과 형식이 달라 [fetchStandings] 와 별도 모델·메서드로 둔다.
  /// 백엔드가 아직 월즈를 지원하지 않아 목업 플래그가 켜진 빌드에서만 값이
  /// 나온다 — **네트워크를 타지 않으므로 [Failure] 가 없다.** null 은 "이 빌드는
  /// 월즈를 보여주지 않는다" 는 뜻이고, 실패가 아니다.
  Future<WorldsStandings?> fetchWorldsStandings();
}
