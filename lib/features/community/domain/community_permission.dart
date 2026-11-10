/// 이 게시판에 글·댓글을 쓸 수 있는가 — **앱이 아는 범위의** 판정.
///
/// 규칙은 하나다 — 전체 게시판(`boardTeamId == null`)은 로그인만 하면 되고,
/// 팀 게시판은 그 팀이 내 응원팀일 때만 쓸 수 있다. 응원팀은 단일
/// 선택(`favoriteTeamId`)이라 비교 한 번으로 끝난다. 읽기는 항상 열려 있다.
///
/// 응원팀을 바꾼 지 30일이 안 지난 쿨다운은 앱이 알 수 없어 여기서 못 거른다.
/// 목록 응답의 `boardViewer` 가 있으면 그쪽(서버 판정)이 우선이고, 이 함수는
/// 서버 판정이 아직 없을 때의 폴백이다.
///
/// 글과 댓글에 같은 판정을 쓴다. 글만 막고 댓글을 열면 아무것도 막은 게 아니다.
bool canWriteToBoard({
  required bool loggedIn,
  required int? myTeamId,
  required int? boardTeamId,
}) {
  if (!loggedIn) return false;
  if (boardTeamId == null) return true;
  return myTeamId != null && myTeamId == boardTeamId;
}
