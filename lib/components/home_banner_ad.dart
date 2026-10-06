import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';
import '../util/ads_bootstrap.dart';

/// 홈 인라인 배너. 광고가 로드되기 전·실패했을 때는 자리를 차지하지 않는다
/// (빈 칸이 남으면 섹션 간격만 어색해진다).
class HomeBannerAd extends StatefulWidget {
  const HomeBannerAd({super.key, required this.scale});

  final double scale;

  @override
  State<HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends State<HomeBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AdsBootstrap.ready;
    if (!mounted) return;
    // 인라인 적응형은 가로폭을 알아야 해서 레이아웃 이후 폭으로 요청한다.
    final width = MediaQuery.of(context).size.width.truncate() - 40;
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: AdConfig.homeBannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[ads] 배너 로드 실패: ${error.code} ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _ad = null);
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
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 28 * widget.scale),
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
