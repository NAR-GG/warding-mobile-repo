import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/nar_button.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 구독 섹션의 한 행 데이터 (팀 또는 선수 공용).
class SubscribedItem {
  const SubscribedItem({
    required this.name,
    this.logoUrl,
    required this.subscribed,
  });

  final String name;
  final String? logoUrl;
  final bool subscribed;
}

/// 구독 설정 화면의 공용 구독 섹션 ('구독중인 팀' / '구독중인 선수' 등).
///
/// 상단 narBgLast 섹션 헤더 바 + 16 gap + 행 리스트 구조.
/// 각 행은 좌측 [로고 + 이름], 우측 구독 토글 버튼([NarButton])으로 spaceBetween 정렬.
class SubscribedSection extends StatelessWidget {
  const SubscribedSection({
    super.key,
    required this.title,
    required this.items,
    this.onToggle,
    this.scale = 1,
  });

  /// 섹션 헤더 바 라벨 ('구독중인 팀' / '구독중인 선수' 등).
  final String title;

  /// 노출할 행 목록.
  final List<SubscribedItem> items;

  /// 행의 구독 토글 버튼 탭 콜백. 인덱스를 넘긴다.
  final void Function(int index)? onToggle;

  /// 비율 스케일. 시안(폭 375) 기준 수치에 곱한다.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubscribedSectionHeader(label: title, scale: scale),
        SizedBox(height: 16 * scale), // 헤더 바 ↔ 첫 행 gap
        for (var i = 0; i < items.length; i++)
          SubscribedItemRow(
            item: items[i],
            onToggle: onToggle == null ? null : () => onToggle!(i),
            scale: scale,
          ),
      ],
    );
  }
}

/// 섹션 헤더 바. narBgLast 배경 + 좌측 라벨, 높이 38.
/// 다른 섹션('전체 목록' 등)에서도 동일 스타일로 재사용.
class SubscribedSectionHeader extends StatelessWidget {
  const SubscribedSectionHeader({
    super.key,
    required this.label,
    this.scale = 1,
  });

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38 * scale,
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 8 * scale,
      ),
      color: AppColors.narBgLast, // #25262B
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 14 * scale,
          height: 1.55, // 155%
          color: AppColors.narTextTertiary, // #FCFDFE
        ),
      ),
    );
  }
}

/// 행 한 줄. [로고 + 이름] | [구독 토글] spaceBetween, 높이 50.
/// [backgroundColor] 가 주어지면 행 배경을 채운다 (전체 목록의 짝수 행 등).
class SubscribedItemRow extends StatelessWidget {
  const SubscribedItemRow({
    super.key,
    required this.item,
    this.onToggle,
    this.backgroundColor,
    this.scale = 1,
  });

  final SubscribedItem item;
  final VoidCallback? onToggle;
  final Color? backgroundColor;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50 * scale,
      color: backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 8 * scale,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ItemLogo(url: item.logoUrl, scale: scale),
              SizedBox(width: 8 * scale),
              Text(
                item.name,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 16 * scale,
                  height: 19 / 16,
                  letterSpacing: 0.21,
                  color: AppColors.narText,
                ),
              ),
            ],
          ),
          NarButton(
            label: item.subscribed
                ? AppLocalizations.of(context)!.subscribing
                : AppLocalizations.of(context)!.subscribe,
            variant: item.subscribed
                ? NarButtonVariant.subscribed
                : NarButtonVariant.subscribe,
            onPressed: onToggle,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

/// 로고/아바타 33×33. URL 없으면 빈 자리(placeholder)로 둔다.
class _ItemLogo extends StatelessWidget {
  const _ItemLogo({required this.url, required this.scale});

  final String? url;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 33 * scale;
    if (url == null || url!.isEmpty) {
      return SizedBox(width: size, height: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: resolveImageUrl(url)!,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
