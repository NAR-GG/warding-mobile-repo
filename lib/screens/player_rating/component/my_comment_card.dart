import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_star_rating.dart';
import '../../../styles/app_colors.dart';

/// 선수 평점 상세 — 내가 남긴 평점·댓글 카드.
///
/// narLine2 테두리 + 라운드 10 카드. 상단 헤더('내 댓글' + 수정/삭제 아이콘),
/// 본문(프로필·닉네임·구독뱃지·시간 / 별점). 프로필·구독뱃지(팀 이미지)는 비워 둔다.
class MyCommentCard extends StatelessWidget {
  const MyCommentCard({
    super.key,
    required this.username,
    required this.timeAgo,
    required this.rating,
    this.onEdit,
    this.onDelete,
    this.scale = 1,
  });

  final String username;
  final String timeAgo;
  final double rating;

  /// 수정(pencil)·삭제(x) 아이콘 탭 콜백.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  final double scale;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.narLine2, width: 1),
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더: '내 댓글' + 수정/삭제.
            Container(
              color: AppColors.narBgContent,
              padding: EdgeInsets.only(
                top: 10 * scale,
                right: 20 * scale,
                bottom: 5 * scale,
                left: 20 * scale,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '내 댓글',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                      fontSize: 14 * scale,
                      height: 1.55,
                      color: AppColors.narText,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _IconButton(
                        icon: 'assets/icons/pencil.svg',
                        onTap: onEdit,
                        scale: scale,
                      ),
                      SizedBox(width: 8 * scale),
                      _IconButton(
                        icon: 'assets/icons/close.svg',
                        onTap: onDelete,
                        scale: scale,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 본문: 프로필·닉네임·시간 / 별점.
            Container(
              color: AppColors.narBgContent,
              padding: EdgeInsets.only(
                top: 8 * scale,
                right: 20 * scale,
                bottom: 20 * scale,
                left: 20 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // TODO: 프로필 이미지 연결 — 현재 37×37 원형 placeholder.
                            Container(
                              width: 37 * scale,
                              height: 37 * scale,
                              decoration: const BoxDecoration(
                                color: AppColors.narDark500,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 5 * scale),
                            Flexible(
                              child: Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14 * scale,
                                  height: 1.45,
                                  color: AppColors.narText,
                                ),
                              ),
                            ),
                            SizedBox(width: 5 * scale),
                            // TODO: 구독뱃지(팀 이미지) 연결 — 현재 21×21 원형 placeholder.
                            Container(
                              width: 21 * scale,
                              height: 21 * scale,
                              decoration: const BoxDecoration(
                                color: AppColors.narDark500,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 11 * scale),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w400,
                          fontSize: 11 * scale,
                          height: 1.45,
                          color: AppColors.narText2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8 * scale),
                  NarStarRating(rating: rating, scale: scale),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 헤더의 24×24 아이콘 버튼(흰색 stroke svg).
class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, this.onTap, required this.scale});

  final String icon;
  final VoidCallback? onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SvgPicture.asset(icon, width: 24 * scale, height: 24 * scale),
    );
  }
}
