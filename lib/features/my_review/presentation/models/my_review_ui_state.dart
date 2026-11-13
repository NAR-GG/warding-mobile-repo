import 'package:warding/core/error/failure.dart';
import 'package:warding/features/my_review/domain/entities/my_review_item.dart';
import 'package:warding/l10n/app_strings.dart';

/// Entity → 화면 표현 변환.
///
/// 도메인 타입이 UI 를 모르게 하려면 이 변환이 presentation 계층에 있어야
/// 한다. [Failure] 를 문구로 바꾸는 일도 여기다 — l10n 을 아는 계층이기 때문이다.
class MyReviewUiState {
  const MyReviewUiState._();

  /// 작성일 기준 'YYYY.MM.DD' → 항목들. 삽입 순서(최신 우선)를 유지한다.
  static Map<String, List<MyReviewItem>> groupByCreatedDate(
    List<MyReviewItem> items,
  ) {
    final map = <String, List<MyReviewItem>>{};
    for (final item in items) {
      map.putIfAbsent(_dateKey(item.createdAt), () => []).add(item);
    }
    return map;
  }

  static String _dateKey(DateTime? c) {
    if (c == null) return '-';
    final m = c.month.toString().padLeft(2, '0');
    final d = c.day.toString().padLeft(2, '0');
    return '${c.year}.$m.$d';
  }

  /// 실패 종류별 사용자 문구.
  ///
  /// 지금은 종류를 가리지 않고 같은 문구를 쓴다. 분기 자리를 미리 열어 둔
  /// 이유는, 401 은 "다시 로그인" 을 안내해야 하고 네트워크 실패는 "잠시 후
  /// 다시" 가 맞아서다 — 문구를 l10n 에 추가할 때 여기만 고치면 된다.
  static String messageFor(Failure failure) {
    final fallback = switch (failure) {
      UnauthorizedFailure() => 'Please sign in again',
      NetworkFailure() => 'Check your network connection',
      _ => 'Failed to load reviews',
    };
    // `appStrings` 는 navigator context 를 거치므로 바인딩이 없으면 던진다
    // (유닛 테스트, 그리고 첫 프레임 전에 실패가 도착한 경우). 문구 하나 때문에
    // 상태 갱신이 깨지면 화면이 로딩에 멈추므로 fallback 으로 떨어진다.
    try {
      return appStrings?.myReviewLoadFailed ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
