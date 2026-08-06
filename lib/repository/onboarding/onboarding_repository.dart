import 'dart:convert';

import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/league.dart';
import '../../model/player.dart';
import '../../model/team.dart';
import '../../util/sentry_logger.dart';

/// 온보딩 관련 API.
class OnboardingRepository {
  OnboardingRepository._();
  static final OnboardingRepository instance = OnboardingRepository._();

  /// 온보딩용 리그 목록 조회. 인증이 필요 없다.
  Future<List<League>> fetchLeagues() async {
    final response = await http.get(Uri.parse(ApiConfig.onboardingLeaguesUrl));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('리그 목록 조회 실패 (${response.statusCode})');
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => League.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 온보딩용 LCK 팀 목록 조회. 인증이 필요 없다.
  Future<List<Team>> fetchTeams() async {
    final response = await http.get(Uri.parse(ApiConfig.onboardingTeamsUrl));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('팀 목록 조회 실패 (${response.statusCode})');
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Team.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 온보딩용 선수 목록 조회. 인증이 필요 없다.
  ///
  /// [teamId] 를 주면 해당 팀 선수만, 안 주면 [year] 시즌 전체 선수를 조회한다.
  Future<List<Player>> fetchPlayers({required int year, int? teamId}) async {
    final response = await http.get(
      Uri.parse(ApiConfig.onboardingPlayersUrl(year: year, teamId: teamId)),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('선수 목록 조회 실패 (${response.statusCode})');
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList()
      // 서버는 이름순으로 주므로 포지션순(탑→정글→미드→바텀→서포터)으로 재정렬. (#97)
      ..sort((a, b) {
        final byRole = a.roleOrder.compareTo(b.roleOrder);
        return byRole != 0 ? byRole : a.name.compareTo(b.name);
      });
  }

  /// 온보딩 완료 — 로그인 사용자의 선호 리그·팀·선수를 서버에 저장한다.
  ///
  /// `POST /api/auth/onboarding` — 인증이 필요하므로 [jwt] 를 헤더에 싣는다.
  Future<void> completeOnboarding({
    String? favoriteLeagueName,
    required int favoriteTeamId,
    List<int> favoritePlayerIds = const [],
    required String jwt,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.onboardingUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({
        'favoriteLeagueName': ?favoriteLeagueName,
        'favoriteTeamId': favoriteTeamId,
        'favoritePlayerIds': favoritePlayerIds,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'postOnboarding',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.onboardingUrl, 'statusCode': response.statusCode},
      );
      throw Exception('온보딩 완료 저장 실패 (${response.statusCode})');
    }
    SentryLogger.info(module: 'API', eventName: 'postOnboarding');
  }
}
