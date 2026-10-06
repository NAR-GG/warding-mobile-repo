import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 광고 SDK 준비: UMP 동의 → iOS 추적 허용(ATT) → SDK 초기화.
///
/// 첫 프레임을 막지 않도록 [main] 이 기다리지 않고 부른다. 어느 단계가 실패해도
/// 앱은 광고 없이 정상 동작해야 하므로 예외를 삼킨다.
class AdsBootstrap {
  AdsBootstrap._();

  static final Completer<void> _ready = Completer<void>();

  /// 초기화가 끝나면(성공이든 실패든) 완료된다. 배너는 이걸 기다린 뒤 요청한다.
  static Future<void> get ready => _ready.future;

  static bool _started = false;

  static Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await _requestConsent();
      await _requestTracking();
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('[ads] 초기화 실패(광고 없이 계속): $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  /// EEA·영국 등 동의가 필요한 지역에서만 UMP 양식이 뜬다. 그 밖(한국)에서는
  /// 상태만 갱신하고 바로 끝난다. 양식은 AdMob '개인 정보 보호 및 메시지'에
  /// 만들어 둔 것을 쓴다 — 없으면 양식 없이 통과한다.
  static Future<void> _requestConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (e) {
          debugPrint('[ads] UMP 양식 실패: $e');
        }
        if (!done.isCompleted) done.complete();
      },
      (error) {
        debugPrint('[ads] UMP 상태 갱신 실패: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future;
  }

  /// iOS 14.5+ 추적 허용 팝업. 앱이 활성 상태일 때만 뜨므로 첫 화면이 그려진
  /// 뒤에 부른다([main] 이 runApp 이후에 start 를 호출한다).
  static Future<void> _requestTracking() async {
    if (!Platform.isIOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }
}
