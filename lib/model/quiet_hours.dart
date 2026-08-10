import 'package:flutter/material.dart';

/// 알림 잠자기(방해금지 시간) 설정.
///
/// `/api/mobile/me/quiet-hours` 요청·응답에 대응한다. 서버는 시각을 `"HH:mm"`
/// 문자열로 주고받는다(초 없음). 켜진 시간대에는 모든 푸시가 소리 없이 알림함에만 쌓인다.
class QuietHours {
  const QuietHours({
    required this.enabled,
    required this.start,
    required this.end,
  });

  /// 서버 기본값과 같은 초기 상태. 조회 실패 시 화면이 빈 채로 남지 않게 쓴다.
  static const QuietHours initial = QuietHours(
    enabled: false,
    start: TimeOfDay(hour: 1, minute: 0),
    end: TimeOfDay(hour: 8, minute: 0),
  );

  final bool enabled;
  final TimeOfDay start;
  final TimeOfDay end;

  /// 시작과 종료가 같으면 서버가 400 을 준다. 24시간 무음으로 빠지는 걸 막기 위한 계약.
  bool get isSameTime => start.hour == end.hour && start.minute == end.minute;

  QuietHours copyWith({bool? enabled, TimeOfDay? start, TimeOfDay? end}) {
    return QuietHours(
      enabled: enabled ?? this.enabled,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  factory QuietHours.fromJson(Map<String, dynamic> json) {
    return QuietHours(
      enabled: json['enabled'] as bool? ?? false,
      start: _parse(json['startTime'] as String?) ?? initial.start,
      end: _parse(json['endTime'] as String?) ?? initial.end,
    );
  }

  /// PUT 본문. 서버가 세 필드를 모두 요구한다(부분 업데이트 없음).
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'startTime': format(start),
        'endTime': format(end),
      };

  /// `TimeOfDay` → `"HH:mm"`.
  static String format(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// `"HH:mm"` → `TimeOfDay`. 형식이 어긋나면 null.
  static TimeOfDay? _parse(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
