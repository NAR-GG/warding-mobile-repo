import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../repository/ad/ad_repository.dart';
import '../repository/preference/cheer_ad_popup_preference_repository.dart';
import '../screens/cheer_ad/cheer_ad_screen.dart';
import 'cheer_ad_banner.dart';
import 'nar_button.dart';
import 'nar_popup_dialog.dart';

/// 팝업이 지금 떠 있는지(겹침 방지).
bool _showing = false;

/// 홈 진입 시 '우리 선수 응원 광고 신청' 팝업을 띄운다.
///
/// '오늘 하루 보지 않기' 를 누르지 않는 한 홈에 들어올 때마다 계속 띄운다 — 그냥
/// 닫은 것은 '관심 없다'는 뜻이 아니다. 그 버튼을 누른 날에만 그날치를 건너뛴다.
/// 가이드 팝업이 뜬 세션에서는 호출하지 않는다(호출 쪽에서 가린다).
Future<void> maybeShowCheerAdPopup(BuildContext context) async {
  if (_showing) {
    debugPrint('[CheerAdPopup] 이미 떠 있어 건너뜀');
    return;
  }
  // 디버그에서는 '오늘 하루 보지 않기' 기록을 무시한다 — 확인하려고 앱을 켤 때마다 뜬다.
  if (!kDebugMode &&
      !await CheerAdPopupPreferenceRepository.instance.shouldShowToday()) {
    debugPrint('[CheerAdPopup] 오늘 하루 보지 않기를 눌러서 건너뜀');
    return;
  }
  if (!context.mounted) return;
  _showing = true;
  try {
    await _showCheerAdPopup(context);
  } finally {
    _showing = false;
  }
}

/// 하단 버튼은 '오늘 하루 보지 않기'(왼쪽)·'닫기'(오른쪽) 둘뿐이고, 신청 화면으로는
/// 배너 카드를 직접 눌러 들어간다 — 광고 자리 자체가 버튼이라 자세히 보기 버튼을
/// 따로 두지 않는다.
Future<void> _showCheerAdPopup(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  final scale = MediaQuery.of(context).size.width.clamp(320.0, 430.0) / 375;
  final navigator = Navigator.of(context);
  return showNarPopup<void>(
    context: context,
    child: _PopupAdCard(scale: scale, navigator: navigator),
    actions: [
      NarPopupAction(
        label: l.cheerAdPopupDismissToday,
        onPressed: () async {
          // 먼저 닫는다 — 저장을 기다리는 사이 버튼이 먹지 않는 것처럼 보인다.
          navigator.pop();
          await CheerAdPopupPreferenceRepository.instance.markDismissedToday();
        },
      ),
      NarPopupAction(
        label: l.cheerAdPopupClose,
        variant: NarButtonVariant.type1,
        onPressed: () => navigator.pop(),
      ),
    ],
  );
}

/// 팝업 안 카드. 백오피스에 `popup` 자리 광고가 있으면 그 광고를(탭하면 광고주
/// 주소로), 없으면 모집 배너를(탭하면 신청 화면으로) 띄운다.
class _PopupAdCard extends StatefulWidget {
  const _PopupAdCard({required this.scale, required this.navigator});

  final double scale;
  final NavigatorState navigator;

  @override
  State<_PopupAdCard> createState() => _PopupAdCardState();
}

class _PopupAdCardState extends State<_PopupAdCard> {
  late final Future<Ad?> _ad = AdRepository.instance.forPlacement('popup');

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return FutureBuilder<Ad?>(
      future: _ad,
      builder: (context, snapshot) {
        final ad = snapshot.data;
        if (ad != null) {
          // 등록 광고는 자기 이동 주소를 갖는다(RegisteredAdCard 가 탭을 처리).
          return RegisteredAdCard(
            ad: ad,
            scale: scale,
            slot: CheerAdSlot.popup,
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.navigator.pop();
            widget.navigator.push(
              MaterialPageRoute<void>(builder: (_) => const CheerAdScreen()),
            );
          },
          child: CheerAdBannerCard(scale: scale, slot: CheerAdSlot.popup),
        );
      },
    );
  }
}
