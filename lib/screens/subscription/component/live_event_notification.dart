import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 라이브 이벤트의 한 쪽 주체 (챔피언/선수 또는 오브젝트).
class LiveActor {
  const LiveActor.champion({required this.name, this.imageUrl})
    : objectiveAsset = null;

  const LiveActor.objective({required this.name, required String asset})
    : imageUrl = null,
      objectiveAsset = asset;

  final String name;
  final String? imageUrl;
  final String? objectiveAsset;

  bool get isObjective => objectiveAsset != null;
}

/// 라이브 이벤트 한 건 (시간 + 출발/대상 액터).
class LiveEventData {
  const LiveEventData({
    required this.time,
    required this.source,
    required this.target,
  });

  final String time;
  final LiveActor source;
  final LiveActor target;
}

/// 라이브 이벤트 알림.
///
/// 접힘 상태: 공용 [NotificationCard] 요약 + '상세보기' 링크.
/// 펼침 상태: 헤더 + 이벤트 타임라인(경기 상세 라이브 이벤트 탭 구조) + '접어두기'.
class LiveEventNotification extends StatefulWidget {
  const LiveEventNotification({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.season,
    required this.events,
    required this.dateTime,
    required this.relativeTime,
    this.scale = 1,
  });

  final String teamA;
  final String teamB;
  final String season;
  final List<LiveEventData> events;
  final String dateTime;
  final String relativeTime;
  final double scale;

  @override
  State<LiveEventNotification> createState() => _LiveEventNotificationState();
}

class _LiveEventNotificationState extends State<LiveEventNotification> {
  bool _expanded = false;

  String get _title => '${widget.teamA} VS ${widget.teamB} 라이브 이벤트 발생!';
  String get _body =>
      '${widget.season} _ ${widget.teamA} VS ${widget.teamB} 경기 실시간 이벤트를 확인해보세요';

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;

    return Container(
      width: double.infinity,
      color: AppColors.narBgSecondary,
      padding: EdgeInsets.all(20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더 (아이콘 + 제목 + body) — 접힘/펼침 공통.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                'assets/icons/pause.svg',
                width: 44 * scale,
                height: 44 * scale,
                colorFilter: const ColorFilter.mode(
                  AppColors.narText,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: 16 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_title, style: _titleStyle(scale)),
                    SizedBox(height: 4 * scale),
                    Text(_body, style: _bodyStyle(scale)),
                  ],
                ),
              ),
            ],
          ),
          // 펼침 타임라인 — 높이 변화를 애니메이션(위→아래로 열림).
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: EdgeInsets.only(top: 8 * scale),
                    // 좌측에 전체 타임라인(연속 그라데이션) 한 번에, 우측에 내용.
                    // IntrinsicHeight: 내용 높이에 맞춰 타임라인 컬럼을 늘린다.
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 11 * scale, // 점 영역 (중심 7.5, 우측 끝 11)
                            child: CustomPaint(
                              painter: _TimelinePainter(
                                count: widget.events.length,
                                latestIndex: 0,
                                scale: scale,
                              ),
                            ),
                          ),
                          SizedBox(width: 10 * scale), // 라인바 ↔ 시각 텍스트 간격
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < widget.events.length; i++)
                                  _EventContent(
                                    event: widget.events[i],
                                    isLatest: i == 0,
                                    scale: scale,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          SizedBox(height: 4 * scale),
          // 상세보기(좌측, 콘텐츠 정렬) / 접어두기(우측) 토글 링크.
          Align(
            alignment: _expanded
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: _expanded ? 0 : 60 * scale),
              child: _LinkText(
                text: _expanded ? '접어두기' : '상세보기',
                scale: scale,
                onTap: () => setState(() => _expanded = !_expanded),
              ),
            ),
          ),
          SizedBox(height: 4 * scale),
          // 아이콘(44) + gap(16) 만큼 들여써 콘텐츠 영역에 정렬.
          Padding(
            padding: EdgeInsets.only(left: 60 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.dateTime, style: _timeStyle(scale)),
                Text(widget.relativeTime, style: _timeStyle(scale)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _titleStyle(double scale) => TextStyle(
  fontFamily: 'Pretendard',
  fontWeight: FontWeight.w600,
  fontSize: 16 * scale,
  height: 25 / 16,
  color: AppColors.narText,
);

TextStyle _bodyStyle(double scale) => TextStyle(
  fontFamily: 'Pretendard',
  fontWeight: FontWeight.w400,
  fontSize: 13 * scale,
  height: 1.45,
  color: AppColors.narTextTertiary,
);

TextStyle _timeStyle(double scale) => TextStyle(
  fontFamily: 'Pretendard',
  fontWeight: FontWeight.w400,
  fontSize: 12 * scale,
  height: 1.45,
  color: AppColors.narText2,
);

/// 밑줄 텍스트 링크 ('상세보기'·'접어두기').
class _LinkText extends StatelessWidget {
  const _LinkText({required this.text, required this.scale, this.onTap});

  final String text;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 5 * scale),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 14 * scale,
            height: 1.45,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.narTextTertiary,
            color: AppColors.narTextTertiary,
          ),
        ),
      ),
    );
  }
}

/// 펼침 타임라인의 이벤트 한 행 내용 — 시간 + 양쪽 액터 + 가운데 킬 아이콘.
/// (좌측 타임라인 점·선은 [_TimelinePainter] 가 전체를 한 번에 그린다.)
class _EventContent extends StatelessWidget {
  const _EventContent({
    required this.event,
    required this.isLatest,
    required this.scale,
  });

  final LiveEventData event;
  final bool isLatest;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54 * scale,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              event.time,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 14 * scale,
                height: 1.45,
                color: isLatest ? AppColors.narPink700 : AppColors.narText2,
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
      ),
    );
  }
}

/// 전체 타임라인을 한 번에 그린다 — 점들과 그 사이 세로선을 하나의 연속
/// 그라데이션([AppColors.narTimelineLine]) shader 로 칠해 끊김이 없게 한다.
///
/// 각 점은 행 높이(54) 의 가운데에 오고, [latestIndex] 점만 빈 링(나머지 채운 원).
class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.count,
    required this.latestIndex,
    required this.scale,
  });

  final int count;
  final int latestIndex;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;

    final rowHeight = 54 * scale;
    final centerX = 7.5 * scale;
    final dotRadius = 3.5 * scale;
    final lineWidth = 1 * scale;
    final firstY = rowHeight / 2;
    final lastY = rowHeight * (count - 1) + rowHeight / 2;

    // 선 — 첫 점 끝 ~ 끝 점 끝(점 안 통과). 선 구간 기준 그라데이션.
    if (count > 1) {
      final lineTop = firstY + dotRadius;
      final lineBottom = lastY - dotRadius;
      canvas.drawLine(
        Offset(centerX, lineTop),
        Offset(centerX, lineBottom),
        Paint()
          ..strokeWidth = lineWidth
          ..shader = AppColors.narTimelineLine.createShader(
            Rect.fromLTWH(0, lineTop, size.width, lineBottom - lineTop),
          ),
      );
    }

    // 점 — 핑크 단색. latestIndex 만 빈 링, 나머지 채운 원.
    for (var i = 0; i < count; i++) {
      final y = rowHeight * i + rowHeight / 2;
      if (i == latestIndex) {
        canvas.drawCircle(
          Offset(centerX, y),
          dotRadius - lineWidth / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = lineWidth
            ..color = AppColors.narPink700,
        );
      } else {
        canvas.drawCircle(
          Offset(centerX, y),
          dotRadius,
          Paint()
            ..style = PaintingStyle.fill
            ..color = AppColors.narPink700,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.count != count ||
      old.latestIndex != latestIndex ||
      old.scale != scale;
}

/// 카드 한쪽 액터(이름 + 아이콘). [isLeftSide] 면 [이름, 아이콘] 순 오른쪽 끝 정렬,
/// 아니면 [아이콘, 이름] 순 왼쪽 정렬. 대상(오른쪽) 이름은 70% 불투명.
class _ActorSide extends StatelessWidget {
  const _ActorSide({
    required this.actor,
    required this.isLeftSide,
    required this.scale,
  });

  final LiveActor actor;
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
          color: isLeftSide ? AppColors.narText : const Color(0xB3FFFFFF),
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

/// 챔피언 미니(38×38 라운드 8) 또는 오브젝트 아이콘(38×38 안 24×24).
class _ActorIcon extends StatelessWidget {
  const _ActorIcon({required this.actor, required this.scale});

  final LiveActor actor;
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
    final hasImage = actor.imageUrl != null && actor.imageUrl!.isNotEmpty;
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
              imageUrl: resolveImageUrl(actor.imageUrl)!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            )
          : null,
    );
  }
}
