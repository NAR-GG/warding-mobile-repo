import 'dart:convert';

import '../../config/api_config.dart';
import '../../util/api_client.dart' as http;

/// 백오피스에서 등록한 광고 배너 1건. [placement] = home | match_list | match_detail.
class Ad {
  const Ad({required this.placement, required this.imageUrl, this.linkUrl});

  final String placement;
  final String imageUrl;
  final String? linkUrl;

  factory Ad.fromJson(Map<String, dynamic> json) => Ad(
    placement: json['placement'] as String,
    imageUrl: json['imageUrl'] as String,
    linkUrl: json['linkUrl'] as String?,
  );
}

/// 노출 중인 광고(`GET /api/ads`). 화면 3곳이 같은 요청을 하므로 5분간 한 번만 받는다.
/// 실패하면 빈 목록 — 광고는 앱 기능이 아니라서 에러를 화면에 올리지 않고 모집 배너로 대체한다.
class AdRepository {
  AdRepository._();
  static final AdRepository instance = AdRepository._();

  static const _ttl = Duration(minutes: 5);
  Future<List<Ad>>? _cache;
  DateTime? _fetchedAt;

  Future<Ad?> forPlacement(String placement) async {
    final ads = await _load();
    for (final ad in ads) {
      if (ad.placement == placement) return ad;
    }
    return null;
  }

  Future<List<Ad>> _load() {
    final at = _fetchedAt;
    if (_cache == null || at == null || DateTime.now().difference(at) > _ttl) {
      _fetchedAt = DateTime.now();
      _cache = _fetch();
    }
    return _cache!;
  }

  Future<List<Ad>> _fetch() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.adsUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      return [for (final e in body) Ad.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }
}
