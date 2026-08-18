import 'package:flutter/material.dart';

import '../styles/app_colors.dart';
import 'nar_button.dart';

/// [NarPopupDialog] 하단 버튼 하나.
///
/// 버튼들은 가로로 폭을 균등하게 나눠 갖는다(시안의 `flex-grow: 1`).
class NarPopupAction {
  const NarPopupAction({
    required this.label,
    required this.onPressed,
    this.variant = NarButtonVariant.set1,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 기본은 어두운 [NarButtonVariant.set1]. 강조 버튼은 밝은
  /// [NarButtonVariant.type1] 을 쓴다.
  final NarButtonVariant variant;
}

/// 공용 팝업 모달을 띄운다.
///
/// 뒷배경은 검정 70%([AppColors.narPopupBarrier])로 깔린다.
/// 반환값은 [NarPopupAction.onPressed] 안에서 `Navigator.of(context).pop(값)`
/// 으로 직접 정한다 — 버튼 개수·의미가 화면마다 달라 여기서 정하지 않는다.
///
/// ```dart
/// await showNarPopup<bool>(
///   context: context,
///   gradientLabel: '와딩 200% 즐기기',
///   title: '환영해요! 와딩 사용 꿀팁이 도착했어요',
///   message: '지금 보지 않아도 [마이페이지 > 와딩 사용 가이드]에서 언제든 다시 볼 수 있어요.',
///   child: Image.asset('assets/images/guide.png'),
///   actions: [
///     NarPopupAction(
///       label: '다시 보지 않기',
///       onPressed: () => Navigator.of(context).pop(false),
///     ),
///     NarPopupAction(
///       label: '가이드 보기',
///       variant: NarButtonVariant.type1,
///       onPressed: () => Navigator.of(context).pop(true),
///     ),
///   ],
/// );
/// ```
Future<T?> showNarPopup<T>({
  required BuildContext context,
  String? gradientLabel,
  String? title,
  String? message,
  Widget? child,
  List<NarPopupAction> actions = const [],
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: AppColors.narPopupBarrier,
    builder: (_) => NarPopupDialog(
      gradientLabel: gradientLabel,
      title: title,
      message: message,
      actions: actions,
      child: child,
    ),
  );
}

/// 공용 팝업 모달.
///
/// 시안(335×auto, radius 16, padding 24, gap 24) 기준이며 위에서부터
/// 텍스트 블록 → [child] → 버튼 행 순으로 쌓는다. 셋 다 선택이라 필요한 것만
/// 넘기면 되고, 넘기지 않은 영역은 gap 까지 함께 빠진다.
///
/// 높이는 시안(553)이 아니라 내용에 맞춘다 — 문구 길이와 [child] 가 화면마다
/// 달라 고정하면 넘치거나 빈 공간이 남는다. 대신 화면 높이의 80% 를 넘으면
/// [child] 영역이 스크롤된다.
///
/// [showNarPopup] 으로 띄우는 걸 권장한다(뒷배경 딤이 함께 적용된다).
class NarPopupDialog extends StatelessWidget {
  const NarPopupDialog({
    super.key,
    this.gradientLabel,
    this.title,
    this.message,
    this.child,
    this.actions = const [],
  });

  /// 최상단 그라데이션 텍스트(14px). 예: '와딩 200% 즐기기'.
  final String? gradientLabel;

  /// 메인 타이틀(18px).
  final String? title;

  /// 설명 문구(12px). 좌측 정렬 — 시안에서 이 줄만 `align-items: center` 가
  /// 아니라 블록 폭을 꽉 채운다.
  final String? message;

  /// 가운데 콘텐츠. 이미지·리스트 등 무엇이든 들어갈 수 있다.
  final Widget? child;

  /// 하단 버튼들. 비우면 버튼 영역 자체가 빠진다.
  final List<NarPopupAction> actions;

  bool get _hasHeader =>
      gradientLabel != null || title != null || message != null;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = media.size.width.clamp(320.0, 430.0) / 375;

    final sections = <Widget>[
      if (_hasHeader) _buildHeader(scale),
      // 콘텐츠가 길면 여기서만 스크롤되게 둔다 — 헤더와 버튼은 항상 보인다.
      if (child != null) Flexible(child: SingleChildScrollView(child: child)),
      if (actions.isNotEmpty) _buildActions(scale),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        child: Container(
          width: 335 * scale,
          padding: EdgeInsets.all(24 * scale),
          decoration: BoxDecoration(
            color: AppColors.narDark800,
            borderRadius: BorderRadius.circular(16 * scale),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) SizedBox(height: 24 * scale),
                sections[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 그라데이션 라벨 + 타이틀 + 설명. 셋 다 선택이라 있는 것만 gap 8 로 쌓는다.
  Widget _buildHeader(double scale) {
    final lines = <Widget>[
      if (gradientLabel != null) _GradientText(gradientLabel!, scale: scale),
      if (title != null)
        Text(
          title!,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            fontSize: 18 * scale,
            height: 1.45,
            letterSpacing: 0.21 * scale,
            color: AppColors.narText,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 라벨과 타이틀은 gap 4, 그 묶음과 설명 사이는 gap 8 (시안).
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) SizedBox(height: 4 * scale),
          lines[i],
        ],
        if (message != null) ...[
          if (lines.isNotEmpty) SizedBox(height: 8 * scale),
          Text(
            message!,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
              fontSize: 12 * scale,
              height: 1.45,
              letterSpacing: 0.21 * scale,
              color: AppColors.narTextTertiary,
            ),
          ),
        ],
      ],
    );
  }

  /// 버튼 행. 각 버튼이 폭을 균등하게 나눠 갖는다(시안 `flex-grow: 1`).
  /// [NarButton] 의 type1/type2 는 폭이 고정이라 [Expanded] 로 감싸 늘린다.
  Widget _buildActions(double scale) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) SizedBox(width: 16 * scale),
          Expanded(
            child: NarButton(
              label: actions[i].label,
              variant: actions[i].variant,
              onPressed: actions[i].onPressed,
              scale: scale,
            ),
          ),
        ],
      ],
    );
  }
}

/// 그라데이션이 글자에만 입혀진 텍스트([AppColors.narBg] 사용).
///
/// 시안의 `background-clip: text` 에 해당한다. [ShaderMask] 는 자식이 그린
/// 픽셀에 셰이더를 곱하므로, 글자는 흰색으로 그려야 그라데이션 색이 그대로 남는다.
class _GradientText extends StatelessWidget {
  const _GradientText(this.text, {required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => AppColors.narBg.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w500,
          fontSize: 14 * scale,
          height: 1.45,
          letterSpacing: 0.21 * scale,
          color: AppColors.narText,
        ),
      ),
    );
  }
}
