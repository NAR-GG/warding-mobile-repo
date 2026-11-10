import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/domain/usecase.dart';
import 'package:warding/features/my_review/domain/repositories/my_review_repository.dart';

/// 내 평가 한 건을 지운다.
class DeleteMyRatingUseCase
    extends UseCase<Unit, DeleteMyRatingParams> {
  DeleteMyRatingUseCase(this._repository);

  final MyReviewRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(DeleteMyRatingParams params) {
    return _repository.deleteMyRating(
      gameId: params.gameId,
      participantId: params.participantId,
    );
  }
}

class DeleteMyRatingParams {
  const DeleteMyRatingParams({
    required this.gameId,
    required this.participantId,
  });

  final String gameId;
  final int participantId;
}
