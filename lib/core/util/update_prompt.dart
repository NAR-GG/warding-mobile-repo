import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:warding/core/ui/nar_alert_dialog.dart';
import 'package:warding/core/config/app_globals.dart';
import 'package:warding/core/config/app_language.dart';
import 'package:warding/l10n/app_localizations.dart';

const String kIosStoreUrl = 'https://apps.apple.com/app/id6786755741';
const String kAndroidStoreUrl =
    'https://play.google.com/store/apps/details?id=com.warding.app';

/// 스토어 설명에 적힌 **최소 버전보다 설치 버전이 낮을 때만** [NarAlertDialog]
/// 팝업을 띄운다. 확인을 누르면 스토어로 보낸다.
///
/// 예전에는 스토어에 더 높은 버전만 있으면 띄웠다. 주 2회꼴 배포(8/9~10/27 동안
/// 24개 버전, 그중 15개는 Dart 만 바뀐 일반 배포)와 겹쳐 사용자는 거의 매번
/// 팝업을 봤고, **팝업을 닫는 습관**이 생기면 정작 올려야 하는 버전에서도 같이
/// 무시된다. 일반 배포는 스토어 자동 업데이트에 맡기고, 꼭 올려야 하는 릴리즈만
/// 스토어 설명에 최소 버전 태그를 단다(방법은 `distribution/README.md`).
/// **태그가 없으면 팝업은 뜨지 않는다.**
///
/// `isUpdateAvailable()`(스토어 버전 > 설치 버전)도 함께 본다. **이미 최신인데
/// 태그만 더 높은 경우**에 스토어로 보내도 받을 게 없는 팝업이 뜨는 것을 막는다.
///
/// 이 가드가 막지 못하는 것 둘:
/// - 태그를 **스토어에 아직 없는 버전**으로 적은 경우(예: 태그 1.0.50 / 스토어
///   1.0.43 / 설치 1.0.42). 설치 버전이 스토어보다 낮으니 `isUpdateAvailable()` 은
///   true 고, 사용자는 올려도 태그에 못 닿아 **팝업이 계속 뜬다.** 태그는 반드시
///   이미 출시된 버전 이하로 적어야 한다.
/// - 2026-10-27 사고(스토어 표시 1.0.41 / 실제 바이너리 1.0.39)처럼 표시 버전과
///   바이너리가 어긋난 경우. 여기는 스토어 **메타데이터**만 보기 때문이다. 그쪽
///   방어는 릴리즈 파이프라인의 ASC 직접 조회가 맡는다.
///
/// `countryCode` 를 안 주면 upgrader 가 미국 스토어를 조회한다. 와딩은 한국
/// 스토어에만 있어서 조회 결과가 비고, 팝업이 영영 안 떴다.
///
/// `durationUntilAlertAgain` 은 `Duration.zero` 다 — 최소 버전 미만이면 꼭 올려야
/// 하는 상황이라 앱을 켤 때마다 알린다. 일반 배포에서는 애초에 팝업이 뜨지 않으니
/// 간격을 둘 이유가 없다.
///
/// 테스트를 위해 조회([upgraderFactory])·확인 팝업([confirm])·스토어 이동
/// ([openStore])을 주입할 수 있다. 실제 앱은 기본 구현을 쓴다.
Future<void> checkForUpdate({
  Upgrader Function()? upgraderFactory,
  Future<bool?> Function(BuildContext context, UpdatePromptText text)? confirm,
  Future<void> Function(String url)? openStore,
}) async {
  try {
    final upgrader = (upgraderFactory ?? _defaultUpgrader)();
    await upgrader.initialize();
    if (!upgrader.isUpdateAvailable() || !upgrader.belowMinAppVersion()) {
      return;
    }

    // await 이후에 navigatorKey 에서 context 를 새로 얻는다 — 이 함수가 받아 둔
    // context 를 async gap 을 넘겨 들고 오는 게 아니라, 지금 살아있는 navigator
    // 의 것을 그때그때 읽으므로 안전하다.
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final l = AppLocalizations.of(ctx);
    if (l == null) return;
    final text = UpdatePromptText(
      title: l.updateAvailableTitle,
      message: l.updateAvailableMessage,
      confirmLabel: l.updateNow,
    );

    final confirmed = await (confirm ?? _defaultConfirm)(ctx, text);
    if (confirmed != true) return;
    await (openStore ?? _defaultOpenStore)(
      Platform.isIOS ? kIosStoreUrl : kAndroidStoreUrl,
    );
  } catch (e) {
    debugPrint('[Update] 업데이트 체크 실패: $e');
  }
}

/// 팝업에 쓸 현지화 문구.
class UpdatePromptText {
  const UpdatePromptText({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
}

Upgrader _defaultUpgrader() => Upgrader(
  languageCode: AppLanguage.instance.isKo ? 'ko' : 'en',
  countryCode: 'KR',
  durationUntilAlertAgain: Duration.zero,
  debugLogging: kDebugMode,
);

Future<bool?> _defaultConfirm(BuildContext context, UpdatePromptText text) =>
    showNarConfirmDialog(
      context: context,
      title: text.title,
      message: text.message,
      confirmLabel: text.confirmLabel,
    );

Future<void> _defaultOpenStore(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
