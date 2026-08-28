import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 게시글 첨부 사진. Cloudinary 업로드 URL 을 앱의 다른 곳과 같은
/// [CachedNetworkImage] 로 그린다.
class CommunityImage extends StatelessWidget {
  const CommunityImage({
    super.key,
    required this.source,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final String source;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.narDark500,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: source,
        width: width,
        height: height,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}
