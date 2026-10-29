import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../components/common_button.dart';
import '../../../components/nar_toggle.dart';
import '../../../repository/live_activity/live_activity_logo_prefetcher.dart';
import '../../../repository/match/match_subscription_repository.dart';
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

/// "알림 끄기"로 닫혔다는 표시. 확인 버튼은 세 알림이 모두 꺼지면 비활성이라
/// 확인으로는 이 값(전부 false)이 나올 수 없다.
const MatchAlarmResult matchAlarmOff = (
  setStart: false,
  setEnd: false,
  liveEvent: false,
  kill: false,
  baron: false,
  dragon: false,
  tower: false,
  inhibitor: false,
);

/// 경기 카드의 벨 아이콘을 탭했을 때 뜨는 '경기 알림 설정' 바텀시트를 띄운다.
/// 하단 확인으로 닫히면 선택한 토글값을, 닫기(X)나 바깥 탭으로 닫히면 null 을 반환한다.
///
/// [initial] 을 주면 그 값으로 토글을 채운다(이미 구독 중인 경기를 수정할 때).
/// 없으면 신규 구독 기본값(전부 ON)으로 연다.
///
/// [subscribed] 면 확인 아래에 "알림 끄기"를 둔다 — 누르면 [matchAlarmOff] 를 반환한다.
Future<MatchAlarmResult?> showMatchAlarmSheet({
  required BuildContext context,
  required String homeName,
  String? homeLogoUrl,
  required String awayName,
  String? awayLogoUrl,
  MatchAlarmResult? initial,
  bool subscribed = false,
}) {
  return showAppBottomSheet<MatchAlarmResult>(
    context: context,
    child: MatchAlarmSheet(
      homeName: homeName,
      homeLogoUrl: homeLogoUrl,
      awayName: awayName,
      awayLogoUrl: awayLogoUrl,
      initial: initial,
      subscribed: subscribed,
    ),
  );
}

/// 경기 알림 벨 공통 흐름 — 경기 카드와 선수 페이지 다음 경기 카드가 같이 쓴다.
///
/// - 미구독: 시트(기본값 전부 ON) → 확인이면 구독.
/// - 구독 중: 서버의 현재 설정으로 시트를 연다 → 확인이면 설정 변경, "알림 끄기"면 해제.
///   바로 끄지 않는다 — 신청과 대칭으로 시트에서 확인받는다.
///
/// 로그인 확인은 호출부가 한다. 흐름이 끝난 뒤의 구독 여부를 반환하고, 취소면 null.
Future<bool?> runMatchAlarmFlow(
  BuildContext context, {
  required String matchId,
  required bool subscribed,
  required String homeName,
  String? homeLogoUrl,
  String homeCode = '',
  required String awayName,
  String? awayLogoUrl,
  String awayCode = '',
  MatchSubscriptionRepository? repository,
}) async {
  final repo = repository ?? MatchSubscriptionRepository.instance;
  final l = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.maybeOf(context);
  void feedback(String message) => showMatchAlarmFeedback(messenger, message);

  MatchAlarmResult? initial;
  if (subscribed) {
    try {
      final st = await repo.matchSubscriptionStatus(matchId);
      initial = (
        setStart: st.setStartEnabled,
        setEnd: st.setEndEnabled,
        liveEvent: st.liveEventEnabled,
        kill: st.killEnabled,
        baron: st.baronEnabled,
        dragon: st.dragonEnabled,
        tower: st.towerEnabled,
        inhibitor: st.inhibitorEnabled,
      );
    } catch (_) {
      // 현재 설정을 못 읽어도 끄기는 할 수 있어야 한다 — 기본값으로 연다.
    }
    if (!context.mounted) return null;
  }

  final result = await showMatchAlarmSheet(
    context: context,
    homeName: homeName,
    homeLogoUrl: homeLogoUrl,
    awayName: awayName,
    awayLogoUrl: awayLogoUrl,
    initial: initial,
    subscribed: subscribed,
  );
  if (result == null) return null;

  if (result == matchAlarmOff) {
    try {
      await repo.unsubscribeMatch(matchId);
      feedback(l.matchAlarmRemoved);
      return false;
    } catch (_) {
      feedback(l.matchAlarmRemoveFailed);
      return true;
    }
  }

  if (subscribed) {
    try {
      await repo.updateMatchAlarms(
        matchId,
        setStartEnabled: result.setStart,
        setEndEnabled: result.setEnd,
        liveEventEnabled: result.liveEvent,
        killEnabled: result.kill,
        baronEnabled: result.baron,
        dragonEnabled: result.dragon,
        towerEnabled: result.tower,
        inhibitorEnabled: result.inhibitor,
      );
      feedback(l.matchAlarmUpdated);
    } catch (_) {
      feedback(l.matchAlarmUpdateFailed);
    }
    return true;
  }

  try {
    await repo.subscribeMatch(
      matchId,
      setStartEnabled: result.setStart,
      setEndEnabled: result.setEnd,
      liveEventEnabled: result.liveEvent,
      killEnabled: result.kill,
      baronEnabled: result.baron,
      dragonEnabled: result.dragon,
      towerEnabled: result.tower,
      inhibitorEnabled: result.inhibitor,
    );
    feedback(l.matchAlarmRegistered);
    // 이 경기는 서버가 세트 시작에 맞춰 카드를 만든다. 그때 앱은 안 떠
    // 있으므로 지금 양 팀 로고를 미리 저장해 둔다.
    unawaited(
      liveActivityLogoPrefetcher.prefetch([
        LogoTarget(code: homeCode, imageUrl: homeLogoUrl ?? ''),
        LogoTarget(code: awayCode, imageUrl: awayLogoUrl ?? ''),
      ]),
    );
    return true;
  } catch (_) {
    feedback(l.matchAlarmRegisterFailed);
    return false;
  }
}

/// 경기 알림 결과 스낵바.
void showMatchAlarmFeedback(ScaffoldMessengerState? messenger, String message) {
  messenger
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: AppColors.narText,
          ),
        ),
        backgroundColor: AppColors.narDark600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
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
    this.subscribed = false,
  });

  final String homeName;
  final String? homeLogoUrl;
  final String awayName;
  final String? awayLogoUrl;

  /// 초기 토글값. null 이면 신규 구독 기본값(전부 ON).
  final MatchAlarmResult? initial;

  /// 구독 중인 경기 — 확인 아래 "알림 끄기"를 둔다.
  final bool subscribed;

  static const Key offKey = ValueKey('matchAlarmOff');

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
        if (widget.subscribed)
          GestureDetector(
            key: MatchAlarmSheet.offKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(matchAlarmOff),
            child: SizedBox(
              height: 48 * scale,
              child: Center(
                child: Text(
                  l.matchAlarmOff,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 15 * scale,
                    color: AppColors.narTextRed,
                  ),
                ),
              ),
            ),
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
                    Flexible(
                      child: _TeamBadge(
                        name: homeName,
                        logoUrl: homeLogoUrl,
                        scale: scale,
                      ),
                    ),
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
                    Flexible(
                      child: _TeamBadge(
                        name: awayName,
                        logoUrl: awayLogoUrl,
                        scale: scale,
                      ),
                    ),
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
  const _TeamBadge({
    required this.name,
    required this.logoUrl,
    required this.scale,
  });

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
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 16 * scale,
              height: 19 / 16,
              letterSpacing: 0.21 * scale,
              color: AppColors.narText,
            ),
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
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 2 * scale,
      ),
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
