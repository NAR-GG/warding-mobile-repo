import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../model/match_champion_pick.dart';
import '../../../styles/app_colors.dart';
import 'match_detail_build_guide.dart';

/// 룬 트리 두 칸(주/부) — 주 트리는 키스톤(큰 아이콘)+나머지 3개, 부 트리는
/// 선택된 룬 2개 모두 같은 크기로.
class BuildRunesRow extends StatelessWidget {
  const BuildRunesRow({super.key, required this.runes, required this.scale});

  final PlayerRunes runes;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _RuneTreeColumn(
            style: runes.primary,
            isPrimary: true,
            scale: scale,
          ),
        ),
        SizedBox(width: 16 * scale),
        Expanded(
          child: _RuneTreeColumn(
            style: runes.sub,
            isPrimary: false,
            scale: scale,
          ),
        ),
      ],
    );
  }
}

class _RuneTreeColumn extends StatelessWidget {
  const _RuneTreeColumn({
    required this.style,
    required this.isPrimary,
    required this.scale,
  });

  final RuneStyle style;
  final bool isPrimary;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasIcon =
        style.styleIconUrl != null && style.styleIconUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8 * scale,
            vertical: 4 * scale,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppColors.narWhiteBorder62,
                width: 3 * scale,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Container(
                  width: 22 * scale,
                  height: 22 * scale,
                  color: AppColors.narBgSecondary,
                  child: hasIcon
                      ? CachedNetworkImage(
                          imageUrl: style.styleIconUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        )
                      : null,
                ),
              ),
              SizedBox(width: 8 * scale),
              Text(
                style.styleName,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 14 * scale,
                  height: 20 / 14,
                  color: AppColors.narText,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8 * scale),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < style.runes.length; i++) ...[
                if (i > 0) SizedBox(height: 8 * scale),
                _RuneEntryRow(
                  entry: style.runes[i],
                  large: isPrimary && i == 0,
                  scale: scale,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 룬 한 칸 — 키스톤([large])은 33px 원형(배경 있음), 나머지는 24px(테두리만).
class _RuneEntryRow extends StatefulWidget {
  const _RuneEntryRow({
    required this.entry,
    required this.large,
    required this.scale,
  });

  final RuneEntry entry;
  final bool large;
  final double scale;

  @override
  State<_RuneEntryRow> createState() => _RuneEntryRowState();
}

class _RuneEntryRowState extends State<_RuneEntryRow> {
  final _layerLink = LayerLink();
  OverlayEntry? _tooltipEntry;

  @override
  void dispose() {
    _tooltipEntry?.remove();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    // onTap 대신 onTapDown 을 쓴다 — 이 위젯이 스와이프 가능한 PageView
    // 안에 있어서, onTap(탭업 기준)은 제스처 아레나가 "탭이냐 스와이프냐"
    // 판정할 때까지 기다리느라 반응이 한 박자 늦게 느껴진다. 손가락이
    // 닿는 즉시(터치다운) 여는 게 호버에 가장 가까운 반응이다.
    if (_tooltipEntry != null) {
      _hideTooltip();
      return;
    }
    final description = widget.entry.description;
    if (description == null || description.isEmpty) return;

    final overlay = Overlay.of(context);
    _tooltipEntry = OverlayEntry(
      builder: (context) => BuildGuideOverlay(
        layerLink: _layerLink,
        name: widget.entry.name,
        description: description,
        scale: widget.scale,
        onDismiss: _hideTooltip,
      ),
    );
    overlay.insert(_tooltipEntry!);
  }

  void _hideTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final large = widget.large;
    final scale = widget.scale;
    final size = (large ? 33.0 : 24.0) * scale;
    final hasIcon = entry.iconUrl != null && entry.iconUrl!.isNotEmpty;
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: large ? AppColors.narBgSecondary : null,
                border: Border.all(color: AppColors.narWhiteBorder15, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasIcon
                  ? CachedNetworkImage(
                      imageUrl: entry.iconUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    )
                  : null,
            ),
            SizedBox(width: 8 * scale),
            Flexible(
              child: Text(
                entry.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  fontSize: 12 * scale,
                  height: 17 / 12,
                  color: AppColors.narText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 능력치 파편 칩 — "{name} {label}"(예: '적응형 능력치 +9').
class BuildShardsRow extends StatelessWidget {
  const BuildShardsRow({super.key, required this.shards, required this.scale});

  final List<RuneShard> shards;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4 * scale,
      runSpacing: 4 * scale,
      children: [
        for (final shard in shards) _ShardPill(shard: shard, scale: scale),
      ],
    );
  }
}

class _ShardPill extends StatelessWidget {
  const _ShardPill({required this.shard, required this.scale});

  final RuneShard shard;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasIcon = shard.iconUrl != null && shard.iconUrl!.isNotEmpty;
    final text = shard.label != null
        ? '${shard.name} ${shard.label}'
        : shard.name;
    return Container(
      padding: EdgeInsets.fromLTRB(2 * scale, 2 * scale, 8 * scale, 2 * scale),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.narWhiteBorder15, width: 0.5),
        borderRadius: BorderRadius.circular(4 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 19 * scale,
            height: 19 * scale,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2 * scale),
            ),
            child: hasIcon
                ? CachedNetworkImage(
                    imageUrl: shard.iconUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  )
                : null,
          ),
          SizedBox(width: 2 * scale),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
              fontSize: 11 * scale,
              height: 13 / 11,
              color: AppColors.narText,
            ),
          ),
        ],
      ),
    );
  }
}
