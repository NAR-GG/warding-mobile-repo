import 'package:flutter/widgets.dart';

/// 시안(375×812)에서 화면을 나눈 높이. 위쪽 무대와 아래 설명 패널.
///
/// 기기 높이가 달라도 두 영역이 시안과 같은 비율로 보이도록, 실제 높이는
/// 이 값들의 비율로 계산한다(고정 px 나 상·하한을 쓰지 않는다).
const double guideDesignWidth = 375;
const double guideStageDesignHeight = 547;
const double guidePanelDesignHeight = 265;

/// 화면 높이에서 아래 설명 패널이 차지하는 몫.
const double guidePanelRatio =
    guidePanelDesignHeight / (guideStageDesignHeight + guidePanelDesignHeight);

/// 가이드 한 장의 내용.
///
/// 공용 뼈대([GuideScreen])가 배경·헤더·진행바·하단 패널을 그리고, 장마다
/// 달라지는 것만 여기에 담는다.
class GuidePageData {
  const GuidePageData({
    this.sectionIcon,
    required this.sectionLabel,
    this.sectionIndex,
    this.sectionTotal,
    required this.headline,
    required this.description,
    this.footnote,
    required this.stageBuilder,
  }) : assert(
         (sectionIndex == null) == (sectionTotal == null),
         'sectionIndex·sectionTotal 은 함께 주거나 함께 비운다.',
       );

  /// 하단 패널 상단의 섹션 아이콘 asset 경로. 예) 'assets/icons/empty-stars.svg'.
  /// null 이면 아이콘 없이 [sectionLabel] 만 그린다.
  final String? sectionIcon;

  /// 아이콘 아래 섹션명. 예) '마이 구독'.
  final String sectionLabel;

  /// 같은 섹션 안에서 이 장의 1-based 순번. 예) '마이 구독' 2장 중 1장이면 1.
  ///
  /// 진행바·페이지 표시는 전체 장 수가 아니라 이 섹션 안에서의 순번/총
  /// 장수를 보여준다. [sectionTotal] 과 함께 null 이면 진행 표시 자체를
  /// 그리지 않는다(섹션이 한 장뿐이라 진행률이 의미 없는 경우).
  final int? sectionIndex;

  /// 같은 섹션에 속한 전체 장 수.
  final int? sectionTotal;

  /// 굵은 안내 문구(20px). 예) '좋아하는 팀 경기, 선수 솔랭 놓치지 않고 챙겨보세요'.
  final String headline;

  /// 보조 설명(14px). 예) '온보딩에서 선택한 팀, 선수가 자동으로 구독돼요.'.
  final String description;

  /// 설명 아래 작은 주석(10px). 예) 연출 이미지 고지. 없으면 그리지 않는다.
  final String? footnote;

  /// 화면 위쪽 영역(앱 화면 목업 + 말풍선). 받은 [scale] 을 내부 수치에 곱한다.
  final Widget Function(BuildContext context, double scale) stageBuilder;
}
