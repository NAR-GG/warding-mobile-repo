import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'nar_filter_sheet.dart';

/// 앱 공용 검색 선택 박스.
///
/// 닫힌 상태는 [value](없으면 [hint])를 보여주는 높이 38 의 박스다.
/// 탭하면 박스 테두리가 빨갛게(nar_red_500) 바뀌고 화살표가 위로 향하며,
/// 화면 아래에서 검색창 + 항목 리스트를 담은 바텀시트가 올라온다.
/// 검색창 입력은 [options] 를 실시간으로 거르고,
/// 항목을 고르면 [onChanged] 호출 후 시트가 닫힌다.
///
/// 시안(폭 375) 기준 수치를 쓰므로 [scale] 을 받아 내부 수치에 곱한다.
class SearchSelectBox extends StatefulWidget {
  const SearchSelectBox({
    super.key,
    required this.options,
    required this.onChanged,
    this.value,
    this.hint,
    this.searchHint,
    this.sheetTitle,
    this.labelBuilder,
    this.scale = 1,
  });

  /// 선택 가능한 항목들.
  final List<String> options;

  /// 항목 선택 콜백.
  final ValueChanged<String> onChanged;

  /// 현재 선택된 항목. null 이면 박스에 [hint] 를 표시한다.
  final String? value;

  /// [value] 가 없을 때 박스에 표시할 안내 문구. null 이면 l10n 기본값([AppLocalizations.selectHint])을 사용한다.
  final String? hint;

  /// 시트 검색창 placeholder. null 이면 l10n 기본값([AppLocalizations.searchInputHint])을 사용한다.
  final String? searchHint;

  /// 시트 헤더 가운데 타이틀. null 이면 [hint] 를 쓰고, 그것도 없으면 헤더를
  /// 빈 타이틀로 그린다(닫기 버튼은 항상 표시).
  final String? sheetTitle;

  /// 옵션 문자열을 표시용 라벨로 변환. null 이면 옵션 문자열 그대로 표시.
  final String Function(String)? labelBuilder;

  /// 비율 스케일. 시안(폭 375) 기준 수치에 곱한다.
  final double scale;

  @override
  State<SearchSelectBox> createState() => _SearchSelectBoxState();
}

class _SearchSelectBoxState extends State<SearchSelectBox> {
  /// 시트가 떠 있는지. 박스 테두리·화살표 모양에 쓴다.
  bool _open = false;

  /// 항목 선택 시트를 띄운다. 고른 값이 있으면 [SearchSelectBox.onChanged] 로 넘긴다.
  Future<void> _openSheet() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _open = true);
    final selected = await showAppBottomSheet<String>(
      context: context,
      child: _SearchSelectSheet(
        options: widget.options,
        value: widget.value,
        title: widget.sheetTitle ?? widget.hint ?? '',
        searchHint: widget.searchHint ?? l.searchInputHint,
        labelBuilder: widget.labelBuilder,
        scale: widget.scale,
      ),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _buildBox(widget.scale, widget.hint ?? l.selectHint);
  }

  /// 닫힌/열린 상태 박스. 높이 38, 좌우 텍스트·화살표 양끝 정렬.
  ///
  /// 테두리는 [Container.foregroundDecoration] 으로 그려, 1px 테두리가
  /// 내부 공간을 깎지 않게 한다(시안의 38·padding 8 을 그대로 유지).
  Widget _buildBox(double scale, String resolvedHint) {
    final radius = BorderRadius.circular(10 * scale);
    return GestureDetector(
      onTap: _openSheet,
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
            // 시트가 떠 있으면 빨간 테두리(nar_red_500), 아니면 nar_line_2.
            color: _open ? AppColors.narRed500 : AppColors.narLine2,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value != null
                    ? (widget.labelBuilder?.call(widget.value!) ?? widget.value!)
                    : resolvedHint,
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
}

/// [SearchSelectBox] 가 띄우는 바텀시트 본문 — 검색창 + 항목 리스트.
///
/// 고른 항목을 [Navigator.pop] 으로 돌려준다(취소하면 null).
class _SearchSelectSheet extends StatefulWidget {
  const _SearchSelectSheet({
    required this.options,
    required this.value,
    required this.title,
    required this.searchHint,
    required this.labelBuilder,
    required this.scale,
  });

  final List<String> options;
  final String? value;
  final String title;
  final String searchHint;
  final String Function(String)? labelBuilder;
  final double scale;

  @override
  State<_SearchSelectSheet> createState() => _SearchSelectSheetState();
}

class _SearchSelectSheetState extends State<_SearchSelectSheet> {
  /// 항목 한 줄 높이(시안 기준). 리스트 높이를 미리 잡는 데 쓴다.
  static const double _optionHeight = 46;

  final TextEditingController _searchController = TextEditingController();

  /// 검색어. 비교는 소문자로 한다.
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final media = MediaQuery.of(context);
    // 리스트 높이는 전체 항목 수로 한 번 정하고 검색 중에도 그대로 둔다.
    // 걸러진 개수를 따라가면 타이핑할 때마다 시트가 늘었다 줄었다 해서
    // 눈이 피로하고, '검색 결과 없음'에서 확 쪼그라든다.
    //
    // 전체가 다 들어갈 만큼만 필요하면 그 높이로, 그보다 많으면 화면 절반까지만
    // 쓰고 안에서 스크롤한다. 항목이 아주 적어도 안내 문구가 들어갈 만큼은 둔다.
    final maxListHeight = media.size.height * 0.5;
    final listHeight = (widget.options.length * _optionHeight * scale)
        .clamp(_optionHeight * 2 * scale, maxListHeight);
    return Padding(
      // 검색창에 포커스가 가면 키보드가 시트를 가리므로 그만큼 밀어 올린다.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더 — 가운데 타이틀 + 우측 닫기. 항목을 고르면 바로 적용·닫힘이라
          // 되돌릴 상태가 없어(마이구독 선수 시트와 달리) 초기화 버튼은 없다.
          NarSheetHeader(
            title: widget.title,
            scale: scale,
            showReset: false,
            // 아래에 검색창이 바로 이어져 기본값(24)이면 위가 허해 보인다.
            verticalPadding: 12,
            onClose: () => Navigator.of(context).pop(),
          ),
          _buildSearchField(scale),
          SizedBox(height: 10 * scale), // 검색창 ↔ 리스트 간격
          SizedBox(
            height: listHeight,
            child: _filtered.isEmpty
                ? _buildEmpty(scale)
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) =>
                        _buildOption(_filtered[i], scale),
                  ),
          ),
        ],
      ),
    );
  }

  /// 시트 상단 검색창. 높이 38 — 시트에서는 손가락으로 눌러야 해 조금 키웠다.
  Widget _buildSearchField(double scale) {
    return Container(
      height: 38 * scale,
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

  /// 검색 결과가 없을 때. 리스트와 같은 고정 높이를 채우므로 가운데 정렬한다.
  Widget _buildEmpty(double scale) {
    return Center(
      child: Text(
        AppLocalizations.of(context)!.noSearchResults,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w400,
          fontSize: 14 * scale,
          color: AppColors.narTextTertiarySub,
        ),
      ),
    );
  }

  /// 항목 한 줄. 아래 0.5px 구분선.
  /// 선택된 항목은 빨간 글씨, 오른쪽 끝에 체크 아이콘이 뜬다.
  ///
  /// 드롭다운일 때(높이 30)보다 키웠다 — 시트는 손가락으로 누르는 영역이라
  /// 최소 44 는 되어야 오조작이 없다.
  Widget _buildOption(String option, double scale) {
    final selected = option == widget.value;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(option),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _optionHeight * scale,
        padding: EdgeInsets.symmetric(horizontal: 8 * scale),
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
                widget.labelBuilder?.call(option) ?? option,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 16 * scale,
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
                width: 18 * scale,
                height: 18 * scale,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
