import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 게시글 첨부 사진. Cloudinary 업로드 URL 을 앱의 다른 곳과 같은
/// [CachedNetworkImage] 로 그린다.
///
/// 서버는 첨부 사진을 변환 없는 원본 URL 로 저장한다. 그대로 쓰면 아이폰 원본
/// (4032×3024, 수 MB)을 통째로 받아 200px 칸에 그리게 되므로, **표시 폭에 맞춰**
/// Cloudinary 변환을 끼우고([cloudinaryScaled]) 디코딩 해상도도 같이 제한한다.
///
/// [width] 가 `double.infinity` 면 화면 폭을 기준으로 잡는다.
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

    // 칸이 화면 폭을 다 쓰는 경우(width: infinity)가 있어 MediaQuery 로 실폭을 잡는다.
    final logicalWidth = width.isFinite ? width : MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final pixelWidth = (logicalWidth * dpr).ceil();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: cloudinaryScaled(source, targetPixelWidth: pixelWidth) ?? source,
        width: width,
        height: height,
        fit: BoxFit.cover,
        // 메모리는 표시 크기가 아니라 디코딩 해상도로 정해진다. 변환으로 받은 폭보다
        // 크게 디코딩할 이유가 없다.
        memCacheWidth: pixelWidth,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}
