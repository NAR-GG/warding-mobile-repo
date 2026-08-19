import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../components/common_button.dart';
import '../../../components/nar_toggle.dart';
import '../../../screens/my_subscription_setting/component/live_event_detail_card.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 경기 알림 설정 결과 — 켠 알림 종류. 확인으로 닫혀야만 반환된다.
///
/// 세부 항목(킬/바론/드래곤/타워/억제기)은 [liveEvent] 가 꺼져 있으면 서버가
/// 어차피 안 쓰지만, 사용자가 라이브 이벤트를 다시 켰을 때 고른 조합이 남아
/// 있도록 값 자체는 그대로 실어 보낸다.
typedef MatchAlarmResult = ({
  bool setStart,
  bool setEnd,
  bool liveEvent,
  bool kill,
  bool baron,
  bool dragon,
  bool tower,
  bool inhibitor,
});

/// 경기 카드의 벨 아이콘을 탭했을 때 뜨는 '경기 알림 설정' 바텀시트를 띄운다.
/// 하단 확인으로 닫히면 선택한 토글값을, 닫기(X)나 바깥 탭으로 닫히면 null 을 반환한다.
///
/// [initial] 을 주면 그 값으로 토글을 채운다(이미 구독 중인 경기를 수정할 때).
/// 없으면 신규 구독 기본값(전부 ON)으로 연다.
Future<MatchAlarmResult?> showMatchAlarmSheet({
  required BuildContext context,
  required String homeName,
  String? homeLogoUrl,
  required String awayName,
  String? awayLogoUrl,
  MatchAlarmResult? initial,
}) {
  return showAppBottomSheet<MatchAlarmResult>(
    context: context,
    child: MatchAlarmSheet(
      homeName: homeName,
      homeLogoUrl: homeLogoUrl,
      awayName: awayName,
      awayLogoUrl: awayLogoUrl,
      initial: initial,
    ),
  );
}

/// 경기 알림 설정 시트 본문.
/// 상단 [타이틀 + 대진 표시] · 닫기 버튼, 알림 토글 3행, 하단 확인 버튼.
/// 라이브 이벤트가 ON 이면 그 아래에 세부 항목 카드([LiveEventDetailCard])를 편다
/// — 마이 구독 설정의 팀 알림과 같은 컴포넌트·같은 규칙이다.
///
/// 3종 모두 끄면 구독할 알림이 없으므로 확인 버튼을 비활성화한다.
class MatchAlarmSheet extends StatefulWidget {
  const MatchAlarmSheet({
    super.key,
    required this.homeName,
    this.homeLogoUrl,
    required this.awayName,
    this.awayLogoUrl,
    this.initial,
  });

  final String homeName;
  final String? homeLogoUrl;
  final String awayName;
  final String? awayLogoUrl;

  /// 초기 토글값. null 이면 신규 구독 기본값(전부 ON).
  final MatchAlarmResult? initial;

  @override
  State<MatchAlarmSheet> createState() => _MatchAlarmSheetState();
}

class _MatchAlarmSheetState extends State<MatchAlarmSheet> {
  late bool _setStart = widget.initial?.setStart ?? true;
  late bool _setEnd = widget.initial?.setEnd ?? true;
  late bool _liveEvent = widget.initial?.liveEvent ?? true;

  /// 라이브 이벤트 세부 항목 중 켜져 있는 것들.
  late Set<LiveEventKind> _detail = _initialDetail();

  Set<LiveEventKind> _initialDetail() {
    final i = widget.initial;
    if (i == null) return LiveEventKind.values.toSet();
    return {
      if (i.kill) LiveEventKind.kill,
      if (i.baron) LiveEventKind.baron,
      if (i.dragon) LiveEventKind.dragon,
      if (i.tower) LiveEventKind.tower,
      if (i.inhibitor) LiveEventKind.inhibitor,
    };
  }

  void _setDetailKind(LiveEventKind kind, bool value) {
    setState(() {
      if (value) {
        _detail = {..._detail, kind};
      } else {
        _detail = {..._detail}..remove(kind);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          homeName: widget.homeName,
          homeLogoUrl: widget.homeLogoUrl,
          awayName: widget.awayName,
          awayLogoUrl: widget.awayLogoUrl,
          scale: scale,
          onClose: () => Navigator.of(context).pop(),
        ),
        SizedBox(height: 12 * scale),
        _AlarmRow(
          label: l.setStartAlarm,
          value: _setStart,
          onChanged: (v) => setState(() => _setStart = v),
          scale: scale,
        ),
        _AlarmRow(
          label: l.setEndAlarm,
          value: _setEnd,
          onChanged: (v) => setState(() => _setEnd = v),
          scale: scale,
        ),
        _AlarmRow(
          label: l.liveEventAlarm,
          value: _liveEvent,
          onChanged: (v) => setState(() => _liveEvent = v),
          scale: scale,
        ),
        // 라이브 이벤트가 켜져 있을 때만 세부 항목 카드를 편다.
        // 마이 구독 설정과 달리 여기는 좌측 라벨 들여쓰기가 없어(시트는 20 패딩)
        // 카드도 같은 20 에 맞춘다.
        if (_liveEvent)
          LiveEventDetailCard(
            selected: _detail,
            onChanged: _setDetailKind,
            leftPadding: 20,
            scale: scale,
          ),
        SizedBox(height: 24 * scale),
        CommonButton(
          label: l.confirm,
          scale: scale,
          // 3종 모두 꺼져 있으면 구독 의미가 없어 비활성(onPressed=null).
          onPressed: (_setStart || _setEnd || _liveEvent)
              ? () => Navigator.of(context).pop((
                    setStart: _setStart,
                    setEnd: _setEnd,
                    liveEvent: _liveEvent,
                    kill: _detail.contains(LiveEventKind.kill),
                    baron: _detail.contains(LiveEventKind.baron),
                    dragon: _detail.contains(LiveEventKind.dragon),
                    tower: _detail.contains(LiveEventKind.tower),
                    inhibitor: _detail.contains(LiveEventKind.inhibitor),
                  ))
              : null,
        ),
      ],
    );
  }
}

/// 헤더: [타이틀 + 대진(팀 로고·이름 VS 팀 로고·이름)] · 우측 닫기(44×44).
class _Header extends StatelessWidget {
  const _Header({
    required this.homeName,
    required this.homeLogoUrl,
    required this.awayName,
    required this.awayLogoUrl,
    required this.scale,
    required this.onClose,
  });

  final String homeName;
  final String? homeLogoUrl;
  final String awayName;
  final String? awayLogoUrl;
  final double scale;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(left: 8 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.matchAlarmSettings,
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w700,
                    fontSize: 16 * scale,
                    height: 1.5, // line-height 150%
                    color: AppColors.narTextGnbDefault, // #CED4DA
                  ),
                ),
                SizedBox(height: 4 * scale),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TeamBadge(name: homeName, logoUrl: homeLogoUrl, scale: scale),
                    SizedBox(width: 12 * scale),
                    Text(
                      'VS',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 16 * scale,
                        height: 19 / 16,
                        letterSpacing: 0.21 * scale,
                        color: AppColors.narText,
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    _TeamBadge(name: awayName, logoUrl: awayLogoUrl, scale: scale),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: SizedBox(
              width: 44 * scale,
              height: 44 * scale,
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/close.svg',
                  width: 24 * scale,
                  height: 24 * scale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 팀 로고(33 원형) + 팀명 한 쌍.
class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.name, required this.logoUrl, required this.scale});

  final String name;
  final String? logoUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 33 * scale;
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.narDark200,
        shape: BoxShape.circle,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        hasLogo
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: resolveImageUrl(logoUrl)!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 150),
                  errorWidget: (_, _, _) => placeholder,
                ),
              )
            : placeholder,
        SizedBox(width: 8 * scale),
        Text(
          name,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 16 * scale,
            height: 19 / 16,
            letterSpacing: 0.21 * scale,
            color: AppColors.narText,
          ),
        ),
      ],
    );
  }
}

/// 알림 토글 한 행: 라벨 + [NarToggle] (좌우 20 패딩, 높이 38).
class _AlarmRow extends StatelessWidget {
  const _AlarmRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.scale,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 2 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
              fontSize: 14 * scale,
              color: AppColors.narText,
            ),
          ),
          NarToggle(value: value, onChanged: onChanged, scale: scale),
        ],
      ),
    );
  }
}
