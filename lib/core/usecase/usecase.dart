import 'package:fpdart/fpdart.dart';

import 'package:warding/core/error/failure.dart';

/// 비즈니스 로직 한 단위.
///
/// "무엇을 할까" 를 담는다. ViewModel 은 "어떻게 보여줄까" 만 하고, 여러
/// repository 를 조합하거나 규칙을 적용하는 일은 UseCase 로 내린다.
///
/// 호출은 `call` 이라 인스턴스를 함수처럼 쓴다 — `await getMyRatings(params)`.
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// 파라미터가 없는 UseCase 용.
///
/// `UseCase<T, void>` 로 두면 호출부가 `call(null)` 이 되어 의도가 흐려진다.
class NoParams {
  const NoParams();
}
