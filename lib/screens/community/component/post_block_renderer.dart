import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../model/community_post_block.dart';
import '../../../styles/app_colors.dart';
import 'community_image.dart';
import 'community_photo_viewer.dart';

/// 블록 본문(bodyFormat=BLOCKS) 렌더러 — 상세 화면의 본문 자리에 블록을
/// 순서대로 쌓는다. link·embed 는 v1 에서 탭 시 외부 브라우저로 연다
/// (인앱 WebView·인라인 재생은 의존성/성능 문제로 보류).
class PostBlockRenderer extends StatelessWidget {
  const PostBlockRenderer({
    super.key,
    required this.blocks,
    required this.scale,
  });

  final List<CommunityPostBlock> blocks;
  final double scale;

  @override
  Widget build(BuildContext context) {
    // 사진 전체화면 뷰어는 글의 모든 이미지를 좌우로 넘긴다 — 인덱스 매핑용.
    final imageUrls = [
      for (final b in blocks)
        if (b.type == 'image' && b.url != null) b.url!,
    ];

    final children = <Widget>[];
    for (final block in blocks) {
      final widget = switch (block.type) {
        'text' => _text(block),
        'image' => _image(context, block, imageUrls),
        'link' => _LinkCard(block: block, scale: scale),
        'embed' => _EmbedCard(block: block, scale: scale),
        _ => null,
      };
      if (widget == null) continue;
      if (children.isNotEmpty) children.add(SizedBox(height: 12 * scale));
      children.add(widget);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _text(CommunityPostBlock block) {
    final heading = block.isHeading;
    return Text(
      block.text ?? '',
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontWeight: heading ? FontWeight.w700 : FontWeight.w400,
        fontSize: (heading ? 16 : 14) * scale,
        height: heading ? 1.45 : 1.65,
        color: heading ? AppColors.narText : AppColors.narText3,
      ),
    );
  }

  Widget _image(
    BuildContext context,
    CommunityPostBlock block,
    List<String> imageUrls,
  ) {
    final url = block.url;
    if (url == null) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => CommunityPhotoViewer.open(
        context,
        urls: imageUrls,
        initialIndex: imageUrls.indexOf(url).clamp(0, imageUrls.length - 1),
      ),
      child: CommunityImage(
        source: url,
        width: double.infinity,
        height: null,
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        radius: 10 * scale,
      ),
    );
  }
}

Future<void> openBlockUrl(BuildContext context, String? url) async {
  if (url == null) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// 링크 카드 — OG 스냅샷(제목·설명·이미지·사이트명). 프리뷰가 없으면 URL 만.
class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.block, required this.scale});

  final CommunityPostBlock block;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final title = block.title;
    final description = block.description;
    final host = Uri.tryParse(block.url ?? '')?.host ?? '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openBlockUrl(context, block.url),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.narDark600,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: AppColors.narLine2, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.imageUrl != null)
              CommunityImage(
                source: block.imageUrl!,
                width: double.infinity,
                height: 160 * scale,
              ),
            Padding(
              padding: EdgeInsets.all(12 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (title == null || title.isEmpty) ? (block.url ?? '') : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5 * scale,
                      height: 1.45,
                      color: AppColors.narText,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    SizedBox(height: 3 * scale),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w400,
                        fontSize: 12 * scale,
                        height: 1.45,
                        color: AppColors.narText2,
                      ),
                    ),
                  ],
                  SizedBox(height: 5 * scale),
                  Text(
                    block.siteName ?? host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          ],
        ),
      ),
    );
  }
}

/// 임베드 카드 — 유튜브는 썸네일 + 재생 아이콘, 나머지는 제공자 라벨 카드.
/// v1 은 탭 시 외부 브라우저(치지직·SOOP·X 는 앱 스킴으로 이어진다).
class _EmbedCard extends StatelessWidget {
  const _EmbedCard({required this.block, required this.scale});

  final CommunityPostBlock block;
  final double scale;

  static const _providerLabels = {
    'youtube': 'YouTube',
    'chzzk': '치지직',
    'soop': 'SOOP',
    'x': 'X',
  };

  @override
  Widget build(BuildContext context) {
    final url = block.url ?? '';
    final videoId =
        block.provider == 'youtube' ? CommunityPostBlock.youtubeVideoId(url) : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openBlockUrl(context, block.url),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.narDark600,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: AppColors.narLine2, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (videoId != null)
              Stack(
                alignment: Alignment.center,
                children: [
                  CommunityImage(
                    source: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                    width: double.infinity,
                    height: 190 * scale,
                  ),
                  Container(
                    width: 46 * scale,
                    height: 46 * scale,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 30 * scale,
                      color: AppColors.narText,
                    ),
                  ),
                ],
              ),
            Padding(
              padding: EdgeInsets.all(12 * scale),
              child: Row(
                children: [
                  Icon(
                    videoId == null ? Icons.play_circle_outline : Icons.link,
                    size: 15 * scale,
                    color: AppColors.narText2,
                  ),
                  SizedBox(width: 6 * scale),
                  Text(
                    _providerLabels[block.provider] ?? block.provider ?? '',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 12 * scale,
                      height: 1.4,
                      color: AppColors.narText,
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w400,
                        fontSize: 11.5 * scale,
                        height: 1.4,
                        color: AppColors.narText2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
