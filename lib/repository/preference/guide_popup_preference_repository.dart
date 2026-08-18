import 'package:flutter/foundation.dart';

import '../../config/secure_storage.dart';

/// 진입 시 뜨는 사용 가이드 팝업을 이미 봤는지 기기에 저장한다.
///
/// 저장하는 값은 본 시점의 가이드 버전([GuidePopupPreferenceRepository.currentVersion])
/// 이다. 가이드 내용을 갈아끼울 때 버전을 올리면, 이전 가이드를 본 사용자에게도
/// 새 가이드가 한 번 더 뜬다 — bool 로 저장하면 그 구분이 안 된다.
///
/// [NoticePreferenceRepository] 와 같은 이유로 이미 설치된 secure storage 를
/// 재사용한다.
class GuidePopupPreferenceRepository {
  GuidePopupPreferenceRepository._();
  static final GuidePopupPreferenceRepository instance =
      GuidePopupPreferenceRepository._();

  static const _key = 'seen_guide_popup_version';

  /// 지금 앱에 담긴 가이드의 버전. 가이드 이미지·문구를 교체할 때 올린다.
  static const int currentVersion = 1;

  /// 이번 버전의 가이드를 봤다고 기록한다.
  Future<void> markSeen() async {
    try {
      await writeWithDuplicateRecovery(key: _key, value: '$currentVersion');
    } catch (e) {
      debugPrint('[GuidePopup] 저장 실패: $e');
    }
  }

  /// 이번 버전의 가이드를 띄워야 하는지. 저장값이 없거나 더 낮은 버전이면 띄운다.
  ///
  /// 읽기에 실패하면 띄우지 않는다 — 이미 본 사용자에게 다시 띄우는 쪽이
  /// 한 번 못 보여주는 것보다 나쁘다.
  Future<bool> shouldShow() async {
    try {
      final raw = await readOrNull(_key);
      if (raw == null || raw.isEmpty) return true;
      final dismissed = int.tryParse(raw);
      if (dismissed == null) return true;
      return dismissed < currentVersion;
    } catch (e) {
      debugPrint('[GuidePopup] 복원 실패: $e');
      return false;
    }
  }
}
