import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';

/// 경기 상세 — 챔피언픽 탭 맨 아래의 "Team Summary" 섹션.
///
/// **실데이터 없음.** 팀 로고 이미지·킬 합계·데미지·시야점수·골드는 지금
/// 어떤 API 응답에도 없어서, 시안의 목업 텍스트("DNS", "T1", "17", "25",
/// "67,200" 등)를 위치 그대로 하드코딩해 UI를 먼저 완성한다. 팀 로고는
/// 이미지 자산이 없어 회색 placeholder 로 남긴다. 시야·골드 아이콘은
/// 받은 [ward.svg]/[gold.svg] 를 그대로 쓴다. 두 킬 숫자 사이의
/// "Vector"(시안 원본은 이미지 없이 흰 도형만 지정) 는 대응하는 자산이
/// 없어 얇은 흰 막대로 근사한다.
/// 백엔드가 값을 내려주기 시작하면 이 텍스트들을 실제 데이터 바인딩으로
/// 바꿔야 한다.
class MatchDetailTeamSummarySection extends StatelessWidget {
  const MatchDetailTeamSummarySection({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.narBgContent,
      padding: EdgeInsets.fromLTRB(
        10 * scale,
        4 * scale,
        10 * scale,
        36 * scale,
      ),
      child: Column(
        children: [
          _TeamLogosKillsRow(scale: scale),
          SizedBox(height: 17 * scale),
          SizedBox(
            width: double.infinity,
            child: _DamageBarBox(scale: scale),
          ),
          SizedBox(height: 17 * scale),
          _VisionGoldRow(scale: scale),
        ],
      ),
    );
  }
}

class _TeamLogosKillsRow extends StatelessWidget {
  const _TeamLogosKillsRow({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 331 * scale,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TeamLogoBlock(code: 'DNS', scale: scale),
          _KillsBlock(kill1: '17', kill2: '25', scale: scale),
          _TeamLogoBlock(code: 'T1', scale: scale),
        ],
      ),
    );
  }
}

class _TeamLogoBlock extends StatelessWidget {
  const _TeamLogoBlock({required this.code, required this.scale});

  final String code;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 49 * scale,
          height: 49 * scale,
          padding: EdgeInsets.all(4 * scale),
          decoration: BoxDecoration(
            color: AppColors.narBgTertiary,
            borderRadius: BorderRadius.circular(10 * scale),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.narDark600,
              borderRadius: BorderRadius.circular(6 * scale),
            ),
          ),
        ),
        SizedBox(
          width: 59 * scale,
          child: Text(
            code,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 16 * scale,
              height: 19 / 16,
              color: AppColors.narText,
            ),
          ),
        ),
      ],
    );
  }
}

class _KillsBlock extends StatelessWidget {
  const _KillsBlock({
    required this.kill1,
    required this.kill2,
    required this.scale,
  });

  final String kill1;
  final String kill2;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final killStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 28 * scale,
      height: 1.3,
      color: const Color(0xFFFCFDFE),
    );
    return SizedBox(
      height: 36 * scale,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(kill1, style: killStyle),
          SizedBox(width: 16 * scale),
          SizedBox(
            width: 35 * scale,
            height: 15.71 * scale,
            child: Center(
              child: Container(
                width: 35 * scale,
                height: 3 * scale,
                decoration: BoxDecoration(
                  color: AppColors.narText,
                  borderRadius: BorderRadius.circular(2 * scale),
                ),
              ),
            ),
          ),
          SizedBox(width: 16 * scale),
          Text(kill2, style: killStyle),
        ],
      ),
    );
  }
}

Widget _diffBadge(String text, Color background, double scale) {
  // Container 에 alignment 를 주면 폭이 정해지지 않은 한 부모가 준 가로
  // 제약을 꽉 채우려 든다(Positioned(left:0,right:0) 라 그 제약이 항상
  // bounded). IntrinsicWidth 로 감싸 텍스트+패딩만큼만 차지하게 한다.
  return IntrinsicWidth(
    child: Container(
      height: 19 * scale,
      padding: EdgeInsets.symmetric(horizontal: 3 * scale),
      alignment: Alignment.center,
      color: background,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w500,
          fontSize: 12 * scale,
          height: 1.55,
          color: AppColors.narText,
        ),
      ),
    ),
  );
}

class _DamageBarBox extends StatelessWidget {
  const _DamageBarBox({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 14 * scale,
      height: 1.55,
      color: const Color(0xFFFCFDFE),
    );
    final percentStyle = TextStyle(
      fontFamily: 'SF Pro',
      fontWeight: FontWeight.w500,
      fontSize: 12 * scale,
      height: 1.55,
      color: const Color(0xFFFCFDFE),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: 4 * scale,
            horizontal: 16 * scale,
          ),
          child: Column(
            children: [
              // 'SF Pro' 폴백 렌더링 폭이 시안 수치보다 넓어질 수 있어
              // 좁은 화면(320~375)에서 이 줄이 overflow 할 수 있다 — 안
              // 맞을 때만 살짝 줄어들게 한다.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('67,200', style: labelStyle),
                    SizedBox(width: 8 * scale),
                    Text(
                      'Total Damage',
                      style: labelStyle.copyWith(color: AppColors.narText2),
                    ),
                    SizedBox(width: 8 * scale),
                    Text('68,200', style: labelStyle),
                  ],
                ),
              ),
              SizedBox(height: 4 * scale),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 7 * scale,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 153,
                        child: Container(color: const Color(0xCC228BE6)),
                      ),
                      Expanded(
                        flex: 171,
                        child: Container(color: const Color(0xCCFA5252)),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 4 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('60.2%', style: percentStyle),
                  Text('39.8%', style: percentStyle),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 2 * scale,
          left: 0,
          right: 0,
          child: Center(
            child: _diffBadge('+1K', const Color(0x80FA5252), scale),
          ),
        ),
      ],
    );
  }
}

class _VisionGoldRow extends StatelessWidget {
  const _VisionGoldRow({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final statStyle = TextStyle(
      fontFamily: 'SF Pro Display',
      fontWeight: FontWeight.w500,
      fontSize: 16 * scale,
      height: 1.5,
      color: const Color(0xFFFCFDFE),
    );
    final ward = SvgPicture.asset(
      'assets/icons/ward.svg',
      width: 20 * scale,
      height: 16 * scale,
    );
    final gold = SvgPicture.asset(
      'assets/icons/gold.svg',
      width: 16 * scale,
      height: 16 * scale,
    );

    return SizedBox(
      width: 333 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ward,
                      SizedBox(width: 7 * scale),
                      Text('411', style: statStyle),
                    ],
                  ),
                  SizedBox(height: 9 * scale),
                  Row(
                    children: [
                      gold,
                      SizedBox(width: 7 * scale),
                      Text('83.6K', style: statStyle),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('347', style: statStyle),
                      SizedBox(width: 7 * scale),
                      ward,
                    ],
                  ),
                  SizedBox(height: 9 * scale),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('79.4K', style: statStyle),
                      SizedBox(width: 7 * scale),
                      gold,
                    ],
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 35.2 * scale,
            left: 0,
            right: 0,
            child: Center(
              child: _diffBadge('+11.2K', const Color(0x99228BE6), scale),
            ),
          ),
        ],
      ),
    );
  }
}
