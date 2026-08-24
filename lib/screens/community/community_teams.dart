import 'package:flutter/foundation.dart';

import '../../model/community_post.dart';
import '../../model/team.dart';
import '../../repository/onboarding/onboarding_repository.dart';

/// 커뮤니티에서 쓰는 **실제** 팀 목록.
///
/// 게시글은 아직 더미지만 팀 로고와 이름만큼은 진짜를 쓴다. 온보딩 팀 API
/// (`/auth/onboarding/teams`)는 인증이 필요 없고 리포지토리가 이미 10분 캐시를
/// 하고 있어서, 백엔드에 커뮤니티 API 가 없어도 이것만은 지금 붙일 수 있다.
///
/// 실패해도 화면은 그대로 뜬다 — 로고 자리는 팀 대표색 원으로 떨어진다.
final ValueNotifier<List<Team>> communityTeams = ValueNotifier(const []);

/// 팀 목록을 한 번 받아 [communityTeams] 에 채운다. 이미 채워져 있으면 아무것도
/// 하지 않는다.
Future<void> loadCommunityTeams() async {
  if (communityTeams.value.isNotEmpty) return;
  try {
    communityTeams.value = await OnboardingRepository.instance.fetchTeams();
  } on Exception catch (e) {
    // 로고는 장식이다. 못 받아도 색 원 폴백으로 계속 그린다.
    debugPrint('[Community] 팀 목록 조회 실패: $e');
  }
}

/// 게시판 id 에 해당하는 실제 팀.
///
/// 게시판 id 를 실제 팀 id 로 맞춰 두었기 때문에 그대로 찾으면 된다
/// ([kDummyBoards] 참고).
Team? teamForBoard(int boardId) {
  for (final team in communityTeams.value) {
    if (team.id == boardId) return team;
  }
  return null;
}

/// 게시판에 보여줄 이름. 실제 팀 이름을 받았으면 그걸 쓰고, 아니면 더미 이름.
String boardDisplayName(CommunityBoard board) {
  if (board.isAll) return board.name;
  return teamForBoard(board.id)?.name ?? board.name;
}
