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
}
