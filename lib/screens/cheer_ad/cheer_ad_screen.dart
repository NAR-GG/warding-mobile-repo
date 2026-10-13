import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../components/bottom_action_bar.dart';
import '../../components/nar_detail_header.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/app_colors.dart';
import '../notice/ad_guide_screen.dart';

/// 지면별 정가(원, 1일). 오픈 기간에는 [_openDiscount] 를 적용한 값을 판다.
const _splashPrice = 60000;
const _popupPrice = 40000;
const _bannerPrice = 20000;
const _openDiscount = 0.5;

/// 응원 광고 신청 상세. 지면(스플래시·팝업·배너)을 2열 그리드로 보이고,
/// 하단 '상세 보기'로 [AdGuideScreen](서버 공지 본문 + 신청 폼)을 연다.
class CheerAdScreen extends StatelessWidget {
  const CheerAdScreen({super.key});

  void _openDetail(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AdGuideScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final l = AppLocalizations.of(context)!;
    final slots = [
      (l.cheerAdSlotSplash, 'assets/images/cheer_ad/splash.png', _splashPrice),
      (l.cheerAdSlotPopup, 'assets/images/cheer_ad/popup.png', _popupPrice),
      (l.cheerAdSlotBanner, 'assets/images/cheer_ad/banner.png', _bannerPrice),
    ];

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NarDetailHeader(title: l.cheerAdScreenTitle, scale: scale),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20 * scale,
                      16 * scale,
                      20 * scale,
                      BottomActionBar.scrollInset * scale,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.cheerAdHeadline,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            fontSize: 20 * scale,
                            height: 1.35,
                            color: AppColors.narText,
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        Text(
                          l.cheerAdSubheadline,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w400,
                            fontSize: 13 * scale,
                            height: 1.55,
                            color: AppColors.narText3,
                          ),
                        ),
                        SizedBox(height: 20 * scale),
                        Wrap(
                          spacing: 12 * scale,
                          runSpacing: 20 * scale,
                          children: [
                            for (final (name, asset, price) in slots)
                              _SlotTile(
                                name: name,
                                asset: asset,
                                price: price,
                                width:
                                    (width.clamp(320.0, 430.0) -
                                        40 * scale -
                                        12 * scale) /
                                    2,
                                scale: scale,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 광고 안내와 같은 하단 버튼(색은 이 화면의 밝은 회색 그대로).
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: BottomActionBar(
                      label: l.cheerAdViewDetail,
                      scale: scale,
                      onTap: () => _openDetail(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.name,
    required this.asset,
    required this.price,
    required this.width,
    required this.scale,
  });

  final String name;
  final String asset;
  final int price;
  final double width;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: width,
            height: width * 1.25,
            padding: EdgeInsets.all(10 * scale),
            decoration: BoxDecoration(
              color: AppColors.narDark600,
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
          SizedBox(height: 12 * scale),
          Text(
            name,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
              fontSize: 13 * scale,
              height: 1.3,
              color: AppColors.narText,
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            l.cheerAdPrice(_won(price)),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 11 * scale,
              color: AppColors.narDark200,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.narDark200,
            ),
          ),
          SizedBox(height: 2 * scale),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${(_openDiscount * 100).round()}%',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 15 * scale,
                  color: AppColors.narTextRed,
                ),
              ),
              SizedBox(width: 6 * scale),
              Text(
                l.cheerAdPrice(_won((price * (1 - _openDiscount)).round())),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 15 * scale,
                  color: AppColors.narText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 6 * scale,
              vertical: 2 * scale,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.narDark300),
              borderRadius: BorderRadius.circular(4 * scale),
            ),
            child: Text(
              l.cheerAdOpenBadge,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 10 * scale,
                color: AppColors.narText3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _won(int n) => NumberFormat.decimalPattern().format(n);
