import 'package:flutter/foundation.dart';

import 'package:warding/core/di_container.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';
import 'package:warding/core/infrastructure/preference/team_preference_repository.dart';
import 'package:warding/domain/team.dart';
import 'package:warding/features/onboarding/domain/repositories/onboarding_repository.dart';

/// 응원팀 하나를 정하는 규칙.
///
/// **로그인 회원은 서버 `favoriteTeamId` 가 정답이고, 그걸 못 얻으면 로컬
/// 캐시로 폴백한다.** 둘을 뒤집으면 다른 기기에서 팀을 바꾼 것이 반영되지
/// 않는다.
///
/// 로그인 상태인데 응원팀을 설정하지 않았으면 **null 을 돌려주고 로컬 캐시로
/// 덮지 않는다** — 사용자가 응원팀을 지운 것일 수 있어서, 캐시로 되살리면
/// 지울 방법이 없어진다.
///
/// 화면 상태(로딩 플래그·notify)는 다루지 않는다. 그건 ViewModel 의 일이다.
///
/// 위젯 갱신 경로는 이것을 쓰지 않는다 — 별도 아이솔레이트에서 돌아
/// 토큰 재발급을 시도하면 포그라운드 앱의 재발급과 경쟁해 토큰이 꼬인다.
/// 그쪽은 `ScheduleWidgetWriter` 안에 재발급하지 않는 사본을 따로 둔다.
class GetPreferredTeam {
  GetPreferredTeam({
    AuthService? auth,
    OnboardingRepository? onboarding,
    TeamPreferenceRepository? teamPreferences,
  }) : _auth = auth ?? AuthService.instance,
       _onboarding = onboarding ?? di<OnboardingRepository>(),
       _teamPreferences = teamPreferences ?? TeamPreferenceRepository.instance;

  final AuthService _auth;
  final OnboardingRepository _onboarding;
  final TeamPreferenceRepository _teamPreferences;

  Future<Team?> call() async {
    try {
      // teamId 를 알기 전에도 팀 목록은 미리 받아둔다 — fetchMe 와 겹쳐서
      // 왕복 한 번을 아낀다.
      final teamsFuture = _onboarding.fetchTeams();
      final me = await _auth.fetchMe();
      final teamId = me.favoriteTeamId;
      final teams = (await teamsFuture).getOrElse((_) => const []);
      if (teamId == null) return null;
      for (final t in teams) {
        if (t.id == teamId) return t;
      }
      return null;
    } catch (e) {
      // 비로그인·네트워크 실패 등은 로컬 캐시로 폴백.
      debugPrint('[GetPreferredTeam] 서버 조회 실패, 로컬 폴백: $e');
      return _teamPreferences.loadPreferredTeam();
    }
  }
}
