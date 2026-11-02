import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_spoiler_toggle.dart';
import '../../../model/team.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 경기 일정 페이지 상단 헤더.
///
/// - 왼쪽: 'yyyy.MM' 월 라벨(탭 → 월 피커).
/// - 오른쪽: 스포방지 토글 · 필터 버튼(44 원형) · 응원팀 아이콘.
///
/// 스포방지는 값이 null 이면 그리지 않는다 — 캘린더와 경기 리스트를 한 화면에
/// 합치며 들어온 것이라, 그 맥락이 아닌 곳에서는 빠진다. 캘린더 월간/주간
/// 전환은 헤더가 아니라 캘린더 아래 화살표 손잡이가 맡는다.
///
/// 시안 폭 375 기준으로 내부에서 [MediaQuery] 폭에 맞춰 스케일한다.
class ScheduleHeader extends StatelessWidget {
  const ScheduleHeader({
    super.key,
    required this.monthLabel,
    this.monthLabelWidget,
    this.onMonthTap,
    this.onFilterTap,
    this.hasActiveFilter = false,
    this.preferredTeam,
    this.teamSelected = false,
    this.onTeamTap,
    this.spoilerPreventionEnabled,
    this.spoilerListenable,
    this.onSpoilerChanged,
  });

  /// 스포방지 상태를 읽는 함수. null 이면 토글을 그리지 않는다.
  ///
  /// 값이 아니라 **함수**로 받는다 — 토글만 [spoilerListenable] 을 구독해
  /// 따로 다시 그리므로, 헤더가 다시 빌드되지 않은 사이에도 최신 값을
  /// 읽어야 한다.
  ///
  /// 경기 리스트가 같은 화면 아래에 들어오면서 리스트 쪽 제목 행이 사라졌고,
  /// 그 행에 있던 토글이 이 헤더로 올라왔다.
  final bool Function()? spoilerPreventionEnabled;

  /// 스포방지 값을 들고 있는 알림원(경기 리스트 VM).
  ///
  /// 이것만 토글 위젯이 구독한다. 헤더 전체가 이 VM 을 구독하면 목록을
  /// 스크롤하는 내내(조회·로딩 통지) 헤더가 통째로 다시 그려진다.
  final Listenable? spoilerListenable;

  /// 스포방지 토글 콜백.
  final ValueChanged<bool>? onSpoilerChanged;

  /// 'yyyy.MM' 형식 월 라벨. 예: '2026.04'.
  final String monthLabel;

  /// 월 라벨 자리에 대신 그릴 위젯. 캘린더 스와이프 진행률에 맞춰 라벨을
  /// 함께 움직이려고 [ScheduleCalendar] 가 넘겨준다. null 이면 [monthLabel]
  /// 을 정적 텍스트로 그린다.
  final Widget? monthLabelWidget;

  /// 월 라벨 텍스트 스타일. 라벨을 밖에서 그릴 때도 같은 스타일을 쓰도록
  /// 공개한다.
  static TextStyle monthLabelStyle(double scale) => TextStyle(
    fontFamily: 'SF Pro Display',
    fontWeight: FontWeight.w700,
    fontSize: 22 * scale,
    height: 1.4, // 140%
    letterSpacing: 0,
    color: AppColors.narText,
  );

  /// 월·달력 영역 탭 콜백. null 이면 비활성.
  final VoidCallback? onMonthTap;

  /// 필터 버튼 탭 콜백. null 이면 비활성.
  final VoidCallback? onFilterTap;

  /// 리그·팀 필터가 '전체'가 아닌 값으로 걸려 있는지. true 면 응원팀
  /// 아이콘과 같은 2px 테두리를 필터 버튼에 두른다.
  final bool hasActiveFilter;

  /// 온보딩에서 고른 선호 팀. null 이면(건너뛰기 등) 팀 아이콘을 숨긴다.
  final Team? preferredTeam;

  /// 팀 아이콘 선택(2px 테두리) 상태.
  final bool teamSelected;

  /// 팀 아이콘 탭 콜백. null 이면 비활성.
  final VoidCallback? onTeamTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: Row(
        children: [
          // 왼쪽: 월 라벨(탭 → 월 피커).
          //
          // [Flexible] 과 [Spacer] 를 같이 두면 안 된다 — 둘 다 flex 1 이라
          // 남는 폭을 **반씩 나눠 갖고**, 그래서 라벨이 자기 폭을 다 못 받아
          // '2026.10' 이 '2026…' 으로 줄어든다.
          //
          // 라벨은 그냥 내용 폭을 쓰고, 폭이 모자랄 때만 줄어들게 한다.
          // 그 '모자랄 때' 는 아래 [Flexible] 이 감싼 토글이 먼저 양보해
          // 처리한다(라벨보다 토글 라벨이 줄어드는 편이 낫다).
          Expanded(
            child: GestureDetector(
              onTap: onMonthTap,
              behavior: HitTestBehavior.opaque,
              child: Align(
                alignment: Alignment.centerLeft,
                child:
                    monthLabelWidget ??
                    Text(
                      monthLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: monthLabelStyle(scale),
                    ),
              ),
            ),
          ),
          // 오른쪽 묶음: 스포방지 토글 · 필터 버튼 · 응원팀 아이콘.
          // 토글은 자기 내용 폭을 그대로 쓴다(라벨이 'OFF'·영문일 때 더 길다).
          if (spoilerPreventionEnabled != null) ...[
            // 토글은 **자기 내용 폭만** 쓴다. [Flexible] 로 두면 위
            // [Expanded] 와 flex 를 나눠 갖느라 필요 이상으로 넓어지고,
            // 그만큼 월 라벨이 줄어 '2026…' 이 된다.
            ListenableBuilder(
              listenable: spoilerListenable ?? const _NeverNotifies(),
              builder: (context, _) => NarSpoilerToggle(
                value: spoilerPreventionEnabled!(),
                onChanged: onSpoilerChanged ?? (_) {},
                scale: scale,
                // 라벨은 '스포방지' 만. ON/OFF 는 옆 스위치로 읽는다 —
                // 두 글자를 더 쓰면 390 폭에서 전체가 넘친다.
                showState: false,
              ),
            ),
            SizedBox(width: 8 * scale),
          ],
          // 오른쪽: 필터 버튼 + (온보딩에서 고른) 팀 아이콘.
          // 알림함 벨은 커뮤니티 헤더로 옮겼다 — 알림함이 커뮤니티 전용이 됐다.
          GestureDetector(
            onTap: onFilterTap,
            child: _CircleSlot(
              scale: scale,
              bordered: hasActiveFilter,
              child: SvgPicture.asset(
                'assets/icons/filter.svg',
                width: 24 * scale,
                height: 24 * scale,
              ),
            ),
          ),
          if (preferredTeam != null) ...[
            SizedBox(width: 8 * scale), // 필터 버튼 ↔ 팀 아이콘 간격 8
            GestureDetector(
              onTap: onTeamTap,
              child: _CircleSlot(
                scale: scale,
                bordered: teamSelected,
                child: CachedNetworkImage(
                  imageUrl: resolveImageUrl(preferredTeam!.imageUrl)!,
                  width: 25 * scale,
                  height: 25 * scale,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 150),
                  errorWidget: (_, _, _) => Icon(
                    Icons.shield_outlined,
                    size: 25 * scale,
                    color: AppColors.narText2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 헤더 오른쪽 끝의 44×44 원형 슬롯. 필터 버튼·팀 아이콘이 공유한다.
///
/// [bordered] 면 2px narBg 그라데이션 테두리를 두른다. 전체 크기는 44 로
/// 유지하고 안쪽 원을 40 으로 줄여, 선택/해제 시 레이아웃이 흔들리지 않는다.
class _CircleSlot extends StatelessWidget {
  const _CircleSlot({
    required this.scale,
    required this.child,
    this.bordered = false,
  });

  final double scale;
  final Widget child;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    if (!bordered) {
      return Container(
        width: 44 * scale,
        height: 44 * scale,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.narBgTertiary,
          shape: BoxShape.circle,
        ),
        child: child,
      );
    }
    return Container(
      width: 44 * scale,
      height: 44 * scale,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: AppColors.narBg, // 2px narBg 테두리
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 40 * scale, // 44 - 테두리 2px ×2
        height: 40 * scale,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.narBgTertiary,
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }
}

/// 아무것도 알리지 않는 [Listenable]. [ScheduleHeader.spoilerListenable] 이
/// 없을 때 [ListenableBuilder] 에 넘길 자리를 채운다.
class _NeverNotifies implements Listenable {
  const _NeverNotifies();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}
