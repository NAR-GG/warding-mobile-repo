import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';

/// 예외 → [Failure].
///
/// repository 구현마다 같은 `switch` 를 복제하지 않도록 한 곳에 둔다. 401·403
/// 을 따로 가르는 이유는 화면이 "다시 로그인" 을 안내해야 하는 경우와 "잠시 후
/// 다시" 를 안내하는 경우가 다르기 때문이다.
Failure toFailure(Object e, {String? op}) {
  if (op != null) debugPrint('[Repo] $op failed: $e');
  return switch (e) {
    ApiStatusException(statusCode: 401) ||
    ApiStatusException(statusCode: 403) =>
      UnauthorizedFailure(cause: e),
    ApiStatusException(:final statusCode) =>
      ServerFailure(statusCode: statusCode, cause: e),
    SocketException() || TimeoutException() => NetworkFailure(cause: e),
    FormatException() || TypeError() => ParseFailure(cause: e),
    _ => ServerFailure(cause: e),
  };
}
