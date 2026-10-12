import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../screens/notice/ad_guide_screen.dart';
import '../styles/app_colors.dart';

/// 광고주 모집 배너. 광고가 들어오기 전까지 광고 자리에 둔다.
///
/// 누르면 광고 안내 화면으로 이동한다(거기서 신청 폼으로 연결).
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
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AdGuideScreen())),
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
