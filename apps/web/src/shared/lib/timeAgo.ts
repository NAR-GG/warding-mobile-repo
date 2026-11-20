import { formatDate } from './formatDate';

/**
 * 상대 시간 표기 — Flutter `core/util/rating_mapping.dart` 의 `ratingTimeAgo`
 * 를 **복제한 것이다.**
 *
 * Dart 와 코드를 공유하지 않는다. 언어가 다르고 이 레포는 코드 생성을 쓰지
 * 않아서(`pubspec.yaml` 에 openapi·json_serializable·freezed 가 없다) 공유할
 * 경로가 아예 없다 — `packages/api` 가 Dart 모델의 널 판단을 복제하는 것과
 * 같은 이유다. **한쪽을 고치면 반드시 다른 쪽도 본다.**
 *
 * 커뮤니티가 웹으로 가도 Dart 쪽은 남는다 — 이름대로 선수 평점이 같은 함수를
 * 쓰고, 그 화면은 네이티브다. 당분간 두 구현이 공존한다.
 *
 * **분기 경계를 Dart 와 같게 맞춘다.** 1분 미만 → 방금, 60분 미만 → N분 전,
 * 24시간 미만 → N시간 전, 7일 미만 → N일 전, 그 이상은 `YYYY.MM.DD`.
 * 경계가 어긋나면 같은 글이 목록(웹)과 상세(네이티브)에서 다른 시각을
 * 말하게 된다.
 *
 * 라벨은 Dart 가 `l10n` 에서 뽑지만 웹은 번역 리소스가 아직 없어 한국어를
 * 직접 쓴다 — Dart 의 한국어 arb 값과 같은 문자열이다.
 *
 * `now` 는 테스트 주입용이다(Dart 쪽도 같은 파라미터를 받는다).
 */
export function timeAgo(time: Date | null, now: Date = new Date()): string {
  if (time === null) return '';

  const ms = now.getTime() - time.getTime();
  // 미래 시각(서버·기기 시계 차이)은 "방금" 으로 접는다. 음수를 그대로
  // 나누면 "-0분 전" 같은 표기가 나온다.
  const minutes = Math.floor(Math.max(ms, 0) / 60_000);

  if (minutes < 1) return '방금 전';
  if (minutes < 60) return `${minutes}분 전`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}시간 전`;

  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}일 전`;

  return formatDate(time);
}
