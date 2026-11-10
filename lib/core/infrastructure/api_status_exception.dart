/// 서버가 2xx 가 아닌 응답을 줬다.
///
/// DataSource 가 던지고 repository 구현이 [Failure] 로 바꾼다. 상태 코드를
/// 실어 보내는 이유는 401 을 `UnauthorizedFailure` 로, 나머지를
/// `ServerFailure` 로 가를 수 있어야 하기 때문이다 — 문자열 메시지만 던지면
/// repository 가 파싱해야 한다.
class ApiStatusException implements Exception {
  const ApiStatusException(this.statusCode, {this.endpoint});

  final int statusCode;
  final String? endpoint;

  @override
  String toString() =>
      'ApiStatusException($statusCode${endpoint == null ? '' : ', $endpoint'})';
}
