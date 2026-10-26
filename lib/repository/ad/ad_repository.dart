import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/painting.dart'
    show ImageConfiguration, ImageInfo, ImageStreamListener;
import 'package:shared_preferences/shared_preferences.dart';

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

  /// 받아 둔 응답 캐시와 메모리 상태를 비운다(테스트 전용).
  /// 프로덕션에서는 호출하지 않는다.
  @visibleForTesting
  void resetForTest() {
    _cache = null;
    _fetchedAt = null;
    _ready.clear();
    _warming.clear();
  }

  Future<({List<Ad> ads, bool ok})>? _cache;
  DateTime? _fetchedAt;

  /// 이미지 내려받기를 자리별로 한 번만 돌린다. 같은 자리를 두 번 그려도
  /// (스플래시 → 홈 배너) 같은 Future 를 기다려 요청이 겹치지 않는다.
  final Map<String, Future<void>> _warming = {};

  /// 이미지까지 준비가 끝난 광고. [readyFor] 가 기다림 없이 답하려고 들고 있는다.
  final Map<String, Ad> _ready = {};

  /// 지난 실행에서 이미지까지 받아 둔 광고를 적어 두는 칸. 값은 [Ad] 한 건의 JSON.
  static const _restoreKey = 'ad_ready_splash';

  /// 지금 **당장** 그릴 수 있는 광고. 응답과 이미지가 모두 캐시에 있을 때만
  /// 돌려주고, 아니면 `null` — 기다리지 않는다.
  ///
  /// 스플래시가 첫 프레임에 쓴다. 스플래시는 1~2초만 떠 있어서 중간에 그림을
  /// 바꾸면 그게 전부 눈에 띈다. 그래서 '받아 놓은 게 있으면 광고, 없으면 모집
  /// 배너' 를 처음에 정하고 끝까지 안 바꾼다.
  ///
  /// 앱을 켤 때마다 비어 있지 않도록 [restoreSplash] 가 첫 프레임 전에 채운다 —
  /// `_ready` 는 메모리에만 있어서, 복원이 없으면 콜드스타트에서 **항상** null 이고
  /// 스플래시 광고가 영원히 안 뜬다.
  Ad? readyFor(String placement) => _ready[placement];

  /// 지난 실행에서 받아 둔 스플래시 광고를 `_ready` 에 되살린다. **첫 프레임 전에**
  /// (`main` 의 초기화 묶음에서) 불러야 [CheerAdSlotView] 가 그 값을 쓸 수 있다.
  ///
  /// 이미지가 아직 디스크 캐시에 있는지는 여기서 확인하지 않는다 — 확인하려면
  /// 비동기 조회가 한 번 더 들어가 첫 프레임을 늦추고, 캐시가 비었어도
  /// [CachedNetworkImage] 가 받아오는 동안 회색 자리만 잠깐 보일 뿐이다
  /// (스플래시는 탭도 안 되는 자리라 피해가 작다).
  Future<void> restoreSplash() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _restoreKey,
      );
      if (raw == null) return;
      final ad = Ad.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      // 이미 이번 실행에서 받아 둔 게 있으면 그게 더 최신이다.
      _ready.putIfAbsent(ad.placement, () => ad);
    } catch (e) {
      debugPrint('[AdRepository] 스플래시 광고 복원 실패: $e');
    }
  }

  /// 적어 둔 스플래시 광고를 지운다. 서버가 더 이상 그 자리를 안 내려주면
  /// (집행 종료·빈 응답) 다음 실행부터 모집 배너로 돌아가야 한다 — 안 지우면
  /// 옛 광고가 기기에 남아 영원히 복원된다.
  Future<void> _forgetSplash() async {
    _ready.remove('splash');
    try {
      await (await SharedPreferences.getInstance()).remove(_restoreKey);
    } catch (e) {
      debugPrint('[AdRepository] 스플래시 광고 삭제 실패: $e');
    }
  }

  /// 다음 실행의 첫 프레임에 쓰도록 스플래시 광고를 적어 둔다. 실패는 삼킨다 —
  /// 적어 두지 못하면 다음 실행이 모집 배너로 가는 것뿐이다.
  Future<void> _rememberSplash(Ad ad) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _restoreKey,
        jsonEncode({
          'placement': ad.placement,
          'imageUrl': ad.imageUrl,
          'linkUrl': ad.linkUrl,
        }),
      );
    } catch (e) {
      debugPrint('[AdRepository] 스플래시 광고 저장 실패: $e');
    }
  }

  /// 이미지까지 준비된 광고. 응답만 와 있고 이미지가 아직이면 기다린다 —
  /// 먼저 돌려주면 회색 자리(+AD 뱃지)가 보였다가 광고로 바뀌는 게 눈에 띈다.
  /// 이미지가 끝내 안 받아지면 `null` 로 떨어뜨려 모집 배너를 그대로 둔다
  /// (반쯤 그려진 광고보다 낫다).
  Future<Ad?> forPlacement(String placement) async {
    final ad = await _adFor(placement);
    if (ad == null) return null;
    final ok = await _warmImage(ad);
    if (!ok) return null;
    await _markReady(placement, ad);
    return ad;
  }

  /// 이미지까지 준비됐다고 기록한다. 스플래시 자리는 다음 실행의 첫 프레임에
  /// 쓰도록 기기에도 적어 둔다.
  Future<void> _markReady(String placement, Ad ad) async {
    _ready[placement] = ad;
    if (placement == 'splash') await _rememberSplash(ad);
  }

  /// 응답만 본다(이미지는 안 기다린다). 미리 받아 둘 자리를 고를 때 쓴다.
  ///
  /// 스플래시 자리를 물었는데 응답에 없으면 기기에 적어 둔 것도 지운다 —
  /// 집행이 끝난 광고가 다음 실행에서 되살아나지 않게 한다.
  Future<Ad?> _adFor(String placement) async {
    final result = await _load();
    for (final ad in result.ads) {
      if (ad.placement == placement) return ad;
    }
    // 조회가 실패했으면(네트워크·5xx) 집행이 끝난 건지 알 수 없다 — 그대로 둔다.
    if (result.ok && placement == 'splash') await _forgetSplash();
    return null;
  }

  /// [placements] 의 광고 이미지를 미리 받아 둔다. 끝나기를 기다리지 않아도 되고,
  /// 실패해도 조용히 넘긴다 — 나중에 [forPlacement] 가 다시 기다린다.
  /// 스플래시에서 홈·팝업 자리를 먼저 데워 두는 데 쓴다.
  void warmUp(Iterable<String> placements) {
    for (final placement in placements) {
      _adFor(placement).then((ad) async {
        if (ad == null) return;
        if (await _warmImage(ad)) await _markReady(placement, ad);
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

  Future<({List<Ad> ads, bool ok})> _load() {
    final at = _fetchedAt;
    if (_cache == null || at == null || DateTime.now().difference(at) > _ttl) {
      _fetchedAt = DateTime.now();
      _cache = _fetch();
    }
    return _cache!;
  }

  /// 광고 목록과 "이 응답을 믿어도 되는지".
  ///
  /// 실패를 빈 목록으로 뭉개면 안 된다 — 비행기 모드로 앱을 켠 것과 집행이
  /// 끝난 것을 구분하지 못해, 멀쩡한 광고를 지워 버린다.
  Future<({List<Ad> ads, bool ok})> _fetch() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.adsUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (ads: const <Ad>[], ok: false);
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      return (
        ads: [for (final e in body) Ad.fromJson(e as Map<String, dynamic>)],
        ok: true,
      );
    } catch (e) {
      debugPrint('[AdRepository] 광고 목록 조회 실패: $e');
      return (ads: const <Ad>[], ok: false);
    }
  }
}
