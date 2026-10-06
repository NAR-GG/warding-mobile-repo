import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../repository/team/team_logo_directory.dart';
import '../styles/app_colors.dart';
import '../util/app_image.dart';

/// 팀 로고 원형 배지. 로고 이미지를 원 안에 그리고, 로고를 못 구했거나 아직
/// 불러오는 중이면 빈 원만 둔다.
///
/// 로고는 [imageUrl] 이 있으면 그걸, 없으면 팀 코드로 [TeamLogoDirectory] 에서
/// 찾는다. 순위표·경기 카드처럼 응답에 로고가 실려 오면 [imageUrl] 로 넘기고,
/// 코드만 있는 자리(솔랭·한줄평 등)는 넘기지 않는다.
///
/// [fallbackImageUrl] 은 순서가 반대다 — 사전을 먼저 보고 **거기에 없을 때만**
/// 쓴다. 사전(온보딩 팀 목록)에 없는 팀, 즉 국가대표(ASIAN_GAMES 의 국기)처럼
/// 응답에만 이미지가 있는 경우를 위한 것이다. 프로팀은 사전 값이 이기므로
/// 두 소스의 여백·비율이 섞여 로고 크기가 들쭉날쭉해지지 않는다.
class TeamCodeBadge extends StatelessWidget {
  const TeamCodeBadge({
    super.key,
    required this.teamCode,
    required this.size,
    this.imageUrl,
    this.fallbackImageUrl,
    this.directory,
  });

  final String teamCode;
  final double size;

  /// 응답이 준 로고 URL. 비어 있으면 [teamCode] 로 찾는다.
  final String? imageUrl;

  /// 사전에 [teamCode] 가 없을 때만 쓰는 로고 URL.
  final String? fallbackImageUrl;

  /// 테스트에서 갈아끼운다. 기본은 [TeamLogoDirectory.instance].
  final TeamLogoDirectory? directory;

  @override
  Widget build(BuildContext context) {
    final explicit = imageUrl;
    if (explicit != null && explicit.isNotEmpty) return _circle(explicit);

    final dir = directory ?? TeamLogoDirectory.instance;
    dir.ensureLoaded();
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: dir.logos,
      builder: (_, _, _) => _circle(dir.logoFor(teamCode) ?? fallbackImageUrl),
    );
  }

  Widget _circle(String? url) {
    final resolved = resolveImageUrl(url);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.narDark500,
        shape: BoxShape.circle,
      ),
      child:
          resolved == null || resolved.isEmpty
              ? null
              : Padding(
                padding: EdgeInsets.all(size * 0.12),
                child: CachedNetworkImage(
                  imageUrl: resolved,
                  width: size * 0.76,
                  height: size * 0.76,
                  fit: BoxFit.contain,
                  memCacheWidth: (size * 3).round(),
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
    );
  }
}
