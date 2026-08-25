import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';

/// 쓰기 권한이 없는 게시판에서 글쓰기 FAB 자리에 대신 놓는 바.
///
/// 그냥 버튼을 숨기면 사용자는 왜 못 쓰는지 모른다. 이유와 다음에 할 수 있는
/// 행동을 같이 준다.
class WriteLockBar extends StatelessWidget {
  const WriteLockBar({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.scale,
    required this.onAction,
  });

  final String title;
  final String? body;
  final String actionLabel;
  final double scale;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final sub = body;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine2, width: 1),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/lock-off.svg',
            width: 16 * scale,
            height: 16 * scale,
            colorFilter: const ColorFilter.mode(
              AppColors.narText2,
              BlendMode.srcIn,
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 12 * scale,
                    height: 1.4,
                    color: AppColors.narText,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                      fontSize: 11 * scale,
                      height: 1.4,
                      color: AppColors.narText2,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10 * scale),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Text(
              actionLabel,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 12 * scale,
                height: 1.4,
                color: AppColors.narViolet3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
