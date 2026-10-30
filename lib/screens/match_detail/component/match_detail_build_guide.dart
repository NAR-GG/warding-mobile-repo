import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 룬·아이템 탭 시 뜨는 가이드(이름+설명) 카드. 탭한 아이콘 바로 아래
/// [layerLink]를 기준으로 붙는다. 배경 전체를 덮는 투명 배리어를 같이 깔아
/// 바깥을 탭하면 닫히게 한다.
class BuildGuideOverlay extends StatelessWidget {
  const BuildGuideOverlay({
    super.key,
    required this.layerLink,
    required this.name,
    required this.description,
    required this.scale,
    required this.onDismiss,
    this.alignRight = false,
  });

  final LayerLink layerLink;
  final String name;
  final String description;
  final double scale;
  final VoidCallback onDismiss;

  /// true 면 카드의 오른쪽 끝을 아이콘 오른쪽에 맞춰 왼쪽으로 펼친다.
  /// 화면 오른쪽 끝 칸(장신구 등)에서 카드가 화면 밖으로 나가는 걸 막는다.
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor: alignRight
              ? Alignment.bottomRight
              : Alignment.bottomLeft,
          followerAnchor: alignRight ? Alignment.topRight : Alignment.topLeft,
          offset: Offset(0, 4 * scale),
          child: BuildGuideCard(
            name: name,
            description: description,
            scale: scale,
          ),
        ),
      ],
    );
  }
}

class BuildGuideCard extends StatelessWidget {
  const BuildGuideCard({
    super.key,
    required this.name,
    required this.description,
    required this.scale,
  });

  final String name;
  final String description;
  final double scale;

  /// 카드 최대 폭(시안 166). 호출부가 화면 밖 판정에도 쓴다.
  static const double maxWidth = 166;

  @override
  Widget build(BuildContext context) {
    // Overlay 트리에는 Material 조상이 없어, 이 카드가 없으면 Text 가
    // 기본(디버그) 텍스트 스타일 — 노란 밑줄 포함 — 로 렌더된다.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth * scale),
        padding: EdgeInsets.all(8 * scale),
        decoration: BoxDecoration(
          color: AppColors.narBgContent,
          border: Border.all(color: AppColors.narWhiteBorder15, width: 1),
          borderRadius: BorderRadius.circular(8 * scale),
          boxShadow: [
            BoxShadow(
              color: AppColors.narDarkOpacity62,
              offset: Offset(2 * scale, 2 * scale),
              blurRadius: 8 * scale,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => AppColors.narBg.createShader(bounds),
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 12 * scale,
                  height: 1.45,
                  color: AppColors.narText,
                ),
              ),
            ),
            SizedBox(height: 4 * scale),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 10 * scale,
                height: 1.45,
                color: AppColors.narText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
