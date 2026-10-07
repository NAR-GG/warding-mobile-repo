import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../util/ads_bootstrap.dart';

/// 인라인 배너. 광고가 로드되기 전·실패했을 때는 자리를 차지하지 않는다
/// (빈 칸이 남으면 섹션 간격만 어색해진다).
///
/// 위치별로 [unitId] 를 달리 줘서 AdMob 리포트에서 자리별 수익을 따로 본다.
class InlineBannerAd extends StatefulWidget {
  const InlineBannerAd({
    super.key,
    required this.unitId,
    required this.scale,
    this.topPadding = 28,
    this.bottomPadding = 0,
  });

  final String unitId;
  final double scale;
  final double topPadding;
  final double bottomPadding;

  @override
  State<InlineBannerAd> createState() => _InlineBannerAdState();
}

class _InlineBannerAdState extends State<InlineBannerAd>
    with AutomaticKeepAliveClientMixin {
  /// 로드 실패 시 다시 요청하는 횟수와 대기. 일시적인 'Invalid request'·네트워크
  /// 실패로 그 세션 내내 광고가 비는 걸 막는다. 무한 재시도는 무효 트래픽이 된다.
  static const _retryDelays = [Duration(seconds: 5), Duration(seconds: 20)];

  BannerAd? _ad;
  bool _loaded = false;

  /// 목록(ListView.builder) 안에서 화면 밖으로 나가도 로드된 광고를 버리지 않는다.
  /// 안 그러면 스크롤할 때마다 새로 요청해 노출 없는 요청이 쌓인다.
  @override
  bool get wantKeepAlive => _loaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([int attempt = 0]) async {
    await AdsBootstrap.ready;
    if (!mounted) return;
    // 인라인 적응형은 가로폭을 알아야 해서 레이아웃 이후 폭으로 요청한다.
    final width = MediaQuery.of(context).size.width.truncate() - 40;
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: widget.unitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
          updateKeepAlive();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[ads] 배너 로드 실패: ${error.code} ${error.message}');
          ad.dispose();
          if (!mounted) return;
          setState(() => _ad = null);
          if (attempt < _retryDelays.length) {
            Future.delayed(_retryDelays[attempt], () => _load(attempt + 1));
          }
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(
        top: widget.topPadding * widget.scale,
        bottom: widget.bottomPadding * widget.scale,
      ),
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
