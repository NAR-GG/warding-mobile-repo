import 'package:warding/core/util/server_time.dart';
import 'dart:convert';

import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/util/api_client.dart' as http;
import 'package:warding/features/player_rating/data/review_source.dart';
import 'package:warding/features/player_rating/domain/review_item.dart';

class ApiReviewSource implements ReviewSource {
  ApiReviewSource({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  @override
  Future<List<ReviewItem>> fetchRecent() async {
    final response = await http.get(Uri.parse(ApiConfig.recentRatingsUrl()));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('최근 한줄평 조회 실패 (${response.statusCode})');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final now = _now();
    return [
      for (final e in data['ratings'] as List<dynamic>? ?? const [])
        _review(e as Map<String, dynamic>, now),
    ];
  }

  ReviewItem _review(Map<String, dynamic> j, DateTime now) {
    return ReviewItem(
      playerName: j['playerName'] as String? ?? '',
      champion: j['championName'] as String? ?? '',
      stars: (j['rating'] as num?)?.toInt() ?? 0,
      comment: j['comment'] as String? ?? '',
      nickname: j['nickname'] as String? ?? '',
      teamCode: j['playerTeamCode'] as String? ?? '',
      minutesAgo: minutesSince(parseServerTime(j['createdAt']), now),
      gameId: j['gameId'] as String?,
      participantId: (j['participantId'] as num?)?.toInt(),
      playerId: (j['playerId'] as num?)?.toInt(),
      teamSide: j['teamSide'] as String?,
      ratingId: (j['ratingId'] as num?)?.toInt(),
    );
  }
}

/// 홈 뉴스 (`GET /api/home/news`, 인증 불필요). 최신 TOP 5 고정.
