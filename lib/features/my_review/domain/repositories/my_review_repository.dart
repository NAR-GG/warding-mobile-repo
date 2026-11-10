import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/features/my_review/domain/entities/my_review_item.dart';

/// 내 평가 목록 조회·삭제.
///
/// 인터페이스를 domain 에 두는 이유가 둘이다.
///
/// 1. **테스트.** 구현을 `implements` 하면 메서드를 전부 손으로 채워야 해서,
///    이 레포는 테스트마다 Fake 를 직접 써 왔다(49개). 인터페이스가 있으면
///    `mocktail` 한 줄로 끝난다.
/// 2. **소유권.** 다른 기능이 이 인터페이스에만 의존하면 구현이 어디 있든
///    상관없다. 구현체를 직접 import 하던 때는 "여러 기능이 쓰는데 누구
///    소유냐" 가 매번 문제였다.
abstract interface class MyReviewRepository {
  /// 내가 작성한 평가 목록 한 페이지.
  Future<Either<Failure, MyReviewPage>> fetchMyRatings({
    int page,
    int size,
  });

  /// 평가 한 건을 지운다.
  Future<Either<Failure, Unit>> deleteMyRating({
    required String gameId,
    required int participantId,
  });
}
