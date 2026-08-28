import 'package:flutter/foundation.dart';

import '../../model/team.dart';
import '../../repository/onboarding/onboarding_repository.dart';

/// 커뮤니티 팀 게시판 목록.
///
/// 게시판 = 전체(`boardTeamId == null`) + 팀 하나당 하나. 팀 목록은 온보딩 팀
/// API(`/auth/onboarding/teams`)를 그대로 쓴다 — 인증이 필요 없고 리포지토리가
/// 이미 10분 캐시를 한다. 커뮤니티 전용 게시판 목록 API 를 따로 두지 않는
/// 이유가 이것이다.
///
/// 못 받아도 화면은 뜬다 — 팀 레일이 비고 게시판 이름 자리가 빌 뿐, 전체
/// 게시판은 그대로 읽힌다.
final ValueNotifier<List<Team>> communityTeams = ValueNotifier(const []);

/// 팀 목록을 한 번 받아 [communityTeams] 에 채운다.
Future<void> loadCommunityTeams() async {
  if (communityTeams.value.isNotEmpty) return;
  try {
    communityTeams.value = await OnboardingRepository.instance.fetchTeams();
  } on Exception catch (e) {
    debugPrint('[Community] 팀 목록 조회 실패: $e');
  }
}

/// 게시판의 팀. 전체 게시판이거나 아직 팀 목록을 못 받았으면 null.
Team? communityTeam(int? teamId) {
  if (teamId == null) return null;
  for (final team in communityTeams.value) {
    if (team.id == teamId) return team;
  }
  return null;
}
