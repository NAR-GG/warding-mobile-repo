import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/nar_alert_dialog.dart';
import '../config/app_globals.dart';
import '../config/app_language.dart';
import '../l10n/app_localizations.dart';

const String kIosStoreUrl = 'https://apps.apple.com/app/id6786755741';
const String kAndroidStoreUrl =
    'https://play.google.com/store/apps/details?id=com.warding.app';

/// 스토어 최신 버전을 조회해 현재 버전보다 높으면 [NarAlertDialog] 팝업을 띄우고,
/// 확인을 누르면 스토어로 보낸다.
///
/// `countryCode` 를 안 주면 upgrader 가 미국 스토어를 조회한다. 와딩은 한국
/// 스토어에만 있어서 조회 결과가 비고, `isUpdateAvailable()` 이 조용히 false 를
/// 돌려줘 팝업이 영영 안 떴다.
///
/// **"어떤 버전에 팝업을 띄울지" 는 아직 이 함수가 결정하지 않는다.** 지금은
/// 스토어에 더 높은 버전이 있으면 띄운다 — 주 2회꼴 배포와 겹쳐 사용자가 거의
/// 매번 팝업을 보는 문제가 있고, 그 판단을 스토어 설명의 최소 버전 태그로
/// 옮기는 작업이 PR #428 에서 따로 진행 중이다(`upgrader` 의
/// `belowMinAppVersion()`). 그 로직이 들어올 자리가 이 함수다.
///
/// `durationUntilAlertAgain` 은 넘기지 않아 upgrader 기본값(3일)을 쓴다. 예전에는
/// `Duration.zero` 로 **앱을 켤 때마다** 알렸는데, 매 실행 알림은 사용자가 팝업을
/// 닫는 습관을 만들어 정작 올려야 하는 버전에서도 같이 무시된다.
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
    if (!upgrader.isUpdateAvailable()) return;

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
