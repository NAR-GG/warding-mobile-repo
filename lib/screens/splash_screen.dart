import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/nar_alert_dialog.dart';
import '../config/app_globals.dart';
import '../config/app_language.dart';
import '../config/secure_storage.dart';
import '../l10n/app_localizations.dart';
import '../repository/auth/auth_service.dart';
import '../repository/fcm/fcm_service.dart';
import '../styles/app_colors.dart';
import '../util/home_widget_service.dart';
import 'login/login_screen.dart';
import 'schedule/schedule_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with WidgetsBindingObserver {
  /// 잠금 상태 백그라운드 launch(iOS prewarming 등)에서 Keychain 접근이
  /// -25308로 실패하면 true — 포그라운드 복귀 시 [_bootstrap]을 재시도한다.
  bool _retryOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _retryOnResume) {
      _retryOnResume = false;
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    final List<Object?> results;
    try {
      // 구 접근성(unlocked)으로 저장된 Keychain 항목을 잠금 중에도 읽히는
      // first_unlock_this_device 로 1회 이전. jwt 읽기보다 먼저 실행해야 한다.
      await migrateKeychainAccessibility();
      results = await Future.wait([
        Future<void>.delayed(const Duration(seconds: 2)),
        AuthService.instance.jwt,
      ]);
    } on PlatformException {
      // Keychain 접근 불가(-25308: 기기 잠금 + 백그라운드 launch 등).
      // '토큰 없음'이 아니므로 LoginScreen 으로 보내면 안 된다 —
      // 포그라운드 복귀 때 재시도한다.
      _retryOnResume = true;
      return;
    }
    if (!mounted) return;

    final jwt = results[1] as String?;
    // 이미 로그인된 상태면 앱 시작 시에도 FCM 토큰을 갱신·등록한다.
    if (jwt != null) unawaited(FcmService.instance.registerToken());
    final destination =
        jwt == null ? const LoginScreen() : const ScheduleScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
    // 콜드 스타트(종료 상태에서 알림 탭) 딥링크는 initMessaging() 시점엔
    // navigatorKey 가 아직 비어 있어 보류돼 있었다 — 첫 화면 분기 위에 push.
    FcmService.instance.consumePendingDeepLink();

    // 콜드 스타트 위젯 딥링크(필터 등)도 같은 이유로 보류돼 있었다 — 여기서 소비.
    // (스플래시 내비게이션과 겹쳐 화면이 두 번 열리는 것처럼 보이는 문제 방지.)
    HomeWidgetService.markSplashReady();

    // 화면 전환 후 업데이트 체크 (팝업은 NarAlertDialog 로 띄운다).
    _checkForUpdate();
  }

  /// 앱스토어/플레이스토어 최신 버전을 조회해, 현재 버전보다 높으면
  /// [NarAlertDialog] 팝업을 띄운다. 확인 누르면 스토어로 이동.
  Future<void> _checkForUpdate() async {
    try {
      final upgrader = Upgrader(
        languageCode: AppLanguage.instance.isKo ? 'ko' : 'en',
      );
      await upgrader.initialize();
      if (!upgrader.isUpdateAvailable()) return;

      // l10n 문자열과 스토어 URL 을 async 전에 캡처한다.
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      final l = AppLocalizations.of(ctx);
      if (l == null) return;
      final title = l.updateAvailableTitle;
      final message = l.updateAvailableMessage;
      final confirmLabel = l.updateNow;

      final confirmed = await showNarConfirmDialog(
        context: ctx,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      );
      if (confirmed == true) {
        const iosUrl = 'https://apps.apple.com/app/id6786755741';
        const androidUrl = 'https://play.google.com/store/apps/details?id=com.warding.app';
        final url = Platform.isIOS ? iosUrl : androidUrl;
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[Update] 업데이트 체크 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 뒤에 깔리는 blur 글로우 레이어 (opacity로 빛 세기 조절)
            Opacity(
              opacity: 0.5,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 14.5, sigmaY: 14.5),
                child: SvgPicture.asset(
                  'assets/images/warding.svg',
                  width: 240,
                  height: 48,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            // 앞의 선명한 로고
            SvgPicture.asset(
              'assets/images/warding.svg',
              width: 240,
              height: 48,
            ),
          ],
        ),
      ),
    );
  }
}
