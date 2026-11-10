import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:warding/core/util/api_client.dart' as http;

import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/data/failure_mapper.dart';
import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/domain/repositories/quiet_hours_repository.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';
import 'package:warding/features/mypage/domain/quiet_hours.dart';
import 'package:warding/core/util/sentry_logger.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';

/// 알림 잠자기 설정 API (`/api/mobile/me/quiet-hours`).
///
/// 인증이 필요하다. [AuthService.authorizedRequest] 로 감싸 Access Token 을 싣고,
/// 만료 시 Refresh Token 으로 자동 갱신·재시도한다.
class QuietHoursRepositoryImpl implements QuietHoursRepository {

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// 내 잠자기 설정을 조회한다.
  @override
  Future<Either<Failure, QuietHours>> fetch() async {
    try {
      return Right(await _fetch());
    } catch (e) {
      return Left(toFailure(e, op: 'quietHours.fetch'));
    }
  }

  Future<QuietHours> _fetch() async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.quietHoursUrl),
        headers: _headers(token),
      ),
    );
    debugPrint('[QuietHours] 조회 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStatusException(response.statusCode);
    }
    return QuietHours.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 잠자기 설정을 저장한다. 서버가 세 필드를 모두 요구하므로 항상 전체를 보낸다.
  ///
  /// 시작 == 종료거나 분이 5의 배수가 아니면 서버가 400 을 준다.
  @override
  Future<Either<Failure, QuietHours>> update(QuietHours settings) async {
    try {
      return Right(await _update(settings));
    } catch (e) {
      return Left(toFailure(e, op: 'quietHours.update'));
    }
  }

  Future<QuietHours> _update(QuietHours settings) async {
    final response = await _auth.authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.quietHoursUrl),
        headers: _headers(token),
        body: jsonEncode(settings.toJson()),
      ),
    );
    debugPrint('[QuietHours] 저장 → ${settings.toJson()} ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'putQuietHours',
        reason: 'status_${response.statusCode}',
        extra: {
          'endpoint': ApiConfig.quietHoursUrl,
          'statusCode': response.statusCode,
        },
      );
      throw ApiStatusException(response.statusCode);
    }
    return QuietHours.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
