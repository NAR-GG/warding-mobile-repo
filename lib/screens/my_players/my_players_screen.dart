import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/nar_chip_multi_select.dart';
import '../../components/nar_detail_header.dart';
import '../../components/nar_tab_bar.dart';
import '../../components/team_logo.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/app_colors.dart';
import '../../repository/home/home_sources.dart';
import '../../util/league_icon.dart';
import '../../viewmodel/my_players/my_players_viewmodel.dart';
import 'component/my_player_tile.dart';
import '../player/player_screen.dart';
import 'component/worlds_player_sheet.dart';

/// 내 선수(구독 전체) 화면 — 홈 "구독 N명 전체"의 목적지.
///
/// 구독 100명 기준으로 그린다: 검색줄과 팀 필터로 좁히고, 상태별로
/// 묶는다(지금 솔랭 중 / 오늘 경기함 / 오늘 솔랭 없음). 소식 없는 선수는
/// "N명 더 보기" 뒤에 접는다. 목록은 슬리버로 지연 생성한다.
///
/// 보기 전용이다 — 알림 벨·구독 관리 버튼을 두지 않는다(관리는 마이페이지,
/// spec 결정). 로딩·에러 UI도 그리지 않는다(spec 상태 표).
/// 홈에서 push 로 열리므로 뒤로가기(pop)는 홈으로 돌아간다.
///
/// [worlds] 면 월즈 솔랭 화면이다 — 같은 묶음·검색·팀 필터에 "LCK 전체 / 구독
/// 선수" 탭, 줄마다 구독 벨, 줄을 누르면 선수 시트가 붙는다.
class MyPlayersScreen extends StatefulWidget {
  const MyPlayersScreen({
    super.key,
    @visibleForTesting this.viewModel,
    this.worlds = false,
  });

  final bool worlds;

  /// 테스트에서 주입하는 뷰모델. 주입하면 화면이 dispose 하지 않는다.
  final MyPlayersViewModel? viewModel;

  static const Key searchFieldKey = ValueKey('myPlayersSearch');
  static const Key showMoreKey = ValueKey('myPlayersShowMore');

  /// 선수 줄 key — 이름은 겹칠 수 있어 playerId 로 만든다.
  static Key tileKey(int playerId) => ValueKey('myPlayer-$playerId');
  static Key bellKey(int playerId) => ValueKey('worldsBell-$playerId');

  @override
  State<MyPlayersScreen> createState() => _MyPlayersScreenState();
}

class _MyPlayersScreenState extends State<MyPlayersScreen>
    with WidgetsBindingObserver {
  late final MyPlayersViewModel _viewModel =
      widget.viewModel ??
      MyPlayersViewModel(
        worlds: widget.worlds ? defaultWorldsSoloSource() : null,
      );
  final TextEditingController _search = TextEditingController();

  /// 리그·팀 칩의 "전체" 값. 리그·팀 코드와 겹치지 않는 내부 키.
  static const String _allTeams = '__all__';

  /// 초당 올라가는 틱. 진행 중인 판의 경과 시간만 이걸 구독해 다시 그린다 —
  /// 목록 전체를 매초 재구성하지 않는다(홈 솔랭 카드와 같은 방식).
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel.addListener(_syncClock);
    _syncClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 화면이 안 보이는 동안 초당 리빌드를 돌릴 이유가 없다.
    _syncClock(foreground: state == AppLifecycleState.resumed);
  }

  /// 카운트업할 판이 있을 때만 타이머를 돌린다. 목록이 갱신돼 진행 중인
  /// 선수가 생기거나 사라지면 따라 켜고 끈다.
  void _syncClock({bool foreground = true}) {
    final needsClock = foreground && _viewModel.liveSolo.isNotEmpty;
    if (needsClock == (_clockTimer != null)) return;
    if (!needsClock) {
      _clockTimer?.cancel();
      _clockTimer = null;
      return;
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _tick.value++;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _viewModel.removeListener(_syncClock);
    _tick.dispose();
    _search.dispose();
    if (widget.viewModel == null) _viewModel.dispose();
    super.dispose();
  }

  /// 팀 칩은 한 번에 하나만 고른다. '전체'(내부 키 [_allTeams])는 팀 없음(null).
  void _onTeamSelected(String value) =>
      _viewModel.setTeamCode(value == _allTeams ? null : value);

  void _onLeagueSelected(String value) =>
      _viewModel.setLeagueCode(value == _allTeams ? null : value);

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
                  title: vm.isWorlds ? l.worldsSoloTitle : l.myPlayersTitle,
                  scale: scale,
                  centerTitle: false,
                  backIconAsset: 'assets/icons/chevron-left.svg',
                  titleLeading: vm.isWorlds
                      ? Image.asset(
                          'assets/icons/leagues/worlds.png',
                          width: 22 * scale,
                          height: 22 * scale,
                        )
                      : null,
                  onBack: () => Navigator.of(context).pop(),
                ),
                if (vm.isWorlds)
                  NarTabBar(
                    tabs: [
                      '${l.worldsSoloTabAll} ${vm.subscribedTotal}',
                      '${l.worldsSoloTabSubscribed} ${vm.subscribedInRoster}',
                    ],
                    selectedIndex: vm.subscribedOnly ? 1 : 0,
                    onChanged: (i) => vm.setSubscribedOnly(i == 1),
                    scale: scale,
                  ),
                if (vm.isWorlds) SizedBox(height: 14 * scale),
                _SearchField(
                  controller: _search,
                  hint: l.myPlayersSearchHint,
                  scale: scale,
                  onChanged: vm.setQuery,
                ),
                // 월즈: 리그 줄 → 고른 리그의 팀 줄. 두 줄은 위아래 패딩을 줄여 붙인다.
                if (vm.isWorlds && vm.leagueCodes.length > 1)
                  NarChipMultiSelect.single(
                    options: [_allTeams, ...vm.leagueCodes],
                    selected: vm.leagueCode ?? _allTeams,
                    labelBuilder: (v) =>
                        v == _allTeams ? l.myPlayersTeamAll : v,
                    // 리그 아이콘은 원본 색이 어두워 칩 글자색으로 칠한다(시안).
                    leadingBuilder: (v) {
                      final icon = v == _allTeams ? null : leagueIconWidget(v);
                      if (icon == null) return null;
                      return ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          v == vm.leagueCode
                              ? AppColors.narText
                              : AppColors.narText2,
                          BlendMode.srcIn,
                        ),
                        child: icon,
                      );
                    },
                    onSelected: _onLeagueSelected,
                    horizontalPadding: 20,
                    verticalPadding: 8,
                    scale: scale,
                  ),
                if (vm.teamCodes.isNotEmpty)
                  NarChipMultiSelect.single(
                    options: [_allTeams, ...vm.teamCodes],
                    selected: vm.teamCode ?? _allTeams,
                    labelBuilder: (v) => v == _allTeams
                        ? (vm.isWorlds
                              ? l.worldsSoloTeamAll
                              : l.myPlayersTeamAll)
                        : v,
                    leadingBuilder: vm.isWorlds
                        ? (v) => v == _allTeams
                              ? null
                              : TeamLogo(
                                  teamCode: v,
                                  size: 16 * scale,
                                  fallbackImageUrl: vm.teamLogoUrl(v),
                                )
                        : null,
                    onSelected: _onTeamSelected,
                    horizontalPadding: vm.isWorlds ? 20 : 16,
                    verticalPadding: vm.isWorlds ? 2 : 10,
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
            fontSize: 14 * scale,
            color: AppColors.narText2,
          ),
        ),
      ),
    );

    if (vm.subscribedTotal == 0) {
      return [
        message(vm.isWorlds ? l.worldsSoloEmptyRoster : l.myPlayersEmpty),
      ];
    }
    if (vm.isWorlds && vm.subscribedOnly && vm.subscribedInRoster == 0) {
      return [message(l.myPlayersEmpty)];
    }
    if (live.isEmpty && played.isEmpty && quiet.isEmpty) {
      return [message(l.myPlayersNoResult)];
    }

    return [
      // 비어 버린 묶음은 제목째 뺀다 — 검색·필터로 좁혔을 때 빈 제목만 남지 않게.
      if (live.isNotEmpty)
        ..._group(
          l.myPlayersGroupLive,
          l.myPlayersGroupCount(live.length),
          live,
          scale,
        ),
      if (played.isNotEmpty)
        ..._group(
          l.myPlayersGroupPlayedToday,
          l.myPlayersGroupCount(played.length),
          played,
          scale,
        ),
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
          final vm = _viewModel;
          final player = entry.player;
          return MyPlayerTile(
            key: MyPlayersScreen.tileKey(player.playerId),
            entry: entry,
            scale: scale,
            isFirst: i == 0,
            isLast: i == entries.length - 1,
            tick: _tick,
            // 타일은 선수 페이지로, 벨은 알림 토글 시트로.
            onTap: vm.isWorlds
                ? () async {
                    await PlayerScreen.open(context, player.playerId);
                    // 선수 페이지에서 구독을 바꿨을 수 있다.
                    await vm.refresh();
                  }
                : null,
            trailing: vm.isWorlds
                ? _BellButton(
                    key: MyPlayersScreen.bellKey(player.playerId),
                    subscribed: player.subscribed,
                    playerName: player.playerName,
                    scale: scale,
                    // 바로 바꾸지 않고 선수 시트를 띄운다 — 알림 토글을 고른 뒤 시트에서 적용.
                    onTap: () => showWorldsPlayerSheet(
                      context,
                      viewModel: vm,
                      playerId: player.playerId,
                      scale: scale,
                    ),
                  )
                : null,
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
      fontSize: 14 * scale,
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
              fontSize: 13 * scale,
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
                fontSize: 13 * scale,
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
                fontSize: 14 * scale,
                color: AppColors.narText2,
              ),
            ),
            SizedBox(width: 3 * scale),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 16 * scale,
              color: AppColors.narText2,
            ),
          ],
        ),
      ),
    );
  }
}

/// 월즈 줄 오른쪽 구독 벨 — 구독 중이면 보라 체크 벨, 아니면 회색 플러스 벨.
class _BellButton extends StatelessWidget {
  const _BellButton({
    super.key,
    required this.subscribed,
    required this.playerName,
    required this.scale,
    required this.onTap,
  });

  final bool subscribed;
  final String playerName;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final size = 36 * scale;
    return Semantics(
      button: true,
      label: subscribed
          ? l.worldsSoloUnsubscribeSemantics(playerName)
          : l.worldsSoloSubscribeSemantics(playerName),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: subscribed
                ? AppColors.narChipActive.withValues(alpha: 0.22)
                : AppColors.narDark500,
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            subscribed
                ? 'assets/icons/bell-check.svg'
                : 'assets/icons/bell-plus.svg',
            width: 18 * scale,
            height: 18 * scale,
            colorFilter: ColorFilter.mode(
              subscribed ? AppColors.narViolet3 : AppColors.narText2,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
