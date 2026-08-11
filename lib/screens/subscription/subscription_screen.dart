import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/app_bottom_sheet.dart';
import '../../components/guest_lock_overlay.dart';
import '../../components/nar_alert_dialog.dart';
import '../../components/nar_banner.dart';
import '../../components/nar_chip_multi_select.dart';
import '../../components/notification_card.dart';
import '../../components/scroll_to_top_button.dart';
import '../../model/member_notification.dart';
import '../../model/schedule_match.dart';
import '../../repository/schedule/schedule_repository.dart';
import '../../repository/subscription/subscription_repository.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/subscription/subscription_feed_viewmodel.dart';
import '../match_detail/match_detail_screen.dart';
import '../match_list/match_list_screen.dart';
import '../mypage/mypage_screen.dart';
import '../schedule/schedule_screen.dart';
import 'component/date_filter_chip.dart';
import 'component/notification_card_skeleton.dart';
import 'component/player_filter_chip.dart';
import 'component/player_select_sheet.dart';
import 'component/rank_start_notification.dart';
import 'component/subscription_date_sheet.dart';
import 'subscription_settings_screen.dart';

/// 마이 구독 페이지. 하단 네비 '마이 구독' 탭에 해당한다.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  /// 서버 알림 피드(`/api/mobile/me/notifications`).
  final SubscriptionFeedViewModel _feedViewModel = SubscriptionFeedViewModel();

  /// 날짜 점프용. 날짜 헤더 위치로 ensureVisible 하려면 직접 잡아야 한다.
  final ScrollController _scrollController = ScrollController();

  /// 날짜 헤더 GlobalKey 맵 (DateTime(y,m,d) → key). build 마다 다시 채운다.
  final Map<DateTime, GlobalKey> _dateHeaderKeys = {};

  /// 날짜 칩에 표시할, 캘린더에서 마지막으로 고른 날짜. null 이면 미선택.
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    debugPrint('[Subscription][perf] 화면 진입 ${DateTime.now()}');
    WidgetsBinding.instance.addObserver(this);
    _loadPlayers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[Subscription][perf] 첫 프레임 ${DateTime.now()}');
    });
  }

  /// 구독한 선수 목록을 불러와 필터 칩/시트에 반영한다.
  /// 실패하면 빈 목록을 유지한다(가짜 placeholder 노출 방지).
  Future<void> _loadPlayers() async {
    try {
      final players = await SubscriptionRepository.instance
          .fetchSubscribedPlayers();
      if (!mounted) return;
      setState(() => _players = players.map((p) => p.playerName).toList());
    } catch (e) {
      debugPrint('[Subscription] 구독선수 로드 실패: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedViewModel.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 백그라운드에서 받은 푸시가 있을 수 있으니 앱 복귀 시 피드를 다시 읽는다.
  /// 앱 설정에서 알림 권한을 바꾸고 돌아왔을 수도 있으니 권한도 다시 확인한다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _feedViewModel.load();
      _feedViewModel.refreshNotificationPermission();
    }
  }

  /// OP.GG 등 외부 URL을 기본 브라우저로 연다.
  Future<void> _launchUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// 절대 시각 'yyyy-MM-dd HH:mm'.
  String _formatAbsolute(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  /// 상대 시각 ('방금 전', 'N분 전', 'N시간 전', 'N일 전').
  String _formatRelative(DateTime t, AppLocalizations l) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return l.justNow;
    if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.hoursAgo(diff.inHours);
    return l.daysAgo(diff.inDays);
  }

  /// 이벤트 타입 필터 내부 키 상수.
  static const String _keyAll = 'ALL';
  static const String _keySetStart = 'SET_START';
  static const String _keySetEnd = 'SET_END';

  /// 칩 내부 키 → 서버 알림 타입. 'ALL'은 null.
  MemberNotificationType? _chipToType(String chip) {
    switch (chip) {
      case _keySetStart:
        return MemberNotificationType.setStart;
      case _keySetEnd:
        return MemberNotificationType.setEnd;
      default:
        return null;
    }
  }

  /// 선택된 칩/선수 필터에 알림 한 건이 걸리는지(클라이언트 필터링).
  /// 아무것도 안 골랐으면('전체') 모두 통과. 타입·선수는 OR 로 합친다.
  bool _matchesFilter(MemberNotification n) {
    final typeFilters = _selectedTypes
        .map(_chipToType)
        .whereType<MemberNotificationType>()
        .toSet();
    final hasType = typeFilters.isNotEmpty;
    final hasPlayer = _selectedPlayers.isNotEmpty;
    if (!hasType && !hasPlayer) return true;
    if (hasType && typeFilters.contains(n.type)) return true;
    if (hasPlayer &&
        n.type == MemberNotificationType.playerSoloRank &&
        _selectedPlayers.contains(n.playerName)) {
      return true;
    }
    return false;
  }

  /// 타입별 카드 아이콘.
  String _iconFor(MemberNotificationType type) {
    switch (type) {
      case MemberNotificationType.setStart:
        return 'assets/icons/play.svg';
      case MemberNotificationType.setEnd:
        return 'assets/icons/closing.svg';
      case MemberNotificationType.liveEvent:
        return 'assets/icons/pause.svg';
      case MemberNotificationType.playerSoloRank:
      case MemberNotificationType.unknown:
        return 'assets/icons/headset.svg';
    }
  }

  /// 알림 탭 — 읽음 처리 후 딥링크 이동.
  /// 솔랭은 OP.GG 링크로 이동하므로 카드 탭은 읽음만, 팀 이벤트는 경기 상세로.
  Future<void> _onNotificationTap(MemberNotification n) async {
    _feedViewModel.markRead(n);
    // 솔랭 알림은 카드 전체 탭으로 OP.GG 소환사 페이지 이동.
    if (n.type == MemberNotificationType.playerSoloRank) {
      final url = n.opggUrl;
      if (url != null && url.isNotEmpty) _launchUrl(url);
      return;
    }
    final matchId = n.matchId;
    if (matchId == null) return;

    // 알림 생성 날짜로 일정 API를 조회해 ScheduleMatch를 찾아 스코어 카드에 넘긴다.
    ScheduleMatch? match;
    try {
      final matches = await ScheduleRepository.instance.fetchMatchesByDate(
        n.createdAt,
      );
      final found = matches.where((m) => m.matchId == matchId);
      if (found.isNotEmpty) match = found.first;
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchDetailScreen(
          matchId: matchId,
          match: match,
          initialTabIndex: 1,
        ),
      ),
    );
  }

  /// 알림 한 건을 타입에 맞는 카드로 그린다. 좌스와이프로 삭제, 탭으로 이동.
  Widget _buildNotification(MemberNotification n, double scale, AppLocalizations l) {
    final Widget card;
    if (n.type == MemberNotificationType.playerSoloRank) {
      card = RankStartNotification(
        playerName: n.playerName,
        champion: n.championName,
        queueType: n.queueType,
        dateTime: _formatAbsolute(n.createdAt),
        relativeTime: _formatRelative(n.createdAt, l),
        scale: scale,
      );
    } else {
      // 팀 이벤트(세트 시작·종료·라이브) — 서버 title/body 를 공용 카드로.
      card = NotificationCard(
        icon: _iconFor(n.type),
        title: n.title,
        body: n.body,
        dateTime: _formatAbsolute(n.createdAt),
        relativeTime: _formatRelative(n.createdAt, l),
        scale: scale,
      );
    }
    // ponytail: 스와이프는 의도적 동작이라 즉시 삭제(undo 없음). 전체 삭제만 확인 다이얼로그.
    return Dismissible(
      key: ValueKey<int>(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteOne(n),
      background: _swipeDeleteBackground(scale, l),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onNotificationTap(n),
        child: card,
      ),
    );
  }

  /// 필터된 알림을 날짜별로 묶어 [날짜 헤더 + 카드들] 위젯 리스트로 만든다.
  /// 날짜가 바뀌는 첫 항목 앞에 헤더를 끼우고, 그 헤더에 점프용 GlobalKey 를 단다.
  /// (items 는 최신순이라 같은 날짜가 연속으로 모여 있다.)
  List<Widget> _buildFeedChildren(
    List<MemberNotification> items,
    double scale,
    AppLocalizations l,
  ) {
    _dateHeaderKeys.clear();
    final children = <Widget>[];
    DateTime? lastDay;
    for (final n in items) {
      final day = _dayOf(n.createdAt);
      if (day != lastDay) {
        final key = GlobalKey();
        _dateHeaderKeys[day] = key;
        children.add(_dateHeader(day, scale, key, l));
        lastDay = day;
      }
      children.add(_buildNotification(n, scale, l));
    }
    return children;
  }

  /// 날짜 구분 헤더 — 'M월 D일'.
  Widget _dateHeader(DateTime day, double scale, Key key, AppLocalizations l) {
    return Padding(
      key: key,
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        16 * scale,
        20 * scale,
        8 * scale,
      ),
      child: Text(
        l.monthDay(day.month, day.day),
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 14 * scale,
          height: 1.4,
          color: AppColors.narTextSecondary,
        ),
      ),
    );
  }

  /// 좌스와이프 시 뒤에 드러나는 빨간 삭제 배경.
  Widget _swipeDeleteBackground(double scale, AppLocalizations l) {
    return Container(
      color: AppColors.liveAccent,
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: 24 * scale),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.delete_outline,
            color: AppColors.narText,
            size: 22 * scale,
          ),
          SizedBox(width: 4 * scale),
          Text(
            l.deleteSwipe,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14 * scale,
              color: AppColors.narText,
            ),
          ),
        ],
      ),
    );
  }

  /// 단건 삭제 실행. 실패 시 스낵바(뷰모델이 항목 복구).
  Future<void> _deleteOne(MemberNotification n) async {
    try {
      await _feedViewModel.delete(n);
    } catch (_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.deleteFailed)));
    }
  }

  /// '비우기' — 전체 삭제 확인 후 실행.
  Future<void> _confirmClearAll() async {
    if (_feedViewModel.notifications.isEmpty) return;
    final l = AppLocalizations.of(context)!;
    final confirmed = await showNarConfirmDialog(
      context: context,
      title: l.deleteAllAlarms,
      message: l.deleteAllAlarmsMessage,
      confirmLabel: l.delete,
    );
    if (confirmed != true) return;
    try {
      await _feedViewModel.deleteAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.deleteFailed)));
    }
  }

  /// 비어있음·에러 안내 문구.
  Widget _centerMessage(String text, double scale) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14 * scale,
          color: AppColors.narTextSecondary,
        ),
      ),
    );
  }

  /// 구독한 선수 목록 — 진입 시 `/api/mobile/me/player-subscriptions`에서 채운다.
  List<String> _players = const [];

  // 초기 상태 — 필터 없음(_keyAll 만 활성).
  Set<String> _selectedTypes = {_keyAll};
  Set<String> _selectedPlayers = {};

  /// _keyAll 활성 조건을 다른 필터와 동기화한다.
  /// 세트 타입·선수 중 하나라도 선택돼 있으면 _keyAll 을 해제하고,
  /// 아무 필터도 없으면 _keyAll 을 활성한다.
  void _syncAll() {
    final hasFilter =
        _selectedTypes.any((t) => t != _keyAll) || _selectedPlayers.isNotEmpty;
    _selectedTypes = hasFilter ? (_selectedTypes..remove(_keyAll)) : {_keyAll};
  }

  /// 이벤트 타입 필터 토글. _keyAll 을 고르면 세트 타입·선수 필터를 모두 비운다.
  void _onTypesChanged(Set<String> next) {
    final added = next.difference(_selectedTypes);
    setState(() {
      if (added.contains(_keyAll)) {
        _selectedTypes = {_keyAll};
        _selectedPlayers = {};
      } else {
        _selectedTypes = next;
        _syncAll();
      }
    });
  }

  /// '선수전체' 드롭다운 탭 → 선수 선택 바텀시트. 조회 시 선택 결과를 반영한다.
  /// 선수를 고르면 '전체' 필터는 자동 해제된다.
  Future<void> _openPlayerSelect() async {
    final result = await showAppBottomSheet<Set<String>>(
      context: context,
      child: PlayerSelectSheet(
        players: _players,
        initialSelected: _selectedPlayers,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedPlayers = result;
        _syncAll();
      });
    }
  }

  /// 날짜만 떼어낸 키 (시·분 무시).
  DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// 주어진 월에서 점을 찍을 일자 — 현재 필터를 통과한 알림 기준.
  /// ponytail: 로드된 알림(첫 페이지)만 본다. 더 과거는 점이 안 찍힘.
  Set<int> _markedDaysOf(DateTime month) {
    return _feedViewModel.notifications
        .where(_matchesFilter)
        .where(
          (n) =>
              n.createdAt.year == month.year &&
              n.createdAt.month == month.month,
        )
        .map((n) => n.createdAt.day)
        .toSet();
  }

  /// 날짜 칩 탭 → 캘린더 바텀시트. 고른 날짜의 헤더 위치로 스크롤한다.
  Future<void> _openDatePicker() async {
    final items = _feedViewModel.notifications.where(_matchesFilter).toList();
    final initialMonth = items.isNotEmpty
        ? items.first.createdAt
        : DateTime.now();
    final picked = await showAppBottomSheet<DateTime>(
      context: context,
      child: SubscriptionDateSheet(
        initialMonth: initialMonth,
        markedDaysOf: _markedDaysOf,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
    // 시트가 닫히고 리스트가 다시 빌드된 뒤에 헤더 위치를 잡는다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToDate(picked));
  }

  /// 해당 날짜 헤더로 부드럽게 스크롤. 키가 없으면(점프 대상 없음) 무시.
  void _scrollToDate(DateTime date) {
    final ctx = _dateHeaderKeys[_dayOf(date)]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0, // 화면 상단에 맞춤
    );
  }

  /// 하단 네비 탭 선택. '마이 구독'을 제외한 탭이면 해당 화면으로 전환한다.
  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
    } else if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
    } else if (tab == AppNavTab.mypage) {
      Navigator.of(context).pushReplacement(tabRoute(const MypageScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    /// 이벤트 타입 필터 옵션 — 내부 키 → 표시 라벨 맵.
    final eventTypeLabels = {
      _keyAll: l.eventTypeAll,
      _keySetStart: l.eventTypeSetStart,
      _keySetEnd: l.eventTypeSetEnd,
    };
    final eventTypeKeys = [_keyAll, _keySetStart, _keySetEnd];

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Stack(
          children: [
            GuestLockOverlay(
              scale: scale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SubscriptionHeader(
                    scale: scale,
                    onClearTap: _confirmClearAll,
                    onSettingsTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  // 알림 권한 미허용 안내 배너 — 온보딩을 건너뛰었거나
                  // '허용 안 함'을 눌러 권한이 없는 동안 계속 노출된다.
                  ListenableBuilder(
                    listenable: _feedViewModel,
                    builder: (context, _) =>
                        _feedViewModel.notificationPermissionGranted
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: EdgeInsets.only(top: 14 * scale),
                            child: NarBanner(
                              scale: scale,
                              onTap: _feedViewModel.requestNotificationPermission,
                              icon: SvgPicture.asset(
                                'assets/icons/bell.svg',
                                width: 24 * scale,
                                height: 24 * scale,
                              ),
                              text: l.enableNotificationPermission,
                            ),
                          ),
                  ),
                  SizedBox(height: 14 * scale), // 헤더 ↔ 필터 간격
                  NarChipMultiSelect(
                    options: eventTypeKeys,
                    labelBuilder: (key) => eventTypeLabels[key] ?? key,
                    selectedValues: _selectedTypes,
                    onChanged: _onTypesChanged,
                    pinned: const {_keyAll}, // _keyAll 은 항상 맨 앞 고정
                    scale: scale,
                    trailing: [
                      (
                        widget: PlayerFilterChip(
                          players: _players,
                          selected: _selectedPlayers,
                          scale: scale,
                          onTap: _openPlayerSelect,
                          onClear: () => setState(() {
                            _selectedPlayers = {};
                            _syncAll();
                          }),
                        ),
                        // 선택되면(보라 활성) 앞으로 정렬에 참여.
                        selected: _selectedPlayers.isNotEmpty,
                      ),
                      // 날짜 점프 칩 — 필터가 아니라 캘린더에서 고른 날짜로 스크롤.
                      (
                        widget: DateFilterChip(
                          selectedDate: _selectedDate,
                          scale: scale,
                          onTap: _openDatePicker,
                          onClear: () => setState(() => _selectedDate = null),
                        ),
                        // 선택되면(보라 활성) 앞으로 정렬에 참여.
                        selected: _selectedDate != null,
                      ),
                    ],
                  ),
                  // 알림 피드 — 네비바에 가리지 않게 하단 패딩.
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _feedViewModel,
                      builder: (context, _) {
                        final vm = _feedViewModel;
                        if (vm.isLoading && vm.notifications.isEmpty) {
                          return ListView.builder(
                            padding: EdgeInsets.only(bottom: 120 * scale),
                            itemCount: 6,
                            itemBuilder: (_, _) =>
                                NotificationCardSkeleton(scale: scale),
                          );
                        }
                        if (vm.error != null && vm.notifications.isEmpty) {
                          return _centerMessage(vm.error!, scale);
                        }
                        final items = vm.notifications
                            .where(_matchesFilter)
                            .toList();
                        return RefreshIndicator(
                          onRefresh: vm.load,
                          child: items.isEmpty
                              ? ListView(
                                  // 당겨서 새로고침이 동작하도록 스크롤 가능하게.
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(height: 120 * scale),
                                    _centerMessage(l.noNotifications, scale),
                                  ],
                                )
                              // ponytail: SingleChildScrollView+Column 으로 모든 항목을
                              // 실제 layout 한다. ListView(children) 는 RenderSliverList 라
                              // 화면 밖 헤더가 layout 안 돼 ensureVisible(날짜 점프)이 실패한다.
                              // 첫 페이지(50건) 가정. 수천 건이면 scrollable_positioned_list 로 교체.
                              : SingleChildScrollView(
                                  controller: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.only(bottom: 120 * scale),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: _buildFeedChildren(items, scale, l),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // 하단 네비(bottom 26 + 높이 72) 위로 띄운다.
            ScrollToTopButton(
              scrollController: _scrollController,
              scale: scale,
              bottom: 110,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: AppBottomNav(
                currentTab: AppNavTab.subscription,
                onTabSelected: _onTabSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 마이 구독 헤더. 좌측 타이틀 + 우측 [비우기, 설정] 아이콘 (양옆 20 패딩).
class _SubscriptionHeader extends StatelessWidget {
  const _SubscriptionHeader({
    required this.scale,
    this.onSettingsTap,
    this.onClearTap,
  });

  final double scale;
  final VoidCallback? onSettingsTap;

  /// '비우기'(알림 모두 삭제) 탭 콜백.
  final VoidCallback? onClearTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 17 * scale, 20 * scale, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l.mySubscription,
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w700,
              fontSize: 22 * scale,
              height: 1.4,
              letterSpacing: 0,
              color: AppColors.narText,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClearTap,
                child: Icon(
                  Icons.delete_outline,
                  size: 24 * scale,
                  color: AppColors.narText,
                ),
              ),
              SizedBox(width: 16 * scale),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSettingsTap,
                child: SvgPicture.asset(
                  'assets/icons/settings.svg',
                  width: 24 * scale,
                  height: 24 * scale,
                  colorFilter: const ColorFilter.mode(
                    AppColors.narText,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
