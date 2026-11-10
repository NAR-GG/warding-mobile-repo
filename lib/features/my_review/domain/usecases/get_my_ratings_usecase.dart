import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/domain/usecase.dart';
import 'package:warding/features/my_review/domain/entities/my_review_item.dart';
import 'package:warding/features/my_review/domain/repositories/my_review_repository.dart';

/// 내 평가 목록 한 페이지를 가져온다.
class GetMyRatingsUseCase
    extends UseCase<MyReviewPage, GetMyRatingsParams> {
  GetMyRatingsUseCase(this._repository);

  final MyReviewRepository _repository;

  @override
  Future<Either<Failure, MyReviewPage>> call(GetMyRatingsParams params) {
    return _repository.fetchMyRatings(
      page: params.page,
      size: params.size,
    );
  }
}

class GetMyRatingsParams {
  const GetMyRatingsParams({this.page = 0, this.size = 20});

  final int page;
  final int size;
}
