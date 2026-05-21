import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';

/// 앱 공용 검색 선택 박스.
///
/// 닫힌 상태는 [value](없으면 [hint])를 보여주는 높이 38 의 박스다.
/// 탭하면 박스 테두리가 빨갛게(nar_red_500) 바뀌고 화살표가 위로 향하며,
/// 아래 9px 간격으로 박스와 같은 폭의 드롭다운이 [OverlayPortal] 로 떠오른다.
/// 드롭다운은 화면 위에 겹쳐 그려져 아래 콘텐츠를 밀어내지 않고,
/// 박스를 [CompositedTransformFollower] 로 따라다닌다.
/// 드롭다운 바깥을 탭하면 닫히고, 상단 검색창 입력은 [options] 를
/// 실시간으로 거른다. 항목을 고르면 [onChanged] 호출 후 닫힌다.
///
/// 시안(폭 375) 기준 수치를 쓰므로 [scale] 을 받아 내부 수치에 곱한다.
class SearchSelectBox extends StatefulWidget {
  const SearchSelectBox({
    super.key,
    required this.options,
    required this.onChanged,
    this.value,
    this.hint = '선택',
    this.searchHint = '검색어를 입력...',
    this.scale = 1,
  });

  /// 선택 가능한 항목들.
  final List<String> options;

  /// 항목 선택 콜백.
  final ValueChanged<String> onChanged;

  /// 현재 선택된 항목. null 이면 박스에 [hint] 를 표시한다.
  final String? value;

  /// [value] 가 없을 때 박스에 표시할 안내 문구.
  final String hint;

  /// 드롭다운 검색창 placeholder.
  final String searchHint;

  /// 비율 스케일. 시안(폭 375) 기준 수치에 곱한다.
  final double scale;

  @override
  State<SearchSelectBox> createState() => _SearchSelectBoxState();
}

class _SearchSelectBoxState extends State<SearchSelectBox> {
  final TextEditingController _searchController = TextEditingController();

  /// 드롭다운 오버레이 표시 컨트롤러.
  final OverlayPortalController _portalController = OverlayPortalController();

  /// 박스 ↔ 드롭다운 위치를 잇는 링크. 박스가 움직이면 드롭다운이 따라온다.
  final LayerLink _link = LayerLink();

  /// 드롭다운 열림 여부. 박스 테두리·화살표 모양에 쓴다.
  bool _open = false;

  /// 검색어. 비교는 소문자로 한다.
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 드롭다운 토글.
  void _toggle() {
    if (_open) {
      _close();
    } else {
      setState(() => _open = true);
      _portalController.show();
    }
  }

  /// 드롭다운을 닫고 검색어를 비운다.
  void _close() {
    if (!_open) return;
    _portalController.hide();
    setState(() {
      _open = false;
      _query = '';
      _searchController.clear();
    });
  }

  /// 항목 선택 → 콜백 호출 후 드롭다운을 닫는다.
  void _select(String option) {
    widget.onChanged(option);
    _close();
  }

  /// 검색어로 거른 항목들.
  List<String> get _filtered {
    if (_query.isEmpty) return widget.options;
    final q = _query.toLowerCase();
    return [
      for (final o in widget.options)
        if (o.toLowerCase().contains(q)) o,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (context) => _buildOverlay(scale),
        child: _buildBox(scale),
      ),
    );
  }

  /// 오버레이 콘텐츠: 바깥 탭을 받는 배리어 + 박스를 따라다니는 드롭다운.
  Widget _buildOverlay(double scale) {
    return Stack(
      children: [
        // 드롭다운 바깥 아무 곳이나 탭하면 닫힌다.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
        // 박스 왼쪽 아래 모서리에 9px 간격으로 드롭다운을 붙인다.
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: Offset(0, 9 * scale),
          child: Material(
            type: MaterialType.transparency,
            child: _buildDropdown(scale),
          ),
        ),
      ],
    );
  }

  /// 닫힌/열린 상태 박스. 높이 38, 좌우 텍스트·화살표 양끝 정렬.
  ///
  /// 테두리는 [Container.foregroundDecoration] 으로 그려, 1px 테두리가
  /// 내부 공간을 깎지 않게 한다(시안의 38·padding 8 을 그대로 유지).
  Widget _buildBox(double scale) {
    final radius = BorderRadius.circular(10 * scale);
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 38 * scale,
        padding: EdgeInsets.symmetric(
          vertical: 8 * scale,
          horizontal: 14 * scale,
        ),
        decoration: BoxDecoration(
          color: AppColors.narBgSecondary, // #1A1B1E
          borderRadius: radius,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            // 열린 상태면 빨간 테두리(nar_red_500), 아니면 nar_line_2.
            color: _open ? AppColors.narRed500 : AppColors.narLine2,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value ?? widget.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w400,
                  fontSize: 14 * scale,
                  height: 1.55, // 155%
                  letterSpacing: 0,
                  color: AppColors.narTextSecondary, // #FFFFFF
                ),
              ),
            ),
            SizedBox(width: 8 * scale),
            SvgPicture.asset(
              _open
                  ? 'assets/icons/chevron-up.svg'
                  : 'assets/icons/chevron-down.svg',
              width: 18 * scale,
              height: 18 * scale,
            ),
          ],
        ),
      ),
    );
  }

  /// 드롭다운 패널. 폭은 셀렉트 박스에 맞추고 높이 191,
  /// 상단 검색창 + 항목 리스트.
  Widget _buildDropdown(double scale) {
    // 셀렉트 박스(LayerLink 의 leader)와 같은 폭으로 그린다.
    final width = _link.leaderSize?.width ?? 210 * scale;
    return Container(
      width: width,
      height: 191 * scale,
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgSecondary, // #1A1B1E
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: AppColors.narLine2, width: 1), // nar_line_2
        boxShadow: const [
          BoxShadow(
            color: AppColors.narSearchSelectShadow, // #0000000A
            offset: Offset(0, 1),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSearchField(scale),
          SizedBox(height: 5 * scale), // 검색창 ↔ 리스트 간격 5
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _filtered.length,
              itemBuilder: (context, i) => _buildOption(_filtered[i], scale),
            ),
          ),
        ],
      ),
    );
  }

  /// 드롭다운 상단 검색창. 높이 35, 왼쪽 텍스트 · 오른쪽 검색 아이콘.
  Widget _buildSearchField(double scale) {
    return Container(
      height: 35 * scale,
      padding: EdgeInsets.symmetric(horizontal: 13 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgSecondary, // #1A1B1E
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: AppColors.narLine, width: 1), // nar_line
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              cursorColor: AppColors.narRed500,
              cursorWidth: 1.5,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w400,
                fontSize: 14 * scale,
                height: 1.55, // 155%
                letterSpacing: 0,
                color: AppColors.narTextSecondary, // #FFFFFF
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: widget.searchHint,
                hintStyle: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w400,
                  fontSize: 14 * scale,
                  height: 1.55, // 155%
                  letterSpacing: 0,
                  color: AppColors.narTextTertiarySub, // #A6A7AB
                ),
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          SvgPicture.asset(
            'assets/icons/search.svg',
            width: 15 * scale,
            height: 15 * scale,
          ),
        ],
      ),
    );
  }

  /// 드롭다운 항목 한 줄. 높이 30, 좌우 패딩 18·7, 아래 0.5px 구분선.
  /// 선택된 항목은 빨간 글씨, 오른쪽 끝에 체크 아이콘이 뜬다.
  Widget _buildOption(String option, double scale) {
    final selected = option == widget.value;
    return GestureDetector(
      onTap: () => _select(option),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 30 * scale,
        padding: EdgeInsets.only(left: 18 * scale, right: 7 * scale),
        decoration: const BoxDecoration(
          border: Border(
            // 줄마다 아래쪽 0.5px 구분선 (#495057).
            bottom: BorderSide(color: AppColors.narLine2, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w400,
                  fontSize: 14 * scale,
                  height: 1.55, // 155%
                  letterSpacing: 0,
                  color: selected
                      ? AppColors.narRed500 // 선택됨
                      : AppColors.narTextSecondary, // #FFFFFF
                ),
              ),
            ),
            // 선택된 항목만 맨 오른쪽에 체크 표시.
            if (selected) ...[
              SizedBox(width: 8 * scale),
              SvgPicture.asset(
                'assets/icons/check.svg', // 이미 #FF6B6B 라 색 보정 불필요
                width: 16 * scale,
                height: 16 * scale,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
