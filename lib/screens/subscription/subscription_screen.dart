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
import '../../config/app_globals.dart';
import '../../viewmodel/subscription/subscription_feed_layout.dart';
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

  /// 날짜 점프·무한 스크롤용.
  final ScrollController _scrollController = ScrollController();

  /// 날짜 칩에 표시할, 캘린더에서 마지막으로 고른 날짜. null 이면 미선택.
  DateTime? _selectedDate;

  /// 목록 배치 — 평탄화·높이 어림·날짜 점프 좌표 계산을 담당한다.
  final SubscriptionFeedLayout _layout = SubscriptionFeedLayout();

  /// 날짜 점프 목적지. [_scrollToDate] 가 걸어두면 [_settleJump] 가 실측 높이로
  /// 위치를 보정한 뒤 비운다.
  DateTime? _pendingJumpDate;

  /// 목록을 내리는 동안 하단 네비를 살짝 줄이는 상태.
  final BottomNavShrinkController _navShrink = BottomNavShrinkController();

  @override
  void initState() {
    super.initState();
    debugPrint('[Subscription][perf] 화면 진입 ${DateTime.now()}');
    WidgetsBinding.instance.addObserver(this);
    // 앱이 떠 있는 채로 푸시가 오면(이 화면에 머물러 있을 때 특히) 복귀 이벤트가 없어
    // 피드가 갱신되지 않았다. FcmService 가 수신 때 올리는 카운터를 듣고 다시 읽는다.
    feedRefreshTick.addListener(_reloadFeed);
    _scrollController.addListener(_onScroll);
    // 필터로 걸러 화면이 덜 찼으면 스크롤이 생기지 않아 _onScroll 이 안 불린다.
    // 피드가 갱신될 때마다 화면이 찼는지 확인해 필요하면 다음 페이지를 당긴다.
    _feedViewModel.addListener(_maybeFillViewport);
    _loadPlayers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[Subscription][perf] 첫 프레임 ${DateTime.now()}');
    });
  }

  /// 스크롤이 끝에서 300px 이내면 다음 페이지를 이어 받는다.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final remaining =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining < 300) _feedViewModel.loadMore();
  }

  /// 목록이 뷰포트를 못 채웠으면(=스크롤이 안 생겼으면) 다음 페이지를 당긴다.
  ///
  /// 이 피드는 받아온 50건을 클라이언트에서 필터링하므로, 필터를 켜면 남는
  /// 건수가 적어 스크롤이 아예 없을 수 있다. 그러면 [_onScroll] 이 영영 안 불려
  /// 뒤 페이지에 있는, 필터에 걸리는 알림을 못 보게 된다.
  void _maybeFillViewport() {
    if (!_feedViewModel.hasMore ||
        _feedViewModel.isLoading ||
        _feedViewModel.isLoadingMore) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) {
        _feedViewModel.loadMore();
      }
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
    feedRefreshTick.removeListener(_reloadFeed);
    _feedViewModel.removeListener(_maybeFillViewport);
    _feedViewModel.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _navShrink.dispose();
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

  /// 푸시 수신 신호로 피드를 다시 읽는다.
  void _reloadFeed() => _feedViewModel.load();

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
  static const String _keyLiveEvent = 'LIVE_EVENT';

  /// 칩 내부 키 → 서버 알림 타입. 'ALL'은 null.
  MemberNotificationType? _chipToType(String chip) {
    switch (chip) {
      case _keySetStart:
        return MemberNotificationType.setStart;
      case _keySetEnd:
        return MemberNotificationType.setEnd;
      case _keyLiveEvent:
        return MemberNotificationType.liveEvent;
      default:
        return null;
    }
  }

  /// [_selectedTypes] 를 알림 타입으로 옮긴 것과, 그때 쓴 원본 Set.
  ///
  /// [_matchesFilter] 는 알림 **한 건마다** 불리는데, 여기서 매번 Set 을 새로
  /// 만들면 피드 길이만큼 같은 Set 이 반복 생성된다(수백 건이면 수백 개).
  /// 선택이 바뀔 때만 다시 만든다 — 갱신은 항상 `_selectedTypes` 에 새 Set 을
  /// 대입하는 식이라 참조 비교로 충분하다.
  Set<String>? _typeFilterSource;
  Set<MemberNotificationType> _typeFilterCache = const {};

  Set<MemberNotificationType> get _typeFilters {
    if (!identical(_typeFilterSource, _selectedTypes)) {
      _typeFilterSource = _selectedTypes;
      _typeFilterCache = _selectedTypes
          .map(_chipToType)
          .whereType<MemberNotificationType>()
          .toSet();
    }
    return _typeFilterCache;
  }

  /// 선택된 칩/선수 필터에 알림 한 건이 걸리는지(클라이언트 필터링).
  /// 아무것도 안 골랐으면('전체') 모두 통과. 타입·선수는 OR 로 합친다.
  bool _matchesFilter(MemberNotification n) {
    final typeFilters = _typeFilters;
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

  /// 필터를 적용한 알림 목록을 [SubscriptionFeedLayout] 에 다시 펴 넣는다.
  ///
  /// 예전엔 build 안에서 `where(_matchesFilter).toList()` 로 매번 전체를 훑고
  /// 위젯까지 전부 만들었다. 이 피드는 [SubscriptionFeedViewModel.loadMore] 로
  /// 계속 누적되므로 그 비용이 알림이 쌓일수록 커졌고, 로딩 플래그 하나 바뀐
  /// 알림에도 똑같이 반복됐다. 목록·필터가 실제로 변했을 때만 다시 편다.
  void _rebuildFeedItems() {
    _layout.rebuild(
      source: _feedViewModel.notifications,
      // 필터 갱신은 항상 새 Set 을 대입하는 식이라 참조가 곧 버전이다.
      typeFilterToken: _selectedTypes,
      playerFilterToken: _selectedPlayers,
      matches: _matchesFilter,
      dayOf: _dayOf,
    );
  }

  /// 평탄화된 한 칸을 위젯으로. 카드는 자기 레이어만 다시 칠하도록 경계를 둔다
  /// (스와이프 삭제 애니메이션이 이웃 카드까지 리페인트하지 않게).
  Widget _buildFeedItem(FeedItem item, double scale, AppLocalizations l) {
    return switch (item) {
      FeedDateHeader(:final day) => _dateHeader(day, scale, l),
      FeedNotificationItem(:final notification) => RepaintBoundary(
          child: _buildNotification(notification, scale, l),
        ),
    };
  }

  /// 날짜 구분 헤더 — 'M월 D일'.
  Widget _dateHeader(DateTime day, double scale, AppLocalizations l) {
    return Padding(
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
    // 제자리 remove 가 아니라 새 Set 을 만든다 — [_typeFilters] 캐시가 참조
    // 비교로 갱신을 감지하므로, 같은 인스턴스를 고쳐 넘기면 선택이 바뀐 걸
    // 알아채지 못한다.
    _selectedTypes = hasFilter
        ? _selectedTypes.where((t) => t != _keyAll).toSet()
        : {_keyAll};
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

  /// 해당 날짜 헤더로 스크롤한다. 그 날짜 그룹이 없으면 아무것도 하지 않는다.
  ///
  /// 예전엔 헤더마다 [GlobalKey] 를 달고 [Scrollable.ensureVisible] 을 썼는데,
  /// 그건 대상이 이미 layout 돼 있어야 동작해서 목록 전체를 실제로 그리는
  /// (=가상화를 포기하는) 구조를 강요했다. 지금은 헤더가 평탄화 목록에서 몇
  /// 번째 칸인지를 찾아 그 앞까지의 높이만큼 직접 이동한다.
  ///
  /// 아직 안 그려진 항목의 높이는 어림이라 한 번에 정확히 닿지 않을 수 있다.
  /// 이동하면 그 구간이 실제로 렌더되면서 실측 높이가 채워지므로([_measureItem]),
  /// 다음 프레임에 [_settleJump] 가 같은 계산을 다시 해 남은 오차를 좁힌다.
  void _scrollToDate(DateTime date) {
    if (!_scrollController.hasClients) return;
    final day = _dayOf(date);
    final index = _layout.indexOfDay(day);
    if (index < 0) return;
    _pendingJumpDate = day;
    _scrollController.jumpTo(
      _layout.offsetOf(index).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _settleJump());
  }

  /// 점프 직후, 새로 채워진 실측 높이로 목적지를 다시 재 오차를 좁힌다.
  ///
  /// 남은 오차가 1px 미만이거나 더 나아가지 못하면(이미 목록 끝) 끝낸다.
  /// 반복 상한을 두는 이유는 어림과 실측이 미세하게 진동할 때 프레임 콜백이
  /// 무한히 이어지는 것을 막기 위해서다.
  void _settleJump({int attempt = 0}) {
    final day = _pendingJumpDate;
    if (day == null || !mounted || !_scrollController.hasClients) return;
    const maxAttempts = 8;
    final index = _layout.indexOfDay(day);
    if (index < 0 || attempt >= maxAttempts) {
      _pendingJumpDate = null;
      return;
    }
    final position = _scrollController.position;
    final target = _layout.offsetOf(index).clamp(0.0, position.maxScrollExtent);
    if ((position.pixels - target).abs() < 1) {
      _pendingJumpDate = null;
      return;
    }
    _scrollController.jumpTo(target);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _settleJump(attempt: attempt + 1));
  }

  /// 그려진 항목의 실제 높이를 기록한다.
  ///
  /// [ListView.builder] 가 만든 칸에서 layout 이 끝난 뒤 불린다. setState 는
  /// 하지 않는다 — 이 값은 다음 점프 계산에만 쓰이고 화면에 직접 나타나지
  /// 않으므로, 여기서 rebuild 를 걸면 방금 끝난 layout 을 곧바로 다시
  /// 요청하는 꼴이 된다.
  void _measureItem(int index, double height) => _layout.measure(index, height);

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
      _keyLiveEvent: l.liveEvent,
    };
    final eventTypeKeys = [_keyAll, _keySetStart, _keySetEnd, _keyLiveEvent];

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _navShrink.handleNotification,
              child: GuestLockOverlay(
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
                                  onTap:
                                      _feedViewModel
                                          .requestNotificationPermission,
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
                          _rebuildFeedItems();
                          final items = _layout.items;
                          // 다음 페이지를 이어 받는 중이면 하단에 스켈레톤 2장.
                          final trailing = vm.isLoadingMore ? 2 : 0;
                          return RefreshIndicator(
                            onRefresh: vm.load,
                            child:
                                items.isEmpty
                                    ? ListView(
                                      // 당겨서 새로고침이 동작하도록 스크롤 가능하게.
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      children: [
                                        SizedBox(height: 120 * scale),
                                        _centerMessage(
                                          l.noNotifications,
                                          scale,
                                        ),
                                      ],
                                    )
                                    // 화면에 보이는 만큼만 만든다. 날짜 점프는
                                    // 헤더의 인덱스를 찾아 그 앞까지의 높이로
                                    // 직접 이동하므로([_scrollToDate]), 목록
                                    // 전체를 미리 layout 할 이유가 없다.
                                    : ListView.builder(
                                      controller: _scrollController,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.only(
                                        bottom: 120 * scale,
                                      ),
                                      itemCount: items.length + trailing,
                                      itemBuilder: (context, index) {
                                        if (index >= items.length) {
                                          return NotificationCardSkeleton(
                                            scale: scale,
                                          );
                                        }
                                        return _MeasuredFeedItem(
                                          index: index,
                                          onMeasured: _measureItem,
                                          child: _buildFeedItem(
                                            items[index],
                                            scale,
                                            l,
                                          ),
                                        );
                                      },
                                    ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
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
              child: ListenableBuilder(
                listenable: _navShrink,
                builder: (context, _) => AppBottomNav(
                  currentTab: AppNavTab.subscription,
                  onTabSelected: _onTabSelected,
                  compact: _navShrink.compact,
                ),
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

/// 자식이 실제로 차지한 높이를 재서 알려주는 래퍼.
///
/// 마이구독 피드는 알림 카드 높이가 서버 텍스트 길이에 따라 달라서, 날짜
/// 점프가 쓸 위치를 상수로는 계산할 수 없다. 화면에 올라온 김에 실제 높이를
/// 재 두면 그 뒤의 점프가 정확해진다.
///
/// layout 이 끝난 뒤(=[addPostFrameCallback]) 알린다 — layout 도중에 부모
/// State 를 건드리면 같은 프레임에 다시 build 를 요청하는 꼴이 된다.
class _MeasuredFeedItem extends StatefulWidget {
  const _MeasuredFeedItem({
    required this.index,
    required this.onMeasured,
    required this.child,
  });

  final int index;
  final void Function(int index, double height) onMeasured;
  final Widget child;

  @override
  State<_MeasuredFeedItem> createState() => _MeasuredFeedItemState();
}

class _MeasuredFeedItemState extends State<_MeasuredFeedItem> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(_MeasuredFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 재활용으로 다른 인덱스를 맡게 됐으면 그 칸의 높이를 새로 잰다.
    if (oldWidget.index != widget.index) _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      widget.onMeasured(widget.index, box.size.height);
    });
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
