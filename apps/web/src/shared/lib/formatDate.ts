/**
 * `YYYY.MM.DD` — Dart 의 `DateFormat('yyyy.MM.dd')` 와 같은 표기다.
 *
 * **한 곳에 모은 이유.** 같은 포맷을 세 군데가 제각각 만들고 있었다 —
 * 공지 상세는 `toISOString()` 으로 UTC 날짜를, `timeAgo` 는 `getMonth()` 로
 * 로컬 날짜를 썼다. 시간대가 다르면 같은 글이 화면마다 하루 다른 날짜를
 * 말한다.
 *
 * **로컬 필드로 맞춘다**(`toISOString` 이 아니라). Dart 의 `DateFormat` 이
 * 기기 시간대로 그리기 때문이고, 두 플랫폼이 같은 응답에서 다른 날짜를
 * 보이면 안 된다.
 *
 * 다만 이 함수를 서버 컴포넌트에서 부르면 "로컬" 은 서버의 시간대다. 앱
 * 사용자가 KST 한 지역에 몰려 있고 서버도 KST 라 지금은 같지만,
 * **시간대가 갈리면 하루 어긋날 수 있는 지점이다.** 정확히 맞추려면 기기
 * 시간대를 브리지로 받아야 한다 — 지금은 그 비용을 치르지 않았다.
 */
export function formatDate(time: Date): string {
  const m = String(time.getMonth() + 1).padStart(2, '0');
  const d = String(time.getDate()).padStart(2, '0');
  return `${time.getFullYear()}.${m}.${d}`;
}
