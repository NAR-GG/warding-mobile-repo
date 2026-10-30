import 'package:flutter/material.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/schedule_match.dart';
import '../../../styles/app_colors.dart';

/// 플랫폼별 브랜드색. 미지정 플랫폼은 기본 회색.
Color streamProviderColor(String provider) {
  switch (provider) {
    case 'chzzk':
      return AppColors.chzzkBrand;
    case 'soop':
      return AppColors.soopBrand;
    default:
      return AppColors.narGray500;
  }
}

/// 중계 채널 선택 바텀시트. 플랫폼별 로고 칩 + 이름/설명, 공식 채널엔 뱃지.
///
/// 중계 링크가 둘 이상일 때만 띄운다 — 하나면 호출부가 바로 연다.
Future<StreamLink?> showStreamPickerSheet(
  BuildContext context,
  List<StreamLink> links,
) {
  final width = MediaQuery.of(context).size.width;
  final scale = width.clamp(320.0, 430.0) / 375;
  return showAppBottomSheet<StreamLink>(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            8 * scale,
            4 * scale,
            8 * scale,
            2 * scale,
          ),
          child: Text(
            AppLocalizations.of(context)!.broadcastChannelSelect,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 16 * scale,
              color: AppColors.narText,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(8 * scale, 0, 8 * scale, 12 * scale),
          child: Text(
            AppLocalizations.of(context)!.watchOnPlatform,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 12.5 * scale,
              color: AppColors.narText2,
            ),
          ),
        ),
        for (final link in links)
          Padding(
            padding: EdgeInsets.fromLTRB(8 * scale, 0, 8 * scale, 8 * scale),
            child: InkWell(
              borderRadius: BorderRadius.circular(12 * scale),
              onTap: () => Navigator.of(context).pop(link),
              child: Container(
                padding: EdgeInsets.all(13 * scale),
                decoration: BoxDecoration(
                  color: AppColors.narDark600,
                  borderRadius: BorderRadius.circular(12 * scale),
                  border: Border.all(color: AppColors.narLine),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38 * scale,
                      height: 38 * scale,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: streamProviderColor(
                          link.provider,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10 * scale),
                      ),
                      child: Text(
                        link.provider.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          // 시안은 w900 이지만 9px 에서는 w700 과 구분되지
                          // 않는다. 앱 전체에서 w900 을 쓰는 곳이 여기뿐이라,
                          // 이것 하나 때문에 Pretendard-Black(1.5MB)을 통째로
                          // 싣게 된다 — 눈에 보이지 않는 차이의 값이 아니다.
                          fontWeight: FontWeight.w700,
                          fontSize: 9 * scale,
                          color: streamProviderColor(link.provider),
                        ),
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            link.label,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5 * scale,
                              color: AppColors.narText,
                            ),
                          ),
                          if (link.description.isNotEmpty)
                            Text(
                              link.description,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w400,
                                fontSize: 12 * scale,
                                color: AppColors.narText2,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (link.description.contains('공식'))
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8 * scale,
                          vertical: 3 * scale,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.chzzkBrand.withValues(alpha: 0.35),
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.official,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5 * scale,
                            color: AppColors.chzzkBrand,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(height: 8 * scale),
      ],
    ),
  );
}
