import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 앱 공용 셀렉트 박스.
///
/// 높이 45·라운드 10 의 탭 가능한 박스. [trailing] 이 없으면 텍스트를
/// 가운데에, 있으면 텍스트를 왼쪽·[trailing] 을 오른쪽 끝에 배치한다.
/// 텍스트는 한 줄로, 박스를 넘치면 `...` 으로 줄인다.
/// 보통 라벨과 함께 쓰려면 [LabeledField] 로 감싼다.
class AppSelectBox extends StatelessWidget {
  const AppSelectBox({
    super.key,
    required this.text,
    this.onTap,
    this.trailing,
    this.scale = 1,
  });

  /// 박스에 표시할 텍스트.
  final String text;

  /// 박스 탭 콜백. null 이면 비활성.
  final VoidCallback? onTap;

  /// 오른쪽 끝에 둘 위젯 (예: 드롭다운 화살표). null 이면 텍스트만.
  final Widget? trailing;

  /// 비율 스케일. 디자인 시안(폭 375) 기준 수치에 곱한다.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasTrailing = trailing != null;
    final label = Text(
      text,
      // trailing 이 있으면 왼쪽 정렬, 없으면 가운데 정렬.
      textAlign: hasTrailing ? TextAlign.left : TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis, // 한 줄, 넘치면 ... 으로 줄임
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w400,
        fontSize: 16 * scale,
        height: 22 / 16, // line-height 22px / font-size 16px
        letterSpacing: 0,
        color: AppColors.narText3, // #C1C2C5
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 45 * scale,
        padding: EdgeInsets.symmetric(
          vertical: 8 * scale, // spacing/2
          horizontal: 16 * scale, // spacing/4
        ),
        decoration: BoxDecoration(
          color: AppColors.narBgLast, // #25262B
          borderRadius: BorderRadius.circular(10 * scale),
        ),
        child: hasTrailing
            ? Row(
                children: [
                  Expanded(child: label),
                  SizedBox(width: 8 * scale),
                  trailing!,
                ],
              )
            : Center(child: label),
      ),
    );
  }
}
