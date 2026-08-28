import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../util/app_image.dart';

/// 원형 프로필 이미지.
///
/// 이미지가 없거나(기본 프로필) 로드에 실패하면 마이페이지와 같은
/// `person.png` 로 떨어진다. 회색 원으로 두면 "아직 로딩 중"처럼 보여서,
/// 프로필을 안 올린 사용자가 화면마다 다르게 보인다.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/images/person.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    final resolved = resolveImageUrl(url);

    return ClipOval(
      child: resolved == null || resolved.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: resolved,
              width: size,
              height: size,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}
