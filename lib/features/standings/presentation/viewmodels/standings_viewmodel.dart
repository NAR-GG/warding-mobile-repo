import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:warding/core/config/home_mocks.dart';
import 'package:warding/core/di_container.dart';
import 'package:warding/core/error/failure_exception.dart';
import 'package:warding/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:warding/features/standings/domain/league_chip.dart';
import 'package:warding/features/standings/domain/repositories/standings_repository.dart';
import 'package:warding/features/standings/domain/standing.dart';
import 'package:warding/features/standings/domain/worlds_standings.dart';

/// 대진 카드가 보여주는 뷰. 하단 버튼으로 전환한다.
enum StandingsView { swiss, knockout }

/// 다른 화면에 끼워 넣는 순위표 섹션의 상태 — 리그 칩 + 표/대진.
///
/// **표인지 대진인지는 응답이 정한다.** 리그 코드로 분기하지 않는다
/// (아래 [loadStandings] 주석 참고).
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [loadLeagueChips]·
/// [loadStandings] 로 정한다.
class StandingsViewModel extends ChangeNotifier {
  StandingsViewModel({
    StandingsRepository? repository,
    ScheduleRepository? schedule,
  }) : _repo = repository ?? di<StandingsRepository>(),
       _schedule = schedule ?? di<ScheduleRepository>();

  final StandingsRepository _repo;

  /// 리그 칩 메타는 일정 필터 API 가 함께 내려준다.
  final ScheduleRepository _schedule;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  static const List<LeagueChip> _fallbackLeagueChips = [
    LeagueChip(code: 'LCK', label: 'LCK', live: true),
    LeagueChip(code: 'LPL', label: 'LPL', live: false),
    LeagueChip(code: 'LEC', label: 'LEC', live: false),
    LeagueChip(code: 'LCS', label: 'LCS', live: false),
    LeagueChip(code: 'WORLDS', label: '월즈', live: false),
  ];

  /// 서버 응답을 받기 전에는 기본 리그 칩 하나만 둔다 — 폴백 5개를 먼저 그렸다가
  /// 서버가 지운 칩이 사라지는 깜빡임을 피한다.
  List<LeagueChip> _leagueChips = const [
    LeagueChip(code: 'LCK', label: 'LCK', live: true),
  ];

  List<LeagueChip> get leagueChips => _leagueChips;

  /// 칩 라벨 **폴백** — 서버 `name` 이 비었을 때만 쓴다. 월즈만 한글,
  /// 나머지는 리그 코드 그대로. 서버가 표시명을 주면 그쪽이 이긴다.
  static String _chipLabel(String code) => code == 'WORLDS' ? '월즈' : code;

  /// 서버가 `standings: true` 를 준 리그가 실제로 순위표를 주는지(`supported`)
  /// 확인한 결과와 시각. 등록만 되고 데이터가 없는 리그(예: DEMACIA_CUP
  /// `UNAVAILABLE`)는 칩을 켜 줘도 표가 비어, 점선으로 처리한다.
  final Map<String, (DateTime, bool)> _standingsSupport = {};
  static const Duration _standingsSupportTtl = Duration(minutes: 10);

  Future<bool> _isStandingsSupported(String code) async {
    final cached = _standingsSupport[code];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < _standingsSupportTtl) {
      return cached.$2;
    }
    final outcome = await _repo.fetchStandings(code);
    return outcome.match(
      (failure) {
        // 확인 실패로 칩을 숨기지 않는다 — 서버 값을 믿는다.
        debugPrint('[Standings] 순위표 지원 확인 실패($code): $failure');
        return true;
      },
      (result) {
        // `supported: false` 여도 대진이 실려 왔으면 그릴 게 있다 — 리그
        // 테이블이 없다는 뜻이지 보여줄 게 없다는 뜻이 아니다. 예전엔 월즈를
        // 코드로 예외 처리했는데, 이제 응답으로 판단한다.
        final usable = result.supported || result.hasBracket;
        _standingsSupport[code] = (DateTime.now(), usable);
        return usable;
      },
    );
  }

  Future<void> loadLeagueChips() async {
    List<LeagueChip> chips;
    // 서버가 준 기본 리그. 메타를 못 받으면 비어 있고, 그때는 기존 기본값을
    // 그대로 둔다.
    String serverDefault = '';
    try {
      final options = (await _schedule.fetchFilterOptions())
          .getOrElse((f) => throw FailureException(f));
      serverDefault = options.defaultLeague;
      if (!options.hasLeagueMeta) {
        chips = _fallbackLeagueChips;
      } else {
        // 순서는 서버가 준 그대로다 — 앱에서 다시 정렬하지 않는다. 예전엔
        // LCK·LPL·LEC·LCS·월즈를 앞으로 당기는 고정 순서를 뒀는데, 그러면
        // 백엔드가 순서를 바꿔도 앱 배포 전엔 반영되지 않는다.
        final served = [
          for (final l in options.leagues)
            if (l.code != 'ALL' && l.standings != null) l,
        ];
        chips = await Future.wait([
          for (final l in served)
            () async {
              final live =
                  l.standings == true && await _isStandingsSupported(l.code);
              return LeagueChip(
                code: l.code,
                // 서버가 준 표시명을 쓴다. 비어 있을 때만 앱 라벨로 폴백 —
                // 예전엔 서버 `name` 을 버리고 코드로만 라벨을 만들어서,
                // 백엔드가 표시명을 바꿔도 앱 배포 전엔 반영되지 않았다.
                label: l.name.isNotEmpty ? l.name : _chipLabel(l.code),
                live: live,
              );
            }(),
        ]);
      }
    } catch (e) {
      debugPrint('[Standings] 리그 칩 조회 실패(하드코딩 폴백): $e');
      chips = _fallbackLeagueChips;
    }
    if (_disposed) return;
    _leagueChips = chips;

    // 기본 선택도 서버가 정한다(`defaultLeague`). 앱은 'LCK' 를 박아 뒀는데,
    // 서버가 그 리그를 안 주거나(칩 없음) 데이터가 없으면(점선) **선택된 칩이
    // 목록에 없는 상태**가 된다 — 순위표 자리가 빈 채로 열린다.
    //
    // 지켜야 할 불변식: **선택된 리그는 항상 고를 수 있는 칩이어야 한다.**
    // 그래서 사용자가 고른 리그라도(_leagueTouched) 그게 더 이상 live 가
    // 아니면 그대로 둘 수 없다 — 그 경우에도 떨어뜨린다. 반대로 사용자가 고른
    // 리그가 아직 live 면 서버 기본값으로 되돌리지 않는다.
    final livable = chips.where((c) => c.live).map((c) => c.code).toList();
    final keepsCurrent = livable.contains(_selectedLeague);
    final String next;
    if (_leagueTouched && keepsCurrent) {
      next = _selectedLeague; // 사용자 선택이 아직 유효하다
    } else if (livable.contains(serverDefault)) {
      next = serverDefault;
    } else if (keepsCurrent) {
      next = _selectedLeague;
    } else if (livable.isNotEmpty) {
      next = livable.first;
    } else {
      next = _selectedLeague; // 고를 수 있는 칩이 하나도 없다 — 그대로 둔다
    }
    if (next != _selectedLeague) {
      _selectedLeague = next;
      _clearStandings();
      unawaited(loadStandings());
    }
    _notify();
  }

  /// 사용자가 칩을 직접 골랐는지. 칩 목록이 늦게 도착해도 그 선택을 덮지
  /// 않으려고 둔다(홈 진입 직후 칩을 누르면 두 흐름이 겹친다).
  bool _leagueTouched = false;

  String _selectedLeague = 'LCK';
  String get selectedLeague => _selectedLeague;

  void selectLeague(String code) {
    final selectable = _leagueChips.any((c) => c.code == code && c.live);
    if (!selectable || code == _selectedLeague) return;
    _selectedLeague = code;
    _leagueTouched = true;
    _clearStandings();
    _notify();
    // 리그 코드로 분기하지 않는다. 표인지 대진인지는 `/api/standings` 응답
    // (`reason: BRACKET_ONLY` · `bracket`)이 정한다.
    unawaited(loadStandings());
  }

  /// 리그가 바뀔 때 이전 리그의 순위표·대진을 즉시 버리고 스켈레톤으로
  /// 되돌린다. 안 비우면 새 응답이 오기 전까지 **새 칩 아래 옛 리그의 표가**
  /// 그대로 남고, 새 조회가 실패하면 계속 남는다. 대진만 비우고 표는 안
  /// 비우던 비대칭을 없앤다.
  void _clearStandings() {
    _standings = null;
    _worldsStandings = null;
    _standingsFirstLoadPending = true;
  }

  StandingsResult? _standings;

  /// 선택한 리그(LCK 등 리그 테이블 형식)의 순위표. 아직 못 받았으면 null.
  StandingsResult? get standings => _standings;

  /// 첫 순위표 응답(성공·실패 모두)이 오기 전 true — 스켈레톤을 그린다.
  bool _standingsFirstLoadPending = true;
  bool get standingsLoading => _standingsFirstLoadPending;

  Future<void> loadStandings() async {
    final league = _selectedLeague;
    final outcome = await _repo.fetchStandings(league);
    // 그 사이 리그를 바꿨으면 옛 응답은 버린다.
    if (_disposed || league != _selectedLeague) return;

    outcome.match(
      (failure) => debugPrint('[Standings] 순위표 조회 실패($league): $failure'),
      (result) {
        _standings = result;
        // 대진은 응답에 실려 왔을 때만 그린다. 안 실려 오면 리그 테이블이다.
        _worldsStandings = result.hasBracket
            ? result.bracket!.toWorldsStandings()
            : null;
        // 백엔드에 아직 대진 API 가 없어, 목업 빌드에서만 대진 UI 를 미리 본다
        // (`--dart-define=HOME_MOCKS=true`). 릴리즈에는 영향이 없다.
        if (_worldsStandings == null && kHomeMocks && !result.supported) {
          unawaited(_loadBracketMock(league));
        }
      },
    );
    // 성공·실패 모두 첫 로드는 끝난 것으로 본다(스켈레톤을 치운다).
    _standingsFirstLoadPending = false;
    _notify();
  }

  WorldsStandings? _worldsStandings;

  /// 대진 데이터(스위스 전적 + 토너먼트). 리그 테이블 형식이면 null.
  ///
  /// 이름이 `worlds` 인 건 월즈용으로 먼저 만들었기 때문이고, 지금은 응답이
  /// `bracket` 을 주는 어느 리그든 여기에 담긴다.
  WorldsStandings? get worldsStandings => _worldsStandings;

  /// 대진 UI 미리보기용 목업. `HOME_MOCKS=true` 빌드에서만 값이 온다.
  Future<void> _loadBracketMock(String league) async {
    try {
      final result = await _repo.fetchWorldsStandings();
      if (_disposed || league != _selectedLeague) return;
      _worldsStandings = result;
      _notify();
    } catch (e) {
      debugPrint('[Standings] 대진 목업 조회 실패($league): $e');
    }
  }

  /// 리그 테이블 대신 대진 카드를 그려야 하는지 — **대진 데이터가 실제로
  /// 있을 때만** true 다. 리그 코드도, `reason` 도 보지 않는다.
  bool get standingsIsBracket => _worldsStandings != null;

  StandingsView _worldsView = StandingsView.swiss;
  StandingsView get worldsView => _worldsView;

  /// 대진 카드 하단 버튼으로 스위스 전적 ↔ 토너먼트 대진을 전환한다.
  void toggleWorldsView() {
    _worldsView = _worldsView == StandingsView.swiss
        ? StandingsView.knockout
        : StandingsView.swiss;
    _notify();
  }

  /// 지금 리그에 스위스·녹아웃이 **둘 다** 있는지. 한쪽만 있으면 전환 버튼을
  /// 숨기고 있는 쪽을 그린다 — 그룹 스테이지 없이 녹아웃만 하는 대회
  /// (ASIAN_GAMES 등)에서 빈 화면으로 전환되는 걸 막는다.
  bool get worldsHasBothViews {
    final d = _worldsStandings;
    return d != null && d.bracket.isNotEmpty && d.knockout.isNotEmpty;
  }

  /// 데이터가 있는 쪽을 고른 실제 표시 뷰.
  StandingsView get effectiveWorldsView {
    final d = _worldsStandings;
    if (d == null) return _worldsView;
    if (d.bracket.isEmpty) return StandingsView.knockout;
    if (d.knockout.isEmpty) return StandingsView.swiss;
    return _worldsView;
  }

  bool _standingsExpanded = false;
  bool get standingsExpanded => _standingsExpanded;

  void toggleStandingsExpanded() {
    _standingsExpanded = !_standingsExpanded;
    _notify();
  }
}
