/// 포지션(라인)명을 라인 아이콘 자산 경로로 매핑하는 유틸.
///
/// 서버/디자인에서 오는 포지션 표기는 한글('탑')·영문('top')·약어('adc') 등
/// 표기가 제각각이라, 들어온 문자열을 정규화한 뒤 `assets/images/` 의
/// 라인 svg 경로로 변환한다.
///
/// 라인 svg 자산: top / jug / mid / bot / sup.
library;

/// 포지션 표기 → 라인 아이콘 자산 경로.
///
/// 매칭되는 라인이 없으면 `null` 을 반환하므로, 호출부에서 placeholder 로
/// 대체하거나 `??` 로 기본값을 줄 수 있다.
String? laneAssetPath(String position) {
  switch (_normalizeLane(position)) {
    case _Lane.top:
      return 'assets/images/top.svg';
    case _Lane.jungle:
      return 'assets/images/jug.svg';
    case _Lane.mid:
      return 'assets/images/mid.svg';
    case _Lane.bot:
      return 'assets/images/bot.svg';
    case _Lane.support:
      return 'assets/images/sup.svg';
    case null:
      return null;
  }
}

enum _Lane { top, jungle, mid, bot, support }

/// 다양한 포지션 표기를 5개 라인으로 정규화한다.
_Lane? _normalizeLane(String position) {
  final key = position.trim().toLowerCase();
  switch (key) {
    case '탑':
    case 'top':
      return _Lane.top;
    case '정글':
    case 'jungle':
    case 'jug':
    case 'jng':
      return _Lane.jungle;
    case '미드':
    case 'mid':
    case 'middle':
      return _Lane.mid;
    case '원딜':
    case '바텀':
    case 'bot':
    case 'bottom':
    case 'adc':
    case 'ad':
      return _Lane.bot;
    case '서폿':
    case '서포터':
    case 'sup':
    case 'support':
    case 'supporter':
      return _Lane.support;
    default:
      return null;
  }
}
