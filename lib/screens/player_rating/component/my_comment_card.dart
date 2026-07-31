import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_star_rating.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 선수 평점 상세 — 내가 남긴 평점·댓글 카드.
///
/// narLine2 테두리 + 라운드 10 카드. 상단 헤더('내 댓글' + 수정/삭제 아이콘),
/// 본문(프로필·닉네임·구독뱃지·시간 / 별점). 프로필은 없으면 기본 person 자산, 구독뱃지(팀 이미지)는 비워 둔다.
class MyCommentCard extends StatelessWidget {
  const MyCommentCard({
    super.key,
    required this.username,
    required this.timeAgo,
    required this.rating,
    this.comment,
    this.profileImageUrl,
    this.teamImageUrl,
    this.onEdit,
    this.onDelete,
    this.scale = 1,
  });

  final String username;
  final String timeAgo;
  final double rating;

  /// 내가 남긴 코멘트 내용. 없으면 표시하지 않는다.
  final String? comment;

  /// 현재 유저 프로필 이미지 URL. 없으면 기본 person 자산.
  final String? profileImageUrl;

  /// 현재 유저 응원팀 로고 URL. 없으면 원형 placeholder.
  final String? teamImageUrl;

  /// 수정(pencil)·삭제(x) 아이콘 탭 콜백.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
                    l.myComment,
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
                            // 프로필 이미지 32×32. 없으면 기본 person 자산.
                            _ProfileImage(url: profileImageUrl, size: 32 * scale),
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
                            // 응원팀 로고 21×21. 없으면 원형 placeholder.
                            _CircleImage(url: teamImageUrl, size: 21 * scale),
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
                  // 내가 남긴 코멘트 내용(있을 때만).
                  if (comment != null && comment!.isNotEmpty) ...[
                    SizedBox(height: 10 * scale),
                    Text(
                      comment!,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w400,
                        fontSize: 14 * scale,
                        height: 1.45,
                        color: AppColors.narText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 원형 이미지(없거나 로드 실패 시 narDark500 원 placeholder).
class _CircleImage extends StatelessWidget {
  const _CircleImage({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.narDark500,
        shape: BoxShape.circle,
      ),
    );
    final resolved = resolveImageUrl(url);
    if (resolved == null || resolved.isEmpty) return placeholder;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

/// 작성자 프로필 이미지(없거나 로드 실패 시 기본 person 자산으로 폴백).
class _ProfileImage extends StatelessWidget {
  const _ProfileImage({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/images/person.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    final resolved = resolveImageUrl(url);
    if (resolved == null || resolved.isEmpty) return ClipOval(child: fallback);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => fallback,
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
