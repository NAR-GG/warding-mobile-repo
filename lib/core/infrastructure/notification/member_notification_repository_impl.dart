import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:warding/core/util/api_client.dart' as http;

import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/data/failure_mapper.dart';
import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/domain/repositories/member_notification_repository.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';
import 'package:warding/core/domain/member_notification.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';

/// 마이구독 알림 피드 API (`/api/mobile/me/notifications`).
///
/// 모두 인증이 필요하다. [AuthService.authorizedRequest] 로 감싸 Access Token을
/// 싣고, 만료 시 Refresh Token으로 자동 갱신·재시도한다.
class MemberNotificationRepositoryImpl
    implements MemberNotificationRepository {

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// 받은 알림 리스트를 조회한다(최신순). [group] 은 묶음 필터(예: 'COMMUNITY') —
  /// 지정하면 unreadCount 도 그 묶음 기준이다.
  @override
  Future<Either<Failure, MemberNotificationPage>> fetchNotifications({
    String? type,
    String? group,
    int page = 0,
    int size = 20,
  }) async {
    try {
      return Right(await _fetchNotifications(
        type: type,
        group: group,
        page: page,
        size: size,
      ));
    } catch (e) {
      return Left(toFailure(e, op: 'fetchNotifications'));
    }
  }

  Future<MemberNotificationPage> _fetchNotifications({
    String? type,
    String? group,
    int page = 0,
    int size = 20,
  }) async {
    final url = ApiConfig.notificationsUrl(
      type: type,
      group: group,
      page: page,
      size: size,
    );
    final sw = Stopwatch()..start();
    final response = await _auth.authorizedRequest(
      (token) => http.get(Uri.parse(url), headers: _headers(token)),
    );
    sw.stop();
    debugPrint('[Notification] 피드 ← ${response.statusCode} '
        '(${sw.elapsedMilliseconds}ms)');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStatusException(response.statusCode);
    }
    return MemberNotificationPage.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  /// 전체 읽음 처리. [group] 이 있으면 그 묶음만.
  @override
  Future<Either<Failure, Unit>> markAllRead({String? group}) async {
    try {
      await _markAllRead(group: group);
      return const Right(unit);
    } catch (e) {
      return Left(toFailure(e, op: 'markAllRead'));
    }
  }

  Future<void> _markAllRead({String? group}) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.notificationsReadAllUrl(group: group)),
        headers: _headers(token),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStatusException(response.statusCode);
    }
  }

  /// 단건 읽음 처리.
  @override
  Future<Either<Failure, Unit>> markRead(int notificationId) async {
    try {
      await _markRead(notificationId);
      return const Right(unit);
    } catch (e) {
      return Left(toFailure(e, op: 'markRead'));
    }
  }

  Future<void> _markRead(int notificationId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.notificationReadUrl(notificationId)),
        headers: _headers(token),
      ),
    );
    debugPrint('[Notification] 읽음 $notificationId → ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStatusException(response.statusCode);
    }
  }

  /// 단건 삭제.
  @override
  Future<Either<Failure, Unit>> delete(int notificationId) async {
    try {
      await _delete(notificationId);
      return const Right(unit);
    } catch (e) {
      return Left(toFailure(e, op: 'deleteNotification'));
    }
  }

  Future<void> _delete(int notificationId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.notificationDeleteUrl(notificationId)),
        headers: _headers(token),
      ),
    );
    debugPrint('[Notification] 삭제 $notificationId → ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStatusException(response.statusCode);
    }
  }

  /// 전체 삭제. 삭제 건수를 반환한다.
  @override
  Future<Either<Failure, int>> deleteAll() async {
    try {
      return Right(await _deleteAll());
    } catch (e) {
      return Left(toFailure(e, op: 'deleteAllNotifications'));
    }
  }

  Future<int> _deleteAll() async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.notificationsDeleteAllUrl),
        headers: _headers(token),
      ),
    );
    debugPrint('[Notification] 전체삭제 → ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStatusException(response.statusCode);
    }
    return int.tryParse(response.body.trim()) ?? 0;
  }
}
