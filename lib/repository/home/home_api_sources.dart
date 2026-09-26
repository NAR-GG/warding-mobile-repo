import 'dart:convert';

import '../../config/api_config.dart';
import '../../model/home_models.dart';
import '../../util/api_client.dart' as http;
import '../auth/auth_service.dart';
import 'home_sources.dart';

/// 오프셋이 없는 시각은 KST 로 본다 — 뉴스·한줄평 `createdAt` 이 `2026-09-16T22:19:16`
/// 꼴이다. 솔랭 시각은 `+09:00` 이 붙어 온다. 파싱에 실패하면 null.
DateTime? parseServerTime(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  final hasOffset = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw);
  return DateTime.tryParse(hasOffset ? raw : '$raw+09:00');
}

int _minutesSince(DateTime? at, DateTime now) =>
    at == null ? 0 : now.difference(at).inMinutes.clamp(0, 1 << 30);

/// 구독 선수 솔랭 상태 (`GET /api/mobile/me/solo-rank`, 로그인 필수).
///
/// 토큰이 없는 비회원은 조회하지 않고 빈 결과를 준다. 승패를 못 받은 판
/// (`win == null`)은 승/패를 그릴 수 없어 끝난 경기에서 뺀다.
class ApiSoloRankSource implements SoloRankSource {
  ApiSoloRankSource({AuthService? auth, DateTime Function()? now})
    : _auth = auth ?? AuthService.instance,
      _now = now ?? DateTime.now;

  final AuthService _auth;
  final DateTime Function() _now;

  @override
  Future<SoloRankSnapshot> fetch() async {
    final token = await _auth.jwt;
    if (token == null || token.isEmpty) {
      return const SoloRankSnapshot(live: [], finished: []);
    }
    final response = await _auth.authorizedRequest(
      (t) => http.get(
        Uri.parse(ApiConfig.soloRankUrl),
        headers: {'Authorization': 'Bearer $t'},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('솔랭 상태 조회 실패 (${response.statusCode})');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final now = _now();

    final live = <HomeLiveSoloPlayer>[
      for (final e in data['live'] as List<dynamic>? ?? const [])
        _live(e as Map<String, dynamic>, now),
    ];
    final finished = <HomeFinishedSoloPlayer>[
      for (final e in data['finished'] as List<dynamic>? ?? const [])
        if ((e as Map<String, dynamic>)['win'] is bool) _finished(e, now),
    ];
    return SoloRankSnapshot(live: live, finished: finished);
  }

  HomeLiveSoloPlayer _live(Map<String, dynamic> j, DateTime now) {
    final startedAt = parseServerTime(j['startedAt']);
    return HomeLiveSoloPlayer(
      name: j['playerName'] as String? ?? '',
      teamCode: j['teamCode'] as String? ?? '',
      champion: j['championName'] as String? ?? '',
      elapsedSeconds: startedAt == null
          ? 0
          : now.difference(startedAt).inSeconds.clamp(0, 1 << 30),
      playerImageUrl: j['playerImageUrl'] as String?,
    );
  }

  HomeFinishedSoloPlayer _finished(Map<String, dynamic> j, DateTime now) {
    final seconds = (j['durationSeconds'] as num?)?.toInt();
    return HomeFinishedSoloPlayer(
      name: j['playerName'] as String? ?? '',
      teamCode: j['teamCode'] as String? ?? '',
      won: j['win'] as bool,
      minutesAgo: _minutesSince(parseServerTime(j['endedAt']), now),
      durationMinutes: seconds == null ? null : seconds ~/ 60,
    );
  }
}

/// 홈 뉴스 (`GET /api/home/news`, 인증 불필요). 최신 TOP 5 고정.
class ApiNewsSource implements NewsSource {
  ApiNewsSource({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  @override
  Future<List<HomeNewsArticle>> fetchTop() async {
    final response = await http.get(Uri.parse(ApiConfig.homeNewsUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('홈 뉴스 조회 실패 (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    final now = _now();
    return [
      for (final e in data)
        HomeNewsArticle(
          title: (e as Map<String, dynamic>)['title'] as String? ?? '',
          office: e['officeName'] as String? ?? '',
          minutesAgo: _minutesSince(parseServerTime(e['createdAt']), now),
          hasThumbnail: (e['thumbnail'] as String?)?.isNotEmpty ?? false,
        ),
    ];
  }
}
