import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../repository/preference/guide_popup_preference_repository.dart';
import '../screens/guide/guide_screen.dart';
import '../screens/guide/page/guide_page_1.dart';
import '../screens/guide/page/guide_page_2.dart';
import '../screens/guide/page/guide_page_3.dart';
import '../screens/guide/page/guide_page_4.dart';
import '../screens/guide/page/guide_page_5.dart';
import '../screens/guide/page/guide_page_6.dart';
import '../styles/app_colors.dart';
import 'nar_button.dart';
import 'nar_popup_dialog.dart';

/// 앱에 담긴 가이드 이미지 경로.
///
/// 가이드를 갈아끼울 때는 이 경로와
/// [GuidePopupPreferenceRepository.currentVersion] 을 함께 올린다 — 버전을
/// 올리지 않으면 이전 가이드를 껐던 사용자에게 새 가이드가 뜨지 않는다.
const String _guideImageAsset = 'assets/images/guide.png';

/// 시안 기준 이미지 크기(185×331).
const double _guideImageWidth = 185;
const double _guideImageHeight = 331;

/// 진입 팝업이 지금 떠 있는지. 같은 팝업이 겹쳐 뜨는 것을 막는다.
bool _showing = false;

/// 앱 진입 시 사용 가이드 팝업을 '아직 안 봤다면' 띄운다.
///
/// 진입 화면에서 한 번 호출한다. 이미 본 적이 있으면 아무것도 하지 않으므로
/// 호출 쪽에서 조건을 따로 두지 않아도 된다.
///
/// 어느 버튼으로 닫든 '봤다'고 기록해 다음 진입부터는 뜨지 않는다 —
/// '다음에 볼게요'도 마찬가지다. 팝업 문구가 마이페이지에서 다시 볼 수 있다고
/// 안내하고 있어, 미룬 사용자에게 매번 다시 내미는 쪽이 오히려 거슬린다.
///
/// 서버와 통신하지 않는다 — 가이드 내용은 앱에 담겨 있고, 봤는지 여부만
/// 기기에 저장한다.
Future<void> maybeShowGuidePopup(BuildContext context) async {
  // '봤다'는 기록은 팝업을 닫은 뒤에야 남는다. 그 사이 다른 탭을 거쳐
  // 진입 화면이 다시 만들어지면 이 함수가 또 불려 팝업이 겹친다.
  if (_showing) return;
  if (!await GuidePopupPreferenceRepository.instance.shouldShow()) return;
  if (!context.mounted) return;
  _showing = true;
  try {
    await showGuidePopup(context);
  } finally {
    _showing = false;
  }
  await GuidePopupPreferenceRepository.instance.markSeen();
}

/// 사용 가이드 팝업을 조건 없이 띄운다.
///
/// '마이페이지 > 와딩 사용가이드'처럼 사용자가 직접 열 때 쓴다. 이 경로로
/// 열었을 때는 '다음에 볼게요'를 노출하지 않는다 — 직접 찾아 들어온 사용자에게
/// 미루기 선택지를 내밀 이유가 없다.
///
/// 여기서는 '봤다'고 기록하지 않는다. 기록은 진입 팝업([maybeShowGuidePopup])이
/// 자동으로 뜬 경우에만 의미가 있다.
Future<void> showGuidePopup(
  BuildContext context, {
  bool allowPostpone = true,
}) {
  final l = AppLocalizations.of(context)!;
  return showNarPopup<void>(
    context: context,
    gradientLabel: l.guidePopupBadge,
    title: l.guidePopupTitle,
    message: l.guidePopupMessage,
    child: const _GuideImage(),
    actions: [
      if (allowPostpone)
        NarPopupAction(
          label: l.guidePopupDismiss,
          onPressed: () => Navigator.of(context).pop(),
        ),
      NarPopupAction(
        label: l.guidePopupConfirm,
        variant: NarButtonVariant.type1,
        onPressed: () {
          Navigator.of(context).pop();
          openGuideScreen(context);
        },
      ),
    ],
  );
}

/// 전체화면 사용 가이드 캐러셀을 연다.
Future<void> openGuideScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => GuideScreen(
        pages: [
          guidePage1(context),
          guidePage2(context),
          guidePage3(context),
          guidePage4(context),
          guidePage5(context),
          guidePage6(context),
        ],
      ),
    ),
  );
}

/// 가이드 이미지. 에셋이 아직 없어도 팝업 전체가 깨지지 않도록 자리만 잡아 둔다.
class _GuideImage extends StatelessWidget {
  const _GuideImage();

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.of(context).size.width.clamp(320.0, 430.0) / 375;
    return Image.asset(
      _guideImageAsset,
      width: _guideImageWidth * scale,
      height: _guideImageHeight * scale,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Container(
        width: _guideImageWidth * scale,
        height: _guideImageHeight * scale,
        decoration: BoxDecoration(
          color: AppColors.narDark600,
          borderRadius: BorderRadius.circular(8 * scale),
        ),
      ),
    );
  }
}
