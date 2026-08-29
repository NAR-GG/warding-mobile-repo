import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';

/// 경기 상세 탭 공용 잠금(lock-off) 빈 상태.
///
/// 좌측 24×24 lock-off 아이콘 + 우측 안내 문구를 가운데 정렬로 배치한다.
/// (선수 평점·라이브 이벤트·챔피언 픽 탭이 아직 볼 게 없을 때 공통으로 쓴다.)
/// 배경색은 부모가 칠하므로 여기서는 지정하지 않는다.
class MatchDetailLockedEmpty extends StatelessWidget {
  const MatchDetailLockedEmpty({
    super.key,
    required this.message,
    this.scale = 1,
  });

  /// 안내 문구. 예) '선수 평점은 경기 종료 후 남길 수 있어요!'.
  final String message;

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 80 * scale,
        horizontal: 20 * scale,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/lock-off.svg',
              width: 24 * scale,
              height: 24 * scale,
              colorFilter: const ColorFilter.mode(
                AppColors.narText2, // #A6A7AB
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 8 * scale),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  fontSize: 16 * scale,
                  height: 1.55,
                  color: AppColors.narText2, // #A6A7AB
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
