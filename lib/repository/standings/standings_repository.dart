import 'dart:convert';

import '../../config/api_config.dart';
import '../../model/standing.dart';
import '../../model/worlds_standings.dart';
import '../../util/api_client.dart' as http;
import '../home/home_sources.dart' show kHomeMocks;
import 'worlds_standings_mock.dart';

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

  /// 월즈 순위표(스위스 전적 버킷 + 토너먼트 대진). 리그 테이블과 형식이
  /// 달라 [fetchStandings]와 별도 모델·메서드로 둔다. 백엔드가 아직 월즈를
  /// 지원하지 않아 [kHomeMocks]가 켜진 빌드에서만 목업을 반환한다.
  Future<WorldsStandings?> fetchWorldsStandings() async {
    if (!kHomeMocks) return null;
    return worldsStandingsMock;
  }
}
