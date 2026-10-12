import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../repository/preference/cheer_ad_popup_preference_repository.dart';
import '../screens/cheer_ad/cheer_ad_screen.dart';
import 'cheer_ad_banner.dart';
import 'nar_button.dart';
import 'nar_popup_dialog.dart';

/// 팝업이 지금 떠 있는지(겹침 방지). 앱을 다시 켜기 전까지 한 세션에 한 번만 띄운다.
bool _showing = false;
bool _shownThisSession = false;

/// 홈 진입 시 '우리 선수 응원 광고 신청' 팝업을 하루(KST) 한 번, 콜드스타트당 한 번만
/// 띄운다. 가이드 팝업이 뜬 세션에서는 호출하지 않는다(호출 쪽에서 가린다).
Future<void> maybeShowCheerAdPopup(BuildContext context) async {
  if (_showing || _shownThisSession) {
    debugPrint('[CheerAdPopup] 이번 실행에서 이미 떠서 건너뜀');
    return;
  }
  // 디버그에서는 하루 한 번 제한을 무시한다 — 확인하려고 앱을 켤 때마다 뜬다.
  if (!kDebugMode &&
      !await CheerAdPopupPreferenceRepository.instance.shouldShowToday()) {
    debugPrint('[CheerAdPopup] 오늘 이미 떠서 건너뜀');
    return;
  }
  if (!context.mounted) return;
  _showing = true;
  _shownThisSession = true;
  try {
    await CheerAdPopupPreferenceRepository.instance.markShownToday();
    if (!context.mounted) return;
    await _showCheerAdPopup(context);
  } finally {
    _showing = false;
  }
}

Future<void> _showCheerAdPopup(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  final scale = MediaQuery.of(context).size.width.clamp(320.0, 430.0) / 375;
  return showNarPopup<void>(
    context: context,
    child: CheerAdBannerCard(scale: scale, slot: CheerAdSlot.popup),
    actions: [
      NarPopupAction(
        label: l.cheerAdPopupClose,
        onPressed: () => Navigator.of(context).pop(),
      ),
      NarPopupAction(
        label: l.cheerAdPopupConfirm,
        variant: NarButtonVariant.type1,
        onPressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CheerAdScreen()),
          );
        },
      ),
    ],
  );
}
