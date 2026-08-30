import 'package:flutter/material.dart';

import '../../components/nar_detail_header.dart';
import '../../components/notification_feed_card.dart';
import '../../l10n/app_localizations.dart';
import '../../model/member_notification.dart';
import '../../styles/app_colors.dart';
import '../../util/match_detail_router.dart';
import '../../viewmodel/subscription/subscription_feed_viewmodel.dart';
import '../community/post_detail_screen.dart';

/// 알림함 — [전체]·[경기]·[커뮤니티] 탭 (커뮤니티 후속 문서 A절).
///
/// 진입점은 홈 헤더 벨과 마이페이지 벨 둘이지만 도착지는 여기 하나다.
/// 피드 ViewModel 은 마이구독과 같은 것을 쓴다 — 알림 원천이 같아서다.
/// 마이구독과 달리 날짜 점프·선수 필터가 없어 단순 ListView 로 충분하다.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

enum _InboxTab { all, match, community }

class _NotificationScreenState extends State<NotificationScreen> {
  final SubscriptionFeedViewModel _vm = SubscriptionFeedViewModel();
  final ScrollController _scroll = ScrollController();
  _InboxTab _tab = _InboxTab.all;

  @override
  void initState() {
    super.initState();
    _vm.load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 300) _vm.loadMore();
  }

  bool _matchesTab(MemberNotification n) => switch (_tab) {
    _InboxTab.all => true,
    _InboxTab.community => n.type.isCommunity,
    _InboxTab.match => !n.type.isCommunity,
  };

  Future<void> _onTap(MemberNotification n) async {
    _vm.markRead(n);
    if (n.type.isCommunity) {
      final postId = n.postId;
      if (postId == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PostDetailScreen(postId: postId)),
      );
      return;
    }
    final matchId = n.matchId;
    if (matchId == null) return;
    // 경기 알림 — 푸시 딥링크와 같은 창구(라우터)로 상세를 연다.
    MatchDetailRouter.open(matchId: matchId, tabIndex: 1);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            final items = _vm.notifications.where(_matchesTab).toList();
            return Column(
              children: [
                NarDetailHeader(title: l.notificationInboxTitle, scale: scale),
                _tabs(l, scale),
                Expanded(
                  child: items.isEmpty
                      ? _empty(l, scale)
                      : ListView.builder(
                          controller: _scroll,
                          padding: EdgeInsets.only(bottom: 24 * scale),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final n = items[i];
                            return RepaintBoundary(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _onTap(n),
                                child: buildNotificationFeedCard(n, scale, l),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tabs(AppLocalizations l, double scale) {
    Widget chip(_InboxTab tab, String label) {
      final selected = _tab == tab;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = tab),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 7 * scale,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.narChipActive : AppColors.narDark600,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 12.5 * scale,
              height: 1.45,
              color: selected ? AppColors.narDark800 : AppColors.narText3,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 6 * scale, 20 * scale, 8 * scale),
      child: Row(
        children: [
          chip(_InboxTab.all, l.notificationTabAll),
          SizedBox(width: 8 * scale),
          chip(_InboxTab.match, l.notificationTabMatch),
          SizedBox(width: 8 * scale),
          chip(_InboxTab.community, l.notificationTabCommunity),
        ],
      ),
    );
  }

  Widget _empty(AppLocalizations l, double scale) => Center(
    child: Text(
      l.notificationEmpty,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13 * scale,
        color: AppColors.narText2,
      ),
    ),
  );
}
