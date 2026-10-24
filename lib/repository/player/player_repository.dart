import 'dart:convert';

import '../../config/api_config.dart';
import '../../model/player_detail.dart';
import '../../util/api_client.dart' as http;
import '../auth/auth_service.dart';
import '../home/home_sources.dart' show kHomeMocks;
import 'player_mock_source.dart';

/// 선수 페이지 데이터 소스. 세 API 모두 비로그인 호출 가능하다.
abstract class PlayerSource {
  Future<PlayerDetail> fetchDetail(int playerId);
  Future<PlayerWorlds> fetchWorlds(int playerId);
  Future<PlayerSoloRank> fetchSoloRank(int playerId);

  /// 월즈 한줄평 전체 — 최신순, [page] 는 0부터.
  Future<PlayerReviewPage> fetchWorldsReviews(
    int playerId, {
    required int page,
  });
}

/// 없는 선수(404).
class PlayerNotFound implements Exception {
  const PlayerNotFound();
}

/// 기본 소스 — 백엔드 배포 전엔 `HOME_MOCKS=true` 로 목업을 본다.
PlayerSource defaultPlayerSource({bool mocks = kHomeMocks}) =>
    mocks ? const MockPlayerSource() : ApiPlayerSource();

class ApiPlayerSource implements PlayerSource {
  ApiPlayerSource({AuthService? auth}) : _auth = auth ?? AuthService.instance;

  final AuthService _auth;

  /// 로그인했으면 토큰을 붙여 개인화 필드(subscribed·cheerMine)를 받는다.
  Future<Map<String, dynamic>> _get(String url) async {
    String? token;
    try {
      token = await _auth.jwt;
    } catch (_) {
      token = null; // Keychain 을 못 읽으면 비로그인으로 본다 — 조회는 된다.
    }
    final uri = Uri.parse(url);
    final response = token == null || token.isEmpty
        ? await http.get(uri)
        : await _auth.authorizedRequest(
            (t) => http.get(uri, headers: {'Authorization': 'Bearer $t'}),
          );
    if (response.statusCode == 404) throw const PlayerNotFound();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('선수 페이지 조회 실패 (${response.statusCode})');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Future<PlayerDetail> fetchDetail(int playerId) async =>
      PlayerDetail.fromJson(await _get(ApiConfig.playerUrl(playerId)));

  @override
  Future<PlayerWorlds> fetchWorlds(int playerId) async =>
      PlayerWorlds.fromJson(await _get(ApiConfig.playerWorldsUrl(playerId)));

  @override
  Future<PlayerReviewPage> fetchWorldsReviews(
    int playerId, {
    required int page,
  }) async => PlayerReviewPage.fromJson(
    await _get(ApiConfig.playerWorldsReviewsUrl(playerId, page: page)),
  );

  @override
  Future<PlayerSoloRank> fetchSoloRank(int playerId) async =>
      PlayerSoloRank.fromJson(
        await _get(ApiConfig.playerSoloRankUrl(playerId)),
      );
}
