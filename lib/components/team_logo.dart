import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../repository/team/team_logo_directory.dart';
import '../styles/app_colors.dart';
import '../util/app_image.dart';

/// 원 없이 로고 이미지만 그리는 팀 로고. 정사각 [size] 칸에 비율을 지켜 담는다.
///
/// 로고는 [imageUrl] 이 있으면 그걸, 없으면 팀 코드로 [TeamLogoDirectory] 에서
/// 찾는다. 못 구했거나 불러오는 중이면 시안의 `.tbd` 처럼 둥근 네모 안에 팀
/// 코드를 작게 적는다. 원형 배지는 [TeamCodeBadge].
///
/// [fallbackImageUrl] 은 사전을 먼저 보고 **거기에 없을 때만** 쓴다
/// ([TeamCodeBadge.fallbackImageUrl] 와 같은 규칙).
class TeamLogo extends StatelessWidget {
  const TeamLogo({
    super.key,
    required this.teamCode,
    required this.size,
    this.imageUrl,
    this.fallbackImageUrl,
    this.directory,
  });

  final String teamCode;
  final double size;
  final String? imageUrl;

  /// 사전에 [teamCode] 가 없을 때만 쓰는 로고 URL.
  final String? fallbackImageUrl;

  /// 테스트에서 갈아끼운다. 기본은 [TeamLogoDirectory.instance].
  final TeamLogoDirectory? directory;

  @override
  Widget build(BuildContext context) {
    final explicit = imageUrl;
    if (explicit != null && explicit.isNotEmpty) return _logo(explicit);

    final dir = directory ?? TeamLogoDirectory.instance;
    dir.ensureLoaded();
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: dir.logos,
      builder: (_, _, _) => _logo(dir.logoFor(teamCode) ?? fallbackImageUrl),
    );
  }

  Widget _logo(String? url) {
    final resolved = resolveImageUrl(url);
    if (resolved == null || resolved.isEmpty) return _placeholder();
    return SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: resolved,
        fit: BoxFit.contain,
        memCacheWidth: (size * 3).round(),
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, _) => _placeholder(),
        errorWidget: (_, _, _) => _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.narLine2,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.06),
          child: Text(
            teamCode.isEmpty ? '?' : teamCode,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w700,
              fontSize: size / 3,
              color: AppColors.narDark200,
            ),
          ),
        ),
      ),
    );
  }
}
