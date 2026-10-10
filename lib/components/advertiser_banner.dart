import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../styles/app_colors.dart';

// ponytail: 문의 폼은 마이페이지 고객센터와 같은 폼을 쓴다. 광고주 전용 폼·소재 노출은
// 광고주가 생기면 features/ad-sales 의 `GET /api/mobile/ads` 로 바꾼다.
const _inquiryUrl =
    'https://docs.google.com/forms/d/e/1FAIpQLSf66NkvON3YrFR0n_CSbnzyjXlEEfO8eiIc9W_2TBYulvihMA/viewform';

/// 광고주 모집 배너. 광고가 들어오기 전까지 광고 자리에 둔다.
///
/// 누르면 문의 폼을 외부 브라우저로 연다.
class AdvertiserBanner extends StatelessWidget {
  const AdvertiserBanner({
    super.key,
    required this.scale,
    this.topPadding = 28,
    this.bottomPadding = 0,
  });

  final double scale;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        topPadding * scale,
        20 * scale,
        bottomPadding * scale,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => launchUrl(
          Uri.parse(_inquiryUrl),
          mode: LaunchMode.externalApplication,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 18 * scale,
            vertical: 16 * scale,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.narBg,
            borderRadius: BorderRadius.circular(14 * scale),
            border: Border.all(
              color: AppColors.narText.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.advertiserBannerTitle,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        fontSize: 18 * scale,
                        height: 1.3,
                        color: AppColors.narText,
                      ),
                    ),
                    SizedBox(height: 3 * scale),
                    Text(
                      l10n.advertiserBannerBody,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5 * scale,
                        height: 1.4,
                        color: AppColors.narText.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12 * scale),
              Container(
                width: 28 * scale,
                height: 28 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.narText.withValues(alpha: 0.22),
                ),
                child: Icon(
                  Icons.chevron_right,
                  size: 20 * scale,
                  color: AppColors.narText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
