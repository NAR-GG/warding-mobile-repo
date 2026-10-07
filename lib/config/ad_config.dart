import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// AdMob 광고 단위 ID.
///
/// 디버그·프로파일 빌드는 구글이 공개한 테스트 단위를 쓴다. 개발 중에 실제 단위로
/// 요청을 보내면 무효 트래픽으로 잡혀 계정이 정지될 수 있다.
class AdConfig {
  AdConfig._();

  // 앱 ID 는 AndroidManifest.xml / Info.plist 에 따로 들어 있다.
  // Android ca-app-pub-9725078965412256~5501917656
  // iOS     ca-app-pub-9725078965412256~1436706252
  static const String _homeBannerAndroid =
      'ca-app-pub-9725078965412256/4755491391';
  static const String _homeBannerIos = 'ca-app-pub-9725078965412256/1581698991';
  static const String _matchListBannerAndroid = 'MATCH_LIST_ANDROID_UNIT';
  static const String _matchListBannerIos = 'MATCH_LIST_IOS_UNIT';

  // https://developers.google.com/admob/flutter/test-ads
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

  /// 홈 화면 인라인 배너.
  static String get homeBannerUnitId {
    final android = Platform.isAndroid;
    if (kReleaseMode) return android ? _homeBannerAndroid : _homeBannerIos;
    return android ? _testBannerAndroid : _testBannerIos;
  }

  /// 경기 리스트 날짜 그룹 사이 배너.
  static String get matchListBannerUnitId {
    final android = Platform.isAndroid;
    if (kReleaseMode) {
      return android ? _matchListBannerAndroid : _matchListBannerIos;
    }
    return android ? _testBannerAndroid : _testBannerIos;
  }
}
