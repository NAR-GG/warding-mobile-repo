import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart'
    show ImageConfiguration, ImageInfo, ImageStreamListener;

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

  /// 광고 이미지 한 장을 기다리는 한계. 이걸 넘으면 그 자리는 모집 배너로 간다 —
  /// 광고를 띄우려고 빈 자리를 오래 들고 있을 이유가 없다.
  static const _imageTimeout = Duration(seconds: 5);

  Future<List<Ad>>? _cache;
  DateTime? _fetchedAt;

  /// 이미지 내려받기를 자리별로 한 번만 돌린다. 같은 자리를 두 번 그려도
  /// (스플래시 → 홈 배너) 같은 Future 를 기다려 요청이 겹치지 않는다.
  final Map<String, Future<void>> _warming = {};

  /// 이미지까지 준비가 끝난 광고. [readyFor] 가 기다림 없이 답하려고 들고 있는다.
  final Map<String, Ad> _ready = {};

  /// 지금 **당장** 그릴 수 있는 광고. 응답과 이미지가 모두 캐시에 있을 때만
  /// 돌려주고, 아니면 `null` — 기다리지 않는다.
  ///
  /// 스플래시가 첫 프레임에 쓴다. 스플래시는 1~2초만 떠 있어서 중간에 그림을
  /// 바꾸면 그게 전부 눈에 띈다. 그래서 '받아 놓은 게 있으면 광고, 없으면 모집
  /// 배너' 를 처음에 정하고 끝까지 안 바꾼다(캐시가 빈 첫 실행은 모집 배너).
  Ad? readyFor(String placement) => _ready[placement];

  /// 이미지까지 준비된 광고. 응답만 와 있고 이미지가 아직이면 기다린다 —
  /// 먼저 돌려주면 회색 자리(+AD 뱃지)가 보였다가 광고로 바뀌는 게 눈에 띈다.
  /// 이미지가 끝내 안 받아지면 `null` 로 떨어뜨려 모집 배너를 그대로 둔다
  /// (반쯤 그려진 광고보다 낫다).
  Future<Ad?> forPlacement(String placement) async {
    final ad = await _adFor(placement);
    if (ad == null) return null;
    final ok = await _warmImage(ad);
    if (!ok) return null;
    _ready[placement] = ad;
    return ad;
  }

  /// 응답만 본다(이미지는 안 기다린다). 미리 받아 둘 자리를 고를 때 쓴다.
  Future<Ad?> _adFor(String placement) async {
    final ads = await _load();
    for (final ad in ads) {
      if (ad.placement == placement) return ad;
    }
    return null;
  }

  /// [placements] 의 광고 이미지를 미리 받아 둔다. 끝나기를 기다리지 않아도 되고,
  /// 실패해도 조용히 넘긴다 — 나중에 [forPlacement] 가 다시 기다린다.
  /// 스플래시에서 홈·팝업 자리를 먼저 데워 두는 데 쓴다.
  void warmUp(Iterable<String> placements) {
    for (final placement in placements) {
      _adFor(placement).then((ad) async {
        if (ad == null) return;
        if (await _warmImage(ad)) _ready[placement] = ad;
      });
    }
  }

  /// 이미지를 디코드까지 끝내 캐시에 올린다. 성공하면 `true` — 그 뒤 같은 주소의
  /// [CachedNetworkImage] 는 캐시에서 바로 꺼내 쓰므로 placeholder 를 거치지 않고
  /// 첫 프레임에 그려진다.
  ///
  /// 디스크만 채우는 것으로는 부족하다. 디코드가 남아 있으면 그 사이 한 프레임이
  /// placeholder 로 나간다. 그래서 [CachedNetworkImageProvider] 로 해석까지 기다린다.
  Future<bool> _warmImage(Ad ad) async {
    final pending = _warming[ad.imageUrl];
    if (pending != null) {
      try {
        await pending;
        return true;
      } catch (_) {
        return false;
      }
    }
    final task = _resolve(ad.imageUrl);
    _warming[ad.imageUrl] = task;
    try {
      await task;
      return true;
    } catch (e) {
      // 다음 그림 때 다시 시도할 수 있게 실패는 기억하지 않는다.
      _warming.remove(ad.imageUrl);
      debugPrint('[AdRepository] 광고 이미지 준비 실패 (${ad.placement}): $e');
      return false;
    }
  }

  /// 이미지 한 장을 받아서 디코드까지 끝낸다. 성공하면 완료, 실패하면 에러로 끝난다.
  ///
  /// [_imageTimeout] 을 넘기면 포기한다. 이 경로는 [CachedNetworkImageProvider] 라
  /// api_client 의 15초 타임아웃이 닿지 않는다 — 안 걸어 두면 네트워크가 느릴 때
  /// 광고 자리가 끝까지 빈 칸으로 남는다. 포기해도 호출 쪽이 모집 배너로 대체한다.
  Future<void> _resolve(String url) {
    final done = Completer<void>();
    final stream = CachedNetworkImageProvider(
      url,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool _) {
        image.dispose();
        stream.removeListener(listener);
        if (!done.isCompleted) done.complete();
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
        if (!done.isCompleted) done.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    return done.future.timeout(
      _imageTimeout,
      onTimeout: () {
        stream.removeListener(listener);
        throw TimeoutException('광고 이미지 응답 없음', _imageTimeout);
      },
    );
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
