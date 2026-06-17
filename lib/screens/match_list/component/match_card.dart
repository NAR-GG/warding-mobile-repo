import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_badge.dart';
import '../../../components/nar_live_badge.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 경기 한 건 카드. 헤더(시간/LIVE 칩·라벨·우측 chevron) + 양 팀 로고·이름 + 가운데 스코어.
/// [isLive] 가 true 면 카드 배경/왼쪽 보더/LIVE 칩/스코어 색 분기.
class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.time,
    required this.label,
    required this.homeName,
    required this.awayName,
    this.homeLogoUrl,
    this.awayLogoUrl,
    required this.homeScore,
    required this.awayScore,
    this.isLive = false,
    this.liveSetLabel,
    this.onTap,
    this.scale = 1,
  });

  final String time;
  final String label;
  final String homeName;
  final String awayName;
  final String? homeLogoUrl;
  final String? awayLogoUrl;
  final int homeScore;
  final int awayScore;

  /// 라이브 경기 여부. 카드 배경/왼쪽 보더/LIVE 칩/스코어 색을 분기한다.
  final bool isLive;

  /// 라이브일 때 스코어 아래 표시할 라벨. 예: 'SET 4 진행중'.
  final String? liveSetLabel;

  final VoidCallback? onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final padding = isLive
        ? EdgeInsets.only(
            top: 10 * scale,
            left: 20 * scale,
            right: 20 * scale,
            bottom: 24 * scale,
          )
        : EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale);

    final decoration = isLive
        ? const BoxDecoration(
            color: AppColors.narDark600,
            border: Border(
              left: BorderSide(color: AppColors.liveSideBorder, width: 3),
            ),
          )
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: decoration,
        padding: padding,
        child: Column(
          children: [
            Row(
              children: [
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TeamColumn(
                  name: homeName,
                  logoUrl: homeLogoUrl,
                  scale: scale,
                ),
                SizedBox(width: 20.5 * scale),
                _SpoilerOverlay(
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
                SizedBox(width: 20.5 * scale),
                _TeamColumn(
                  name: awayName,
                  logoUrl: awayLogoUrl,
                  scale: scale,
                ),
              ],
            ),
          ],
        ),
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
    return Column(
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
                  child: Image.network(
                    resolveImageUrl(logoUrl)!,
                    width: 40 * scale,
                    height: 40 * scale,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                )
              : null,
        ),
        SizedBox(height: 4 * scale),
        Text(
          name,
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
            fontSize: 16 * scale,
            height: 19 / 16,
            color: AppColors.narTextTertiary,
          ),
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.home,
    required this.away,
    required this.scale,
  });

  final int home;
  final int away;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'SF Pro',
      fontWeight: FontWeight.w700,
      fontSize: 28 * scale,
      height: 33 / 28,
      color: AppColors.narDark200,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$home', style: style),
        SizedBox(width: 14 * scale),
        Text(':', style: style),
        SizedBox(width: 14 * scale),
        Text('$away', style: style),
      ],
    );
  }
}

/// 라이브 스코어. 큰 숫자 + 아래 'SET N 진행중' 라벨.
/// 점수 색: 앞서는 쪽 scoreWin, 뒤지는 쪽 narDark600(배경과 거의 동일), 동점은 narDark200.
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

  Color _colorFor(int self, int other) {
    if (self > other) return AppColors.scoreWin;
    if (self < other) return AppColors.narDark600;
    return AppColors.narDark200;
  }

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
            Text(':', style: _bigStyle(AppColors.narDark200)),
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
/// 안쪽 child(실제 스코어)는 가운데 정렬되어 보이고, 위에 흐림 + 텍스트가 덮인다.
/// 탭하면 [_revealed=true] → 오버레이 사라지고 실제 스코어 노출.
class _SpoilerOverlay extends StatefulWidget {
  const _SpoilerOverlay({required this.child, required this.scale});

  final Widget child;
  final double scale;

  @override
  State<_SpoilerOverlay> createState() => _SpoilerOverlayState();
}

class _SpoilerOverlayState extends State<_SpoilerOverlay> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return SizedBox(
      width: 116 * scale,
      height: 77 * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 실제 스코어 — 가운데 정렬.
          Center(child: widget.child),
          if (!_revealed)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _revealed = true),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14 * scale),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                    child: Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(11 * scale),
                      decoration: BoxDecoration(
                        color: const Color(0x66141517), // narDark800 + 40%
                        borderRadius: BorderRadius.circular(14 * scale),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '스포방지',
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
                            '클릭시 스코어 확인 가능',
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
              ),
            ),
        ],
      ),
    );
  }
}
