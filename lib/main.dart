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
import 'repository/notification/live_match_notification_store.dart';
import 'repository/notification/solo_rank_notification_store.dart';
import 'screens/schedule/schedule_screen.dart';
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
  await HomeWidgetService.refreshFromApi();
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // 포그라운드 알림 표시·알림 탭 핸들링을 준비한다 (토큰 등록은 로그인 후).
  await FcmService.instance.initMessaging();
  await AppLanguage.instance.load();
  KakaoSdk.init(nativeAppKey: ApiConfig.kakaoNativeAppKey);
  await HomeWidgetService.init();
  // 백그라운드 위젯 갱신 콜백 등록
  HomeWidget.registerInteractivityCallback(_homeWidgetBackgroundCallback);
  // 앱 시작 시 위젯에 최신 캘린더 데이터 전달 (경기일정 탭 안 들어가도 동작)
  HomeWidgetService.refreshFromApi();

  // 위젯 딥링크: MethodChannel로 Swift에서 전달받음
  HomeWidgetService.listenWidgetActions();

  if (kReleaseMode) {
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
      appRunner: () => runApp(
        SentryWidget(child: const MyApp()),
      ),
    );
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        );
      },
    );
  }
}
