/**
 * 게시판 배지 — Flutter `core/ui/board_badge.dart` 의 웹 구현.
 *
 * 판정 규칙을 Dart 와 같게 맞춘다:
 * - `boardTeamId == null` → 전체 게시판 라벨
 * - `boardTeamId` 가 있는데 `boardTeamCode` 가 없으면 **아무것도 그리지 않는다**
 *   (구버전 응답. 틀린 코드를 보이는 것보다 낫다)
 *
 * 전체 라벨은 `l10n` 이 아니라 prop 으로 받는다 — 웹은 번역 리소스를 아직 안
 * 갖고 있고, 호출부가 서버·브리지에서 받은 문자열을 넘기는 쪽이 솔직하다.
 */
export type BoardBadgeProps = {
  boardTeamId: number | null;
  boardTeamCode: string | null;
  /** `boardTeamId` 가 null 일 때 보일 라벨 (Dart: `l.myCommunityBadgeAll`) */
  allLabel: string;
};

export function BoardBadge({ boardTeamId, boardTeamCode, allLabel }: BoardBadgeProps) {
  const text = boardTeamId === null ? allLabel : boardTeamCode;
  if (text === null || text === '') return null;

  return <span className="wd-board-badge">{text}</span>;
}
