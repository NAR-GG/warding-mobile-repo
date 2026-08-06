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
import '../repository/preference/filter_preference_repository.dart';
import '../repository/schedule/schedule_repository.dart';
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

  /// 로고가 최소한 이만큼은 보이도록 잡아두는 시간.
  ///
  /// 예전엔 2초를 무조건 기다렸다. Keychain 조회는 수십 ms 라 나머지 시간은
  /// 순수한 대기였고, 그 뒤에야 일정 화면이 캘린더를 부르기 시작해
  /// 사용자는 '2초 + API' 를 겪었다. 지금은 이 시간 동안 캘린더를 미리
  /// 받아두므로(=[_prefetchCalendar]) 대기가 실제 로딩과 겹친다.
  static const _minSplashDuration = Duration(milliseconds: 600);

  Future<void> _bootstrap() async {
    final String? jwt;
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

      // 스플래시가 떠 있는 동안 첫 화면(일정)의 캘린더를 미리 받아둔다.
      // 실패해도 화면 진입을 막지 않는다 — 그때는 일정 화면이 평소대로
      // 직접 부르고 에러 UI 도 거기서 처리한다.
      final prefetch = _prefetchCalendar();

      final results = await Future.wait([
        Future<void>.delayed(_minSplashDuration),
        AuthService.instance.jwt,
      ]);
      jwt = results[1] as String?;

      // 프리페치가 최소 표시 시간 안에 끝났으면 일정 화면은 캐시를 그대로
      // 쓴다. 아직이면 기다리지 않고 넘어간다 — 화면 진입을 느린 네트워크에
      // 묶어두면 프리페치가 오히려 손해다. 이 경우에도 요청은 이미 떠 있어
      // 일정 화면의 조회가 그 요청에 합류한다.
      unawaited(prefetch);
    } on PlatformException {
      // Keychain 접근 불가(-25308: 기기 잠금 + 백그라운드 launch 등).
      // '토큰 없음'이 아니므로 LoginScreen 으로 보내면 안 된다.
      _scheduleRetry();
      return;
    }
    _proceed(jwt);
  }

  /// 일정 화면이 진입 직후 부를 캘린더를 미리 받아 캐시에 채운다.
  ///
  /// [ScheduleViewModel] 과 **같은 조건**(저장된 필터·이번 달)으로 불러야
  /// 캐시가 맞는다 — 조건이 어긋나면 프리페치는 버려지고 화면은 새로 받는다.
  Future<void> _prefetchCalendar() async {
    try {
      // 아래 기본값·복원 규칙은 ScheduleViewModel._init() 과 같아야 한다.
      // 조건이 어긋나면 URL 이 달라져 캐시가 빗나가고 프리페치가 헛돈다.
      List<String> leagues = const ['ALL'];
      List<int> teamIds = const [];
      final saved = await FilterPreferenceRepository.instance
          .load(FilterPreferenceRepository.scheduleKey);
      if (saved != null) {
        final savedLeagues = (saved['leagues'] as List?)?.cast<String>();
        leagues =
            savedLeagues != null && savedLeagues.isNotEmpty ? savedLeagues : ['ALL'];
        teamIds = (saved['teamIds'] as List?)?.cast<int>() ?? const [];
      }
      await ScheduleRepository.instance.fetchCalendar(
        DateTime.now(),
        leagues: leagues,
        teamIds: teamIds,
      );
    } catch (e) {
      debugPrint('[Splash] 캘린더 프리페치 실패(무시): $e');
    }
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
