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
///
/// [height] 가 null 이면 **원본 비율을 지킨다** — 폭에 맞추고 세로는 사진이 정하되
/// [maxHeight] 까지만 늘어난다. 상세 화면처럼 사진 자체가 콘텐츠인 자리에서 쓴다.
/// null 이 아니면 그 높이에 맞춰 `BoxFit.cover` 로 잘라낸다(목록 썸네일).
class CommunityImage extends StatelessWidget {
  const CommunityImage({
    super.key,
    required this.source,
    required this.width,
    required this.height,
    this.maxHeight,
    this.radius = 8,
  });

  final String source;
  final double width;

  /// null 이면 원본 비율 유지(잘리지 않는다).
  final double? height;

  /// [height] 가 null 일 때 세로 상한. 세로로 긴 사진이 화면을 통째로 먹는 걸 막는다.
  final double? maxHeight;

  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      // 비율 유지 모드에서는 로드 전 높이를 모른다. 자리를 아예 안 잡으면 사진이 뜨는
      // 순간 아래 내용이 밀려 내려가므로(레이아웃 점프) 흔한 가로 사진 비율(4:3)로
      // 임시 자리를 잡아둔다.
      height: height ?? (width.isFinite ? width * 3 / 4 : null),
      color: AppColors.narDark500,
    );

    // 칸이 화면 폭을 다 쓰는 경우(width: infinity)가 있어 MediaQuery 로 실폭을 잡는다.
    final logicalWidth = width.isFinite ? width : MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final pixelWidth = (logicalWidth * dpr).ceil();

    final image = CachedNetworkImage(
      imageUrl: cloudinaryScaled(source, targetPixelWidth: pixelWidth) ?? source,
      width: width,
      height: height,
      // 높이를 받았으면 그 칸을 채우려 잘라내고(썸네일), 없으면 폭에 맞춰 비율을 지킨다.
      fit: height == null ? BoxFit.fitWidth : BoxFit.cover,
      // 메모리는 표시 크기가 아니라 디코딩 해상도로 정해진다. 변환으로 받은 폭보다
      // 크게 디코딩할 이유가 없다.
      memCacheWidth: pixelWidth,
      placeholder: height == null ? (_, _) => placeholder : null,
      fadeInDuration: const Duration(milliseconds: 150),
      errorWidget: (_, _, _) => placeholder,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: height == null && maxHeight != null
          ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight!),
              child: image,
            )
          : image,
    );
  }
}
