import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/story_video.dart';
import '../../../styles/app_colors.dart';
import '../../../util/shorts_url.dart';

/// 플레이어 아래 정보 영역. 유튜브 정책상 플레이어 위에는 아무것도 덮지 않아
/// 채널·제목·조회수는 전부 이 바깥 영역에 둔다.
class ShortsInfoSheet extends StatelessWidget {
  const ShortsInfoSheet({super.key, required this.video, required this.scale});

  final StoryVideo video;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        12 * scale,
        20 * scale,
        8 * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 24 * scale,
                  height: 24 * scale,
                  child: video.channelProfileUrl.isEmpty
                      ? const ColoredBox(color: AppColors.narBgLast)
                      : CachedNetworkImage(
                          imageUrl: video.channelProfileUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              const ColoredBox(color: AppColors.narBgLast),
                        ),
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  video.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 13 * scale,
                    color: AppColors.narText,
                  ),
                ),
              ),
              // 상태 표시일 뿐 토글이 아니다 — 소리는 항상 끈 채로 재생한다.
              Icon(
                Icons.volume_off_rounded,
                size: 14 * scale,
                color: AppColors.narText2,
                semanticLabel: l.shortsFeedMuted,
              ),
              SizedBox(width: 3 * scale),
              Text(
                l.shortsFeedMuted,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 11 * scale,
                  color: AppColors.narText2,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14 * scale,
              height: 1.35,
              color: AppColors.narText,
            ),
          ),
          SizedBox(height: 6 * scale),
          Row(
            children: [
              Text(
                l.communityViewCount(video.viewCount),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12 * scale,
                  color: AppColors.narText2,
                ),
              ),
              const Spacer(),
              // 출처를 밝히는 의도적 이탈 링크 — 눈에 띄지 않게 둔다.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: video.videoUrl.isEmpty && video.youtubeVideoId.isEmpty
                    ? null
                    : () => openShortsExternally(_watchUrl(video)),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4 * scale),
                  child: Text(
                    l.shortsFeedWatchOnYoutube,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12 * scale,
                      color: AppColors.narText2,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.narText2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 원본 링크. 서버가 안 줬으면 영상 ID 로 만든다.
String _watchUrl(StoryVideo v) => v.videoUrl.isNotEmpty
    ? v.videoUrl
    : 'https://www.youtube.com/shorts/${v.youtubeVideoId}';
