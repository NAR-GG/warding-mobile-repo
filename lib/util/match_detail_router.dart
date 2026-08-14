import 'package:flutter/material.dart';

import '../config/app_globals.dart';
import '../screens/match_detail/match_detail_screen.dart';

/// 딥링크로 들어오는 경기 상세를 한 장만 유지하는 진입 창구.
///
/// Live Activity 카드 · 다이나믹 아일랜드 · FCM 푸시는 모두 같은 경기 상세로
/// 향하는데, 각자 따로 `Navigator.push` 를 하고 있어서 카드를 연달아 누르면
/// 똑같은 화면이 스택에 계속 쌓였다. URL 문자열로 중복을 걸러도
/// `warding://match/1` 과 `warding://match/1?tab=rating&set=2` 는 서로 다른
/// 문자열이라 그냥 통과했다.
///
/// 여기서는 URL 이 아니라 **스택 상태**를 기준으로 판단한다.
/// - 이미 상세가 떠 있고 같은 경기면: 그 라우트까지 pop 한 뒤 탭·세트만 갱신.
/// - 이미 상세가 떠 있는데 다른 경기면: 그 상세를 걷어내고 새 상세를 push
///   (상세 위에 상세가 겹치지 않게).
/// - 없으면: 평소대로 push.
///
/// 경기 목록에서 사용자가 카드를 직접 눌러 들어가는 경로는 이 창구를 쓰지
/// 않는다 — 그건 뒤로가기 흐름이 자연스러운 일반 내비게이션이다.
class MatchDetailRouter {
  MatchDetailRouter._();

  /// 현재 떠 있는 경기 상세 화면. push 될 때 등록되고 pop 되면 지워진다.
  static final Map<Route<dynamic>, GlobalKey<MatchDetailScreenState>> _open = {};

  /// 딥링크로 경기 상세를 연다.
  ///
  /// [tabIndex] 0: 챔피언 픽, 1: 라이브 이벤트, 2: 선수 평점.
  /// [setNumber] 가 있으면 해당 세트를 선택한 상태로 연다.
  static void open({
    required String matchId,
    int tabIndex = 0,
    int? setNumber,
  }) {
    if (matchId.isEmpty) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // 이미 떠 있는 상세를 찾는다. 화면이 dispose 된 뒤에도 남아 있을 수 있어
    // (뒤로가기 등) currentState 로 살아있는지 함께 확인한다.
    _open.removeWhere((_, key) => key.currentState == null);
    final existing = _open.entries.isEmpty ? null : _open.entries.last;

    if (existing != null) {
      final state = existing.value.currentState!;
      if (state.matchId == matchId) {
        // 같은 경기 — 그 화면까지 되돌아가서 탭·세트만 갈아끼운다.
        nav.popUntil((route) => route == existing.key);
        state.applyDeepLink(tabIndex: tabIndex, setNumber: setNumber);
        debugPrint('[MatchDetailRouter] 기존 상세 재사용: $matchId '
            '(tab=$tabIndex, set=$setNumber)');
        return;
      }
      // 다른 경기 — 예전 상세는 걷어내고 새로 연다.
      // 상세가 스택의 첫 라우트면 pop 하지 않는다. 마지막 한 장을 빼면 화면이
      // 아무것도 없는 상태가 되므로, 그 경우엔 새 상세로 교체(replace)한다.
      nav.popUntil((route) => route == existing.key);
      if (nav.canPop()) {
        nav.pop();
      } else {
        // 교체되면 옛 라우트의 completed 가 완료돼 _open 에서 스스로 빠진다.
        nav.pushReplacement(
          _buildRoute(
            matchId: matchId,
            tabIndex: tabIndex,
            setNumber: setNumber,
          ),
        );
        return;
      }
    }

    debugPrint('[MatchDetailRouter] 상세 push: $matchId '
        '(tab=$tabIndex, set=$setNumber)');
    nav.push(
      _buildRoute(matchId: matchId, tabIndex: tabIndex, setNumber: setNumber),
    );
  }

  /// 상세 라우트를 만들고, 열려 있는 상세로 등록한다.
  /// 라우트가 사라지면(뒤로가기·교체) 등록도 함께 지운다.
  static MaterialPageRoute<void> _buildRoute({
    required String matchId,
    required int tabIndex,
    int? setNumber,
  }) {
    final key = GlobalKey<MatchDetailScreenState>();
    late final MaterialPageRoute<void> route;
    route = MaterialPageRoute<void>(
      builder: (_) => MatchDetailScreen(
        key: key,
        matchId: matchId,
        initialTabIndex: tabIndex,
        initialSet: setNumber,
      ),
    );
    _open[route] = key;
    route.completed.whenComplete(() => _open.remove(route));
    return route;
  }
}
