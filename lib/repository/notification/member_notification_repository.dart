import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../model/member_notification.dart';
import '../auth/auth_service.dart';

/// 마이구독 알림 피드 API (`/api/mobile/me/notifications`).
///
/// 모두 인증이 필요하다. [AuthService.authorizedRequest] 로 감싸 Access Token을
/// 싣고, 만료 시 Refresh Token으로 자동 갱신·재시도한다.
class MemberNotificationRepository {
  MemberNotificationRepository._();
  static final MemberNotificationRepository instance =
      MemberNotificationRepository._();

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// 받은 알림 리스트를 조회한다(최신순).
  Future<MemberNotificationPage> fetchNotifications({
    String? type,
    int page = 0,
    int size = 20,
  }) async {
    final url = ApiConfig.notificationsUrl(type: type, page: page, size: size);
    final response = await _auth.authorizedRequest(
      (token) => http.get(Uri.parse(url), headers: _headers(token)),
    );
    debugPrint('[Notification] 피드 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('알림 조회 실패 (${response.statusCode})');
    }
    return MemberNotificationPage.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  /// 단건 읽음 처리.
  Future<void> markRead(int notificationId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.notificationReadUrl(notificationId)),
        headers: _headers(token),
      ),
    );
    debugPrint('[Notification] 읽음 $notificationId → ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('읽음 처리 실패 (${response.statusCode})');
    }
  }

  /// 단건 삭제.
  Future<void> delete(int notificationId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.notificationDeleteUrl(notificationId)),
        headers: _headers(token),
      ),
    );
    debugPrint('[Notification] 삭제 $notificationId → ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('삭제 실패 (${response.statusCode})');
    }
  }

  /// 전체 삭제. 삭제 건수를 반환한다.
  Future<int> deleteAll() async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.notificationsDeleteAllUrl),
        headers: _headers(token),
      ),
    );
    debugPrint('[Notification] 전체삭제 → ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('전체 삭제 실패 (${response.statusCode})');
    }
    return int.tryParse(response.body.trim()) ?? 0;
  }
}
