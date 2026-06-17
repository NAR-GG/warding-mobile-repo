/// FCM 푸시 `data['type']` 값(백엔드와의 계약).
///
/// 문자열을 여기저기 흩뿌리지 않도록 한곳에 모아둔다.
/// 백엔드와 동일한 상수를 보내야 라우팅/피드 저장이 동작한다.
class FcmNotificationType {
  FcmNotificationType._();

  /// 선수 솔로 랭크 시작. → 마이구독 화면.
  static const String playerSoloRankStarted = 'PLAYER_SOLO_RANK_STARTED';

  /// 라이브 경기: 세트 시작. → 경기 상세 '라이브 이벤트' 탭.
  static const String setStart = 'SET_START';

  /// 라이브 경기: 세트 종료. → 경기 상세 '라이브 이벤트' 탭.
  static const String setEnd = 'SET_END';

  /// 라이브 경기: 경기 중 이벤트(킬/오브젝트 등). → 경기 상세 '라이브 이벤트' 탭.
  static const String liveEvent = 'LIVE_EVENT';

  /// 라이브 경기 관련 타입 모음(딥링크·피드 저장 대상).
  static const Set<String> liveMatchTypes = {setStart, setEnd, liveEvent};

  /// 라이브 경기 푸시인지.
  static bool isLiveMatch(Object? type) => liveMatchTypes.contains(type);
}
