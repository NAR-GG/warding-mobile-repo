import 'package:warding/core/error/failure.dart';

/// [Failure] 를 예외로 감싼다.
///
/// `Either` 를 쓰는데도 예외가 필요한 자리가 있다. 낙관적 UI 처럼 **ViewModel 이
/// 복구를 하고 그 사실을 호출부(화면)에 알려야** 하는 경우다 — 화면은 스낵바를
/// 띄우고, ViewModel 은 목록을 되돌린다. `bool` 을 돌려주는 것으로도 되지만
/// `rethrow` 계약을 이미 쓰는 호출부가 있으면 그쪽을 깨지 않는 편이 낫다.
///
/// `Error` 가 아니라 `Exception` 을 구현한다 — `StateError` 를 쓰면
/// `throwsException` 으로 검증하던 테스트가 깨지고, 의미도 다르다(프로그래밍
/// 오류가 아니라 예상된 실패다).
class FailureException implements Exception {
  const FailureException(this.failure);

  final Failure failure;

  @override
  String toString() => 'FailureException($failure)';
}
