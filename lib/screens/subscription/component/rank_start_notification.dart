import 'package:flutter/material.dart';

import '../../../components/notification_card.dart';
import '../../../styles/app_colors.dart';

/// 선수 랭크 시작 감지 알림. headset 아이콘 + 선수/챔피언/큐 정보.
/// [opggUrl] 이 있으면 'OP.GG 바로가기' 링크를 노출한다.
class RankStartNotification extends StatelessWidget {
  const RankStartNotification({
    super.key,
    required this.playerName,
    required this.champion,
    required this.dateTime,
    required this.relativeTime,
    this.queueType = '솔로 랭크',
    this.opggUrl,
    this.championImageUrl,
    this.onOpggTap,
    this.scale = 1,
  });

  /// 선수명 (예: 'Faker').
  final String playerName;

  /// 챔피언명 (예: '아지르').
  final String champion;

  /// 챔피언 아이콘 URL. 있으면 좌측 아이콘으로 쓰고, 없으면 headset 아이콘 폴백.
  final String? championImageUrl;

  /// 큐 타입 (예: '솔로 랭크').
  final String queueType;

  /// OP.GG 소환사 페이지 URL. 없으면 링크를 숨긴다.
  final String? opggUrl;

  /// 'OP.GG 바로가기' 탭 콜백.
  final VoidCallback? onOpggTap;

  final String dateTime;
  final String relativeTime;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return NotificationCard(
      icon: 'assets/icons/headset.svg',
      iconOverride: _championIcon(scale),
      title: '$playerName 선수 랭크 시작 감지!',
      body: '지금 $playerName 선수가 $champion으로 $queueType를 시작했습니다',
      dateTime: dateTime,
      relativeTime: relativeTime,
      action: (opggUrl == null || opggUrl!.isEmpty)
          ? null
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpggTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'OP.GG 바로가기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 13 * scale,
                      height: 1.45,
                      color: AppColors.narButton1Bg,
                    ),
                  ),
                  SizedBox(width: 2 * scale),
                  Icon(
                    Icons.chevron_right,
                    size: 16 * scale,
                    color: AppColors.narButton1Bg,
                  ),
                ],
              ),
            ),
      scale: scale,
    );
  }

  /// 챔피언 아이콘(44×44, 둥근 사각형). URL 없으면 null → headset 폴백.
  /// 로드 실패 시 게임 패드 아이콘 placeholder.
  Widget? _championIcon(double scale) {
    final url = championImageUrl;
    if (url == null || url.isEmpty) return null;
    final size = 44 * scale;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8 * scale),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.narDark600,
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          child: Icon(
            Icons.sports_esports,
            color: AppColors.narText2,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
