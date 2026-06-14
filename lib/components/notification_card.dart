import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';

/// 공용 알림 카드.
///
/// 좌측 44×44 아이콘 + 우측 콘텐츠(제목·본문·옵션 액션·하단 시간) 레이아웃.
/// 선수 랭크 시작·경기 종료 등 알림 템플릿의 공통 뼈대로 쓴다.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.dateTime,
    required this.relativeTime,
    this.iconOverride,
    this.action,
    this.scale = 1,
  });

  /// 좌측 아이콘 svg 경로. [iconOverride] 가 있으면 무시된다.
  final String icon;

  /// 좌측 아이콘을 직접 지정할 때 쓴다(예: 챔피언 이미지). null 이면 [icon] svg 를 쓴다.
  final Widget? iconOverride;

  /// 제목 (강조 텍스트, 600/16).
  final String title;

  /// 본문 (400/13).
  final String body;

  /// 하단 좌측 절대 시각 ('2026-05-07 15:47').
  final String dateTime;

  /// 하단 우측 상대 시각 ('30분 전').
  final String relativeTime;

  /// 본문과 시간 사이에 들어갈 옵션 위젯 (예: '경기 평점 남기기' 링크).
  final Widget? action;

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.narBgSecondary, // #1A1B1E
      padding: EdgeInsets.all(20 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconOverride ??
              SvgPicture.asset(
                icon,
                width: 44 * scale,
                height: 44 * scale,
                colorFilter: const ColorFilter.mode(
                  AppColors.narText,
                  BlendMode.srcIn,
                ),
              ),
          SizedBox(width: 16 * scale), // gap 16
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 16 * scale,
                    height: 25 / 16,
                    color: AppColors.narText,
                  ),
                ),
                SizedBox(height: 4 * scale), // gap 4
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    fontSize: 13 * scale,
                    height: 1.45,
                    color: AppColors.narTextTertiary, // #FCFDFE
                  ),
                ),
                if (action != null) ...[
                  SizedBox(height: 4 * scale),
                  action!,
                ],
                SizedBox(height: 4 * scale),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateTime, style: _timeStyle(scale)),
                    Text(relativeTime, style: _timeStyle(scale)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _timeStyle(double scale) => TextStyle(
    fontFamily: 'Pretendard',
    fontWeight: FontWeight.w400,
    fontSize: 12 * scale,
    height: 1.45,
    color: AppColors.narText2, // #A6A7AB
  );
}
