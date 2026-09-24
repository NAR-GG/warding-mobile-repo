import 'package:flutter/material.dart';

import '../../components/nar_chip_multi_select.dart';
import '../../components/nar_detail_header.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/my_players/my_players_viewmodel.dart';
import 'component/my_player_tile.dart';

/// 내 선수(구독 전체) 화면 — 홈 "구독 N명 전체"의 목적지.
///
/// 구독 100명 기준으로 그린다: 검색줄과 팀 필터로 좁히고, 상태별로
/// 묶는다(지금 솔랭 중 / 오늘 경기함 / 오늘 소식 없음). 소식 없는 선수는
/// "N명 더 보기" 뒤에 접는다. 목록은 슬리버로 지연 생성한다.
///
/// 보기 전용이다 — 알림 벨·구독 관리 버튼을 두지 않는다(관리는 마이페이지,
/// spec 결정). 로딩·에러 UI도 그리지 않는다(spec 상태 표).
/// 홈에서 push 로 열리므로 뒤로가기(pop)는 홈으로 돌아간다.
class MyPlayersScreen extends StatefulWidget {
  const MyPlayersScreen({super.key, @visibleForTesting this.viewModel});

  /// 테스트에서 주입하는 뷰모델. 주입하면 화면이 dispose 하지 않는다.
  final MyPlayersViewModel? viewModel;

  static const Key searchFieldKey = ValueKey('myPlayersSearch');
  static const Key showMoreKey = ValueKey('myPlayersShowMore');
  /// 선수 줄 key — 이름은 겹칠 수 있어 playerId 로 만든다.
  static Key tileKey(int playerId) => ValueKey('myPlayer-$playerId');

  @override
  State<MyPlayersScreen> createState() => _MyPlayersScreenState();
}

class _MyPlayersScreenState extends State<MyPlayersScreen> {
  late final MyPlayersViewModel _viewModel =
      widget.viewModel ?? MyPlayersViewModel();
  final TextEditingController _search = TextEditingController();

  /// 팀 칩의 "전체" 값. 팀 코드와 겹치지 않는 내부 키.
  static const String _allTeams = '__all__';

  @override
  void dispose() {
    _search.dispose();
    if (widget.viewModel == null) _viewModel.dispose();
    super.dispose();
  }

  /// 팀 칩은 한 번에 하나만 고른다. '전체'(내부 키 [_allTeams])는 팀 없음(null).
  void _onTeamSelected(String value) =>
      _viewModel.setTeamCode(value == _allTeams ? null : value);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final vm = _viewModel;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NarDetailHeader(
                  title: l.myPlayersTitle,
                  scale: scale,
                  centerTitle: false,
                  backIconAsset: 'assets/icons/chevron-left.svg',
                  onBack: () => Navigator.of(context).pop(),
                ),
                _SearchField(
                  controller: _search,
                  hint: l.myPlayersSearchHint,
                  scale: scale,
                  onChanged: vm.setQuery,
                ),
                if (vm.teamCodes.isNotEmpty)
                  NarChipMultiSelect.single(
                    options: [_allTeams, ...vm.teamCodes],
                    selected: vm.teamCode ?? _allTeams,
                    labelBuilder: (v) =>
                        v == _allTeams ? l.myPlayersTeamAll : v,
                    onSelected: _onTeamSelected,
                    scale: scale,
                  ),
                Expanded(
                  child: CustomScrollView(
                    slivers: _slivers(context, l, vm, scale),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _slivers(
    BuildContext context,
    AppLocalizations l,
    MyPlayersViewModel vm,
    double scale,
  ) {
    final live = vm.liveSolo;
    final played = vm.playedToday;
    final quiet = vm.quiet;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    Widget message(String text) => SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20 * scale,
          vertical: 40 * scale,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13 * scale,
            color: AppColors.narText2,
          ),
        ),
      ),
    );

    if (vm.subscribedTotal == 0) return [message(l.myPlayersEmpty)];
    if (live.isEmpty && played.isEmpty && quiet.isEmpty) {
      return [message(l.myPlayersNoResult)];
    }

    return [
      // 비어 버린 묶음은 제목째 뺀다 — 검색·필터로 좁혔을 때 빈 제목만 남지 않게.
      if (live.isNotEmpty) ..._group(l.myPlayersGroupLive, null, live, scale),
      if (played.isNotEmpty)
        ..._group(l.myPlayersGroupPlayedToday, null, played, scale),
      if (quiet.isNotEmpty) ...[
        ..._group(
          l.myPlayersGroupQuiet,
          l.myPlayersGroupCount(quiet.length),
          vm.quietVisible,
          scale,
        ),
        if (vm.quietCollapsible)
          SliverToBoxAdapter(
            child: _ShowMoreButton(
              label: vm.quietExpanded
                  ? l.myPlayersShowLess
                  : l.myPlayersShowMore(vm.quietHiddenCount),
              expanded: vm.quietExpanded,
              scale: scale,
              onTap: vm.toggleQuietExpanded,
            ),
          ),
      ],
      SliverToBoxAdapter(child: SizedBox(height: 24 * scale + bottomInset)),
    ];
  }

  List<Widget> _group(
    String title,
    String? count,
    List<MyPlayerEntry> entries,
    double scale,
  ) {
    return [
      SliverToBoxAdapter(
        child: _GroupHeader(title: title, count: count, scale: scale),
      ),
      SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final entry = entries[i];
          return MyPlayerTile(
            key: MyPlayersScreen.tileKey(entry.player.playerId),
            entry: entry,
            scale: scale,
            isFirst: i == 0,
            isLast: i == entries.length - 1,
          );
        },
      ),
    ];
  }
}

/// 검색줄. 입력할 때마다 뷰모델 검색어를 바꾼다.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.scale,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final double scale;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 13 * scale,
      height: 1.4,
      color: AppColors.narText,
    );
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20 * scale),
      padding: EdgeInsets.symmetric(horizontal: 13 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 16 * scale, color: AppColors.narDark200),
          SizedBox(width: 8 * scale),
          Expanded(
            child: TextField(
              key: MyPlayersScreen.searchFieldKey,
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: textStyle,
              cursorColor: AppColors.narChipActive,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: textStyle.copyWith(color: AppColors.narDark200),
                contentPadding: EdgeInsets.symmetric(vertical: 10 * scale),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 묶음 제목 — 작은 대문자 톤. 소식 없음은 뒤에 "N명"을 붙인다.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.scale, this.count});

  final String title;
  final String? count;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        16 * scale,
        20 * scale,
        8 * scale,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 11 * scale,
              letterSpacing: 0.5,
              color: AppColors.narDark200,
            ),
          ),
          if (count != null) ...[
            SizedBox(width: 6 * scale),
            Text(
              count!,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 11 * scale,
                color: AppColors.narDark300,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "N명 더 보기" / "접기" 토글.
class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({
    required this.label,
    required this.expanded,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: MyPlayersScreen.showMoreKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 34 * scale,
        margin: EdgeInsets.fromLTRB(20 * scale, 9 * scale, 20 * scale, 0),
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 12.5 * scale,
                color: AppColors.narText2,
              ),
            ),
            SizedBox(width: 3 * scale),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 14 * scale,
              color: AppColors.narText2,
            ),
          ],
        ),
      ),
    );
  }
}
