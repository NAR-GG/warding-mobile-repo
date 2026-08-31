import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 경기 상세 — 챔피언픽 탭 맨 아래의 "Objectives" 섹션.
///
/// **실데이터 없음.** 드래곤·바론·타워·억제기 획득 수는 지금 어떤 API
/// 응답에도 없어서, 시안의 목업 숫자를 위치 그대로 하드코딩해 UI를 먼저
/// 완성한다. 오브젝트 아이콘은 받은 샘플 이미지([_ObjectiveIcons])를
/// 그대로 쓴다. 전령·공허유충·타워 플레이트 행은 요청에 따라 뺐다.
/// 백엔드가 값을 내려주기 시작하면 이 숫자를 실제 데이터 바인딩으로
/// 바꿔야 한다.
class MatchDetailObjectivesSection extends StatelessWidget {
  const MatchDetailObjectivesSection({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.narBgContent,
      padding: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 80 * scale),
      alignment: Alignment.topCenter,
      child: Container(
        width: 328 * scale,
        padding: EdgeInsets.symmetric(
          vertical: 12 * scale,
          horizontal: 16 * scale,
        ),
        child: Column(
          children: [
            _DividedLabel(label: '주요 오브젝트', scale: scale),
            SizedBox(height: 25 * scale),
            _ObjectiveRow(
              icon: _ObjectiveIcons.dragon,
              label: '드래곤',
              left: '4',
              right: '1',
              scale: scale,
            ),
            SizedBox(height: 15 * scale),
            _DragonTypesRow(scale: scale),
            SizedBox(height: 25 * scale),
            _ObjectiveRow(
              icon: _ObjectiveIcons.elderDragon,
              label: '장로',
              left: '0',
              right: '1',
              scale: scale,
            ),
            SizedBox(height: 25 * scale),
            _ObjectiveRow(
              icon: _ObjectiveIcons.baron,
              label: '바론',
              left: '1',
              right: '1',
              scale: scale,
            ),
            SizedBox(height: 25 * scale),
            _DividedLabel(label: '구조물', scale: scale),
            SizedBox(height: 25 * scale),
            _ObjectiveRow(
              icon: _ObjectiveIcons.turret,
              label: '타워',
              left: '10',
              right: '5',
              scale: scale,
            ),
            SizedBox(height: 25 * scale),
            _ObjectiveRow(
              icon: _ObjectiveIcons.inhibitor,
              label: '억제기',
              left: '2',
              right: '0',
              scale: scale,
            ),
          ],
        ),
      ),
    );
  }
}

/// 받은 오브젝트 샘플 아이콘 경로 모음.
class _ObjectiveIcons {
  static const String baron = 'assets/images/baron.png';
  static const String dragon = 'assets/images/dragon.png';
  static const String elderDragon = 'assets/images/elder-dragon.png';
  static const String infernalDragon = 'assets/images/infernal-dragon.png';
  static const String mountainDragon = 'assets/images/mountain-dragon.png';
  static const String oceanDragon = 'assets/images/ocean-dragon.png';
  static const String cloudDragon = 'assets/images/cloud-dragon.png';
  static const String hextechDragon = 'assets/images/hextech-dragon.png';
  static const String turret = 'assets/images/turret.png';
  static const String inhibitor = 'assets/images/inhibitor.png';
}

/// "──── 라벨 ────" 형태의 구분선 라벨.
class _DividedLabel extends StatelessWidget {
  const _DividedLabel({required this.label, required this.scale});

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: AppColors.narText2, height: 1, thickness: 1),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10 * scale),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w400,
              fontSize: 14 * scale,
              height: 1.55,
              color: AppColors.narText2,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: AppColors.narText2, height: 1, thickness: 1),
        ),
      ],
    );
  }
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
    final iconWidget = Image.asset(icon, width: 24 * scale, height: 24 * scale);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            SizedBox(width: 14 * scale),
            Text(left, style: countStyle),
          ],
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w700,
            fontSize: 14 * scale,
            height: 1.55,
            color: const Color(0xFFFCFDFE),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(right, style: countStyle),
            SizedBox(width: 14 * scale),
            iconWidget,
          ],
        ),
      ],
    );
  }
}

/// 드래곤 종류 미니 아이콘 — 왼쪽 4개(좌측 팀이 먹은 드래곤 종류: 인페르날·
/// 마운틴·오션·헥스텍), 오른쪽 1개(우측 팀: 클라우드). 실제로 어느 팀이
/// 어떤 속성을 먹었는지는 데이터가 없어 받은 샘플 아이콘을 그대로 나열한
/// 목업이다.
class _DragonTypesRow extends StatelessWidget {
  const _DragonTypesRow({required this.scale});

  final double scale;

  static const List<String> _left = [
    _ObjectiveIcons.infernalDragon,
    _ObjectiveIcons.mountainDragon,
    _ObjectiveIcons.oceanDragon,
    _ObjectiveIcons.hextechDragon,
  ];

  @override
  Widget build(BuildContext context) {
    Widget chip(String asset) =>
        Image.asset(asset, width: 20 * scale, height: 20 * scale);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            for (var i = 0; i < _left.length; i++) ...[
              if (i > 0) SizedBox(width: 8 * scale),
              chip(_left[i]),
            ],
          ],
        ),
        chip(_ObjectiveIcons.cloudDragon),
      ],
    );
  }
}
