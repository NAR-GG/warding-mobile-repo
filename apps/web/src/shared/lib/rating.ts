/**
 * 평점 표시용 순수 변환 — Flutter `core/util/rating_mapping.dart` 의 웹 구현.
 *
 * **도메인 타입을 import 하지 않는다.** 들어오는 것은 서버가 주는 문자열
 * 코드뿐이라 `shared` 에 둬도 이 레이어가 평점 도메인을 알게 되지 않는다.
 *
 * 코드 생성이 없으므로 Dart 쪽을 고치면 여기도 본다.
 */

/** 백엔드 `teamSide` → 진영. 모르는 값은 blue 로 본다(Dart 와 같다). */
export function sideFromTeamSide(teamSide: string): 'blue' | 'red' {
  return teamSide.toUpperCase() === 'RED' ? 'red' : 'blue';
}

/**
 * 백엔드 `role` 코드 → 포지션 라벨.
 *
 * **모르는 값은 원본을 그대로 돌려준다** — 빈칸으로 만들면 새 포지션이
 * 생겼을 때 화면에서 사라진다.
 *
 * 웹에 번역 리소스가 없어 한국어로 고정한다(Dart 는 `appStrings` 를 탄다).
 */
export function positionFromRole(role: string): string {
  switch (role.toUpperCase()) {
    case 'TOP':
      return '탑';
    case 'JUNGLE':
      return '정글';
    case 'MID':
    case 'MIDDLE':
      return '미드';
    case 'BOTTOM':
    case 'BOT':
    case 'ADC':
      return '원딜';
    case 'SUPPORT':
    case 'UTILITY':
      return '서포터';
    default:
      return role;
  }
}

/**
 * 별 다섯 칸을 채움 비율로 바꾼다.
 *
 * 각 칸은 0~1 이다 — 3.5 면 `[1, 1, 1, 0.5, 0]`. 반 칸을 CSS 그라데이션
 * 폭으로 그리려고 비율로 돌려준다.
 */
export function starFills(rating: number): number[] {
  return Array.from({ length: 5 }, (_, i) =>
    Math.max(0, Math.min(1, rating - i)),
  );
}

/**
 * 포지션 표기 → 라인 아이콘 경로 — Flutter `core/util/lane_asset.dart` 와
 * 같은 정규화다.
 *
 * 한국어·영어 표기가 섞여 들어온다(서버 role 은 `mid`, 화면 라벨은 `미드`).
 * **모르는 값은 null** 이고 호출부는 회색 자리를 그린다.
 */
export function laneIconPath(position: string): string | null {
  switch (position.trim().toLowerCase()) {
    case '탑':
    case 'top':
      return '/lanes/top.svg';
    case '정글':
    case 'jungle':
    case 'jug':
    case 'jng':
      return '/lanes/jug.svg';
    case '미드':
    case 'mid':
    case 'middle':
      return '/lanes/mid.svg';
    case '원딜':
    case '바텀':
    case 'bot':
    case 'bottom':
    case 'adc':
    case 'ad':
      return '/lanes/bot.svg';
    case '서폿':
    case '서포터':
    case 'sup':
    case 'support':
    case 'supporter':
    case 'utility':
      return '/lanes/sup.svg';
    default:
      return null;
  }
}
