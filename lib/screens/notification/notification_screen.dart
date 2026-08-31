import 'package:flutter/material.dart';

import '../../components/nar_detail_header.dart';
import '../../components/notification_feed_card.dart';
import '../../l10n/app_localizations.dart';
import '../../model/member_notification.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/subscription/subscription_feed_viewmodel.dart';
import '../community/post_detail_screen.dart';

/// 커뮤니티 알림함. 진입점은 커뮤니티 헤더 벨 하나다.
///
/// 커뮤니티 알림만 다룬다(서버 group=COMMUNITY 필터) — 경기 알림은 마이구독
/// 피드가 담당한다. 그래서 예전의 [전체]·[경기]·[커뮤니티] 탭이 없다.
/// 피드 ViewModel 은 마이구독과 같은 것을 group 만 걸어 쓴다.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final SubscriptionFeedViewModel _vm =
      SubscriptionFeedViewModel(group: 'COMMUNITY');
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
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

  Future<void> _onTap(MemberNotification n) async {
    _vm.markRead(n);
    final postId = n.postId;
    if (postId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PostDetailScreen(postId: postId)),
    );
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
            final items = _vm.notifications;
            return Column(
              children: [
                NarDetailHeader(
                  title: l.communityNotificationTitle,
                  scale: scale,
                  trailing: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _vm.markAllRead,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                      child: Text(
                        l.notificationReadAll,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          fontSize: 13 * scale,
                          height: 1.45,
                          color: _vm.unreadCount > 0
                              ? AppColors.narText3
                              : AppColors.narDark300,
                        ),
                      ),
                    ),
                  ),
                ),
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
                                      if (!n.read) ...[
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: ColoredBox(
                                              color: AppColors.narViolet3
                                                  .withValues(alpha: 0.08),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 7 * scale,
                                          top: 20 * scale,
                                          child: Container(
                                            width: 6 * scale,
                                            height: 6 * scale,
                                            decoration: const BoxDecoration(
                                              color: AppColors.narViolet3,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ],
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
