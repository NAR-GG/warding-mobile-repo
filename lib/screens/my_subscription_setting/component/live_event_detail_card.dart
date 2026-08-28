import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';

/// 라이브 이벤트 세부 항목 종류.
///
/// `TeamNotificationSubscription` 의 killEnabled/baronEnabled/dragonEnabled/
/// towerEnabled/inhibitorEnabled 에 각각 대응하며,
/// `PUT /notification-subscriptions/{teamId}` 로 반영된다.
enum LiveEventKind { kill, baron, dragon, tower, inhibitor }

extension LiveEventKindLabel on LiveEventKind {
  String label(AppLocalizations l) {
    switch (this) {
      case LiveEventKind.kill:
        return l.objectKill;
      case LiveEventKind.baron:
        return l.objectBaron;
      case LiveEventKind.dragon:
        return l.objectDragon;
      case LiveEventKind.tower:
        return l.objectTower;
      case LiveEventKind.inhibitor:
        return l.objectInhibitor;
    }
  }
}

/// 라이브 이벤트 알림 세부 설정 카드.
///
/// 라이브 이벤트 토글이 ON 일 때만 그 아래에 나타난다.
/// 바깥 여백 padding 10/20/10/[leftPadding] (알림 행 라벨보다 더 들여쓴다).
/// 카드는 narDark500 배경 + radius 10 + padding 4/8, 안에 항목 행을 쌓는다.
/// 행 사이는 0.5 narLine2 구분선, 마지막 행에는 선이 없다.
class LiveEventDetailCard extends StatelessWidget {
  const LiveEventDetailCard({
    super.key,
    required this.selected,
    required this.onChanged,
    this.leftPadding = 70,
    this.scale = 1,
  });

  /// 켜져 있는 항목들.
  final Set<LiveEventKind> selected;

  /// 항목 탭. (종류, 켤지 여부)
  final void Function(LiveEventKind kind, bool value) onChanged;

  /// 카드 좌측 들여쓰기. 마이 구독 설정(팀 알림)은 라벨이 60 들여쓴 자리라
  /// 기본 70, 경기 알림 시트는 라벨이 20 이라 20 을 준다.
  final double leftPadding;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const kinds = LiveEventKind.values;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        leftPadding * scale,
        10 * scale,
        20 * scale,
        10 * scale,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 4 * scale,
          horizontal: 8 * scale,
        ),
        decoration: BoxDecoration(
          color: AppColors.narDark500,
          borderRadius: BorderRadius.circular(10 * scale),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < kinds.length; i++)
              _LiveEventRow(
                label: kinds[i].label(l),
                value: selected.contains(kinds[i]),
                onTap: () => onChanged(kinds[i], !selected.contains(kinds[i])),
                // 마지막 행은 구분선 없이 높이 34.
                showDivider: i < kinds.length - 1,
                scale: scale,
              ),
          ],
        ),
      ),
    );
  }
}

/// 세부 항목 한 행: 체크 아이콘(17) + gap 14 + 라벨.
///
/// ON 은 그라데이션 체크 + narTextTertiary 라벨,
/// OFF 는 narDark300 체크 + narDark300 라벨.
class _LiveEventRow extends StatelessWidget {
  const _LiveEventRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.showDivider,
    required this.scale,
  });

  final String label;
  final bool value;
  final VoidCallback onTap;
  final bool showDivider;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final check = SvgPicture.asset(
      'assets/icons/check.svg',
      width: 17 * scale,
      height: 17 * scale,
      // 에셋 stroke 가 빨강으로 박혀 있어 상태 색으로 덮어쓴다.
      // ON 은 아래 ShaderMask 가 그라데이션으로 다시 덮으므로 흰색을 깐다.
      colorFilter: ColorFilter.mode(
        value ? AppColors.narText : AppColors.narDark300,
        BlendMode.srcIn,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // 구분선이 있는 행은 0.5 만큼 더 높다(34 + 0.5).
        height: (showDivider ? 34.5 : 34) * scale,
        padding: EdgeInsets.symmetric(horizontal: 8 * scale),
        decoration: showDivider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.narLine2,
                    width: 0.5 * scale,
                  ),
                ),
              )
            : null,
        child: Row(
          children: [
            if (value)
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.narBg.createShader(bounds),
                child: check,
              )
            else
              check,
            SizedBox(width: 14 * scale),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                height: 34 / 14,
                color: value ? AppColors.narTextTertiary : AppColors.narDark300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
