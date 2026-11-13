import 'package:fpdart/fpdart.dart';

import 'package:warding/core/error/failure.dart';
import 'package:warding/domain/member_notification.dart';

/// 받은 알림 피드. 인증이 필요하다.
abstract interface class MemberNotificationRepository {
  /// 알림 목록(최신순).
  ///
  /// [group] 은 묶음 필터(예: 'COMMUNITY') — 지정하면 `unreadCount` 도 그 묶음
  /// 기준이다.
  Future<Either<Failure, MemberNotificationPage>> fetchNotifications({
    String? type,
    String? group,
    int page,
    int size,
  });

  /// 전체 읽음 처리. [group] 이 있으면 그 묶음만.
  Future<Either<Failure, Unit>> markAllRead({String? group});

  /// 한 건 읽음 처리.
  Future<Either<Failure, Unit>> markRead(int notificationId);

  /// 한 건 삭제.
  Future<Either<Failure, Unit>> delete(int notificationId);

  /// 전체 삭제. 지워진 건수를 돌려준다.
  Future<Either<Failure, int>> deleteAll();
}
