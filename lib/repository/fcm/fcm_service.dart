import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../config/app_globals.dart';
import '../../screens/subscription/subscription_screen.dart';
import '../../util/match_detail_router.dart';
import '../../util/sentry_logger.dart';
import '../device/device_repository.dart';
import '../notification/live_match_notification_store.dart';
import '../notification/solo_rank_notification_store.dart';
import 'fcm_notification_types.dart';

/// FCM(푸시) 초기화·토큰 등록·메시지 핸들링을 담당한다.
///
/// - [initMessaging] : 앱 시작 시 호출. 포그라운드 알림 표시와 알림 탭 처리를 준비.
/// - [registerToken] : 로그인 직후 호출. 권한 요청 + 토큰을 백엔드에 등록.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _refreshListenerAttached = false;

  /// Android 포그라운드 알림용 채널. 중요도 high 라야 배너로 뜬다.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'warding_high_importance',
    '구독 알림',
    description: '구독 선수·팀의 경기/이벤트 알림',
    importance: Importance.high,
  );

  /// 알림 잠자기 시간대 발송용 채널.
  ///
  /// Android O+ 는 채널 설정이 서버 payload 보다 우선한다. 서버가 sound 를 비우고
  /// priority 를 낮춰도 채널 importance 가 high 면 시스템이 소리를 내므로, 무음은
  /// 중요도 낮은 채널을 따로 둬야 한다. id 는 서버
  /// (FirebaseMobilePushGateway.QUIET_CHANNEL_ID)와 반드시 일치해야 한다 — 없는 채널로
  /// 오면 Android 가 알림을 아예 띄우지 못한다.
  static const AndroidNotificationChannel _quietChannel =
      AndroidNotificationChannel(
    'warding_quiet',
    '알림 잠자기',
    description: '잠자기 시간대에 소리 없이 받는 알림',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  /// 서버가 기대하는 플랫폼 문자열.
  String get _platform => Platform.isIOS ? 'IOS' : 'ANDROID';

  /// 앱 시작 시: 로컬 알림 초기화 + 메시지 리스너 등록.
  /// (알림 권한은 온보딩 알림 단계에서 요청한다.)
  Future<void> initMessaging() async {
    // 포그라운드에서도 배너/사운드가 뜨도록 표시 옵션 설정(iOS).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 1) 로컬 알림(포그라운드 표시용) 초기화.
    // 상태바 아이콘은 흰색 단색 드로어블이어야 함(컬러 런처 아이콘은 네모로 뭉개짐).
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_warding');
    // request*Permission 을 꺼서 초기화 시점에 시스템 알림 팝업이 자동으로
    // 뜨지 않게 한다. 권한 요청은 온보딩 알림 단계에서만 트리거한다.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.createNotificationChannel(_quietChannel);

    // 2) 포그라운드 수신 → 직접 알림 표시 (Android 는 자동 표시가 안 됨).
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // 3) 백그라운드에서 알림 탭으로 앱이 열렸을 때.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);

    // 4) 종료 상태에서 알림 탭으로 앱이 시작됐을 때.
    //
    // 이 시점은 main() 이 runApp() 을 호출하기 전이라 navigatorKey 에 아직
    // NavigatorState 가 붙어 있지 않다 — 여기서 바로 push 하면 조용히 무시된다.
    // 그래서 데이터만 보관해두고, 스플래시가 첫 화면 분기를 마친 뒤
    // [consumePendingDeepLink] 로 그 위에 push 하게 한다.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] 종료 상태에서 알림으로 시작 → 딥링크 보류');
      _pendingInitialData = initial.data;
    }
  }

  /// 콜드 스타트 딥링크로 보류해 둔 알림 데이터. 스플래시가 소비한다.
  Map<String, dynamic>? _pendingInitialData;

  /// 스플래시가 첫 화면(로그인/홈) 분기 내비게이션을 마친 직후 호출한다.
  /// 보류된 콜드 스타트 딥링크가 있으면 그 위에 push 하고 비운다.
  void consumePendingDeepLink() {
    final data = _pendingInitialData;
    _pendingInitialData = null;
    if (data != null) _navigateFromData(data);
  }

  /// 로그인 직후: 토큰 발급·등록 → 갱신 리스너 연결.
  /// (알림 권한은 앱 시작 시 [initMessaging] 에서 이미 요청한다.)
  Future<void> registerToken() async {
    // iOS 시뮬레이터는 APNs 토큰이 없어 getToken 이 예외를 던진다.
    // 실패해도 앱 흐름을 막지 않고, 아래 onTokenRefresh 로 이후 토큰을 잡는다.
    String? token;
    try {
      token = await _messaging.getToken();
      SentryLogger.info(module: 'FCM', eventName: 'getToken');
    } catch (e) {
      SentryLogger.warning(
        module: 'FCM',
        eventName: 'getToken',
        reason: e.runtimeType.toString(),
        error: e,
      );
      debugPrint('[FCM] 토큰 발급 실패(시뮬레이터/APNs 미설정 가능): $e');
    }
    // 테스트용: 이 토큰을 Firebase Console > Cloud Messaging > 테스트 메시지에 붙여
    // 넣으면 백엔드 없이도 실제 푸시를 보낼 수 있다.
    debugPrint('[FCM] 토큰: $token');
    if (token != null) {
      await _safeRegister(token);
    }

    if (!_refreshListenerAttached) {
      _refreshListenerAttached = true;
      _messaging.onTokenRefresh.listen(_safeRegister);
    }
  }

  Future<void> _safeRegister(String token) async {
    try {
      await DeviceRepository.instance.registerDevice(
        fcmToken: token,
        platform: _platform,
      );
      SentryLogger.info(module: 'FCM', eventName: 'registerToken');
    } catch (e) {
      SentryLogger.warning(
        module: 'FCM',
        eventName: 'registerToken',
        reason: e.runtimeType.toString(),
        error: e,
      );
      // 토큰 등록 실패가 로그인 흐름을 막지 않도록 삼킨다.
      debugPrint('[FCM] 토큰 등록 실패: $e');
    }
  }

  /// 포그라운드에서 받은 메시지를 로컬 알림으로 띄운다.
  /// iOS 는 setForegroundNotificationPresentationOptions 로 시스템이 표시하므로
  /// 중복을 막기 위해 Android 에서만 직접 표시한다.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    debugPrint('[FCM] 포그라운드 메시지: ${message.notification?.title}');
    final type = message.data['type'] as String? ?? 'unknown';
    // 솔랭/라이브 경기 알림이면 마이구독 피드용으로 기기에 저장.
    try {
      await SoloRankNotificationStore.instance.addFromFcmData(message.data);
      await LiveMatchNotificationStore.instance.addFromFcmData(
        message.data,
        title: message.notification?.title,
        body: message.notification?.body,
      );
    } catch (e) {
      SentryLogger.error(
        module: 'FCM',
        eventName: 'saveNotification',
        reason: e.runtimeType.toString(),
        throwable: e,
      );
    }
    // 앱이 떠 있는 동안 온 알림은 생명주기 이벤트도, 화면 재생성도 일으키지 않아
    // 마이구독 피드가 그대로 남아 있었다. 서버는 발송 전에 피드를 적재하므로
    // 지금 다시 읽으면 방금 온 알림이 들어 있다.
    feedRefreshTick.value++;
    if (!Platform.isAndroid) {
      SentryLogger.info(
        module: 'FCM',
        eventName: 'receiveNotification',
        extra: {'type': type},
      );
      return;
    }
    final notification = message.notification;
    if (notification == null) return;
    // 백그라운드는 시스템이 payload 채널대로 표시하지만, 포그라운드는 여기서 직접
    // 띄우므로 서버가 지정한 채널을 따라가야 잠자기 시간에 소리가 나지 않는다.
    // 소리 나는 발송에는 서버가 AndroidNotification 을 붙이지 않아 channelId 가 null 이다.
    final quiet = notification.android?.channelId == _quietChannel.id;
    final channel = quiet ? _quietChannel : _channel;
    try {
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: quiet ? Importance.low : Importance.high,
            priority: quiet ? Priority.low : Priority.high,
            playSound: !quiet,
            enableVibration: !quiet,
            icon: '@drawable/ic_stat_warding',
          ),
        ),
        payload: jsonEncode(message.data),
      );
      SentryLogger.info(
        module: 'FCM',
        eventName: 'receiveNotification',
        extra: {'type': type},
      );
    } catch (e) {
      SentryLogger.error(
        module: 'FCM',
        eventName: 'showNotification',
        reason: e.runtimeType.toString(),
        throwable: e,
      );
    }
  }

  /// 로컬 알림 탭 → payload(JSON)에서 데이터를 꺼내 딥링크 처리.
  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateFromData(data);
    } catch (e) {
      SentryLogger.error(
        module: 'FCM',
        eventName: 'parsePayload',
        reason: e.runtimeType.toString(),
        throwable: e,
      );
      debugPrint('[FCM] payload 파싱 실패: $e');
    }
  }

  /// 푸시 메시지(백그라운드/종료에서 탭) → 딥링크 처리.
  void _handleMessageNavigation(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  /// 푸시 데이터로 화면을 이동한다(알림 탭 딥링크).
  ///
  /// 백엔드 페이로드 type 별 라우팅:
  /// - PLAYER_SOLO_RANK_STARTED (playerId, gameId) → 마이구독([SubscriptionScreen]).
  /// - SET_START / SET_END / LIVE_EVENT (matchId, setNumber?) → 경기 상세의
  ///   '라이브 이벤트' 탭(index 1)을 matchId 로 연다.
  ///
  /// 솔랭 선수 상세는 화면이 경기 컨텍스트를 요구해 아직 연결 보류(피드 저장만).
  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type'];
    debugPrint('[FCM] 알림 탭 → type=$type');
    // 탭한 알림이 피드에 빠짐없이 들어가도록 저장(중복은 무시됨).
    // Keychain 접근 실패(-25308 등)만 무시 — 피드 한 건 누락일 뿐.
    SoloRankNotificationStore.instance.addFromFcmData(data).catchError(
          (Object e) => debugPrint('[FCM] 탭 알림 저장 실패: $e'),
          test: (e) => e is PlatformException,
        );
    LiveMatchNotificationStore.instance.addFromFcmData(data).catchError(
          (Object e) => debugPrint('[FCM] 탭 알림 저장 실패: $e'),
          test: (e) => e is PlatformException,
        );

    if (type == FcmNotificationType.playerSoloRankStarted) {
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
      );
      return;
    }

    if (FcmNotificationType.isLiveMatch(type)) {
      final matchId = (data['matchId'] ?? '').toString();
      if (matchId.isEmpty) {
        debugPrint('[FCM] 라이브 경기 푸시에 matchId 가 없어 딥링크 생략');
        return;
      }
      // 경기 상세를 '라이브 이벤트' 탭(index 1)으로 연다. 헤더용 match 객체는
      // 푸시에 없으므로 null 로 두면 상세 화면이 matchId 로 데이터를 로드한다.
      //
      // 라우터를 거치므로 푸시를 연달아 눌러도 상세가 겹겹이 쌓이지 않고
      // 이미 떠 있는 화면의 탭·세트만 바뀐다.
      final setNumber = int.tryParse((data['setNumber'] ?? '').toString());
      MatchDetailRouter.open(
        matchId: matchId,
        tabIndex: 1,
        setNumber: setNumber,
      );
      return;
    }
  }
}
