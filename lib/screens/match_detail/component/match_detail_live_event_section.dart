import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';

/// 경기 상세 — 라이브 이벤트 탭 콘텐츠.
///
/// 상단의 최근 상태 로드 버튼(리로드 아이콘 + 안내 문구)과 그 아래
/// 좌측 narPink700 타임라인(점·세로선)으로 이어지는 이벤트 카드 리스트로 구성된다.
class MatchDetailLiveEventSection extends StatefulWidget {
  const MatchDetailLiveEventSection({
    super.key,
    this.scale = 1,
    this.onReload,
  });

  final double scale;

  /// 리로드 버튼을 눌렀을 때 호출. 로딩 상태(아이콘/문구 변경) 동안 외부에서
  /// 라이브 이벤트를 가져온 뒤, 완료되면 다시 idle 로 돌아가도록 반환을 기다린다.
  final Future<void> Function()? onReload;

  @override
  State<MatchDetailLiveEventSection> createState() =>
      _MatchDetailLiveEventSectionState();
}

class _MatchDetailLiveEventSectionState
    extends State<MatchDetailLiveEventSection> {
  bool _loading = false;

  // 데모용 샘플 이벤트. 추후 API 응답으로 교체.
  static const List<_LiveEvent> _events = [
    _LiveEvent(
      time: '17:34',
      source: _Actor.champion(name: 'Faker'),
      target: _Actor.objective(
        name: '바람드래곤',
        asset: 'assets/icons/cloud-dragon.png',
      ),
    ),
    _LiveEvent(
      time: '10:34',
      source: _Actor.champion(name: 'Faker'),
      target: _Actor.champion(name: 'Chovy'),
    ),
    _LiveEvent(
      time: '07:34',
      source: _Actor.champion(name: 'XUN'),
      target: _Actor.champion(name: 'ON'),
    ),
    _LiveEvent(
      time: '02:34',
      source: _Actor.objective(
        name: '바람드래곤',
        asset: 'assets/icons/cloud-dragon.png',
      ),
      target: _Actor.champion(name: 'ABCDEFG'),
    ),
  ];

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
    return Container(
      width: double.infinity,
      color: AppColors.narBgContent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReloadButton(
            loading: _loading,
            onTap: _handleReload,
            scale: scale,
          ),
          // 로딩 중이면 이벤트 리스트 맨 위에 스켈레톤 한 줄 추가. 카드는 그대로 보여준다.
          if (_loading) _LoadingSkeleton(scale: scale),
          for (var i = 0; i < _events.length; i++) ...[
            _LiveEventRow(
              event: _events[i],
              isFirst: i == 0,
              isLast: i == _events.length - 1,
              isLatest: i == 0,
              // 로딩 중에는 좌측 핑크 점·세로선(타임라인) 숨김.
              showTimeline: !_loading,
              scale: scale,
            ),
            // 카드 사이 4 gap. gap 영역에도 narPink700 세로선을 그려 점들이 끊김 없이 이어지도록.
            if (i < _events.length - 1)
              _LineConnector(scale: scale, showLine: !_loading),
          ],
        ],
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
    required this.scale,
  });

  final bool loading;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        loading ? AppColors.narText3 : AppColors.narTextTertiary;
    final textColor = loading ? AppColors.narText3 : AppColors.narTextTertiary;
    final label = loading ? '라이브 이벤트를 가져오는 중이에요...' : '경기 진행 중';

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
    if (actor.isObjective) {
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
          ? Image.network(
              actor.championImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
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

/// 라이브 이벤트의 한 쪽 주체. 챔피언(선수) 또는 오브젝트 중 하나.
class _Actor {
  const _Actor.champion({
    required this.name,
    this.championImageUrl,
  }) : objectiveAsset = null;

  const _Actor.objective({
    required this.name,
    required String asset,
  })  : championImageUrl = null,
        objectiveAsset = asset;

  final String name;
  final String? championImageUrl;
  final String? objectiveAsset;

  bool get isObjective => objectiveAsset != null;
}
