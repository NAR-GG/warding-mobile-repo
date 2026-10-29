import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/nar_card.dart';
import '../../../components/nar_section_title.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../util/champion_image.dart';
import '../../../util/champion_name_map.dart';

/// 선수 페이지 공용 조각 — 숫자 포맷·텍스트 스타일·섹션 제목·챔피언 아이콘·승패 줄.
/// 카드 틀은 공용 [NarCard] 를 쓴다.

/// "2.1만" / "21K". 딜량처럼 큰 수를 짧게 — 유효숫자 2자리.
String compactNumber(BuildContext context, int n) => (NumberFormat.compact(
  locale: Localizations.localeOf(context).toString(),
)..significantDigits = 2).format(n);

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

/// "월즈 성적  3경기 · 2승 1패" — 공용 [NarSectionTitle] 에 선수 페이지 섹션
/// 간격(위 28 / 아래 12)과 부제 크기(12)만 얹은 것.
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
    return NarSectionTitle(
      title: title,
      subtitle: sub,
      subtitleSize: 12,
      scale: scale,
      padding: EdgeInsets.only(top: 28 * scale, bottom: 12 * scale),
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
