import 'dart:async';
import 'dart:ui' show ImageFilter, TileMode;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_badge.dart';
import '../../../components/nar_live_badge.dart';
import '../../../repository/auth/auth_service.dart';
import '../../../repository/live_activity/live_activity_logo_prefetcher.dart';
import '../../../repository/match/match_subscription_repository.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../login/login_screen.dart';
import 'match_alarm_sheet.dart';
import '../../../config/secure_storage.dart';

/// 경기 한 건 카드. 헤더(알림 벨/시간·LIVE 칩·라벨·우측 chevron) + 양 팀 로고·이름 + 가운데 스코어.
/// [isLive] 가 true 면 카드 배경/왼쪽 보더/LIVE 칩/스코어 색 분기.
class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.matchId,
    required this.time,
    required this.label,
    required this.homeName,
    required this.awayName,
    this.homeLogoUrl,
    this.awayLogoUrl,
    this.homeCode = '',
    this.awayCode = '',
    required this.homeScore,
    required this.awayScore,
    this.isLive = false,
    this.liveSetLabel,
    this.onTap,
    this.scale = 1,
    this.leagueInfo = '',
    this.spoilerPreventionEnabled = true,
    this.spoilerRevealed = false,
    this.onSpoilerReveal,
    this.showTopBorder = true,
  });

  /// 경기 예약 알림 구독 API(`/match-subscriptions`)에 쓰는 경기 ID.
  final String matchId;
  final String time;
  final String label;
  final String homeName;
  final String awayName;
  final String? homeLogoUrl;
  final String? awayLogoUrl;

  /// 양 팀 코드. 알림을 켤 때 실시간 카드용 로고를 이 코드로 미리 캐싱한다
  /// (파일명이 `<팀코드>.png` 라 코드가 없으면 저장할 이름이 없다).
  final String homeCode;
  final String awayCode;

  final int homeScore;
  final int awayScore;

  /// 라이브 경기 여부. 카드 배경/왼쪽 보더/LIVE 칩/스코어 색을 분기한다.
  final bool isLive;

  /// 라이브일 때 스코어 아래 표시할 라벨. 예: 'SET 4 진행중'.
  final String? liveSetLabel;

  final VoidCallback? onTap;
  final double scale;

  /// 리그 정보. LCK·MSI·EWC·KeSPA 경기가 아니면 알림 버튼을 숨긴다.
  final String leagueInfo;

  /// 스포방지 on/off. false 면 [_SpoilerOverlay] 없이 스코어를 바로 보여준다.
  final bool spoilerPreventionEnabled;

  /// 사용자가 이 경기의 스코어를 이미 공개했는지. 목록이 카드를 파괴·재생성해도
  /// 공개 상태가 유지되도록 화면이 경기 단위로 들고 내려준다.
  final bool spoilerRevealed;

  /// 스포방지 오버레이를 탭했을 때. 화면이 [spoilerRevealed] 를 켜 준다.
  final VoidCallback? onSpoilerReveal;

  /// 위쪽 1px 구분선을 그릴지. 날짜 헤더 바로 아래 첫 카드는 헤더와 붙어
  /// 선이 겹쳐 보이므로 false 로 끈다. LIVE 카드는 위 보더가 없어 무관.
  final bool showTopBorder;

  bool get _isAlarmEligibleLeague {
    final info = leagueInfo.toUpperCase();
    return info.contains('LCK') ||
        info.contains('MSI') ||
        info.contains('EWC') ||
        info.contains('KESPA');
  }

  @override
  Widget build(BuildContext context) {
    // 시안 공통: padding 10px 16px 24px.
    final padding = EdgeInsets.only(
      top: 10 * scale,
      left: 16 * scale,
      right: 16 * scale,
      bottom: 24 * scale,
    );

    // LIVE: 배경 narDark600 + 왼쪽 3px 보더 + 위쪽 2px 구분선(시안 'Line 16',
    // narFadeLine 그라데이션 — border 로는 그라데이션을 못 그려 별도 바로 얹는다).
    // 예정·종료: 배경 narBgTertiary + 위쪽 1px 보더(카드 구분선 역할).
    //
    // 예정·종료 카드는 날짜/리그 헤더 바로 아래 첫 카드일 때 위 구분선을 꺼서
    // 헤더와 선이 겹쳐 보이지 않게 한다(showTopBorder). 라이브 카드는 그 규칙과
    // 무관하게 항상 그린다 — 헤더 바로 아래 오더라도 라이브 카드는 시안대로
    // 위 구분선으로 뚜렷하게 구분돼야 한다.
    final decoration = isLive
        ? const BoxDecoration(
            color: AppColors.narDark600,
            border: Border(
              left: BorderSide(color: AppColors.liveSideBorder, width: 3),
            ),
          )
        : BoxDecoration(
            color: AppColors.narBgTertiary,
            border: showTopBorder
                ? const Border(
                    top: BorderSide(color: AppColors.narLine2, width: 1),
                  )
                : null,
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            Container(
              height: 2 * scale,
              decoration: const BoxDecoration(gradient: AppColors.narFadeLine),
            ),
          Container(
            decoration: decoration,
            padding: padding,
            child: Column(
              children: [
                Row(
                  children: [
                    if (_isAlarmEligibleLeague) ...[
                      _AlarmBell(
                        matchId: matchId,
                        homeName: homeName,
                        homeLogoUrl: homeLogoUrl,
                        homeCode: homeCode,
                        awayName: awayName,
                        awayLogoUrl: awayLogoUrl,
                        awayCode: awayCode,
                        scale: scale,
                      ),
                      SizedBox(width: 8 * scale),
                    ],
                    if (isLive)
                      NarLiveBadge(scale: scale)
                    else
                      NarBadge(label: time, scale: scale),
                    SizedBox(width: 8 * scale),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.w600,
                          fontSize: 12 * scale,
                          height: 18 / 12,
                          color: AppColors.narText2,
                        ),
                      ),
                    ),
                    SvgPicture.asset(
                      'assets/icons/chevron-right.svg',
                      width: 18 * scale,
                      height: 18 * scale,
                    ),
                  ],
                ),
                SizedBox(height: 20 * scale),
                // 시안 'box': 헤더보다 좌우 16 안쪽, 팀 컬럼 80 고정 + space-between.
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _TeamColumn(
                        name: homeName,
                        logoUrl: homeLogoUrl,
                        scale: scale,
                      ),
                      _SpoilerOverlay(
                        enabled: spoilerPreventionEnabled,
                        revealed: spoilerRevealed,
                        onReveal: onSpoilerReveal,
                        scale: scale,
                        child: isLive
                            ? _LiveScore(
                                home: homeScore,
                                away: awayScore,
                                setLabel: liveSetLabel,
                                scale: scale,
                              )
                            : _ScoreRow(
                                home: homeScore,
                                away: awayScore,
                                scale: scale,
                              ),
                      ),
                      _TeamColumn(
                        name: awayName,
                        logoUrl: awayLogoUrl,
                        scale: scale,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 헤더 좌측 알림 벨. 미구독이면 bell-plus, 구독 중이면 bell-check.
///
/// 탭하면: 구독 중이면 즉시 구독 해제, 미구독이면 [showMatchAlarmSheet] 로
/// 알림 설정 시트를 띄우고 '확인'으로 닫히면 구독을 등록한다.
/// 비회원(JWT 없음)이 탭하면 로그인 화면으로 보낸다(평점 남기기와 동일 패턴).
class _AlarmBell extends StatefulWidget {
  const _AlarmBell({
    required this.matchId,
    required this.homeName,
    required this.homeLogoUrl,
    required this.homeCode,
    required this.awayName,
    required this.awayLogoUrl,
    required this.awayCode,
    required this.scale,
  });

  final String matchId;
  final String homeName;
  final String? homeLogoUrl;
  final String homeCode;
  final String awayCode;
  final String awayName;
  final String? awayLogoUrl;
  final double scale;

  @override
  State<_AlarmBell> createState() => _AlarmBellState();
}

class _AlarmBellState extends State<_AlarmBell> {
  final _repo = MatchSubscriptionRepository.instance;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    try {
      final jwt = await AuthService.instance.jwt;
      if (jwt == null || jwt.isEmpty) return; // 비회원은 정적 상태로 둔다.
      final ids = await _repo.subscribedMatchIds();
      if (mounted && ids.contains(widget.matchId)) {
        setState(() => _subscribed = true);
      }
    } catch (_) {
      // 조회 실패 시 기본값(미구독) 유지.
    }
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _handleTap() async {
    // 경기 알림은 회원 기반(서버도 로그인 필수) — 비회원은 로그인 화면으로 보낸다.
    final String? jwt;
    try {
      jwt = await AuthService.instance.jwt;
    } on SecureStorageUnavailableException {
      // 잠금으로 토큰을 못 읽은 것뿐 — 로그인 유저를 로그인 화면으로 보내면 안 된다.
      return;
    }
    if (!mounted) return;
    if (jwt == null || jwt.isEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      // 로그인하고 돌아왔으면 구독 상태를 다시 읽는다(벨을 다시 탭해 설정 진행).
      _loadInitialState();
      return;
    }

    final l = AppLocalizations.of(context)!;
    if (_subscribed) {
      setState(() => _subscribed = false);
      try {
        await _repo.unsubscribeMatch(widget.matchId);
        _showFeedback(l.matchAlarmRemoved);
      } catch (_) {
        if (mounted) setState(() => _subscribed = true);
        _showFeedback(l.matchAlarmRemoveFailed);
      }
      return;
    }

    final result = await showMatchAlarmSheet(
      context: context,
      homeName: widget.homeName,
      homeLogoUrl: widget.homeLogoUrl,
      awayName: widget.awayName,
      awayLogoUrl: widget.awayLogoUrl,
    );
    if (result == null) return;

    setState(() => _subscribed = true);
    try {
      await _repo.subscribeMatch(
        widget.matchId,
        setStartEnabled: result.setStart,
        setEndEnabled: result.setEnd,
        liveEventEnabled: result.liveEvent,
        killEnabled: result.kill,
        baronEnabled: result.baron,
        dragonEnabled: result.dragon,
        towerEnabled: result.tower,
        inhibitorEnabled: result.inhibitor,
      );
      _showFeedback(l.matchAlarmRegistered);

      // 이 경기는 서버가 세트 시작에 맞춰 카드를 만든다. 그때 앱은 안 떠
      // 있으므로 지금 양 팀 로고를 미리 저장해 둔다.
      unawaited(liveActivityLogoPrefetcher.prefetch([
        LogoTarget(code: widget.homeCode, imageUrl: widget.homeLogoUrl ?? ''),
        LogoTarget(code: widget.awayCode, imageUrl: widget.awayLogoUrl ?? ''),
      ]));
    } catch (_) {
      if (mounted) setState(() => _subscribed = false);
      _showFeedback(l.matchAlarmRegisterFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('matchCardAlarmBell'),
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: SvgPicture.asset(
        _subscribed ? 'assets/icons/bell-check.svg' : 'assets/icons/bell-plus.svg',
        width: 24 * widget.scale,
        height: 24 * widget.scale,
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.name,
    required this.logoUrl,
    required this.scale,
  });

  final String name;
  final String? logoUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    // 시안 폭 80 고정 — 스코어를 카드 정중앙에 두려면 양쪽 폭이 같아야 한다.
    return SizedBox(
      width: 80 * scale,
      child: Column(
        children: [
          Container(
            width: 50 * scale,
            height: 50 * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.narLine2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: hasLogo
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: resolveImageUrl(logoUrl)!,
                      width: 40 * scale,
                      height: 40 * scale,
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 150),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  )
                : null,
          ),
          SizedBox(height: 4 * scale),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
              fontSize: 16 * scale,
              height: 19 / 16,
              color: AppColors.narTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 예정·종료 카드 스코어. 예정 경기는 0:0 이라 둘 다 기본색으로 보이고,
/// 종료 경기는 이긴 쪽만 [AppColors.scoreWin] 로 강조된다(라이브와 동일 규칙).
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.home,
    required this.away,
    required this.scale,
  });

  final int home;
  final int away;
  final double scale;

  Color _colorFor(int self, int other) =>
      self > other ? AppColors.scoreWin : AppColors.narDark200;

  TextStyle _style(Color c) => TextStyle(
    fontFamily: 'SF Pro',
    fontWeight: FontWeight.w700,
    fontSize: 28 * scale,
    height: 33 / 28,
    color: c,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$home', style: _style(_colorFor(home, away))),
        SizedBox(width: 14 * scale),
        Text(':', style: _style(AppColors.narDark200)),
        SizedBox(width: 14 * scale),
        Text('$away', style: _style(_colorFor(away, home))),
      ],
    );
  }
}

/// 라이브 스코어. 큰 숫자(28/700) + gap 8 + 아래 'SET N 진행중' 라벨(12/400).
/// 시안 색: 앞서는 쪽 scoreWin(#FA5252), 나머지 숫자와 콜론은 흰색.
class _LiveScore extends StatelessWidget {
  const _LiveScore({
    required this.home,
    required this.away,
    required this.setLabel,
    required this.scale,
  });

  final int home;
  final int away;
  final String? setLabel;
  final double scale;

  /// 앞서는 쪽만 빨강, 나머지(뒤지는 쪽·동점)는 흰색.
  Color _colorFor(int self, int other) =>
      self > other ? AppColors.scoreWin : AppColors.narText;

  TextStyle _bigStyle(Color c) => TextStyle(
    fontFamily: 'SF Pro',
    fontWeight: FontWeight.w700,
    fontSize: 28 * scale,
    height: 33 / 28,
    color: c,
  );

  @override
  Widget build(BuildContext context) {
    final hasLabel = setLabel != null && setLabel!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$home', style: _bigStyle(_colorFor(home, away))),
            SizedBox(width: 14 * scale),
            Text(':', style: _bigStyle(AppColors.narText)),
            SizedBox(width: 14 * scale),
            Text('$away', style: _bigStyle(_colorFor(away, home))),
          ],
        ),
        if (hasLabel) ...[
          SizedBox(height: 8 * scale),
          Text(
            setLabel!,
            style: TextStyle(
              fontFamily: 'Open Sans',
              fontWeight: FontWeight.w400,
              fontSize: 12 * scale,
              height: 16 / 12,
              color: AppColors.narRed500,
            ),
          ),
        ],
      ],
    );
  }
}

/// 모든 카드 스코어 위에 깔리는 스포방지 오버레이.
/// 시안에 맞춰 116×77 고정 영역을 차지하며, 양옆 [_TeamColumn] 을 침범하지 않는다.
/// 공개 전에는 실제 스코어 대신 0:0 더미를 깔고 위에 흐림 + 텍스트를 덮는다.
/// 탭하면 [onReveal] 로 알리고, 화면이 [revealed] 를 켜 주면 실제 스코어가 나온다.
/// [enabled] 가 false 면(경기리스트 헤더 스포방지 토글 off) 오버레이 없이 바로 노출한다.
///
/// 공개 여부를 이 위젯의 State 로 들지 않는다 — 목록은 뷰포트를 벗어난 카드를
/// 파괴했다가 다시 만들기 때문에, 내부 State 면 스크롤로 화면 밖에 나갔다
/// 돌아왔을 때 공개했던 카드가 다시 가려진다.
class _SpoilerOverlay extends StatelessWidget {
  const _SpoilerOverlay({
    required this.child,
    required this.scale,
    required this.revealed,
    this.onReveal,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  /// 이 경기의 스코어를 이미 공개했는지. 화면이 경기 단위로 들고 있다.
  final bool revealed;

  /// 오버레이를 탭했을 때. 화면이 공개 상태를 기록한다.
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final revealed = this.revealed || !enabled;
    return SizedBox(
      width: 116 * scale,
      height: 77 * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 공개 전에는 실제 스코어를 아예 그리지 않는다 — 흐림만으로는
          // 숫자가 비쳐 스포일러가 새기 때문에 0:0 더미를 깔아 둔다.
          //
          // 흐림은 이 더미에만 건다. 예전엔 위 오버레이가 BackdropFilter 로
          // '뒤에 있는 것'을 흐렸는데, 그건 뒤 레이어 전체를 샘플링하는 연산이라
          // 뷰포트에 뜬 카드 수만큼 곱해져 스크롤 프레임에 그대로 드러났다.
          // 실제로 흐려야 할 대상은 이 더미 하나뿐이므로, 자기 서브트리만
          // 처리하는 ImageFiltered 로 같은 그림을 훨씬 싸게 낸다.
          if (revealed)
            Center(child: child)
          else
            // 더미는 이 칸(116×77)을 꽉 채워야 한다. Center 로 두면 자연 크기를
            // 그대로 요구해 좁은 화면에서 안쪽 Row 가 가로로 넘친다 — 예전엔
            // 위 오버레이의 ClipRRect 가 가려 줬지만, 흐림이 이쪽으로 내려온
            // 지금은 여기서 직접 크기를 묶고 잘라야 한다.
            //
            // 자르는 이유가 하나 더 있다: ImageFiltered 는 BackdropFilter 와
            // 달리 자식을 클립하지 않아, 흐림이 번지면 모서리 밖으로 삐져나온다.
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14 * scale),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 2.5,
                    sigmaY: 2.5,
                    tileMode: TileMode.decal,
                  ),
                  child: _SpoilerDummyScore(scale: scale),
                ),
              ),
            ),
          if (!revealed)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onReveal,
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(11 * scale),
                  decoration: BoxDecoration(
                    // 시안대로 narDark800 40% 를 얹는다. 흐림은 이 레이어가
                    // 아니라 아래 더미 스코어가 직접 쓰므로(위 ImageFiltered),
                    // 여기서는 BackdropFilter 없이 색만 덮으면 된다.
                    color: AppColors.narSpoilerOverlayBg,
                    borderRadius: BorderRadius.circular(14 * scale),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.spoilerBlock,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.w400,
                          fontSize: 14 * scale,
                          height: 1,
                          color: AppColors.narTextTertiary,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        l.clickToSeeScore,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.w400,
                          fontSize: 10 * scale,
                          height: 1,
                          color: AppColors.narText2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 스포방지 오버레이 아래 깔리는 0:0 더미 스코어.
/// 실제 스코어([_ScoreRow]/[_LiveScore])보다 큰 시안(36/700, narText2)이고
/// 배경 narDark600 + radius 14 로 오버레이 뒤를 가린다.
class _SpoilerDummyScore extends StatelessWidget {
  const _SpoilerDummyScore({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'SF Pro',
      fontWeight: FontWeight.w700,
      fontSize: 36 * scale,
      height: 43 / 36,
      color: AppColors.narText2,
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      alignment: Alignment.center,
      // 시안 그대로면 좁은 화면(320)에서 이 행이 칸(116)보다 넓어진다.
      // 넘치는 대신 비율을 지키며 줄어들게 한다 — 어차피 흐림이 덮여 있어
      // 몇 px 작아진 것은 드러나지 않지만, overflow 는 그대로 보인다.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('0', style: style),
            SizedBox(width: 14 * scale),
            Text(':', style: style),
            SizedBox(width: 14 * scale),
            Text('0', style: style),
          ],
        ),
      ),
    );
  }
}
