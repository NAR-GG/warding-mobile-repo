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
                            // 안 읽은 알림은 배경색으로만 구분한다(인스타 방식).
                            // 카드가 자체 불투명 배경을 칠하므로 틴트는 카드 "위"에
                            // 오버레이로 얹는다 — 밑에 깔면 완전히 가려진다.
                            // 탭하면 markRead 로 상태가 바뀌어 즉시 평범해진다.
                            // ponytail: 스와이프는 의도적 동작이라 즉시 삭제(undo 없음) — 마이구독과 동일.
                            return RepaintBoundary(
                              child: Dismissible(
                                key: ValueKey<int>(n.id),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => _deleteOne(n),
                                background: _swipeDeleteBackground(scale, l),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _onTap(n),
                                  child: Stack(
                                    children: [
                                      buildNotificationFeedCard(n, scale, l),
                                      if (!n.read)
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: ColoredBox(
                                              color: AppColors.narViolet3
                                                  .withValues(alpha: 0.08),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
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

  /// 단건 삭제. 실패 시 스낵바(뷰모델이 항목 복구) — 마이구독과 같은 동작.
  Future<void> _deleteOne(MemberNotification n) async {
    try {
      await _vm.delete(n);
    } catch (_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.deleteFailed)));
    }
  }

  /// 좌스와이프 시 드러나는 빨간 삭제 배경 — 마이구독과 같은 모양.
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
