import 'package:flutter/foundation.dart';

import '../../config/secure_storage.dart';

/// 응원 광고 진입 팝업을 오늘(KST) 그만 보겠다고 했는지 기기에 저장한다.
///
/// 저장하는 값은 '오늘 하루 보지 않기' 를 누른 날짜(`yyyy-MM-dd`)다. 그 버튼을
/// 누르지 않으면 아무것도 저장하지 않아 다음 실행에 다시 뜬다 — 그냥 닫은 것은
/// '관심 없다'는 뜻이 아니다.
/// [GuidePopupPreferenceRepository] 와 같은 이유로 이미 설치된 secure storage 를
/// 재사용한다.
class CheerAdPopupPreferenceRepository {
  CheerAdPopupPreferenceRepository._();
  static final CheerAdPopupPreferenceRepository instance =
      CheerAdPopupPreferenceRepository._();

  static const _key = 'cheer_ad_popup_dismissed_date';

  static String _todayKst() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final m = kst.month.toString().padLeft(2, '0');
    final d = kst.day.toString().padLeft(2, '0');
    return '${kst.year}-$m-$d';
  }

  /// '오늘 하루 보지 않기' 를 눌렀다고 기록한다.
  Future<void> markDismissedToday() async {
    try {
      await writeWithDuplicateRecovery(key: _key, value: _todayKst());
    } catch (e) {
      debugPrint('[CheerAdPopup] 저장 실패: $e');
    }
  }

  /// 오늘 띄워도 되는지. '오늘 하루 보지 않기' 를 누른 날이 오늘이면 띄우지 않는다.
  ///
  /// 읽기에 실패하면 띄우지 않는다 — 그만 보겠다고 한 사용자에게 다시 내미는 쪽이
  /// 한 번 못 보여주는 것보다 나쁘다.
  Future<bool> shouldShowToday() async {
    try {
      // 읽기 실패는 예외로 올라와 catch 에서 false 가 된다(null 은 '저장된 적 없음'뿐).
      return await readOrThrowIfUnavailable(_key) != _todayKst();
    } catch (e) {
      debugPrint('[CheerAdPopup] 복원 실패: $e');
      return false;
    }
  }
}
