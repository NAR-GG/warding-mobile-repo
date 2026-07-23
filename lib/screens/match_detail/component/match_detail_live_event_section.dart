import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../model/match_game.dart';
import '../../../model/match_live_event.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import 'match_detail_locked_empty.dart';

/// 경기 상세 — 라이브 이벤트 탭 콘텐츠.
///
/// 상단의 최근 상태 로드 버튼(리로드 아이콘 + 안내 문구)과 그 아래
/// 좌측 narPink700 타임라인(점·세로선)으로 이어지는 이벤트 카드 리스트로 구성된다.
class MatchDetailLiveEventSection extends StatefulWidget {
  const MatchDetailLiveEventSection({
    super.key,
    this.events = const [],
    this.blueTeamImageUrl,
    this.redTeamImageUrl,
    this.initialLoading = false,
    this.errorMessage,
    this.scale = 1,
    this.onReload,
    this.status = MatchGameStatus.live,
  });

  /// 표시할 라이브 이벤트 (최신순). ViewModel 에서 주입.
  final List<MatchLiveEvent> events;

  /// 오브젝트 이벤트 출처 팀 로고용 — 응답 최상위의 양 팀 로고 URL (null 가능).
  final String? blueTeamImageUrl;
  final String? redTeamImageUrl;

  /// 최초 로드 중(아직 이벤트 한 건도 못 받은 상태)인지.
  final bool initialLoading;

  /// 이벤트 로드 에러 메시지. null 이면 에러 없음.
  final String? errorMessage;

  final double scale;

  /// 리로드 버튼을 눌렀을 때 호출. 로딩 상태(아이콘/문구 변경) 동안 외부에서
  /// 라이브 이벤트를 가져온 뒤, 완료되면 다시 idle 로 돌아가도록 반환을 기다린다.
  final Future<void> Function()? onReload;

  /// 현재 세트 상태("LIVE"|"ENDED"|"SCHEDULED"). 리로드 버튼 라벨 분기에 쓴다.
  /// 미지정 시 LIVE(기존 동작 유지).
  final String status;

  @override
  State<MatchDetailLiveEventSection> createState() =>
      _MatchDetailLiveEventSectionState();
}

class _MatchDetailLiveEventSectionState
    extends State<MatchDetailLiveEventSection> {
  bool _loading = false;

  /// 백엔드 [MatchLiveEvent] → 표시용 [_LiveEvent] 매핑.
  /// KILL 은 killer→victim, 오브젝트는 팀(또는 출처)→오브젝트 라벨로 표현.
  _LiveEvent _toViewEvent(MatchLiveEvent e) {
    if (e.isKill) {
      return _LiveEvent(
        time: e.gameTime,
        source: _Actor.champion(
          name: e.killer?.playerName ?? '',
          championImageUrl: e.killer?.imageUrl,
        ),
        target: _Actor.champion(
          name: e.victim?.playerName ?? '',
          championImageUrl: e.victim?.imageUrl,
        ),
      );
    }
    // 오브젝트 이벤트: 출처(팀)에서 오브젝트를 처치/파괴.
    final asset = e.objectiveAsset();
    final objective = asset != null
        ? _Actor.objective(name: e.objectiveLabel(), asset: asset)
        : _Actor.objectiveLabel(e.objectiveLabel());
    // teamSide('Blue'/'Red') 로 해당 팀 로고 URL 을 고른다.
    final side = (e.teamSide ?? '').toLowerCase();
    final teamLogoUrl = side == 'blue'
        ? widget.blueTeamImageUrl
        : side == 'red'
            ? widget.redTeamImageUrl
            : null;
    return _LiveEvent(
      time: e.gameTime,
      source: _Actor.teamLogo(
        name: e.teamName ?? '',
        logoUrl: teamLogoUrl,
      ),
      target: objective,
    );
  }

  Future<void> _handleReload() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (widget.onReload != null) {
        await widget.onReload!();
      } else {
        // API 미연동 상태 — 데모용으로 잠시 로딩 상태 보여주고 복귀.
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final events = widget.events.map(_toViewEvent).toList();
    // 최초 로드 중이거나 리로드 진행 중이면 로딩 상태로 본다.
    final loading = _loading || widget.initialLoading;
    final hasError = widget.errorMessage != null && events.isEmpty;

    return Container(
      width: double.infinity,
      color: AppColors.narBgContent,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReloadButton(
            loading: loading,
            onTap: _handleReload,
            status: widget.status,
            scale: scale,
          ),
          // 로딩 중이면 이벤트 리스트 맨 위에 스켈레톤 한 줄 추가. 카드는 그대로 보여준다.
          if (loading) _LoadingSkeleton(scale: scale),
          if (hasError && !loading)
            _EmptyState(message: widget.errorMessage!, scale: scale)
          else if (events.isEmpty && !loading)
            MatchDetailLockedEmpty(
              message: AppLocalizations.of(context)!.eventDuringMatch,
              scale: scale,
            )
          else
            for (var i = 0; i < events.length; i++) ...[
              _LiveEventRow(
                event: events[i],
                isFirst: i == 0,
                isLast: i == events.length - 1,
                isLatest: i == 0,
                // 로딩 중에는 좌측 핑크 점·세로선(타임라인) 숨김.
                showTimeline: !loading,
                scale: scale,
              ),
              // 카드 사이 4 gap. gap 영역에도 narPink700 세로선을 그려 점들이 끊김 없이 이어지도록.
              if (i < events.length - 1)
                _LineConnector(scale: scale, showLine: !loading),
            ],
        ],
      ),
    );
  }
}

/// 이벤트가 없거나 에러일 때의 안내 문구.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.scale});

  final String message;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40 * scale),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            fontSize: 14 * scale,
            color: AppColors.narText2,
          ),
        ),
      ),
    );
  }
}

/// 최근 상태 로드 버튼. 좌측에 24×24 리로드 아이콘, 우측 끝에 안내 문구를 spaceBetween 으로 배치.
/// 로딩 중일 때 아이콘·문구 모두 [AppColors.narText3] 로 디머 처리.
/// (스펙은 아이콘 narGray100 이었으나 기본색 narTextTertiary 와 사실상 동일한 흰색이라
///  시각적 변화가 없어, 텍스트와 톤을 맞춘 narText3 로 통일.)
class _ReloadButton extends StatelessWidget {
  const _ReloadButton({
    required this.loading,
    required this.onTap,
    required this.status,
    required this.scale,
  });

  final bool loading;
  final VoidCallback onTap;
  final String status;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final iconColor =
        loading ? AppColors.narText3 : AppColors.narTextTertiary;
    final textColor = loading ? AppColors.narText3 : AppColors.narTextTertiary;
    final String label;
    if (loading) {
      label = l.loadingLiveEvents;
    } else {
      switch (status) {
        case MatchGameStatus.ended:
          label = l.matchEnded;
          break;
        case MatchGameStatus.scheduled:
          label = l.matchScheduled;
          break;
        default: // LIVE
          label = l.matchInProgress;
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 16 * scale,
          horizontal: 20.5 * scale,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/reload.svg',
              width: 24 * scale,
              height: 24 * scale,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w500,
                fontSize: 12 * scale,
                height: 14 / 12,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 라이브 이벤트 한 행. 카드 위에 타임라인(점 + 세로선)을 좌측 padding 영역에 Stack 으로 오버레이.
/// 행끼리 gap 없이 붙여 두면 점-선이 자연스럽게 이어진다.
class _LiveEventRow extends StatelessWidget {
  const _LiveEventRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
    required this.isLatest,
    required this.scale,
    this.showTimeline = true,
  });

  final _LiveEvent event;
  final bool isFirst;
  final bool isLast;
  final bool isLatest;
  final double scale;

  /// 로딩 상태에서는 좌측 핑크 점·세로선 오버레이만 숨긴다. 카드(시간·액터·킬 아이콘)는 그대로 표시.
  final bool showTimeline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54 * scale,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _LiveEventCard(
            event: event,
            isLatest: isLatest,
            scale: scale,
          ),
          // 카드 좌측 padding(16) 영역에 타임라인 오버레이.
          // overlay width 15 → 점 중심 x = 7.5, 점 오른쪽 가장자리 x = 11,
          // 텍스트 시작(x = 16)까지 간격 정확히 5.
          if (showTimeline)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 15 * scale,
              child: CustomPaint(
                painter: _TimelinePainter(
                  isFirst: isFirst,
                  isLast: isLast,
                  isLatest: isLatest,
                  scale: scale,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 카드 사이 4 gap 영역에 그리는 narPink700 1px 세로선.
/// 점은 없고, 카드 안의 타임라인 점·선과 같은 x(=7.5 * scale) 위치에 그려 시각적으로 끊김이 없게 한다.
/// [showLine] 이 false 면 라인은 안 그리고 4 gap 만 유지 (로딩 중 사용).
class _LineConnector extends StatelessWidget {
  const _LineConnector({required this.scale, this.showLine = true});

  final double scale;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    if (!showLine) {
      return SizedBox(height: 4 * scale);
    }
    final lineWidth = 1 * scale;
    final centerX = 7.5 * scale;
    return SizedBox(
      height: 4 * scale,
      child: Stack(
        children: [
          Positioned(
            left: centerX - lineWidth / 2,
            top: 0,
            bottom: 0,
            width: lineWidth,
            child: const ColoredBox(color: AppColors.narPink700),
          ),
        ],
      ),
    );
  }
}

/// 라이브 이벤트 로딩 스켈레톤. height 54, padding 8/20/8/10, opacity 0.5 그라데이션.
/// AnimationController.repeat(reverse:true) 로 그라데이션 방향이 미세하게 좌우 왕복.
class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton({required this.scale});

  final double scale;

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 그라데이션 begin/end Alignment 를 동일 방향으로 살짝 시프트 → 빛이 좌우로 흐르는 느낌.
        final shift = _controller.value * 0.5;
        return Opacity(
          opacity: 0.5,
          child: Container(
            height: 54 * scale,
            padding: EdgeInsets.fromLTRB(
              10 * scale,
              8 * scale,
              20 * scale,
              8 * scale,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 - shift, 0),
                end: Alignment(1 - shift, 0),
                colors: const [
                  Color(0xFF1A1B1E),
                  Color(0xFF727784),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 타임라인 셀. 가운데 7×7 점과 그 위/아래로 이어지는 1px narPink700 세로선.
/// - [isFirst] 면 점 위쪽 선 생략 (첫 이벤트라 더 위로 이어질 게 없음).
/// - [isLast] 면 점 아래쪽 선 생략.
/// - [isLatest] 면 점이 비어 있는 링(stroke), 아니면 채운 원.
class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.isFirst,
    required this.isLast,
    required this.isLatest,
    required this.scale,
  });

  final bool isFirst;
  final bool isLast;
  final bool isLatest;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final dotRadius = 3.5 * scale;
    final lineWidth = 1 * scale;

    final linePaint = Paint()
      ..color = AppColors.narPink700
      ..strokeWidth = lineWidth;

    if (!isFirst) {
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, centerY - dotRadius),
        linePaint,
      );
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(centerX, centerY + dotRadius),
        Offset(centerX, size.height),
        linePaint,
      );
    }

    if (isLatest) {
      // 비어 있는 링: 1.5px stroke 가 시각적 지름 7px 이 되도록 radius 보정.
      final stroke = Paint()
        ..color = AppColors.narPink700
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth;
      canvas.drawCircle(
        Offset(centerX, centerY),
        dotRadius - lineWidth / 2,
        stroke,
      );
    } else {
      final fill = Paint()
        ..color = AppColors.narPink700
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), dotRadius, fill);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.isFirst != isFirst ||
      old.isLast != isLast ||
      old.isLatest != isLatest ||
      old.scale != scale;
}

/// 라이브 이벤트 카드. 시간 + 양쪽 액터(챔피언 또는 오브젝트) + 사이의 킬 아이콘.
/// 높이 54, padding 8/20/8/16, gap 28, narBgSecondary 배경.
class _LiveEventCard extends StatelessWidget {
  const _LiveEventCard({
    required this.event,
    required this.isLatest,
    required this.scale,
  });

  final _LiveEvent event;
  final bool isLatest;
  final double scale;

  @override
  Widget build(BuildContext context) {
    // 부모(_LiveEventRow)에서 SizedBox(height: 54)·StackFit.expand 로 높이를 강제하므로
    // Container 에는 별도 height 를 지정하지 않는다.
    return Container(
      color: AppColors.narBgSecondary,
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        8 * scale,
        20 * scale,
        8 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 시간 텍스트는 절대 줄바꿈되지 않도록 maxLines: 1 + softWrap: false. 자연 폭 그대로 사용.
          Text(
            event.time,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 14 * scale,
              height: 1.45,
              color: isLatest ? AppColors.narPink700 : AppColors.narText3,
            ),
          ),
          SizedBox(width: 28 * scale),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _ActorSide(
                    actor: event.source,
                    isLeftSide: true,
                    scale: scale,
                  ),
                ),
                SizedBox(width: 10 * scale),
                SvgPicture.asset(
                  'assets/icons/nar_icon_set2.svg',
                  width: 24.38 * scale,
                  height: 29.08 * scale,
                ),
                SizedBox(width: 10 * scale),
                Expanded(
                  child: _ActorSide(
                    actor: event.target,
                    isLeftSide: false,
                    scale: scale,
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

/// 카드 한쪽 액터(이름 + 아이콘). [isLeftSide] 면 [이름, 아이콘] 순서로 오른쪽 끝 정렬,
/// 아니면 [아이콘, 이름] 순서로 왼쪽 정렬.
class _ActorSide extends StatelessWidget {
  const _ActorSide({
    required this.actor,
    required this.isLeftSide,
    required this.scale,
  });

  final _Actor actor;
  final bool isLeftSide;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final text = Flexible(
      child: Text(
        actor.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 14 * scale,
          height: 1.45,
          // 오브젝트 이름은 흰색 70% 불투명도, 챔피언(선수)명은 단색 흰색.
          color: actor.isObjective
              ? const Color(0xB3FFFFFF)
              : AppColors.narText,
        ),
      ),
    );
    final icon = _ActorIcon(actor: actor, scale: scale);
    final gap = SizedBox(width: 6 * scale);

    return Row(
      mainAxisAlignment:
          isLeftSide ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: isLeftSide ? [text, gap, icon] : [icon, gap, text],
    );
  }
}

/// 챔피언 미니(38×38 라운드 8 박스 + 챔피언 이미지) 또는 오브젝트 아이콘(38×38 안 24×24).
class _ActorIcon extends StatelessWidget {
  const _ActorIcon({required this.actor, required this.scale});

  final _Actor actor;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 38 * scale;
    // 오브젝트 출처 팀: 38×38 라운드 박스에 팀 로고. URL 없으면 빈 박스(플레이스홀더).
    if (actor.isTeamLogo) {
      final hasLogo =
          actor.teamLogoUrl != null && actor.teamLogoUrl!.isNotEmpty;
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(4 * scale),
        decoration: BoxDecoration(
          color: AppColors.narDark500,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasLogo
            ? CachedNetworkImage(
                imageUrl: resolveImageUrl(actor.teamLogoUrl)!,
                fit: BoxFit.contain,
                fadeInDuration: const Duration(milliseconds: 150),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              )
            : null,
      );
    }
    if (actor.isObjective) {
      // 에셋 없는 오브젝트(라벨 전용)면 빈 38×38 자리만 둔다 (라벨 텍스트만 표시).
      if (actor.objectiveAsset == null) {
        return SizedBox(width: size, height: size);
      }
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Image.asset(
            actor.objectiveAsset!,
            width: 24 * scale,
            height: 24 * scale,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    final hasImage = actor.championImageUrl != null &&
        actor.championImageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.narDark500,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: resolveImageUrl(actor.championImageUrl)!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            )
          : null,
    );
  }
}

/// 라이브 이벤트 한 건의 데이터(시간 + 출발/대상 액터).
class _LiveEvent {
  const _LiveEvent({
    required this.time,
    required this.source,
    required this.target,
  });

  final String time;
  final _Actor source;
  final _Actor target;
}

/// 라이브 이벤트의 한 쪽 주체. 챔피언(선수)·오브젝트·팀(로고) 중 하나.
class _Actor {
  const _Actor.champion({
    required this.name,
    this.championImageUrl,
  })  : objectiveAsset = null,
        teamLogoUrl = null,
        isTeamLogo = false,
        isObjectiveLabel = false;

  /// 오브젝트 이벤트의 출처 팀 — 38×38 박스에 팀 로고(NetworkImage)를 표시.
  const _Actor.teamLogo({
    required this.name,
    String? logoUrl,
  })  : championImageUrl = null,
        objectiveAsset = null,
        teamLogoUrl = logoUrl,
        isTeamLogo = true,
        isObjectiveLabel = false;

  const _Actor.objective({
    required this.name,
    required String asset,
  })  : championImageUrl = null,
        objectiveAsset = asset,
        teamLogoUrl = null,
        isTeamLogo = false,
        isObjectiveLabel = false;

  /// 로컬 에셋이 없는 오브젝트 — 라벨만 오브젝트 스타일로 표시.
  const _Actor.objectiveLabel(this.name)
      : championImageUrl = null,
        objectiveAsset = null,
        teamLogoUrl = null,
        isTeamLogo = false,
        isObjectiveLabel = true;

  final String name;
  final String? championImageUrl;
  final String? objectiveAsset;

  /// 팀 로고 URL (오브젝트 출처 팀). null/빈 문자열이면 플레이스홀더.
  final String? teamLogoUrl;
  final bool isTeamLogo;

  /// 에셋 없는 오브젝트(라벨 전용) 여부.
  final bool isObjectiveLabel;

  bool get isObjective => objectiveAsset != null || isObjectiveLabel;
}
