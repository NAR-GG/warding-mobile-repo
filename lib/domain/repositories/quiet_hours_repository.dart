import 'package:fpdart/fpdart.dart';

import 'package:warding/core/error/failure.dart';
import 'package:warding/domain/quiet_hours.dart';

/// 알림 잠자기(방해 금지) 설정. 인증이 필요하다.
abstract interface class QuietHoursRepository {
  /// 내 잠자기 설정.
  Future<Either<Failure, QuietHours>> fetch();

  /// 잠자기 설정 저장. 서버가 세 필드를 모두 요구하므로 항상 전체를 보낸다.
  ///
  /// 시작 == 종료거나 분이 5 의 배수가 아니면 서버가 400 을 준다 —
  /// `ServerFailure(statusCode: 400)` 으로 온다.
  Future<Either<Failure, QuietHours>> update(QuietHours settings);
}
