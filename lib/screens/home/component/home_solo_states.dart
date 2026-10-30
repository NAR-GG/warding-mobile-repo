import 'package:flutter/material.dart';

import '../../../components/dashed_border.dart';
import '../../../components/solo_face.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/player_subscription.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import 'home_solo_rank_section.dart';

/// 구독 0명 — 점선 빈 카드와 빈 프로필 원.
class HomeSoloEmptyCard extends StatelessWidget {
  const HomeSoloEmptyCard({super.key, required this.scale, this.onSubscribe});

  final double scale;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return KeyedSubtree(
      key: HomeSoloRankSection.emptyCardKey,
      child: DashedBorder(
        radius: 14 * scale,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 186 * scale),
          padding: EdgeInsets.symmetric(
            horizontal: 18 * scale,
            vertical: 24 * scale,
          ),
          decoration: BoxDecoration(
            color: AppColors.narBgTertiary,
            borderRadius: BorderRadius.circular(14 * scale),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DashedBorder(
                circle: true,
                child: Container(
                  width: 64 * scale,
                  height: 64 * scale,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.narBgTertiary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 34 * scale,
                    color: AppColors.narDark400,
                  ),
                ),
              ),
              SizedBox(height: 12 * scale),
              Text(
                l.homeHeroEmptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15 * scale,
                  height: 1.55,
                  color: AppColors.narGray400,
                ),
              ),
              SizedBox(height: 14 * scale),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSubscribe,
                child: Container(
                  height: 40 * scale,
                  padding: EdgeInsets.symmetric(horizontal: 22 * scale),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.narBg,
                    borderRadius: BorderRadius.circular(20 * scale),
                  ),
                  child: Text(
                    l.homeHeroEmptyButton,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 14 * scale,
                      color: AppColors.narText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 구독은 있는데 진행 중인 선수도 오늘 끝난 경기도 0명 — 한 줄짜리 조용한
/// 상태. 누르면 내 선수 화면.
///
/// 끝난 경기가 하나라도 있으면 이 대신 끝난 경기 줄(활성 상태)을 보여주므로,
/// 여기는 정말 아무 소식도 없을 때만 그린다 — "마지막 경기" 같은 보조 정보는
/// 없다. 시안(`mockup.html`)의 `.quiet`: 구독 선수 얼굴이 겹쳐 놓인 스택 +
/// 구독 수 한 줄 + 화살표. 구독이 얼굴 수보다 많으면 "+N" 칸이 붙는다.
class HomeSoloQuietRow extends StatelessWidget {
  const HomeSoloQuietRow({
    super.key,
    required this.faces,
    required this.subscribedTotal,
    required this.scale,
    this.onTap,
  });

  final List<PlayerSubscription> faces;
  final int subscribedTotal;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return GestureDetector(
      key: HomeSoloRankSection.quietKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 18 * scale,
        ),
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(14 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        child: Row(
          children: [
            if (faces.isNotEmpty) ...[
              _FaceStack(
                faces: faces,
                extra: subscribedTotal - faces.length,
                scale: scale,
              ),
              SizedBox(width: 14 * scale),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.homeSoloQuietTitle,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 15 * scale,
                      height: 1.35,
                      color: AppColors.narTextTertiary,
                    ),
                  ),
                  SizedBox(height: 5 * scale),
                  Text(
                    l.homeSoloQuietSubscribed(subscribedTotal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13 * scale,
                      height: 1.5,
                      color: AppColors.narText2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8 * scale),
            Icon(
              Icons.chevron_right,
              size: 16 * scale,
              color: AppColors.narText2,
            ),
          ],
        ),
      ),
    );
  }
}

/// 구독 선수 얼굴을 겹쳐 놓은 스택 — 38 원, 12씩 겹치고 카드 색 2px 테두리로
/// 서로를 갈라 놓는다. 뒤에 오는 얼굴이 위에 올라온다. [extra] 가 0보다 크면
/// 마지막에 "+N" 칸을 붙인다.
class _FaceStack extends StatelessWidget {
  const _FaceStack({
    required this.faces,
    required this.extra,
    required this.scale,
  });

  final List<PlayerSubscription> faces;
  final int extra;
  final double scale;

  static const double _size = 38;
  static const double _step = 26; // 38 - 겹침 12

  @override
  Widget build(BuildContext context) {
    final count = faces.length + (extra > 0 ? 1 : 0);
    final size = _size * scale;
    return SizedBox(
      width: (_size + _step * (count - 1)) * scale,
      height: size,
      child: Stack(
        children: [
          for (final (i, p) in faces.indexed)
            Positioned(
              left: _step * i * scale,
              child: SoloFace(
                name: p.playerName,
                url: resolveImageUrl(p.playerImageUrl),
                size: size,
                scale: scale,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: _step * faces.length * scale,
              child: SoloFace(
                name: '+$extra',
                url: null,
                size: size,
                scale: scale,
              ),
            ),
        ],
      ),
    );
  }
}
