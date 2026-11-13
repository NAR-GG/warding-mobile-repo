/// 계층을 넘어 전달되는 실패 표현.
///
/// repository 구현이 `Exception` 을 던지는 대신 `Either<Failure, T>` 의 Left 로
/// 돌려준다. ViewModel 은 `try/catch` 없이 `fold` 로 분기하므로, 실패를
/// 처리하지 않으면 컴파일이 통과하지 않는다 — 예전엔 `catch (e)` 를 빠뜨려도
/// 아무도 몰랐다.
///
/// 사용자에게 보일 문구는 여기 담지 않는다. 메시지는 l10n 을 아는
/// presentation 계층이 [Failure] 종류를 보고 고른다.
sealed class Failure {
  const Failure({this.cause});

  /// 원인 예외·에러. 로깅용이며 사용자에게 보이지 않는다.
  final Object? cause;
}

/// 서버가 2xx 가 아닌 응답을 줬다.
class ServerFailure extends Failure {
  const ServerFailure({this.statusCode, super.cause});

  final int? statusCode;
}

/// 네트워크에 닿지 못했다 (오프라인·타임아웃).
class NetworkFailure extends Failure {
  const NetworkFailure({super.cause});
}

/// 응답은 받았지만 파싱에 실패했다. 서버 스펙 변경 신호일 수 있다.
class ParseFailure extends Failure {
  const ParseFailure({super.cause});
}

/// 인증이 필요하거나 토큰이 만료됐다.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.cause});
}

/// 요청은 성공했지만 보여줄 데이터가 없다.
///
/// 빈 목록을 실패로 볼지 성공으로 볼지는 화면마다 다르다. 목록 화면은 보통
/// 성공(빈 상태 UI)으로 다루므로, 이 Failure 는 "없으면 진행할 수 없는" 경우에만 쓴다.
class NoDataFailure extends Failure {
  const NoDataFailure();
}
