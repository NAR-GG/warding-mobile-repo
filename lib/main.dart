import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'config/api_config.dart';
import 'config/app_globals.dart';
import 'config/app_language.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'repository/fcm/fcm_service.dart';
import 'repository/live_activity/live_activity_logo_prefetcher.dart';
import 'repository/live_activity/live_activity_service.dart';
import 'repository/live_activity/live_match_activity_controller.dart';
import 'repository/notification/live_match_notification_store.dart';
import 'repository/notification/solo_rank_notification_store.dart';
import 'screens/splash_screen.dart';
import 'styles/app_colors.dart';
import 'util/home_widget_service.dart';

/// 홈 화면 위젯 백그라운드 갱신 콜백.
///
/// iOS Background App Refresh 또는 WidgetKit 타임라인 갱신 시 호출된다.
/// 별도 isolate 에서 실행되므로 최상위 함수여야 한다.
@pragma('vm:entry-point')
Future<void> _homeWidgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidgetService.init();
  await HomeWidgetService.handleBackgroundWidgetAction(uri);
}

/// 앱이 백그라운드/종료 상태일 때 도착하는 FCM 메시지 핸들러.
///
/// 별도 isolate 에서 실행되므로 최상위 함수여야 하고 `vm:entry-point` 가 필요하다.
/// 알림(notification) 페이로드가 있으면 시스템이 자동으로 알림을 표시한다.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] 백그라운드 메시지: ${message.messageId}');
  // 백그라운드/종료 상태에서 받은 솔랭·라이브 경기 알림도 마이구독 피드에 남긴다.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await SoloRankNotificationStore.instance.addFromFcmData(message.data);
    await LiveMatchNotificationStore.instance.addFromFcmData(
      message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  } catch (e) {
    debugPrint('[FCM] 백그라운드 저장 실패: $e');
  }
}

/// Firebase 초기화 → 백그라운드 메시지 핸들러 등록 → FCM 포그라운드 준비.
/// 셋이 서로 순서 의존이 있어(핸들러 등록·initMessaging 모두 Firebase 초기화가
/// 먼저 끝나야 함) 하나로 묶어, [main] 에서 다른 무관한 초기화와 병렬로 돌린다.
Future<void> _initFirebaseMessaging() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // 포그라운드 알림 표시·알림 탭 핸들링을 준비한다 (토큰 등록은 로그인 후).
  await FcmService.instance.initMessaging();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase/FCM 준비, 언어 설정 로드, 홈 위젯 App Group 설정은 서로 의존하지
  // 않는데 예전엔 순서대로 await 해서 앱을 켤 때마다 첫 프레임이 그만큼
  // 늦어졌다. 동시에 돌려 가장 느린 하나의 시간만 걸리게 한다.
  //
  // 실패·지연은 삼켜야 한다. 여기서 예외가 나거나 응답이 안 오면 runApp 이
  // 아예 호출되지 않아 화면이 영원히 검게 남는다 — 사용자에겐 '앱이 안 열림'
  // 이고, 스토어 심사에선 손상된 기능(로드 문제)으로 리젝된다. 알림·위젯이
  // 준비되지 않은 앱이 열리는 게 안 열리는 앱보다 낫다.
  try {
    await Future.wait([
      _initFirebaseMessaging(),
      AppLanguage.instance.load(),
      HomeWidgetService.init(),
    ]).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('[main] 시작 초기화 실패·지연(무시하고 앱은 띄운다): $e');
  }
  KakaoSdk.init(nativeAppKey: ApiConfig.kakaoNativeAppKey);
  // 백그라운드 위젯 갱신 콜백 등록
  HomeWidget.registerInteractivityCallback(_homeWidgetBackgroundCallback);
  // 앱 시작 시 위젯에 최신 캘린더 데이터 전달 (경기일정 탭 안 들어가도 동작)
  HomeWidgetService.refreshFromApi();

  // 위젯 딥링크: MethodChannel로 Swift에서 전달받음
  HomeWidgetService.listenWidgetActions();

  if (kReleaseMode) {
    // Sentry 초기화도 runApp 앞을 막고 있다 — 게다가 릴리즈 전용이라 디버그
    // 실행으로는 절대 드러나지 않는다. 실패하든 늦든 앱은 떠야 하므로,
    // appRunner 가 돌았는지를 보고 안 돌았으면 Sentry 없이 직접 띄운다.
    var started = false;
    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = const String.fromEnvironment(
            'SENTRY_DSN',
            defaultValue: 'https://47b58c932607203cb2906e7410cfc3de@o4511782525534208.ingest.us.sentry.io/4511782542245889',
          );
          options.environment = const String.fromEnvironment(
            'APP_ENV',
            defaultValue: 'production',
          );
          options.sendDefaultPii = true;
          // 비용 절감을 위해 트레이스·프로파일 샘플링 비율을 낮춘다.
          options.tracesSampleRate = 0.1;
          options.profilesSampleRate = 0.1;
          // 민감 정보 마스킹
          options.beforeSend = (event, hint) {
            event.request?.headers.remove('Authorization');
            return event;
          };
        },
        appRunner: () {
          started = true;
          runApp(SentryWidget(child: const MyApp()));
        },
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[main] Sentry 초기화 실패·지연: $e');
    }
    if (!started) runApp(const MyApp());
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 앱 시작 시 잘못 남은 실시간 카드를 정리한다. 카드 생성·갱신·종료는
    // 서버가 APNs 로 처리하고, 앱은 서버가 못 닫는(토큰 미등록) 카드만 치운다.
    liveMatchActivityController.dismissStaleCards();

    // push-to-start 토큰을 관찰해 서버에 올린다. 이게 등록돼야 앱이 꺼져
    // 있어도 서버가 세트 시작에 맞춰 카드를 직접 만든다.
    LiveActivityService.instance.observePushToStartToken();

    // 서버가 만든 카드는 앱 없이 렌더되므로 로고를 미리 저장해 둬야 한다.
    // 이미 받아둔 팀은 존재 확인만 하고 넘어간다.
    liveActivityLogoPrefetcher.prefetchLeague();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 포그라운드로 돌아올 때마다 고착 카드가 없는지 다시 살핀다.
    if (state == AppLifecycleState.resumed) {
      liveMatchActivityController.dismissStaleCards();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        final locale = AppLanguage.instance.isKo
            ? const Locale('ko')
            : const Locale('en');
        return MaterialApp(
          title: 'Warding',
          navigatorKey: navigatorKey,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [SentryNavigatorObserver()],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            scaffoldBackgroundColor: AppColors.narDark800,
          ),
          home: const SplashScreen(),
          // 이 앱은 named route 를 쓰지 않고 `home:` + Navigator.push 로만
          // 화면을 쌓는다. 그런데 OS 가 초기 라우트를 '/' 가 아닌 값으로
          // 넘겨줄 때가 있다(딥링크·위젯/알림 탭 실행 등). 그러면 라우트를
          // 만들 수 없어 WidgetsApp 의 기본 _onUnknownRoute 가 돌고,
          // 거기서 null check 가 터져 시작 크래시가 된다
          // (Sentry WARDING-APP-FLUTTER-4, 177 events / 86 users).
          //
          // 알 수 없는 라우트는 그냥 첫 화면으로 보낸다 — 딥링크 자체는
          // FcmService.consumePendingDeepLink / HomeWidgetService 가
          // 스플래시 이후에 따로 처리하므로 여기서 잃는 것은 없다.
          onUnknownRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SplashScreen(),
          ),
        );
      },
    );
  }
}
