import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../model/team.dart';

/// 온보딩 관련 API.
class OnboardingRepository {
  OnboardingRepository._();
  static final OnboardingRepository instance = OnboardingRepository._();

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

  /// 온보딩 완료 — 로그인 사용자의 선호 팀을 서버에 저장한다.
  ///
  /// `POST /api/auth/onboarding` — 인증이 필요하므로 [jwt] 를 헤더에 싣는다.
  Future<void> completeOnboarding({
    required int favoriteTeamId,
    required String jwt,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.onboardingUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({'favoriteTeamId': favoriteTeamId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('온보딩 완료 저장 실패 (${response.statusCode})');
    }
  }
}
