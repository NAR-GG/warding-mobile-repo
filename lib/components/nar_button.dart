import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// nar_button 디자인 토큰 버튼 종류.
enum NarButtonVariant {
  /// nar_button_1 — 밝은 배경, 테두리 없음. 폭 고정(110.5).
  type1,

  /// nar_button_2 — 어두운 배경 + 테두리. 폭 고정(110.5).
  type2,

  /// nar_button_set1 — narDark300 배경, 테두리 없음, 부모 폭을 채움.
  set1,

  /// set1 비활성 — narDark600 배경 + narDark300 테두리·텍스트, 부모 폭을 채움.
  /// (예: 경기 상세 '준비중'·'경기 종료')
  set1Disabled,

  /// 구독 — 미구독 상태. 밝은 회색 90% 배경 + #495057 텍스트. 64×34 고정.
  subscribe,

  /// 구독중 — 구독 상태. 보라 50% 배경 + #FCFDFE 텍스트. 64×34 고정.
  subscribed,
}

/// 앱 공용 버튼.
/// [variant] 별 사이즈/스타일:
/// - type1/type2: 110.5×34 고정, Open Sans 400, padding 10, radius 8.
/// - set1: 부모 폭을 채우고 34 높이, Open Sans 400, padding 10, radius 8.
/// - subscribe/subscribed: 64×34 고정, Pretendard 500, padding 16, radius 10.
class NarButton extends StatelessWidget {
  const NarButton({
    super.key,
    required this.label,
    required this.variant,
    this.onPressed,
    this.scale = 1.0,
  });

  final String label;
  final NarButtonVariant variant;
  final VoidCallback? onPressed;
  final double scale;

  bool get _isSubscribe =>
      variant == NarButtonVariant.subscribe ||
      variant == NarButtonVariant.subscribed;

  Color get _bgColor {
    switch (variant) {
      case NarButtonVariant.type1:
        return AppColors.narButton1Bg;
      case NarButtonVariant.type2:
        return AppColors.narButton2Bg;
      case NarButtonVariant.set1:
        return AppColors.narDark300;
      case NarButtonVariant.set1Disabled:
        return AppColors.narDark600;
      case NarButtonVariant.subscribe:
        return AppColors.narSubscribeBg;
      case NarButtonVariant.subscribed:
        return AppColors.narChipSelectedBg;
    }
  }

  Color get _textColor {
    switch (variant) {
      case NarButtonVariant.type1:
        return AppColors.narButton1Text;
      case NarButtonVariant.type2:
        return AppColors.narButton2Text;
      case NarButtonVariant.set1:
        return AppColors.narText;
      case NarButtonVariant.set1Disabled:
        return AppColors.narDark300; // #5C5F66
      case NarButtonVariant.subscribe:
        return AppColors.narLine2; // #495057
      case NarButtonVariant.subscribed:
        return AppColors.narTextTertiary; // #FCFDFE
    }
  }

  BoxBorder? _border(double scale) {
    if (variant == NarButtonVariant.type2) {
      return Border.all(color: AppColors.narButton2Line, width: 1.5 * scale);
    }
    if (variant == NarButtonVariant.set1Disabled) {
      return Border.all(color: AppColors.narDark300, width: 1.5 * scale);
    }
    return null;
  }

  /// type1/type2 는 시안 폭 고정, set1 은 부모를 채우고, subscribe* 는 콘텐츠 자동 폭.
  double? _width(double scale) {
    switch (variant) {
      case NarButtonVariant.type1:
      case NarButtonVariant.type2:
        return 110.5 * scale;
      case NarButtonVariant.set1:
      case NarButtonVariant.set1Disabled:
        return double.infinity;
      case NarButtonVariant.subscribe:
      case NarButtonVariant.subscribed:
        // 라벨 길이('구독' vs '구독중')에 따라 폭이 달라지지 않도록, 더 긴 라벨
        // '구독중' 기준으로 폭을 고정한다(짧은 '구독'은 같은 폭 안에서 가운데 정렬).
        return _measureText('구독중', _textStyle(scale)).width +
            _horizontalPadding * scale * 2;
    }
  }

  /// [text] 를 [style] 로 한 줄 렌더링했을 때 크기를 잰다(줄바꿈 폭 계산용).
  Size _measureText(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.size;
  }

  double get _radius => _isSubscribe ? 10 : 8;
  double get _horizontalPadding => _isSubscribe ? 16 : 10;

  TextStyle _textStyle(double scale) => _isSubscribe
      ? TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w500,
          fontSize: 14 * scale,
          height: 1,
          color: _textColor,
        )
      : TextStyle(
          fontFamily: 'Open Sans',
          fontWeight: FontWeight.w400,
          fontSize: 14 * scale,
          letterSpacing: 0,
          color: _textColor,
        );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: _width(scale),
        height: 34 * scale,
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding * scale),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(_radius * scale),
          border: _border(scale),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: _textStyle(scale),
        ),
      ),
    );
  }
}
