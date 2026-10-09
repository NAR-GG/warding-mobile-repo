import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../repository/home/home_sources.dart';

/// 솔랭 카드 응원의 낙관적 집계와 묶음 전송.
///
/// - 탭 한 번은 바로 [totalOf]·[mineOf] 에 반영한다(낙관적).
/// - 서버에는 탭마다 보내지 않는다. 마지막 탭 후 [debounce], 또는 첫 미전송 탭부터
///   [maxWait] 가 지나면 선수별로 모아 `count`(최대 [maxPerRequest])로 한 번에 보낸다.
/// - 앱이 백그라운드로 가거나 카드가 사라지면 [flushAll]/[flushMissing] 으로 남은 걸
///   보낸다.
/// - 전송이 실패해도 숫자를 되돌리지 않는다. 미결 수를 그대로 두고 다음 flush 에
///   다시 보낸다. 다만 서버가 거절(409·400)하면 재시도해도 소용없어 버린다.
/// - 서버 폴링 값은 [sync] 로 합친다. 내 낙관적 수보다 작으면 무시(max)해 숫자가
///   줄어들지 않는다.
///
/// 키는 선수 매칭 키(현재는 이름)다.
class SoloCheerController extends ChangeNotifier {
  SoloCheerController({
    required CheerSource source,
    this.debounce = const Duration(seconds: 1),
    this.maxWait = const Duration(seconds: 3),
  }) : _source = source;

  static const int maxPerRequest = 30;

  final CheerSource _source;

  /// 마지막 탭 뒤 이 시간이 지나면 보낸다.
  final Duration debounce;

  /// 계속 탭해도 첫 미전송 탭부터 이 시간이 지나면 보낸다.
  final Duration maxWait;

  final Map<String, _Entry> _entries = {};
  bool _disposed = false;

  /// 이 판 응원 수 — 서버 값과 내 낙관적 값 중 큰 쪽.
  int totalOf(String key) => _entries[key]?.total ?? 0;

  /// 내가 보탠 수.
  int mineOf(String key) => _entries[key]?.mine ?? 0;

  /// 아직 서버에 보내지 못한 수(테스트·진단용).
  int pendingOf(String key) => _entries[key]?.pending ?? 0;

  /// 폴링으로 받은 서버 값을 합친다. [playerId] 가 있으면 전송 대상으로 갱신한다.
  void sync(
    String key, {
    required int total,
    required int mine,
    int? playerId,
  }) {
    final e = _entries.putIfAbsent(key, _Entry.new);
    final beforeTotal = e.total;
    final beforeMine = e.mine;
    if (total > e.total) e.total = total;
    if (mine > e.mine) e.mine = mine;
    if (playerId != null) e.playerId = playerId;
    if (e.total != beforeTotal || e.mine != beforeMine) _notify();
  }

  /// 탭 한 번 = +1. 숫자를 바로 올리고 전송은 모아서 한다.
  void tap(String key) {
    final e = _entries.putIfAbsent(key, _Entry.new);
    e.total++;
    e.mine++;
    e.pending++;
    e.debounceTimer?.cancel();
    e.debounceTimer = Timer(debounce, () => unawaited(_flush(key)));
    e.maxTimer ??= Timer(maxWait, () {
      e.maxTimer = null;
      unawaited(_flush(key));
    });
    _notify();
  }

  /// 미결이 있는 모든 선수를 지금 보낸다(앱 백그라운드·종료).
  Future<void> flushAll() =>
      Future.wait([for (final k in _entries.keys.toList()) _flush(k)]);

  /// [liveKeys] 에 없는 선수(카드가 사라진 선수)의 미결을 보내고 정리한다.
  Future<void> flushMissing(Set<String> liveKeys) => Future.wait([
    for (final k in _entries.keys.toList())
      if (!liveKeys.contains(k)) _flush(k),
  ]);

  Future<void> _flush(String key) async {
    final e = _entries[key];
    if (e == null || e.inFlight || e.pending == 0) return;
    final id = e.playerId;
    if (id == null) return; // 전송 대상을 모른다 — 알게 되면 다음 flush 가 보낸다.
    e.debounceTimer?.cancel();
    e.maxTimer?.cancel();
    e.debounceTimer = null;
    e.maxTimer = null;

    e.inFlight = true;
    try {
      while (e.pending > 0) {
        final count = e.pending > maxPerRequest ? maxPerRequest : e.pending;
        try {
          final r = await _source.send(id, count);
          e.pending -= count;
          if (r.total > e.total) e.total = r.total;
          if (r.mine > e.mine) e.mine = r.mine;
        } on CheerRejected catch (err) {
          // 솔랭이 이미 끝났거나 범위 밖 — 응원 영역이 사라질 상태라 조용히 버린다.
          debugPrint('[Cheer] 서버가 거절해 버림: $err');
          e.pending = 0;
        } catch (err) {
          // 숫자는 되돌리지 않는다. 미결을 남겨 다음 flush 에 다시 보낸다.
          debugPrint('[Cheer] 전송 실패 — 다음 flush 에 재시도: $err');
          break;
        }
      }
    } finally {
      e.inFlight = false;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final e in _entries.values) {
      e.debounceTimer?.cancel();
      e.maxTimer?.cancel();
    }
    super.dispose();
  }
}

class _Entry {
  int total = 0;
  int mine = 0;
  int pending = 0;
  int? playerId;
  bool inFlight = false;
  Timer? debounceTimer;
  Timer? maxTimer;
}
