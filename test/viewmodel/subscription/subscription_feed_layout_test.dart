import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/member_notification.dart';
import 'package:warding/viewmodel/subscription/subscription_feed_layout.dart';

/// 서버는 알림을 최신순으로 준다 — 목록도 그 순서를 그대로 쓴다.
MemberNotification _n(int id, DateTime at, {MemberNotificationType? type}) =>
    MemberNotification(
      id: id,
      type: type ?? MemberNotificationType.setStart,
      title: 'title-$id',
      body: 'body-$id',
      data: const {},
      read: false,
      createdAt: at,
    );

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

bool _all(MemberNotification _) => true;

void main() {
  group('rebuild — 평탄화', () {
    test('날짜가 바뀌는 첫 항목 앞에만 헤더를 끼운다', () {
      final layout = SubscriptionFeedLayout();
      layout.rebuild(
        source: [
          _n(1, DateTime(2026, 8, 19, 20)),
          _n(2, DateTime(2026, 8, 19, 10)),
          _n(3, DateTime(2026, 8, 18, 22)),
        ],
        typeFilterToken: Object(),
        playerFilterToken: Object(),
        matches: _all,
        dayOf: _dayOf,
      );

      // [헤더 8/19, 알림1, 알림2, 헤더 8/18, 알림3]
      expect(layout.items.length, 5);
      expect(layout.items[0], isA<FeedDateHeader>());
      expect(layout.items[1], isA<FeedNotificationItem>());
      expect(layout.items[2], isA<FeedNotificationItem>());
      expect(layout.items[3], isA<FeedDateHeader>());
      expect(layout.items[4], isA<FeedNotificationItem>());
      expect((layout.items[0] as FeedDateHeader).day, DateTime(2026, 8, 19));
      expect((layout.items[3] as FeedDateHeader).day, DateTime(2026, 8, 18));
    });

    test('필터에 걸러진 알림은 물론, 그 날짜의 헤더도 남지 않는다', () {
      final layout = SubscriptionFeedLayout();
      layout.rebuild(
        source: [
          _n(1, DateTime(2026, 8, 19), type: MemberNotificationType.setStart),
          _n(2, DateTime(2026, 8, 18), type: MemberNotificationType.setEnd),
        ],
        typeFilterToken: Object(),
        playerFilterToken: Object(),
        matches: (n) => n.type == MemberNotificationType.setStart,
        dayOf: _dayOf,
      );

      expect(layout.items.length, 2); // 8/19 헤더 + 알림1 뿐
      expect((layout.items[0] as FeedDateHeader).day, DateTime(2026, 8, 19));
      expect((layout.items[1] as FeedNotificationItem).notification.id, 1);
    });

    test('입력이 그대로면 다시 펴지 않는다 — 로딩 플래그 알림에 낭비하지 않기 위한 것', () {
      final layout = SubscriptionFeedLayout();
      final source = [_n(1, DateTime(2026, 8, 19))];
      final typeToken = Object();
      final playerToken = Object();
      var calls = 0;
      bool counting(MemberNotification _) {
        calls++;
        return true;
      }

      layout.rebuild(
        source: source,
        typeFilterToken: typeToken,
        playerFilterToken: playerToken,
        matches: counting,
        dayOf: _dayOf,
      );
      final first = layout.items;
      expect(calls, 1);

      layout.rebuild(
        source: source,
        typeFilterToken: typeToken,
        playerFilterToken: playerToken,
        matches: counting,
        dayOf: _dayOf,
      );
      expect(calls, 1, reason: '같은 입력이면 필터를 다시 돌리지 않는다');
      expect(identical(layout.items, first), isTrue);
    });

    test('필터 토큰이 바뀌면 다시 편다', () {
      final layout = SubscriptionFeedLayout();
      final source = [
        _n(1, DateTime(2026, 8, 19), type: MemberNotificationType.setStart),
        _n(2, DateTime(2026, 8, 19), type: MemberNotificationType.setEnd),
      ];
      layout.rebuild(
        source: source,
        typeFilterToken: Object(),
        playerFilterToken: Object(),
        matches: _all,
        dayOf: _dayOf,
      );
      expect(layout.items.length, 3); // 헤더 + 2건

      layout.rebuild(
        source: source,
        typeFilterToken: Object(), // 새 선택
        playerFilterToken: Object(),
        matches: (n) => n.type == MemberNotificationType.setStart,
        dayOf: _dayOf,
      );
      expect(layout.items.length, 2); // 헤더 + 1건
    });
  });

  group('indexOfDay / offsetOf — 날짜 점프 좌표', () {
    SubscriptionFeedLayout buildThreeDays() {
      final layout = SubscriptionFeedLayout();
      layout.rebuild(
        source: [
          _n(1, DateTime(2026, 8, 19)),
          _n(2, DateTime(2026, 8, 18)),
          _n(3, DateTime(2026, 8, 17)),
        ],
        typeFilterToken: Object(),
        playerFilterToken: Object(),
        matches: _all,
        dayOf: _dayOf,
      );
      return layout;
    }

    test('날짜 헤더의 인덱스를 찾는다', () {
      final layout = buildThreeDays();
      // [헤더8/19, 알림1, 헤더8/18, 알림2, 헤더8/17, 알림3]
      expect(layout.indexOfDay(DateTime(2026, 8, 19)), 0);
      expect(layout.indexOfDay(DateTime(2026, 8, 18)), 2);
      expect(layout.indexOfDay(DateTime(2026, 8, 17)), 4);
    });

    test('그 날짜 그룹이 없으면 -1 — 점프를 건너뛰는 신호', () {
      final layout = buildThreeDays();
      expect(layout.indexOfDay(DateTime(2026, 8, 1)), -1);
    });

    test('실측이 없으면 종류별 기본 높이를 누적한다', () {
      final layout = buildThreeDays();
      expect(layout.offsetOf(0), 0);
      // 헤더8/19 + 알림1
      expect(
        layout.offsetOf(2),
        SubscriptionFeedLayout.fallbackHeaderHeight +
            SubscriptionFeedLayout.fallbackCardHeight,
      );
    });

    test('실측한 높이를 그 자리에 그대로 쓴다', () {
      final layout = buildThreeDays();
      layout.measure(0, 40); // 헤더
      layout.measure(1, 200); // 알림 카드
      expect(layout.offsetOf(2), 240);
    });

    test('안 그려진 항목은 같은 종류의 실측 평균으로 메운다', () {
      final layout = buildThreeDays();
      // 헤더 둘을 40/60 으로 재면 평균 50 — 아직 안 잰 셋째 헤더에 이 값이 쓰인다.
      layout.measure(0, 40);
      layout.measure(2, 60);
      // 카드는 하나만 쟀으므로 평균은 그 값 그대로.
      layout.measure(1, 100);

      // offsetOf(5) = 헤더0 + 카드1 + 헤더2 + 카드3(평균100) + 헤더4(평균50)
      expect(layout.offsetOf(5), 40 + 100 + 60 + 100 + 50);
    });

    test('헤더 평균이 카드 높이에 섞이지 않는다', () {
      final layout = buildThreeDays();
      layout.measure(0, 10); // 헤더만 실측
      // 카드(인덱스 1)는 카드 실측이 없으니 헤더 10 이 아니라 카드 기본값을 쓴다.
      expect(layout.heightOf(1), SubscriptionFeedLayout.fallbackCardHeight);
    });

    test('목록이 바뀌면 실측을 버린다 — 인덱스가 밀려 엉뚱한 항목에 붙기 때문', () {
      final layout = buildThreeDays();
      layout.measure(0, 999);
      expect(layout.heightOf(0), 999);

      layout.rebuild(
        source: [_n(9, DateTime(2026, 8, 19))],
        typeFilterToken: Object(),
        playerFilterToken: Object(),
        matches: _all,
        dayOf: _dayOf,
      );
      expect(
        layout.heightOf(0),
        SubscriptionFeedLayout.fallbackHeaderHeight,
        reason: '새 목록에는 예전 실측을 쓰면 안 된다',
      );
    });

    test('범위를 넘는 인덱스를 물어도 목록 전체 높이까지만 센다', () {
      final layout = buildThreeDays();
      expect(layout.offsetOf(999), layout.offsetOf(layout.items.length));
    });
  });
}
