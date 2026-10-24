import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../util/champion_image.dart';
import '../../../util/champion_name_map.dart';

/// 선수 페이지 공용 조각 — 카드 틀·섹션 제목·챔피언 아이콘·승패 줄.

/// "2.4만" / "24K". 딜량처럼 큰 수를 짧게.
String compactNumber(BuildContext context, int n) => NumberFormat.compact(
  locale: Localizations.localeOf(context).toString(),
).format(n);

/// 소수 첫째 자리. 정수면 "6.0" 처럼 그대로 둔다(시안).
String oneDecimal(double v) => v.toStringAsFixed(1);

/// 판 하나의 KDA — 데스 0 이면 1로 나눈다.
double gameKda(int k, int d, int a) => (k + a) / (d == 0 ? 1 : d);

TextStyle playerText(
  double scale, {
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.narText,
  String family = 'Pretendard',
}) => TextStyle(
  fontFamily: family,
  fontWeight: weight,
  fontSize: size * scale,
  color: color,
);

class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.child,
    required this.scale,
    this.padding,
  });

  final Widget child;
  final double scale;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: child,
    );
  }
}

/// "월즈 성적  3경기 · 2승 1패".
class PlayerSectionTitle extends StatelessWidget {
  const PlayerSectionTitle({
    super.key,
    required this.title,
    required this.scale,
    this.sub,
  });

  final String title;
  final String? sub;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 28 * scale, bottom: 12 * scale),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: title),
            if (sub != null)
              TextSpan(
                text: '  $sub',
                style: playerText(scale, size: 12, color: AppColors.narText2),
              ),
          ],
        ),
        style: playerText(scale, size: 17, weight: FontWeight.w700),
      ),
    );
  }
}

/// 챔피언 정사각 아이콘. 서버 URL 이 없으면 이름으로 Data Dragon 주소를 만든다.
class ChampionIcon extends StatelessWidget {
  const ChampionIcon({
    super.key,
    required this.name,
    required this.size,
    required this.scale,
    this.url,
  });

  final String name;
  final String? url;
  final double size;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final server = resolveImageUrl(url);
    final src = ChampionImage.resolve(
      server == null || server.isEmpty ? null : server,
      championToEn(name),
    );
    final box = Container(
      width: size * scale,
      height: size * scale,
      color: AppColors.narDark500,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6 * scale),
      child: src == null
          ? box
          : CachedNetworkImage(
              imageUrl: src,
              width: size * scale,
              height: size * scale,
              fit: BoxFit.cover,
              placeholder: (_, _) => box,
              errorWidget: (_, _, _) => box,
            ),
    );
  }
}

/// 승패 줄 — 왼쪽 3px 띠(승 빨강 / 패 회색) + 내용.
class PlayerResultRow extends StatelessWidget {
  const PlayerResultRow({
    super.key,
    required this.win,
    required this.child,
    required this.scale,
    this.divider = true,
  });

  final bool win;
  final Widget child;
  final double scale;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: win ? AppColors.scoreWin : AppColors.narDark300,
            width: 3 * scale,
          ),
          top: divider
              ? const BorderSide(color: AppColors.narLine)
              : BorderSide.none,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        12 * scale,
        12 * scale,
        14 * scale,
        12 * scale,
      ),
      child: child,
    );
  }
}

/// "전체 8개 보기 ⌄" / "15판 더 보기 ⌄".
class PlayerMoreButton extends StatelessWidget {
  const PlayerMoreButton({
    super.key,
    required this.label,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 38 * scale,
        margin: EdgeInsets.only(top: 10 * scale),
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: playerText(
                scale,
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.narText2,
              ),
            ),
            SizedBox(width: 3 * scale),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16 * scale,
              color: AppColors.narText2,
            ),
          ],
        ),
      ),
    );
  }
}

/// "4 / 1 / 11" — 데스만 빨강.
InlineSpan kdaSpan(int k, int d, int a) => TextSpan(
  children: [
    TextSpan(text: '$k / '),
    TextSpan(
      text: '$d',
      style: const TextStyle(color: AppColors.narTextRed),
    ),
    TextSpan(text: ' / $a'),
  ],
);
