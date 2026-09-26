import 'dart:convert';

import '../../config/api_config.dart';
import '../../model/standing.dart';
import '../../util/api_client.dart' as http;

/// 리그 순위표 API (`/api/standings`).
class StandingsRepository {
  StandingsRepository._();
  static final StandingsRepository instance = StandingsRepository._();

  Future<StandingsResult> fetchStandings(String league) async {
    final response =
        await http.get(Uri.parse(ApiConfig.standingsUrl(league: league)));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('순위표 조회 실패 ($league, ${response.statusCode})');
    }
    return StandingsResult.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
