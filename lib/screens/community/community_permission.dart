import '../../model/community_post.dart';

/// 이 게시판에 글·댓글을 쓸 수 있는가.
///
/// 규칙은 하나다 — **전체 게시판은 로그인만 하면 되고, 팀 게시판은 그 팀이 내
/// 응원팀일 때만 쓸 수 있다.** 응원팀은 단일 선택(`favoriteTeamId`)이라
/// 비교 한 번으로 끝난다. 읽기는 이 함수와 무관하게 항상 열려 있다.
///
/// 글과 댓글에 같은 판정을 쓴다. 글만 막고 댓글을 열면 아무것도 막은 게 아니다.
bool canWriteToBoard({
  required bool loggedIn,
  required int? myTeamId,
  required int boardId,
}) {
  if (!loggedIn) return false;
  if (boardId == CommunityBoard.allId) return true;
  return myTeamId != null && myTeamId == boardId;
}
