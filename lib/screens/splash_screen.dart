import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
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
  /// Keychain 접근 불가(잠금 상태 백그라운드 launch 등)로 부팅을 보류하면
  /// true — 포그라운드 복귀 시 [_bootstrap]을 재시도한다.
  bool _retryOnResume = false;

  /// 포그라운드인데도 Keychain 이 계속 실패할 때(기기 keychain 고장 등)의
  /// 지연 재시도 횟수. [_maxForegroundRetries]를 넘으면 포기하고 진행한다.
  int _foregroundRetries = 0;
  static const _maxForegroundRetries = 5;

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

  /// Keychain 접근 실패 시 재시도 예약. 백그라운드면 resumed 이벤트가
  /// 트리거지만, 이미 포그라운드면 그 이벤트가 안 오므로 지연 재시도로
  /// 커버한다 (계속 실패하면 포기하고 진행 — 스플래시에 갇히지 않게).
  void _scheduleRetry() {
    _retryOnResume = true;
    if (WidgetsBinding.instance.lifecycleState !=
        AppLifecycleState.resumed) {
      return;
    }
    if (_foregroundRetries >= _maxForegroundRetries) {
      _retryOnResume = false;
      _proceed(null);
      return;
    }
    _foregroundRetries++;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _retryOnResume) {
        _retryOnResume = false;
        _bootstrap();
      }
    });
  }

  Future<void> _bootstrap() async {
    final List<Object?> results;
    try {
      // 구 접근성(unlocked)으로 저장된 Keychain 항목을 잠금 중에도 읽히는
      // first_unlock_this_device 로 1회 이전. 미완료 상태에선 jwt read 가
      // 예외 없이 null 을 반환하므로(접근성 불일치 → notFound), 완료 전엔
      // 절대 jwt 로 로그인 여부를 판단하지 않는다.
      final migrated = await migrateKeychainAccessibility();
      if (!migrated) {
        _scheduleRetry();
        return;
      }
      // 첫 실행(마이그레이션 직후)이면 main()에서 미리 읽은 언어 설정이
      // 구 접근성 항목이라 null(→ko)로 폴백됐을 수 있다 — 다시 읽는다.
      await AppLanguage.instance.load();
      results = await Future.wait([
        Future<void>.delayed(const Duration(seconds: 2)),
        AuthService.instance.jwt,
      ]);
    } on PlatformException {
      // Keychain 접근 불가(-25308: 기기 잠금 + 백그라운드 launch 등).
      // '토큰 없음'이 아니므로 LoginScreen 으로 보내면 안 된다.
      _scheduleRetry();
      return;
    }
    _proceed(results[1] as String?);
  }

  /// [jwt] 유무에 따라 첫 화면으로 전환한다. 재시도 포기 시엔 null 로 호출.
  void _proceed(String? jwt) {
    if (!mounted) return;

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
    // 스토어 업데이트 팝업이 떴으면 코드푸시 안내는 생략 — 팝업 두 개는 과하다.
    _checkForUpdate().then((storePrompted) {
      if (!storePrompted) _promptPatchRestart();
    });
  }

  /// 앱스토어/플레이스토어 최신 버전을 조회해, 현재 버전보다 높으면
  /// [NarAlertDialog] 팝업을 띄운다. 확인 누르면 스토어로 이동.
  /// 팝업을 띄웠으면 true.
  Future<bool> _checkForUpdate() async {
    try {
      final upgrader = Upgrader(
        languageCode: AppLanguage.instance.isKo ? 'ko' : 'en',
      );
      await upgrader.initialize();
      if (!upgrader.isUpdateAvailable()) return false;

      // l10n 문자열과 스토어 URL 을 async 전에 캡처한다.
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return false;
      final l = AppLocalizations.of(ctx);
      if (l == null) return false;
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
      return true;
    } catch (e) {
      debugPrint('[Update] 업데이트 체크 실패: $e');
      return false;
    }
  }

  /// Shorebird 코드푸시 패치 안내. 패치는 이미 로딩된 Dart 코드에는 못 붙어서
  /// **다음 실행부터** 적용된다 — 받아둔 패치가 있으면 재실행을 안내한다
  /// (안 띄우면 앱을 며칠 안 죽이는 유저는 계속 구버전 코드로 남는다).
  /// iOS 는 앱이 스스로 종료·재실행할 방법이 없어 안내만, Android 는 종료까지.
  Future<void> _promptPatchRestart() async {
    final updater = ShorebirdUpdater();
    // shorebird release 로 빌드되지 않았거나 디버그면 업데이터가 없다.
    if (!updater.isAvailable) return;
    try {
      var status = await updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        // auto_update 가 이미 받는 중이면 여기서 실패할 수 있다 — 다음 실행에
        // 어차피 다시 받으므로 조용히 넘긴다.
        await updater.update();
        status = UpdateStatus.restartRequired;
      }
      if (status != UpdateStatus.restartRequired) return;

      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      final l = AppLocalizations.of(ctx);
      if (l == null) return;
      final confirmed = await showNarConfirmDialog(
        context: ctx,
        title: l.patchReadyTitle,
        message: Platform.isAndroid ? l.patchReadyMessageAndroid : l.patchReadyMessageIos,
        confirmLabel: Platform.isAndroid ? l.patchRestartNow : l.confirm,
      );
      if (confirmed == true && Platform.isAndroid) {
        await SystemNavigator.pop();
      }
    } catch (e) {
      debugPrint('[Patch] 코드푸시 확인 실패: $e');
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
