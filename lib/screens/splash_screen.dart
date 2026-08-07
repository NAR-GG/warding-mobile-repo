import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// 기기가 잠금해제되길 기다리는 폴링 타이머.
  ///
  /// 잠금 상태에서 launch 되면 `resumed` 가 이미 와 있어 라이프사이클
  /// 이벤트로는 잠금해제 시점을 알 수 없다 — 보호 데이터 가용 여부를
  /// 직접 주기적으로 확인한다.
  Timer? _unlockPoll;

  /// 보호 데이터가 열린 뒤에도 Keychain 이 실패할 때의 재시도 횟수.
  ///
  /// 잠금이 원인인 실패는 이 카운터를 쓰지 않는다 — 그건 시간이 해결하는
  /// 문제라 횟수로 끊으면 멀쩡한 로그인 사용자를 로그인 화면으로 보낸다.
  int _unlockedRetries = 0;
  static const _maxUnlockedRetries = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    _unlockPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 사용자가 앱을 실제로 열면 잠금은 이미 풀려 있다 — 폴링을 기다리지 않고
    // 곧바로 재시도한다(폴링은 그동안의 백그라운드 구간을 메우는 용도).
    if (state == AppLifecycleState.resumed && _retryOnResume) {
      _unlockPoll?.cancel();
      _retryOnResume = false;
      _bootstrap();
    }
  }

  /// Keychain 접근 실패 시 재시도를 예약한다.
  ///
  /// 실패 원인을 두 갈래로 나눠 다르게 다룬다. 기기 잠금 때문이면 시간이
  /// 해결하는 문제라 **횟수 제한 없이** 잠금해제를 기다리고, 잠금이 아닌데도
  /// 실패하면(기기 keychain 고장 등) 몇 번 재시도하다 포기한다.
  ///
  /// 잠금 상태를 라이프사이클로 판단하면 안 된다 — 잠금화면 위에서 launch
  /// (prewarming·백그라운드 푸시)돼도 iOS 는 `resumed` 를 보고한다. 그래서
  /// 예전 구현은 잠긴 기기를 '포그라운드'로 오해해 5초 만에 포기하고
  /// 로그인 화면으로 보냈다(-25308 이 로그아웃으로 체감된 경로).
  Future<void> _scheduleRetry() async {
    _retryOnResume = true;

    final unlocked = await _isProtectedDataAvailable();
    if (!mounted || !_retryOnResume) return;

    if (!unlocked) {
      // 잠금해제될 때까지 기다린다. 사용자가 앱을 열었을 땐 이미 풀려 있다.
      _startUnlockPolling();
      return;
    }

    // 잠금은 풀렸는데도 실패 — 여기서만 횟수로 끊는다.
    if (_unlockedRetries >= _maxUnlockedRetries) {
      _retryOnResume = false;
      _proceed(null);
      return;
    }
    _unlockedRetries++;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _retryOnResume) {
        _retryOnResume = false;
        _bootstrap();
      }
    });
  }

  /// Keychain 을 읽을 수 있는 상태(기기 잠금해제)인지.
  ///
  /// iOS 가 아니거나 조회 자체가 실패하면 true 로 본다 — 잠금이 원인이
  /// 아니라는 뜻이라 일반 재시도 경로로 보낸다.
  Future<bool> _isProtectedDataAvailable() async {
    if (kIsWeb || !Platform.isIOS) return true;
    try {
      return await secureStorage.isCupertinoProtectedDataAvailable() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// 잠금해제를 기다렸다가 [_bootstrap] 을 재시도한다.
  ///
  /// 잠금 중에는 화면도 보이지 않으므로 스플래시에 머물러도 사용자가 겪는
  /// 불편이 없다. 여기서 포기하고 로그인 화면을 띄우면, 나중에 사용자가
  /// 앱을 열었을 때 멀쩡한 토큰을 두고 로그아웃된 것처럼 보인다.
  void _startUnlockPolling() {
    _unlockPoll?.cancel();
    _unlockPoll = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || !_retryOnResume) {
        timer.cancel();
        return;
      }
      if (!await _isProtectedDataAvailable()) return;
      timer.cancel();
      if (!mounted || !_retryOnResume) return;
      _retryOnResume = false;
      _bootstrap();
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

  /// 첫 화면 전환을 이미 시작했는지. 부팅 경로가 둘(정상 부팅·재시도 포기)이라
  /// 잠금 재시도와 겹치면 [_proceed] 가 두 번 불릴 수 있는데, 그러면
  /// pushReplacement 가 두 번 돌아 첫 화면이 딥링크 상세 위로 튀어나온다.
  bool _proceeded = false;

  /// [jwt] 유무에 따라 첫 화면으로 전환한다. 재시도 포기 시엔 null 로 호출.
  void _proceed(String? jwt) {
    if (!mounted || _proceeded) return;
    _proceeded = true;

    // 이미 로그인된 상태면 앱 시작 시에도 FCM 토큰을 갱신·등록한다.
    if (jwt != null) unawaited(FcmService.instance.registerToken());
    final destination =
        jwt == null ? const LoginScreen() : const ScheduleScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
    // 보류해 둔 딥링크는 위 pushReplacement 가 실제로 반영된 뒤에 소비한다.
    //
    // pushReplacement 는 호출 즉시 끝나지 않는다 — 전환이 도는 동안 스택에는
    // 아직 스플래시가 남아 있어서, 바로 push 하면 곧 제거될 라우트 위에 상세가
    // 얹힌다. 그러면 전환이 끝나며 상세까지 같이 걷혀 "들어갔다가 튕겨나오고"
    // 첫 화면만 남는다(Live Activity 카드를 눌렀을 때의 증상).
    //
    // 다음 프레임으로 미루면 교체가 끝난 ScheduleScreen 위에 정상적으로 쌓인다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 콜드 스타트(종료 상태에서 알림 탭) 딥링크는 initMessaging() 시점엔
      // navigatorKey 가 아직 비어 있어 보류돼 있었다 — 첫 화면 분기 위에 push.
      FcmService.instance.consumePendingDeepLink();

      // 콜드 스타트 위젯·Live Activity 딥링크도 같은 이유로 보류돼 있었다.
      HomeWidgetService.markSplashReady();
    });

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
