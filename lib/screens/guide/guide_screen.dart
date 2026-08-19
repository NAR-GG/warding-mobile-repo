import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';
import '../../styles/app_colors.dart';
import 'component/guide_progress_bar.dart';
import 'guide_page_data.dart';

/// 온보딩 사용 가이드 전체화면 캐러셀.
///
/// 장마다 달라지는 것은 [GuidePageData] 로 받고, 여기서는 모든 장에 공통인
/// 배경·상단 헤더·진행바·하단 패널만 그린다.
///
/// 화면은 시안(375×812)의 무대 547 : 패널 265 비율로 나눈다
/// ([guidePanelRatio]). 고정 높이나 상·하한을 두지 않아, 화면이 길든 짧든
/// 두 영역이 차지하는 몫은 어느 기기에서나 같다.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, required this.pages});

  final List<GuidePageData> pages;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final PageController _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index == _current) return;
    setState(() => _current = index);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final scale = media.size.width.clamp(320.0, 430.0) / 375;

    // 무대와 하단 패널을 시안 비율(547 : 265) 그대로 나눈다. 상·하한을 두면
    // 그 구간을 벗어난 기기에서 두 영역의 비율이 시안과 달라지므로 두지 않는다.
    //
    // 비율은 홈 인디케이터를 뺀 높이에 적용한다 — 시안(812)에는 그 영역이
    // 없어서, 화면 전체에 곱하면 패널 안쪽이 인디케이터에 먹혀 시안보다
    // 좁아진다. 인디케이터 몫은 패널 높이에 따로 더해 검정 배경만 그 아래까지
    // 깔리게 한다(패널 내부의 SafeArea 가 콘텐츠를 그만큼 밀어 올린다).
    final bottomInset = media.padding.bottom;
    final designHeight = media.size.height - bottomInset;
    final panelHeight = designHeight * guidePanelRatio + bottomInset;

    return Scaffold(
      backgroundColor: AppColors.narGray500,
      body: Stack(
        children: [
          // 무대(앱 화면 목업 + 말풍선). 페이지마다 갈아끼운다.
          Positioned.fill(
            bottom: panelHeight,
            child: Stack(
              children: [
                // 시안의 rgba(112,72,232,0.25) 오버레이.
                const Positioned.fill(
                  child: ColoredBox(color: AppColors.narGuideOverlay),
                ),
                PageView.builder(
                  controller: _controller,
                  onPageChanged: _onPageChanged,
                  itemCount: widget.pages.length,
                  itemBuilder: (context, index) =>
                      widget.pages[index].stageBuilder(context, scale),
                ),
              ],
            ),
          ),
          // 하단 패널 — 진행바 + 현재 장의 설명.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: panelHeight,
            child: _BottomPanel(
              page: widget.pages[_current],
              current: _current,
              total: widget.pages.length,
              scale: scale,
            ),
          ),
          // 상단 헤더 — 뒤로가기 + '가이드 종료하기'. 상태바 위로 겹치지 않게 띄운다.
          Positioned(
            left: 0,
            right: 0,
            top: media.padding.top,
            child: _GuideHeader(
              label: l.guideExit,
              onBack: () => Navigator.of(context).maybePop(),
              onExit: () => Navigator.of(context).maybePop(),
              scale: scale,
            ),
          ),
        ],
      ),
    );
  }
}

/// 상단 헤더 — 좌측 뒤로가기 아이콘, 우측 '가이드 종료하기'.
class _GuideHeader extends StatelessWidget {
  const _GuideHeader({
    required this.label,
    required this.onBack,
    required this.onExit,
    required this.scale,
  });

  final String label;
  final VoidCallback onBack;
  final VoidCallback onExit;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60 * scale,
      child: Padding(
        padding: EdgeInsets.only(left: 4 * scale, right: 8 * scale),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: SizedBox(
                width: 44 * scale,
                height: 44 * scale,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/chevron-left.svg',
                    width: 24 * scale,
                    height: 24 * scale,
                    colorFilter: const ColorFilter.mode(
                      AppColors.narBgContent,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onExit,
              child: Container(
                height: 44 * scale,
                padding: EdgeInsets.symmetric(horizontal: 18 * scale),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 14 * scale,
                    color: AppColors.narBgContent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 하단 검정 패널 — 진행바 + 섹션 아이콘·라벨 + 안내 문구 + 페이지 표시.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.page,
    required this.current,
    required this.total,
    required this.scale,
  });

  final GuidePageData page;

  /// 0-based 현재 장 — 캐러셀 전체(6장) 기준. 점 진행바는 항상 전체
  /// 장수만큼 찍고 현재 위치만 하이라이트한다.
  final int current;
  final int total;
  final double scale;

  @override
  Widget build(BuildContext context) {
    // 페이지 숫자('1/2' 등)는 전체 장 수가 아니라 같은 섹션 안에서의
    // 순번/장수를 쓴다 ('마이 구독' 1/2·2/2, '마이 페이지' 1/3·2/3·3/3).
    // 섹션이 한 장뿐이면(예: 위젯 소개) [sectionIndex]·[sectionTotal] 이
    // null 이라 숫자 표시를 그리지 않는다. 점 진행바는 이와 무관하게 항상
    // 전체 6장 기준으로 그린다.
    final sectionIndex = page.sectionIndex;
    final sectionTotal = page.sectionTotal;
    final showPageNumber = sectionIndex != null && sectionTotal != null;

    return ColoredBox(
      color: AppColors.narBgContent,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(10 * scale),
              child: Center(
                child: GuideProgressBar(
                  count: total,
                  current: current,
                  scale: scale,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * scale,
                  vertical: 10 * scale,
                ),
                // 설명 묶음을 진행바 바로 아래에 붙인다. 남는 높이는 아래에
                // 두어, 기기가 길어져도 설명이 캐러셀에서 멀어지지 않는다.
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IntrinsicHeight(
                    child: Row(
                      // 페이지 표시는 시안대로 설명 문단의 아래끝에 맞춘다.
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _PanelText(page: page, scale: scale),
                        ),
                        if (showPageNumber) ...[
                          SizedBox(width: 16 * scale),
                          Text(
                            '$sectionIndex/$sectionTotal',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              fontSize: 14 * scale,
                              height: 1.55,
                              color: AppColors.narGuideAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 패널 좌측 텍스트 묶음 — 아이콘·섹션명, 굵은 안내, 보조 설명.
class _PanelText extends StatelessWidget {
  const _PanelText({required this.page, required this.scale});

  final GuidePageData page;
  final double scale;

  @override
  Widget build(BuildContext context) {
    // 패널 높이가 화면 비율로 정해지므로, 짧은 기기에서는 이 문단이 들어갈
    // 자리가 시안보다 좁다. 그때는 잘라 내거나 글자를 줄이는 대신 스크롤한다 —
    // 폭은 그대로 두어야 문구가 시안과 같은 지점에서 줄바꿈된다.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 아이콘이 없는 장(예: 위젯 소개)은 라벨만 그린다.
              if (page.sectionIcon != null) ...[
                SvgPicture.asset(
                  page.sectionIcon!,
                  width: 30 * scale,
                  height: 30 * scale,
                  colorFilter: const ColorFilter.mode(
                    AppColors.narGuideAccent,
                    BlendMode.srcIn,
                  ),
                ),
                SizedBox(height: 4 * scale),
              ],
              Text(
                page.sectionLabel,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 16 * scale,
                  height: 1.61,
                  letterSpacing: -0.16 * scale,
                  color: AppColors.narGuideAccent,
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),
          Text(
            page.headline,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 20 * scale,
              height: 1.55,
              color: AppColors.narText,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            page.description,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 14 * scale,
              height: 1.55,
              color: AppColors.narText,
            ),
          ),
          if (page.footnote != null) ...[
            SizedBox(height: 4 * scale),
            Text(
              page.footnote!,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 10 * scale,
                height: 1.55,
                color: AppColors.narText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
