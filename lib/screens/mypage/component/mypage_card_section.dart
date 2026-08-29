import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_radio.dart';
import '../../../components/nar_toggle.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../../../components/nar_word_break_text.dart';

/// 마이페이지 카드 섹션의 행 하나.
///
/// [leadingIcon] 을 주면 타이틀 왼쪽에 44 칩 안에 24 아이콘을 그린다
/// (화면 설정 섹션). 없으면 타이틀만 좌측 12 패딩으로 시작한다(내 활동 섹션).
/// [count] 를 주면 chevron 앞에 'N건'을 그라데이션으로 표시한다.
/// [description] 을 주면 행 아래에 회색 안내 문구를 덧붙인다.
/// [enabled] 가 false 면 비활성(회색 타이틀·탭 불가) — 준비 중인 메뉴 자리용.
class MypageCardItem {
  const MypageCardItem({
    required this.title,
    this.leadingIcon,
    this.count,
    this.description,
    this.onTap,
    this.enabled = true,
  });

  final String title;

  /// 타이틀 앞 아이콘 asset 경로. 예) 'assets/icons/layout-list.svg'.
  final String? leadingIcon;

  /// 우측 'N건'. null 이면 건수를 표시하지 않는다.
  final int? count;

  /// 행 아래 안내 문구. 예) 나르지지 웹사이트 소개.
  final String? description;

  final VoidCallback? onTap;

  /// false 면 회색 타이틀 + 탭 무시.
  final bool enabled;
}

/// 마이페이지 카드 섹션 (양옆 [horizontalPadding] 만큼 여백).
///
/// 카드 밖 좌측 상단 [label] + 카드 컨테이너(#1F2024, radius 10) 안에
/// 내용을 8 간격으로 쌓는다. '내 활동'·'화면 설정'·'일반 설정' 이 공유하는
/// 껍데기로, 새 섹션을 추가할 때도 label 과 내용만 넘기면 된다.
/// 설정 상세 화면처럼 라벨이 필요 없으면 [label] 을 비운다.
///
/// 내용은 둘 중 하나로 준다:
/// - [items] — 진입 행(타이틀 + chevron). '내 활동'·'화면 설정'.
/// - [children] — 토글 행처럼 진입 행이 아닌 위젯. '일반 설정'.
class MypageCardSection extends StatelessWidget {
  const MypageCardSection({
    super.key,
    required this.scale,
    this.label,
    this.items = const [],
    this.children = const [],
    this.horizontalPadding = 8,
  });

  final double scale;

  /// 섹션 라벨. 예) '내 활동', '화면 설정'. null 이면 라벨 줄을 그리지 않는다.
  final String? label;

  /// 진입 행 목록. [children] 보다 먼저 그린다.
  final List<MypageCardItem> items;

  /// 진입 행이 아닌 임의 위젯(예: 토글 행).
  final List<Widget> children;

  /// 섹션 좌우 여백. 마이페이지는 8, 설정 상세 화면은 16.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 섹션 라벨 — 카드 밖 좌측 상단.
          if (label != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16 * scale,
                vertical: 10 * scale,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 15 * scale,
                    height: 25 / 15,
                    color: AppColors.narText2,
                  ),
                ),
              ),
            ),
          // 카드 컨테이너.
          Container(
            padding: EdgeInsets.all(8 * scale),
            decoration: BoxDecoration(
              color: AppColors.narBgTertiary,
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, item) in items.indexed) ...[
                  if (i > 0) SizedBox(height: 8 * scale),
                  _MypageCardRow(item: item, scale: scale),
                ],
                for (final (i, child) in children.indexed) ...[
                  if (i > 0 || items.isNotEmpty) SizedBox(height: 8 * scale),
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드 안의 값 표시 행 (높이 44, 좌측 12 패딩).
///
/// 좌측 라벨(14/500) + 우측 값(14/500 회색). [showChevron] 이면 값 대신
/// chevron 을 그린다. 예) 계정 설정의 닉네임·이메일·회원탈퇴.
/// [emphasizeLabel] 이면 라벨을 진입 행과 같은 17/600 흰색으로 키운다
/// (예: 회원 탈퇴 화면의 '고객센터/문의').
class MypageCardValueRow extends StatelessWidget {
  const MypageCardValueRow({
    super.key,
    required this.scale,
    required this.label,
    this.value,
    this.showChevron = false,
    this.emphasizeLabel = false,
    this.onTap,
  });

  final double scale;
  final String label;

  /// 우측에 보일 값. null 이면 값 자리를 비운다.
  final String? value;

  /// true 면 우측에 chevron 을 그린다.
  final bool showChevron;

  /// true 면 라벨을 17/600 흰색으로 그린다.
  final bool emphasizeLabel;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44 * scale,
        child: Padding(
          padding: EdgeInsets.only(left: 12 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: emphasizeLabel
                    ? TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 17 * scale,
                        height: 25 / 17,
                        color: AppColors.narText,
                      )
                    : TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                        fontSize: 14 * scale,
                        height: 25 / 14,
                        color: showChevron
                            ? AppColors.narTextTertiary
                            : AppColors.narText,
                      ),
              ),
              if (showChevron)
                SizedBox(
                  width: 44 * scale,
                  height: 44 * scale,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/chevron-right.svg',
                      width: 24 * scale,
                      height: 24 * scale,
                    ),
                  ),
                )
              else if (value != null)
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(right: 10 * scale),
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                        fontSize: 14 * scale,
                        height: 1.55,
                        color: AppColors.narText2,
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

/// 카드 안의 라디오 선택 행 (padding 상하 5·우 10).
///
/// 위에서부터 타이틀(17/600) → gap 4 → 설명(14/500 회색) → gap 10 →
/// [options] 를 세로로 쌓은 라디오 목록. 예) 캘린더 시작 요일(월요일/일요일).
class MypageCardRadioRow<T> extends StatelessWidget {
  const MypageCardRadioRow({
    super.key,
    required this.scale,
    required this.title,
    required this.description,
    required this.options,
    required this.value,
    this.onChanged,
  });

  final double scale;
  final String title;

  /// 타이틀 아래 안내 문구.
  final String description;

  /// 선택지 — (값, 라벨) 쌍을 위에서부터 순서대로 그린다.
  final List<({T value, String label})> options;

  /// 현재 선택된 값.
  final T value;

  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 5 * scale, 10 * scale, 5 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 12 * scale),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 17 * scale,
                height: 25 / 17,
                color: AppColors.narText,
              ),
            ),
          ),
          SizedBox(height: 4 * scale),
          Padding(
            padding: EdgeInsets.only(left: 12 * scale),
            child: NarWordBreakText(
              description,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                height: 25 / 14,
                color: AppColors.narText2,
              ),
            ),
          ),
          SizedBox(height: 10 * scale),
          // 라디오 목록 — 타이틀·설명 아래, 좌우 12 패딩 안에 세로로 쌓는다.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, option) in options.indexed) ...[
                  if (i > 0) SizedBox(height: 10 * scale),
                  NarRadio(
                    label: option.label,
                    selected: option.value == value,
                    scale: scale,
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(option.value),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드 안의 토글 행 (padding 상하 5·우 10, 타이틀↔설명 gap 4).
///
/// 위: 타이틀(17/600) + 우측 [NarToggle], 아래: 설명(14/500 회색).
/// [extra] 를 주면 설명 아래에 덧붙인다(예: 시작/종료 시각 선택).
class MypageCardToggleRow extends StatelessWidget {
  const MypageCardToggleRow({
    super.key,
    required this.scale,
    required this.title,
    required this.description,
    required this.value,
    this.onChanged,
    this.extra,
  });

  final double scale;
  final String title;

  /// 토글 아래 안내 문구.
  final String description;

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// 설명 아래에 덧붙일 위젯. 없으면 표시하지 않는다.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 5 * scale, 10 * scale, 5 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 12 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 17 * scale,
                      height: 25 / 17,
                      color: AppColors.narText,
                    ),
                  ),
                ),
                SizedBox(width: 8 * scale),
                NarToggle(value: value, onChanged: onChanged, scale: scale),
              ],
            ),
          ),
          SizedBox(height: 4 * scale),
          Padding(
            padding: EdgeInsets.only(left: 12 * scale),
            child: NarWordBreakText(
              description,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                height: 25 / 14,
                color: AppColors.narText2,
              ),
            ),
          ),
          ?extra,
        ],
      ),
    );
  }
}

/// 카드 안의 행 하나 (높이 44).
///
/// 좌측 [MypageCardItem.leadingIcon] 칩 + 타이틀,
/// 우측 'N건'(그라데이션) + chevron.
/// [MypageCardItem.description] 이 있으면 행 아래에 안내 문구를 덧붙인다.
class _MypageCardRow extends StatelessWidget {
  const _MypageCardRow({required this.item, required this.scale});

  final MypageCardItem item;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hasIcon = item.leadingIcon != null;
    final description = item.description;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.enabled ? item.onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44 * scale,
            child: Padding(
              // 아이콘이 있으면 44 칩의 10 패딩이 여백을 만들어 좌측 패딩은 없다.
              padding: EdgeInsets.only(left: hasIcon ? 0 : 12 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasIcon) ...[
                          // 44 칩 안에 24 아이콘 — 시안 아이콘 색이 제각각이라 흰색으로 통일.
                          SizedBox(
                            width: 44 * scale,
                            height: 44 * scale,
                            child: Center(
                              child: SvgPicture.asset(
                                item.leadingIcon!,
                                width: 24 * scale,
                                height: 24 * scale,
                                colorFilter: ColorFilter.mode(
                                  item.enabled
                                      ? AppColors.narText
                                      : AppColors.narLine,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 1 * scale),
                        ],
                        Flexible(
                          child: Text(
                            item.title,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              fontSize: 17 * scale,
                              height: 25 / 17,
                              color: item.enabled
                                  ? AppColors.narText
                                  : AppColors.narLine,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (item.count != null) ...[
                        // 'N건' — narBg 그라데이션 텍스트.
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.narBg.createShader(bounds),
                          child: Text(
                            l.countUnit(item.count!),
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w500,
                              fontSize: 14 * scale,
                              height: 25 / 14,
                              // ShaderMask 가 덮어쓰므로 흰색이어야 그라데이션이 보인다.
                              color: AppColors.narText,
                            ),
                          ),
                        ),
                        SizedBox(width: 10 * scale),
                      ],
                      SizedBox(
                        width: 44 * scale,
                        height: 44 * scale,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/chevron-right.svg',
                            width: 24 * scale,
                            height: 24 * scale,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (description != null)
            Padding(
              // 아이콘 행은 44 칩이 좌측을 차지하므로 설명도 같은 만큼 들여쓴다.
              padding: EdgeInsets.only(left: hasIcon ? 45 * scale : 12 * scale),
              child: NarWordBreakText(
                description,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  fontSize: 14 * scale,
                  height: 25 / 14,
                  color: AppColors.narText2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
