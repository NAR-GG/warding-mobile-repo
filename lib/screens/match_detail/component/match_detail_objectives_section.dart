import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../model/match_champion_pick.dart';
import '../../../styles/app_colors.dart';
import '../../../util/dragon_type.dart';

/// 경기 상세 — 챔피언픽 탭 맨 아래의 "Objectives" 섹션.
///
/// `GET /api/mobile/live/games/{gameId}/champions` 응답의 `objectives`
/// (드래곤·장로·바론·타워·억제기)를 하나의 라운드 박스 안에 그대로
/// 렌더링한다(Figma 최신 시안 기준 — "주요 오브젝트"/"구조물" 구분선은
/// 뺐다). 전령·공허유충·타워 플레이트는 API에 없어 행 자체를 뺐다.
class MatchDetailObjectivesSection extends StatelessWidget {
  const MatchDetailObjectivesSection({
    super.key,
    required this.blueTeam,
    required this.redTeam,
    this.scale = 1,
  });

  final TeamObjectives blueTeam;
  final TeamObjectives redTeam;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.narBgContent,
      // 좌우 10 + 안쪽 박스 좌우 0 = Team Summary(_VisionGoldRow)의 와드
      // 아이콘과 같은 x좌표(화면 가장자리에서 10px)에 오도록 맞췄다.
      padding: EdgeInsets.fromLTRB(10 * scale, 16 * scale, 10 * scale, 36 * scale),
      alignment: Alignment.topCenter,
      child: Container(
        width: 333 * scale,
        padding: EdgeInsets.symmetric(vertical: 12 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ObjectiveRow(
              icon: _ObjectiveIcons.dragon,
              label: '드래곤',
              left: '${blueTeam.dragons}',
              right: '${redTeam.dragons}',
              scale: scale,
            ),
            SizedBox(height: 15 * scale),
            _DragonTypesRow(
              blueDragonTypes: blueTeam.dragonTypes,
              redDragonTypes: redTeam.dragonTypes,
              scale: scale,
            ),
            SizedBox(height: 25 * scale),
            _ObjectiveRow(
              icon: _ObjectiveIcons.elderDragon,
              label: '장로',
              left: '${blueTeam.elders}',
              right: '${redTeam.elders}',
              scale: scale,
            ),
            SizedBox(height: 25 * scale),
            _ObjectiveRow(
              icon: _ObjectiveIcons.baron,
              label: '바론',
              left: '${blueTeam.barons}',
              right: '${redTeam.barons}',
              scale: scale,
            ),
            SizedBox(height: 25 * scale),
            _ObjectiveRow(
              icon: _ObjectiveIcons.turret,
              label: '타워',
              left: '${blueTeam.towers}',
              right: '${redTeam.towers}',
              scale: scale,
            ),
            SizedBox(height: 25 * scale),
            _ObjectiveRow(
              icon: _ObjectiveIcons.inhibitor,
              label: '억제기',
              left: '${blueTeam.inhibitors}',
              right: '${redTeam.inhibitors}',
              scale: scale,
            ),
          ],
        ),
      ),
    );
  }
}

/// 주요 오브젝트·구조물 아이콘 경로 모음.
/// 드래곤 속성별 미니 아이콘은 [dragonAssetFor] 가 담당한다.
class _ObjectiveIcons {
  static const String baron = 'assets/icons/nar-icon-baron.svg';
  static const String dragon = 'assets/icons/nar-icon-dragon.svg';
  static const String elderDragon = 'assets/icons/nar-icon-elder-dragon.svg';
  static const String turret = 'assets/icons/nar-icon-turret.svg';
  static const String inhibitor = 'assets/icons/nar-icon-inhibitor.svg';
}

/// 아이콘·라벨·좌우 카운트를 나란히 놓는 오브젝트 한 줄.
/// 카운트는 항상 라벨에 붙고(안쪽), 아이콘은 바깥쪽 — 좌우 대칭 배치.
class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({
    required this.icon,
    required this.label,
    required this.left,
    required this.right,
    required this.scale,
  });

  final String icon;
  final String label;
  final String left;
  final String right;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final countStyle = TextStyle(
      fontFamily: 'SF Pro',
      fontWeight: FontWeight.w600,
      fontSize: 16 * scale,
      height: 1.55,
      color: const Color(0xFFFFFEFE),
    );
    final iconWidget = SvgPicture.asset(
      icon,
      width: 24 * scale,
      height: 24 * scale,
    );

    // 좌우 블록(아이콘+숫자)을 같은 고정 폭으로 맞춰야 라벨이 실제 화면
    // 정중앙에 온다. 두 블록을 자기 콘텐츠 크기(mainAxisSize.min)로만
    // 두면, 좌우 숫자 자릿수가 다를 때(예: 왼쪽 '10' vs 오른쪽 '5') 블록
    // 폭이 서로 달라져 그 폭 차이만큼 가운데 라벨이 한쪽으로 밀린다.
    const sideWidth = 58.0;
    return Row(
      children: [
        SizedBox(
          width: sideWidth * scale,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              SizedBox(width: 14 * scale),
              Text(left, style: countStyle),
            ],
          ),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w700,
              fontSize: 14 * scale,
              height: 1.55,
              color: AppColors.narText2,
            ),
          ),
        ),
        SizedBox(
          width: sideWidth * scale,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(right, style: countStyle),
              SizedBox(width: 14 * scale),
              iconWidget,
            ],
          ),
        ),
      ],
    );
  }
}

/// 드래곤 종류 미니 아이콘 — 왼쪽(블루팀이 먹은 속성들), 오른쪽(레드팀).
/// [dragonAssetFor] 로 한국어 속성 라벨을 로컬 에셋에 매핑한다.
class _DragonTypesRow extends StatelessWidget {
  const _DragonTypesRow({
    required this.blueDragonTypes,
    required this.redDragonTypes,
    required this.scale,
  });

  final List<String> blueDragonTypes;
  final List<String> redDragonTypes;
  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget chip(String subType) => Image.asset(
      dragonAssetFor(subType),
      width: 20 * scale,
      height: 20 * scale,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            for (var i = 0; i < blueDragonTypes.length; i++) ...[
              if (i > 0) SizedBox(width: 8 * scale),
              chip(blueDragonTypes[i]),
            ],
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < redDragonTypes.length; i++) ...[
              if (i > 0) SizedBox(width: 8 * scale),
              chip(redDragonTypes[i]),
            ],
          ],
        ),
      ],
    );
  }
}
