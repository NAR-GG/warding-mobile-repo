import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'config/api_config.dart';
import 'config/app_globals.dart';
import 'config/app_language.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'repository/fcm/fcm_service.dart';
import 'repository/notification/live_match_notification_store.dart';
import 'repository/notification/solo_rank_notification_store.dart';
import 'screens/splash_screen.dart';
import 'styles/app_colors.dart';

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
  runApp(const MyApp());
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
