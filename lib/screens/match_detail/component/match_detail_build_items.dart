import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../model/match_champion_pick.dart';
import '../../../styles/app_colors.dart';
import 'match_detail_build_guide.dart';

/// 아이템 8칸 — 코어 6 + 퀘스트 아이템(신발) + 장신구, 한 줄에 나란히.
/// 칸을 탭하면 룬과 같은 가이드 카드(이름+설명)가 뜬다. 이름·설명이 있는
/// [ChampionPick.items] 를 우선 쓰고, 구버전 응답(null)이면 URL 목록으로
/// 이미지만 그린다(툴팁 없음).
class BuildItemRow extends StatelessWidget {
  const BuildItemRow({super.key, required this.pick, required this.scale});

  final ChampionPick pick;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final items = pick.items;

    final List<ItemEntry?> slots;
    if (items != null) {
      ItemEntry? coreAt(int index) =>
          index < items.core.length ? items.core[index] : null;
      slots = [
        for (var i = 0; i < 6; i++) coreAt(i),
        items.questItem,
        items.trinket,
      ];
    } else {
      final core = pick.coreItemImageUrls;
      ItemEntry? fromUrl(String? url) => url == null || url.isEmpty
          ? null
          : ItemEntry(name: '', iconUrl: url);
      slots = [
        for (var i = 0; i < 6; i++) fromUrl(i < core.length ? core[i] : null),
        fromUrl(pick.questItemImageUrl),
        fromUrl(pick.trinketItemImageUrl),
      ];
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final entry in slots) _ItemSlot(entry: entry, scale: scale),
      ],
    );
  }
}

/// 아이템 한 칸. 탭(터치다운)하면 이름+설명 가이드 카드를 연다 — 동작·이유는
/// 룬 한 칸(`BuildRuneEntryRow`)의 터치다운 처리와 동일.
class _ItemSlot extends StatefulWidget {
  const _ItemSlot({required this.entry, required this.scale});

  /// null 이면 빈 칸(배경만).
  final ItemEntry? entry;
  final double scale;

  @override
  State<_ItemSlot> createState() => _ItemSlotState();
}

class _ItemSlotState extends State<_ItemSlot> {
  final _layerLink = LayerLink();
  OverlayEntry? _tooltipEntry;

  @override
  void dispose() {
    _tooltipEntry?.remove();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (_tooltipEntry != null) {
      _hideTooltip();
      return;
    }
    final entry = widget.entry;
    final description = entry?.description;
    if (entry == null || description == null || description.isEmpty) return;

    // 카드(최대 166)를 아이콘 왼쪽 끝에서 오른쪽으로 펼쳤을 때 화면을 넘으면
    // 오른쪽 끝에 맞춰 왼쪽으로 펼친다 — 오른쪽 2~3칸(퀘스트·장신구)이 해당.
    final box = context.findRenderObject() as RenderBox?;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final left = box?.localToGlobal(Offset.zero).dx ?? 0;
    final alignRight =
        left + BuildGuideCard.maxWidth * widget.scale > screenWidth;

    final overlay = Overlay.of(context);
    _tooltipEntry = OverlayEntry(
      builder: (context) => BuildGuideOverlay(
        layerLink: _layerLink,
        name: entry.name,
        description: description,
        scale: widget.scale,
        onDismiss: _hideTooltip,
        alignRight: alignRight,
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
    final scale = widget.scale;
    final url = widget.entry?.iconUrl;
    final hasImage = url != null && url.isNotEmpty;
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        child: Container(
          width: 37 * scale,
          height: 37 * scale,
          decoration: BoxDecoration(
            color: AppColors.narBgSecondary,
            borderRadius: BorderRadius.circular(4 * scale),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                )
              : null,
        ),
      ),
    );
  }
}
