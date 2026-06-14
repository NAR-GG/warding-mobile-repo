import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../config/app_globals.dart';
import '../../screens/subscription/subscription_screen.dart';
import '../device/device_repository.dart';
import '../notification/solo_rank_notification_store.dart';

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

  /// 서버가 기대하는 플랫폼 문자열.
  String get _platform => Platform.isIOS ? 'IOS' : 'ANDROID';

  /// 앱 시작 시: 로컬 알림 초기화 + 메시지 리스너 등록.
  Future<void> initMessaging() async {
    // 1) 로컬 알림(포그라운드 표시용) 초기화.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 2) 포그라운드 수신 → 직접 알림 표시 (Android 는 자동 표시가 안 됨).
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // 3) 백그라운드에서 알림 탭으로 앱이 열렸을 때.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);

    // 4) 종료 상태에서 알림 탭으로 앱이 시작됐을 때.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleMessageNavigation(initial);
    }
  }

  /// 로그인 직후: 알림 권한 요청 → 토큰 발급·등록 → 갱신 리스너 연결.
  Future<void> registerToken() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    // iOS 포그라운드에서도 배너/사운드가 뜨도록.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS 시뮬레이터는 APNs 토큰이 없어 getToken 이 예외를 던진다.
    // 실패해도 앱 흐름을 막지 않고, 아래 onTokenRefresh 로 이후 토큰을 잡는다.
    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
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
    } catch (e) {
      // 토큰 등록 실패가 로그인 흐름을 막지 않도록 삼킨다.
      debugPrint('[FCM] 토큰 등록 실패: $e');
    }
  }

  /// 포그라운드에서 받은 메시지를 로컬 알림으로 띄운다.
  /// iOS 는 setForegroundNotificationPresentationOptions 로 시스템이 표시하므로
  /// 중복을 막기 위해 Android 에서만 직접 표시한다.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    debugPrint('[FCM] 포그라운드 메시지: ${message.notification?.title}');
    // 솔랭 알림이면 마이구독 피드용으로 기기에 저장.
    await SoloRankNotificationStore.instance.addFromFcmData(message.data);
    if (!Platform.isAndroid) return;
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// 로컬 알림 탭 → payload(JSON)에서 데이터를 꺼내 딥링크 처리.
  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateFromData(data);
    } catch (e) {
      debugPrint('[FCM] payload 파싱 실패: $e');
    }
  }

  /// 푸시 메시지(백그라운드/종료에서 탭) → 딥링크 처리.
  void _handleMessageNavigation(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  /// 푸시 데이터로 화면을 이동한다.
  ///
  /// 백엔드 페이로드 예: type=PLAYER_SOLO_RANK_STARTED, playerId, gameId.
  /// 딥링크: nar://players/{playerId}
  ///
  /// TODO: playerId 단독으로 여는 선수 상세 화면이 생기면 navigatorKey 로 push 한다.
  /// 현재 선수 화면(PlayerRatingScreen)은 경기 컨텍스트가 필요해 연결을 보류한다.
  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type'];
    debugPrint('[FCM] 알림 탭 → type=$type');
    // 탭한 알림이 피드에 빠짐없이 들어가도록 저장(중복은 무시됨).
    SoloRankNotificationStore.instance.addFromFcmData(data);
    if (type == 'PLAYER_SOLO_RANK_STARTED') {
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
      );
    }
  }
}
