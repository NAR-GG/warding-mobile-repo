import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../model/match_champion_pick.dart';
import '../../model/match_game.dart';
import '../../model/match_live_event.dart';
import '../../model/schedule_match.dart';

/// 경기 상세 관련 API (`/api/mobile/matches/{matchId}/games`,
/// `/api/mobile/live/games/{gameId}/{champions,events}`). 모두 인증 불필요.
class MatchDetailRepository {
  MatchDetailRepository._();
  static final MatchDetailRepository instance = MatchDetailRepository._();

  /// 단일 경기 정보를 조회한다. 실패 시 null 을 반환한다.
  Future<ScheduleMatch?> fetchMatch(String matchId) async {
    final url = ApiConfig.matchUrl(matchId);
    debugPrint('[MatchDetail] GET $url');
    try {
      final response = await http.get(Uri.parse(url));
      debugPrint('[MatchDetail] match ← ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return ScheduleMatch.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[MatchDetail] fetchMatch failed: $e');
      return null;
    }
  }

  /// 경기(matchId)의 세트별 게임 목록을 조회한다 (인증 불필요).
  /// 세트 순서 → gameId 해석에 쓴다.
  Future<List<MatchGame>> fetchGames(String matchId) async {
    final url = ApiConfig.matchGamesUrl(matchId);
    debugPrint('[MatchDetail] GET $url');
    final response = await http.get(Uri.parse(url));
    debugPrint('[MatchDetail] games ← ${response.statusCode} '
        '(${response.body.length} bytes)');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('세트 목록 조회 실패 ($matchId, ${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    // 응답이 { "games": [...] } 또는 배열 자체일 수 있어 둘 다 처리.
    final List<dynamic> rawGames;
    if (decoded is Map<String, dynamic>) {
      rawGames = decoded['games'] as List<dynamic>? ?? const [];
    } else if (decoded is List) {
      rawGames = decoded;
    } else {
      rawGames = const [];
    }
    final games = rawGames
        .map((e) => MatchGame.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.gameOrder.compareTo(b.gameOrder));
    debugPrint('[MatchDetail] games: ${games.length}');
    return games;
  }

  /// 세트(gameId)의 챔피언 밴·픽을 조회한다 (인증 불필요).
  Future<MatchChampionPick> fetchChampionPick(String gameId) async {
    final url = ApiConfig.gameChampionsUrl(gameId);
    debugPrint('[MatchDetail] GET $url');
    final response = await http.get(Uri.parse(url));
    debugPrint('[MatchDetail] champions ← ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('챔피언 픽 조회 실패 ($gameId, ${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return MatchChampionPick.fromJson(data);
  }

  /// 세트(gameId)의 라이브 이벤트를 조회한다 (인증 불필요, 최신순).
  /// 응답 최상위의 양 팀 로고 URL과 이벤트 목록을 함께 담아 반환한다.
  Future<MatchLiveEvents> fetchLiveEvents(String gameId) async {
    final url = ApiConfig.gameEventsUrl(gameId);
    debugPrint('[MatchDetail] GET $url');
    final response = await http.get(Uri.parse(url));
    debugPrint('[MatchDetail] events ← ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('라이브 이벤트 조회 실패 ($gameId, ${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final result = MatchLiveEvents.fromJson(data);
    debugPrint('[MatchDetail] events: ${result.events.length}');
    return result;
  }
}
