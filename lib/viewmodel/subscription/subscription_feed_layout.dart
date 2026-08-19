import '../../model/member_notification.dart';

/// 마이구독 피드 목록의 한 칸 — 날짜 헤더이거나 알림 카드.
///
/// 날짜 헤더와 카드를 한 인덱스 공간에 담아, 날짜 점프가 "그 날짜가 몇 번째
/// 칸인지"만 알면 되도록 한다. 그래야 목록을 전부 그려 두지 않고도
/// (=`ListView.builder` 를 쓰면서도) 화면 밖 날짜로 이동할 수 있다.
sealed class FeedItem {
  const FeedItem();

  /// 날짜 헤더인지. 높이 어림이 헤더와 카드를 따로 평균 내는 데 쓴다 —
  /// 둘은 높이 차가 커서 한 덩어리로 평균 내면 양쪽 다 틀린다.
  bool get isHeader;
}

class FeedDateHeader extends FeedItem {
  const FeedDateHeader(this.day);

  /// 자정으로 자른 날짜. 점프 목적지와 이 값을 맞춰 인덱스를 찾는다.
  final DateTime day;

  @override
  bool get isHeader => true;
}

class FeedNotificationItem extends FeedItem {
  const FeedNotificationItem(this.notification);

  final MemberNotification notification;

  @override
  bool get isHeader => false;
}

/// 마이구독 피드의 목록 배치 — 평탄화, 높이 어림, 날짜 → 인덱스 → 오프셋 변환.
///
/// 이 피드는 [SubscriptionFeedViewModel.loadMore] 로 알림이 계속 누적되는데,
/// 예전 화면은 목록 전체를 `SingleChildScrollView` + `Column` 으로 실제 layout
/// 했다. 날짜 점프가 `Scrollable.ensureVisible` 을 쓰느라 대상 헤더가 이미
/// 그려져 있어야 했기 때문이다 — 즉 가상화를 포기한 대가로 점프를 산 셈이라,
/// 알림이 쌓일수록 화면이 무거워졌다.
///
/// 여기서는 점프에 필요한 것을 "헤더의 인덱스와 그 앞까지의 높이"로 바꾼다.
/// 그러면 `ListView.builder` 로 보이는 만큼만 그리면서도 점프가 된다.
///
/// 높이는 상수로 둘 수 없다 — 알림 카드는 서버가 준 title/body 길이에 따라
/// 줄 수가 달라진다. 대신 화면에 올라온 항목의 실제 높이를 [measure] 로 받아
/// 기억해 두고, 아직 안 그려진 항목은 같은 종류의 실측 평균으로 메운다.
/// 그래서 점프는 한 번에 정확히 닿지 않을 수 있고, 이동으로 그 구간이 실제
/// 렌더되며 실측이 채워지면 다시 계산해 오차를 좁히는 식으로 수렴한다.
class SubscriptionFeedLayout {
  /// 아직 아무것도 실측하지 못했을 때 쓰는 어림 높이(px, scale 1 기준).
  /// 시안 기준 대략치이고, 실측이 하나라도 쌓이면 곧바로 대체된다.
  static const double fallbackHeaderHeight = 48;
  static const double fallbackCardHeight = 132;

  List<FeedItem> _items = const [];

  /// 화면에 그릴 항목 목록. [rebuild] 가 갱신한다.
  List<FeedItem> get items => _items;

  /// 인덱스 → 실측 높이(px).
  final Map<int, double> _measured = {};

  /// [rebuild] 가 마지막으로 딛고 선 입력. 이게 그대로면 다시 펴지 않는다.
  List<MemberNotification>? _source;
  Object? _typeFilterToken;
  Object? _playerFilterToken;

  /// 필터를 적용한 [source] 를 [날짜 헤더 + 카드] 1차원 목록으로 편다.
  ///
  /// [typeFilterToken]/[playerFilterToken] 은 현재 필터 선택을 가리키는 값으로,
  /// 화면이 필터를 바꿀 때마다 새 인스턴스를 넘긴다(참조 비교로 변경을 안다).
  /// 입력 셋이 모두 그대로면 아무것도 하지 않는다 — 로딩 플래그 하나 바뀐
  /// 알림에도 목록 전체를 다시 펴던 것을 막기 위한 것이다.
  ///
  /// [matches] 는 알림 한 건이 현재 필터에 걸리는지 판정한다.
  /// [dayOf] 는 알림 시각을 자정으로 자른 날짜로 옮긴다.
  void rebuild({
    required List<MemberNotification> source,
    required Object? typeFilterToken,
    required Object? playerFilterToken,
    required bool Function(MemberNotification) matches,
    required DateTime Function(DateTime) dayOf,
  }) {
    if (identical(_source, source) &&
        identical(_typeFilterToken, typeFilterToken) &&
        identical(_playerFilterToken, playerFilterToken)) {
      return;
    }
    _source = source;
    _typeFilterToken = typeFilterToken;
    _playerFilterToken = playerFilterToken;

    final items = <FeedItem>[];
    DateTime? lastDay;
    // source 는 최신순이라 같은 날짜가 연속으로 모여 있다 — 날짜가 바뀌는
    // 첫 항목 앞에만 헤더를 끼운다.
    for (final n in source) {
      if (!matches(n)) continue;
      final day = dayOf(n.createdAt);
      if (day != lastDay) {
        items.add(FeedDateHeader(day));
        lastDay = day;
      }
      items.add(FeedNotificationItem(n));
    }
    _items = items;
    // 항목 구성이 달라졌으면 인덱스가 밀려 예전 실측값이 엉뚱한 항목에 붙는다.
    _measured.clear();
  }

  /// 그려진 항목의 실제 높이를 기록한다. 값이 그대로면 아무 일도 하지 않는다.
  void measure(int index, double height) {
    if (_measured[index] == height) return;
    _measured[index] = height;
  }

  /// [index] 번째 항목의 높이 — 실측이 있으면 그 값, 없으면 어림.
  ///
  /// 어림은 같은 종류(헤더/카드)로 이미 실측한 것들의 평균을 쓴다. 카드 높이는
  /// 서버 텍스트에 좌우돼 고정값이 잘 맞지 않는데, 실제로 본 카드들의 평균은
  /// 그 피드의 경향을 그대로 반영한다.
  double heightOf(int index) {
    final measured = _measured[index];
    if (measured != null) return measured;
    final isHeader = index >= 0 && index < _items.length
        ? _items[index].isHeader
        : false;
    var sum = 0.0;
    var count = 0;
    for (final entry in _measured.entries) {
      if (entry.key >= _items.length) continue;
      if (_items[entry.key].isHeader != isHeader) continue;
      sum += entry.value;
      count++;
    }
    if (count > 0) return sum / count;
    return isHeader ? fallbackHeaderHeight : fallbackCardHeight;
  }

  /// 목록 맨 위에서 [index] 번째 항목까지의 거리.
  double offsetOf(int index) {
    var offset = 0.0;
    final limit = index < _items.length ? index : _items.length;
    for (var i = 0; i < limit; i++) {
      offset += heightOf(i);
    }
    return offset;
  }

  /// [day] 날짜 헤더가 몇 번째 칸인지. 그 날짜 그룹이 없으면 -1.
  int indexOfDay(DateTime day) =>
      _items.indexWhere((item) => item is FeedDateHeader && item.day == day);
}
