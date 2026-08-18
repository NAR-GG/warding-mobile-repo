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
    required this.headline,
    required this.description,
    this.footnote,
    required this.stageBuilder,
  });

  /// 하단 패널 상단의 섹션 아이콘 asset 경로. 예) 'assets/icons/empty-stars.svg'.
  /// null 이면 아이콘 없이 [sectionLabel] 만 그린다.
  final String? sectionIcon;

  /// 아이콘 아래 섹션명. 예) '마이 구독'.
  final String sectionLabel;

  /// 굵은 안내 문구(20px). 예) '좋아하는 팀 경기, 선수 솔랭 놓치지 않고 챙겨보세요'.
  final String headline;

  /// 보조 설명(14px). 예) '온보딩에서 선택한 팀, 선수가 자동으로 구독돼요.'.
  final String description;

  /// 설명 아래 작은 주석(10px). 예) 연출 이미지 고지. 없으면 그리지 않는다.
  final String? footnote;

  /// 화면 위쪽 영역(앱 화면 목업 + 말풍선). 받은 [scale] 을 내부 수치에 곱한다.
  final Widget Function(BuildContext context, double scale) stageBuilder;
}
