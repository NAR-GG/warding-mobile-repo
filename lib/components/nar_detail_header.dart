import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';

/// 상세 페이지 공용 헤더. 좌측 뒤로가기 + 가운데 타이틀 + (옵션) 우측 슬롯.
///
/// 경기 상세·선수 평점·구독 설정·온보딩 등 같은 레이아웃을 쓰는 화면에서
/// 타이틀과 우측 슬롯만 바꿔 재사용한다.
///
/// - 우측 슬롯에는 [NarDropdown] (세트 전환), [TextButton] (건너뛰기), 아이콘 버튼 등
///   상황에 맞는 위젯을 자유롭게 넣는다. null 이면 우측 비워둔다.
/// - [onBack] 미지정 시 `Navigator.maybePop` 으로 폴백.
class NarDetailHeader extends StatelessWidget {
  const NarDetailHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.backIconAsset = 'assets/icons/back.svg',
    this.scale = 1,
    this.centerTitle = true,
  });

  /// 타이틀 텍스트.
  final String title;

  /// 뒤로가기 탭 콜백. null 이면 `Navigator.maybePop` 호출.
  final VoidCallback? onBack;

  /// 우측 슬롯. 드롭다운·텍스트버튼·아이콘 등 임의 위젯.
  final Widget? trailing;

  /// 좌측 뒤로가기 아이콘 에셋 경로. 기본 [back.svg].
  /// 온보딩 등 chevron-left 가 어울리는 화면은 다른 경로로 바꾼다.
  final String backIconAsset;

  /// 비율 스케일. 시안(폭 375) 기준 수치에 곱한다.
  final double scale;

  /// true(기본) 면 타이틀을 가운데 고정. false 면 뒤로가기 아이콘 바로 옆(좌측)에
  /// 붙이고 우측 슬롯과 양끝 정렬한다(예: 경기 일정 상세 헤더).
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w700,
      fontSize: 18 * scale,
      height: 21 / 18,
      color: AppColors.narText,
    );
    final backButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onBack ?? () => Navigator.of(context).maybePop(),
      child: SvgPicture.asset(
        backIconAsset,
        width: 24 * scale,
        height: 24 * scale,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: 18.5 * scale,
        left: 20 * scale,
        right: 20 * scale,
        bottom: 22 * scale,
      ),
      child: SizedBox(
        height: 34 * scale,
        child: centerTitle
            ? Stack(
                alignment: Alignment.center,
                children: [
                  // 가운데 제목이 좌우 슬롯(뒤로가기 24, 우측 아이콘)을 침범하지
                  // 않도록 양쪽에 자리를 비워 둔다. 제약이 없으면 긴 제목이
                  // 아이콘 위로 그대로 넘어가 겹친다.
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 44 * scale),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: titleStyle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(child: backButton),
                  ),
                  if (trailing != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(child: trailing!),
                    ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 우측 슬롯 폭은 내용에 따라 달라진다(스포방지 토글 등).
                  // 제목이 길어도 슬롯을 밀어내지 않도록 제목만 줄인다.
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        backButton,
                        SizedBox(width: 16 * scale),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
      ),
    );
  }
}
