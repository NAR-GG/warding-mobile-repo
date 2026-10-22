import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../repository/ad/ad_repository.dart';
import '../repository/preference/cheer_ad_popup_preference_repository.dart';
import '../screens/cheer_ad/cheer_ad_screen.dart';
import '../styles/app_colors.dart';
import 'cheer_ad_banner.dart';

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
/// 광고 이미지를 직접 눌러 들어간다 — 광고 자리 자체가 버튼이라 자세히 보기 버튼을
/// 따로 두지 않는다.
///
/// 가이드 팝업이 쓰는 공용 [showNarPopup] 은 안쪽 여백 24 에 어두운 버튼이라 광고가
/// 작아 보인다. 광고는 이미지를 가장자리까지 채우고 하단에 어두운 버튼 바를 두는 전용
/// 레이아웃([_AdPopupDialog])으로 띄운다(공용 팝업·가이드 팝업은 건드리지 않는다).
Future<void> _showCheerAdPopup(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  final scale = MediaQuery.of(context).size.width.clamp(320.0, 430.0) / 375;
  final navigator = Navigator.of(context);
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.narPopupBarrier,
    builder: (_) => _AdPopupDialog(
      scale: scale,
      image: _PopupAdCard(scale: scale, navigator: navigator),
      dismissLabel: l.cheerAdPopupDismissToday,
      closeLabel: l.cheerAdPopupClose,
      onDismissToday: () async {
        // 저장을 끝낸 뒤에 닫는다. 먼저 닫으면 _showing 이 풀려서, 저장이 끝나기
        // 전에 홈으로 되돌아온 경우 옛 날짜를 읽고 팝업이 다시 뜬다.
        await CheerAdPopupPreferenceRepository.instance.markDismissedToday();
        navigator.pop();
      },
      onClose: () => navigator.pop(),
    ),
  );
}

/// 광고 팝업 틀. 위는 광고 이미지(여백 없음), 아래는 어두운 버튼 바 — 왼쪽 '오늘 하루
/// 보지 않기', 오른쪽 '닫기' 를 가는 세로선으로 나눈다.
class _AdPopupDialog extends StatelessWidget {
  const _AdPopupDialog({
    required this.scale,
    required this.image,
    required this.dismissLabel,
    required this.closeLabel,
    required this.onDismissToday,
    required this.onClose,
  });

  final double scale;
  final Widget image;
  final String dismissLabel;
  final String closeLabel;
  final VoidCallback onDismissToday;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w600,
      fontSize: 15 * scale,
      color: AppColors.narText,
    );
    Widget button(String text, VoidCallback onTap) => Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(
          // 긴 문구가 두 줄로 꺾이지 않게 줄여 맞춘다.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale),
              child: Text(text, style: label, maxLines: 1),
            ),
          ),
        ),
      ),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 335 * scale),
        // 이미지 위쪽이 어두우면 둥근 모서리가 딤 배경에 묻혀 radius 가 안 먹은 것처럼 보인다 —
        // 얇은 테두리를 이미지 위에 덧그려 윤곽을 드러낸다.
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16 * scale),
            border: Border.all(color: AppColors.narWhiteBorder15),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16 * scale),
            child: ColoredBox(
              color: AppColors.narDark800,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  image,
                  Container(
                    height: 56 * scale,
                    color: AppColors.narDark600,
                    child: Row(
                      children: [
                        button(dismissLabel, onDismissToday),
                        Container(
                          width: 1,
                          height: 24 * scale,
                          color: AppColors.narLine,
                        ),
                        button(closeLabel, onClose),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        if (snapshot.connectionState != ConnectionState.done) {
          return const AdLoadingSlot(slot: CheerAdSlot.popup);
        }
        final ad = snapshot.data;
        if (ad != null) {
          // 등록 광고는 자기 이동 주소를 갖는다(RegisteredAdCard 가 탭을 처리).
          return RegisteredAdCard(
            ad: ad,
            scale: scale,
            slot: CheerAdSlot.popup,
            radius: 0,
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
          child: CheerAdBannerCard(
            scale: scale,
            slot: CheerAdSlot.popup,
            radius: 0,
          ),
        );
      },
    );
  }
}
