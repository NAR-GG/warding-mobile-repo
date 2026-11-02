import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 선수 얼굴 원형 아바타. 사진이 없으면 이름 앞 두 글자를, `+N` 처럼 넘긴
/// 이름은 그대로 보여준다.
///
/// 홈 솔랭 섹션(겹친 얼굴 스택·끝난 경기 칩), 월즈 솔랭 블록, 선수 페이지
/// 솔랭 탭이 같이 쓴다.
class SoloFace extends StatelessWidget {
  const SoloFace({
    super.key,
    required this.name,
    required this.url,
    required this.size,
    required this.scale,
  });

  final String name;
  final String? url;
  final double size;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final label = name.startsWith('+')
        ? name
        : (name.length >= 2 ? name.substring(0, 2) : name).toUpperCase();
    final initials = Center(
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w700,
          fontSize: 13 * scale,
          color: AppColors.narText2,
        ),
      ),
    );
    final photo = url;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.narLine2,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.narBgTertiary, width: 2 * scale),
      ),
      child: ClipOval(
        child: photo == null || photo.isEmpty
            ? initials
            : CachedNetworkImage(
                imageUrl: photo,
                fit: BoxFit.cover,
                // 전신 사진이라 얼굴이 위쪽에 있다 — 시안의 `center 12%`.
                alignment: const Alignment(0, -0.75),
                memCacheWidth: (size * 3).round(),
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, _) => initials,
                errorWidget: (_, _, _) => initials,
              ),
      ),
    );
  }
}
