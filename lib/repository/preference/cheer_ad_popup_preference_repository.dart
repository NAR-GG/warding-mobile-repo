import 'package:flutter/foundation.dart';

import '../../config/secure_storage.dart';

/// 응원 광고 진입 팝업을 오늘(KST) 이미 띄웠는지 기기에 저장한다.
///
/// 하루(KST) 한 번만 띄운다. 저장하는 값은 띄운 날짜(`yyyy-MM-dd`)다.
/// [GuidePopupPreferenceRepository] 와 같은 이유로 이미 설치된 secure storage 를
/// 재사용한다.
class CheerAdPopupPreferenceRepository {
  CheerAdPopupPreferenceRepository._();
  static final CheerAdPopupPreferenceRepository instance =
      CheerAdPopupPreferenceRepository._();

  static const _key = 'cheer_ad_popup_shown_date';

  static String _todayKst() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final m = kst.month.toString().padLeft(2, '0');
    final d = kst.day.toString().padLeft(2, '0');
    return '${kst.year}-$m-$d';
  }

  /// 오늘 띄웠다고 기록한다.
  Future<void> markShownToday() async {
    try {
      await writeWithDuplicateRecovery(key: _key, value: _todayKst());
    } catch (e) {
      debugPrint('[CheerAdPopup] 저장 실패: $e');
    }
  }

  /// 오늘 아직 안 띄웠는지. 읽기에 실패하면 띄우지 않는다(같은 날 반복 노출이 더 나쁘다).
  Future<bool> shouldShowToday() async {
    try {
      return await readOrNull(_key) != _todayKst();
    } catch (e) {
      debugPrint('[CheerAdPopup] 복원 실패: $e');
      return false;
    }
  }
}
