import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'league_meta.dart';

/// 아이콘이 있는 리그 코드. `/mobile/schedules/filters` 가 내려주는 13개 리그
/// 전부 아이콘을 받았다.
///
/// LCS·MSI·WORLDS 는 원본이 벡터가 아니라 (Figma 가 래스터 레이어를
/// mask+pattern 으로 감싸 내보낸) SVG 라 flutter_svg 가 렌더링하지 못해서
/// PNG 로 추출해 뒀다 — 나머지는 깨끗한 벡터라 그대로 SVG.
const Map<String, String> _leagueIcons = {
  'LCK': 'assets/icons/leagues/lck.svg',
  'LCS': 'assets/icons/leagues/lcs.png',
  'LEC': 'assets/icons/leagues/lec.svg',
  'LPL': 'assets/icons/leagues/lpl.svg',
  'MSI': 'assets/icons/leagues/msi.png',
  'WORLDS': 'assets/icons/leagues/worlds.png',
  'EWC': 'assets/icons/leagues/ewc.svg',
  'KESPA': 'assets/icons/leagues/kespa.svg',
  'CBLOL': 'assets/icons/leagues/cblol.svg',
  'FIRST_STAND': 'assets/icons/leagues/first-stand.svg',
  'LCP': 'assets/icons/leagues/lcp.svg',
  'ASIAN_GAMES': 'assets/icons/leagues/asian-games.svg',
  'DEMACIA_CUP': 'assets/icons/leagues/demacia-cup.svg',
};

/// [leagueCode] 에 해당하는 아이콘 asset 경로. 대소문자를 가리지 않으며,
/// 아이콘이 없는 리그(또는 '전체' 등 리그 코드가 아닌 값)면 null.
String? leagueIconAsset(String leagueCode) =>
    _leagueIcons[leagueCode.toUpperCase()];

/// [leagueCode] 아이콘을 그릴 위젯. 서버가 URL 을 주면([LeagueMeta.iconUrl],
/// PNG) 그걸 쓰고, 없거나 받지 못하면 번들 아이콘으로 폴백한다. 번들은 확장자에
/// 따라 SVG/PNG 렌더러를 알아서 고른다 — 호출부는 어떤 포맷인지 몰라도 된다.
/// 둘 다 없으면 null(호출부가 텍스트만 표시하도록).
Widget? leagueIconWidget(String leagueCode, {BoxFit fit = BoxFit.contain}) {
  final asset = leagueIconAsset(leagueCode);
  final bundled = asset == null
      ? null
      : (asset.endsWith('.png')
            ? Image.asset(asset, fit: fit)
            : SvgPicture.asset(asset, fit: fit));
  final url = LeagueMeta.iconUrl(leagueCode);
  if (url == null) return bundled;
  return CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    // 받는 동안·실패 시 번들 아이콘(없으면 빈 칸) — 새 리그만 URL 만 있다.
    placeholder: (_, _) => bundled ?? const SizedBox.shrink(),
    errorWidget: (_, _, _) => bundled ?? const SizedBox.shrink(),
  );
}
