import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 첨부 사진 전체화면 뷰어. 좌우 스와이프로 넘기고 핀치로 확대한다.
///
/// 패키지를 쓰지 않고 [InteractiveViewer] 로만 만들었다. 줌·팬은 기본 위젯으로
/// 충분하고, 더블탭 줌이나 드래그로 닫기가 필요해지면 그때 photo_view 를 들이면 된다.
///
/// **본문의 [CommunityImage] 와 달리 큰 폭으로 받는다.** 본문은 표시 폭에 맞춰
/// w_400~800 으로 깎아 받는데, 그걸 확대하면 뭉개진다. 여기서는 버킷 최대값을 쓴다
/// (업로드가 maxWidth 1600 이라 사실상 원본에 가깝다).
class CommunityPhotoViewer extends StatefulWidget {
  const CommunityPhotoViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  /// 뷰어를 띄운다. 사진이 없으면 아무것도 하지 않는다.
  static void open(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
  }) {
    if (urls.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            CommunityPhotoViewer(urls: urls, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<CommunityPhotoViewer> createState() => _CommunityPhotoViewerState();
}

class _CommunityPhotoViewerState extends State<CommunityPhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 사진에만 집중하도록 완전한 검정. 앱 배경(narDark600)보다 어둡다.
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl:
                      cloudinaryScaled(
                        widget.urls[i],
                        targetPixelWidth: kCloudinaryWidthBuckets.last,
                      ) ??
                      widget.urls[i],
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.narText2,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: SvgPicture.asset(
                        'assets/icons/close.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          AppColors.narText,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  // 한 장이면 "1 / 1" 이 정보를 주지 않는다.
                  if (widget.urls.length > 1)
                    Text(
                      '${_index + 1} / ${widget.urls.length}',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.narText,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
