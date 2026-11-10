import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/features/shorts/domain/entities/story_video.dart';

/// 유튜브 쇼츠 목록 조회.
abstract interface class ShortsRepository {
  /// [sort]: 'latest' | 'views' | 'likes'.
  ///
  /// [teamCode] 는 그 팀 채널의 쇼츠만 받는다(서버 필터). 서버가 아직 모르는
  /// 동안은 무시되므로 호출하는 쪽도 응답의 `teamCode` 로 한 번 더 거른다.
  Future<Either<Failure, ShortsPage>> fetchShortsPage({
    String sort,
    int size,
    int page,
    String? teamCode,
  });
}
