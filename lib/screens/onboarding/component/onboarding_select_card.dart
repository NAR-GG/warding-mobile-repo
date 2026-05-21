import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 온보딩 선택 그리드(리그/팀/선수)에 쓰는 카드.
///
/// 외부 크기는 부모(GridView 등)가 결정하고, 이미지는 카드 너비에 비례한다.
/// 선택되면 narBg 그라데이션 4px 테두리와 '선택됨' 배지가 표시된다.
class OnboardingSelectCard extends StatelessWidget {
  const OnboardingSelectCard({
    super.key,
    required this.image,
    required this.mainTitle,
    this.subTitle,
    this.onTap,
    this.selected = false,
    this.scale = 1.0,
  });

  /// 카드 상단 이미지.
  final Widget image;

  /// 큰 메인 타이틀 (18px 기준). 예: 'T1'.
  final String mainTitle;

  /// 작은 서브 타이틀 (11px 기준). null 이면 빈 줄로 자리만 남겨,
  /// 서브타이틀 유무와 상관없이 메인타이틀 위치가 고정된다.
  final String? subTitle;

  /// 카드 탭 콜백.
  final VoidCallback? onTap;

  /// 선택 여부. 선택되면 그라데이션 테두리와 배지가 표시된다.
  final bool selected;

  /// 디자인 시안(119×152) 대비 스케일. 폰트·간격에 적용된다.
  final double scale;

  /// 카드 너비 대비 이미지 비율 (디자인 71 / 119).
  static const double _imageRatio = 71 / 119;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 이미지는 카드 너비에 비례한다.
          final imageSize = constraints.maxWidth * _imageRatio;

          final content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: imageSize, height: imageSize, child: image),
              SizedBox(height: 6 * scale),
              // 서브타이틀이 없어도 빈 줄로 자리를 남겨, 서브타이틀 유무와
              // 상관없이 이미지·메인타이틀 위치를 고정한다.
              Text(
                subTitle ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  fontSize: 11 * scale,
                  height: 1.45,
                  letterSpacing: 0.21 * scale,
                  color: AppColors.narTextSecondary,
                ),
              ),
              Text(
                mainTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 18 * scale,
                  height: 1.0,
                  letterSpacing: 0.21 * scale,
                  color: AppColors.narText,
                ),
              ),
            ],
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              // 카드 본체
              if (selected)
                // 그라데이션 테두리: 바깥 그라데이션 Container + 안쪽 배경 Container
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.narBg,
                    borderRadius: BorderRadius.circular(16 * scale),
                  ),
                  padding: EdgeInsets.all(4 * scale),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.narDark600,
                      borderRadius: BorderRadius.circular(12 * scale),
                    ),
                    child: content,
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.narDark600,
                    borderRadius: BorderRadius.circular(16 * scale),
                    border: Border.all(
                      color: AppColors.narDark400,
                      width: 2 * scale,
                    ),
                  ),
                  child: content,
                ),
              if (selected)
                Positioned(
                  top: 10 * scale,
                  right: 14 * scale,
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.narBg.createShader(bounds),
                    child: Text(
                      '선택됨',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 10 * scale,
                        letterSpacing: 0.21 * scale,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
