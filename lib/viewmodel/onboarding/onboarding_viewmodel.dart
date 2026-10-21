import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../model/league.dart';
import '../../model/onboarding_selection.dart';
import '../../model/player.dart';
import '../../model/team.dart';
import '../../repository/auth/auth_service.dart';
import '../../util/analytics.dart';
import '../../util/analytics_events.dart';
import '../../repository/onboarding/onboarding_repository.dart';
import '../../repository/preference/onboarding_preference_repository.dart';
import '../../repository/preference/team_preference_repository.dart';

/// 온보딩 단계.
enum OnboardingStep { league, team, player, notification }

/// 온보딩 화면 ViewModel.
///
/// 단계 이동, 리그·팀·선수 선택, 알림 권한 등 온보딩의 상태와 로직을 담당한다.
/// 화면 전환(Navigator)은 [onFinish] 콜백을 통해 View 에 위임한다.
class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel({
    required OnboardingRepository repository,
    required VoidCallback onFinish,
    TeamPreferenceRepository? teamPreferences,
    OnboardingPreferenceRepository? onboardingPreferences,
    AuthService? authService,
  }) : _repository = repository,
       _onFinish = onFinish,
       _teamPreferences = teamPreferences ?? TeamPreferenceRepository.instance,
       _onboardingPreferences =
           onboardingPreferences ?? OnboardingPreferenceRepository.instance,
       _authService = authService ?? AuthService.instance {
    loadLeagues();
    loadTeams();
    _loadLoginStatus();
    _trackSectionView();
  }

  /// 회원/비회원 여부. `login_status` 로 실린다.
  ///
  /// 온보딩 진입 경로는 둘 다 `prev_page=login` 이라(로그인 성공, 비회원
  /// 시작) 이 값이 회원 온보딩과 비회원 온보딩을 가르는 유일한 구분자다.
  /// JWT 조회가 비동기라 진입 직후 몇 프레임은 null 이고, 그때는 키를
  /// 보내지 않는다(설계 문서 14번).
  bool? _loggedIn;

  /// `login_status` 전송 값. 아직 모르면 null.
  String? get loginStatusValue => switch (_loggedIn) {
    true => AnalyticsValue.loggedIn,
    false => AnalyticsValue.guest,
    null => null,
  };

  /// 트래킹용 값이라 실패가 온보딩을 막아선 안 된다 — 못 읽으면 키를
  /// 보내지 않고 넘어간다([Analytics] 가 예외를 삼키는 것과 같은 방침).
  Future<void> _loadLoginStatus() async {
    try {
      final jwt = await _authService.jwt;
      _loggedIn = jwt != null && jwt.isNotEmpty;
    } catch (e) {
      debugPrint('[Onboarding] login_status 확인 실패: $e');
    }
  }

  /// `section_view` 를 이미 쏜 단계. 뒤로 돌아온 재노출은 찍지 않는다 —
  /// 퍼널 분모("각 단계에 몇 명이 도달했나")가 흐려지지 않게 한다.
  /// 화면을 나갔다 다시 들어오면 ViewModel 이 새로 만들어져 초기화된다.
  final Set<OnboardingStep> _viewedSteps = {};

  /// 지금 단계의 `section_view`. 온보딩 단계는 스크롤 노출이 아니라 위젯
  /// 교체라(한 단계만 존재하고 항상 화면 100%) '50% 노출' 판정 없이 전환
  /// 시점에 찍는다(설계 문서 15·17·19·21번).
  void _trackSectionView() {
    final step = currentStep;
    if (!_viewedSteps.add(step)) return;
    Analytics.track(AnalyticsEvent.sectionView, {
      AnalyticsProp.locationPage: AnalyticsPage.onboarding,
      AnalyticsProp.locationSection: AnalyticsFormat.onboardingStep(step),
    });
  }

  /// 리그·팀·선수 조회가 응답을 기다리는 동안 사용자가 뒤로 가거나 건너뛰면
  /// 화면이 이 모델을 dispose 한다. 그 뒤에 `notifyListeners()` 가 불리면
  /// 예외가 난다 — 온보딩은 탭해서 넘기는 화면이라 실제로 닿는다.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  final OnboardingRepository _repository;
  final VoidCallback _onFinish;
  final TeamPreferenceRepository _teamPreferences;
  final OnboardingPreferenceRepository _onboardingPreferences;
  final AuthService _authService;

  // ── 단계 ──────────────────────────────────────────────
  int _stepIndex = 0;

  int get stepIndex => _stepIndex;
  OnboardingStep get currentStep => OnboardingStep.values[_stepIndex];
  int get totalSteps => OnboardingStep.values.length;
  bool get isLastStep => _stepIndex == totalSteps - 1;
  bool get canGoBack => _stepIndex > 0;

  // ── 리그 ──────────────────────────────────────────────
  List<League> _leagues = const [];
  bool _leaguesLoading = false;
  Object? _leaguesError;
  String? _selectedLeagueName;

  List<League> get leagues => _leagues;
  bool get leaguesLoading => _leaguesLoading;
  Object? get leaguesError => _leaguesError;
  String? get selectedLeagueName => _selectedLeagueName;

  // ── 팀 ────────────────────────────────────────────────
  List<Team> _teams = const [];
  bool _teamsLoading = false;
  Object? _teamsError;
  int? _selectedTeamId;

  List<Team> get teams => _teams;
  bool get teamsLoading => _teamsLoading;
  Object? get teamsError => _teamsError;
  int? get selectedTeamId => _selectedTeamId;

  /// 현재 선택된 팀. 선택 전이거나 목록에 없으면 null.
  Team? get selectedTeam {
    for (final t in _teams) {
      if (t.id == _selectedTeamId) return t;
    }
    return null;
  }

  // ── 선수 ──────────────────────────────────────────────
  List<Player> _players = const [];
  bool _playersLoading = false;
  Object? _playersError;
  bool _playersLoaded = false;
  // 선수 목록을 마지막으로 불러온 기준 팀 ID.
  int? _playersTeamId;
  final Set<int> _selectedPlayerIds = {};

  List<Player> get players => _players;
  bool get playersLoading => _playersLoading;
  Object? get playersError => _playersError;
  int get selectedPlayerCount => _selectedPlayerIds.length;
  bool isPlayerSelected(int id) => _selectedPlayerIds.contains(id);

  // ── 알림 ──────────────────────────────────────────────
  bool _notificationDone = false;

  bool get notificationDone => _notificationDone;

  /// 현재 단계에서 '다음'으로 진행할 수 있는지.
  bool get canProceed {
    switch (currentStep) {
      case OnboardingStep.league:
        return _selectedLeagueName != null;
      case OnboardingStep.team:
        return _selectedTeamId != null;
      case OnboardingStep.player:
        // 선수는 선택하지 않아도 진행할 수 있다 (중복 선택만 허용).
        return true;
      case OnboardingStep.notification:
        return _notificationDone;
    }
  }

  /// 다음 단계로. 마지막 단계면 선택 결과를 저장하고 온보딩을 완료한다.
  Future<void> goNext() async {
    if (!canProceed) return;

    // 마지막 단계에서는 버튼 라벨이 '와딩 시작하기'로 바뀌고 온보딩 완료를
    // 뜻한다(같은 핸들러). 그래서 `step=notification` 인 이 이벤트가 온보딩
    // 완료 지표다(설계 문서 23번). selected_count 는 리그·팀이 항상 1 이라
    // 무의미하므로 선수 단계에만 싣는다.
    Analytics.track(AnalyticsEvent.nextButtonClick, {
      AnalyticsProp.locationPage: AnalyticsPage.onboarding,
      AnalyticsProp.step: AnalyticsFormat.onboardingStep(currentStep),
      if (currentStep == OnboardingStep.player)
        AnalyticsProp.selectedCount: _selectedPlayerIds.length,
    });

    if (isLastStep) {
      await _savePreferences();
      _onFinish();
      return;
    }
    _stepIndex++;
    // 선수 단계 진입 시, 선택한 팀 기준으로 선수 목록을 준비한다.
    if (currentStep == OnboardingStep.player &&
        (!_playersLoaded || _playersTeamId != _selectedTeamId)) {
      loadPlayers();
    }
    // 알림 단계 진입 시 이미 권한이 허용돼 있으면(예: 이전에 다른 경로로
    // 허용한 경우) 화면을 보여주지 않고 곧장 다음(완료)으로 넘어간다.
    if (currentStep == OnboardingStep.notification && !_notificationDone) {
      final status = await Permission.notification.status;
      if (status.isGranted) _notificationDone = true;
    }
    if (currentStep == OnboardingStep.notification && _notificationDone) {
      // 권한이 이미 허용돼 있으면 이 단계는 화면을 그리지 않고 통과한다 —
      // section_view(notification) 가 발생하지 않으므로, player → notification
      // 전환율에는 그 사용자들이 이탈처럼 섞인다(설계 문서 21번).
      await goNext();
      return;
    }
    _trackSectionView();
    _safeNotify();
  }

  /// 이전 단계로. 첫 단계에서는 호출하지 않는다([canGoBack] 확인).
  ///
  /// 되돌아온 단계의 `section_view` 는 다시 찍지 않는다([_viewedSteps]).
  void goBack() {
    if (!canGoBack) return;
    _stepIndex--;
    _safeNotify();
  }

  /// 온보딩 건너뛰기. 선호 팀·온보딩 selection 로컬 저장값을 지운 뒤 완료한다.
  Future<void> skip() async {
    // 이름과 달리 단계 건너뛰기가 아니라 온보딩 전체 포기다 — 아래에서
    // 선택값을 모두 지우고 종료한다. step 은 "어느 단계에서 포기했는지"를
    // 뜻하며 그것이 이 값의 유일한 의미다(설계 문서 24번).
    Analytics.track(AnalyticsEvent.skipButtonClick, {
      AnalyticsProp.locationPage: AnalyticsPage.onboarding,
      AnalyticsProp.step: AnalyticsFormat.onboardingStep(currentStep),
    });
    await _teamPreferences.clearPreferredTeam();
    await _onboardingPreferences.clear();
    _onFinish();
  }

  /// 선택한 선호 리그·팀·선수를 저장하고 온보딩을 마무리한다.
  ///
  /// 회원(JWT 보유)은 서버에 저장하고(`POST /api/auth/onboarding`) 로컬
  /// selection 을 지운다. 비회원은 selection 을 로컬에 저장해 두었다가 로그인
  /// 시 동기화한다. 회원·비회원 모두 선호 팀은 로컬에 캐싱해 헤더가 읽게 한다.
  Future<void> _savePreferences() async {
    final teamId = _selectedTeamId;
    if (teamId == null) return;

    final team = selectedTeam;

    final jwt = await _authService.jwt;
    if (jwt != null) {
      try {
        await _repository.completeOnboarding(
          favoriteLeagueName: _selectedLeagueName,
          favoriteTeamId: teamId,
          favoritePlayerIds: _selectedPlayerIds.toList(),
          jwt: jwt,
        );
        // 서버 저장 성공 시에만 로컬 selection 제거(실패 시 보존, 다음 로그인에 재시도).
        await _onboardingPreferences.clear();
      } catch (e) {
        debugPrint('[Onboarding] 서버 온보딩 저장 실패: $e');
      }
    } else {
      // 비회원: 로그인 시 동기화할 selection 을 로컬에 저장.
      await _onboardingPreferences.saveSelection(
        OnboardingSelection(
          leagueName: _selectedLeagueName,
          teamId: teamId,
          playerIds: _selectedPlayerIds.toList(),
        ),
      );
    }

    // 회원·비회원 모두 로컬에 팀 캐싱 (헤더가 로컬에서 읽음).
    if (team != null) {
      await _teamPreferences.savePreferredTeam(team);
    }
  }

  /// 온보딩용 리그 목록을 불러온다.
  Future<void> loadLeagues() async {
    _leaguesLoading = true;
    _leaguesError = null;
    _safeNotify();
    try {
      _leagues = await _repository.fetchLeagues();
    } catch (e) {
      _leaguesError = appStrings?.leagueLoadFailed ?? 'Failed to load leagues';
      debugPrint('[Onboarding] loadLeagues 에러: $e');
    } finally {
      _leaguesLoading = false;
      _safeNotify();
    }
  }

  void selectLeague(String name) {
    _selectedLeagueName = name;
    // 해제가 없다(덮어쓰기만) — 그래서 is_on 을 싣지 않는다. 다른 리그로
    // 갈아타면 이벤트가 다시 찍히고 최종 선택은 마지막 이벤트다.
    Analytics.track(AnalyticsEvent.leagueCardClick, {
      AnalyticsProp.locationPage: AnalyticsPage.onboarding,
      AnalyticsProp.locationSection: AnalyticsSection.league,
      AnalyticsProp.league: AnalyticsFormat.league(name),
    });
    _safeNotify();
  }

  /// 온보딩용 팀 목록을 불러온다.
  Future<void> loadTeams() async {
    _teamsLoading = true;
    _teamsError = null;
    _safeNotify();
    try {
      _teams = await _repository.fetchTeams();
    } catch (e) {
      _teamsError = appStrings?.teamLoadFailed ?? 'Failed to load teams';
      debugPrint('[Onboarding] loadTeams 에러: $e');
    } finally {
      _teamsLoading = false;
      _safeNotify();
    }
  }

  void selectTeam(int id) {
    _selectedTeamId = id;
    // 리그와 같이 해제가 없어 is_on 을 싣지 않는다.
    Analytics.track(AnalyticsEvent.teamCardClick, {
      AnalyticsProp.locationPage: AnalyticsPage.onboarding,
      AnalyticsProp.locationSection: AnalyticsSection.team,
      AnalyticsProp.teamId: id,
    });
    _safeNotify();
  }

  /// 온보딩용 선수 목록을 불러온다. 선택한 팀이 있으면 그 팀 선수만 조회한다.
  ///
  /// 팀이 바뀌어도 이미 고른 선수 선택은 유지한다(여러 팀에서 중복 선택 가능).
  Future<void> loadPlayers() async {
    final teamId = _selectedTeamId;
    _playersTeamId = teamId;
    _playersLoading = true;
    _playersError = null;
    _safeNotify();
    try {
      _players = await _repository.fetchPlayers(
        year: DateTime.now().year,
        teamId: teamId,
      );
      _playersLoaded = true;
    } catch (e) {
      _playersError = appStrings?.playerLoadFailed ?? 'Failed to load players';
      debugPrint('[Onboarding] loadPlayers 에러: $e');
    } finally {
      _playersLoading = false;
      _safeNotify();
    }
  }

  /// 선수 선택을 토글한다. 이미 선택돼 있으면 해제한다 (중복 선택 가능).
  void togglePlayer(int id) {
    if (!_selectedPlayerIds.add(id)) {
      _selectedPlayerIds.remove(id);
    }
    // 세 단계 중 유일하게 해제가 실제로 있어 is_on 이 유의미하다.
    Analytics.track(AnalyticsEvent.playerCardClick, {
      AnalyticsProp.locationPage: AnalyticsPage.onboarding,
      AnalyticsProp.locationSection: AnalyticsSection.player,
      AnalyticsProp.playerId: id,
      AnalyticsProp.isOn: _selectedPlayerIds.contains(id),
    });
    _safeNotify();
  }

  /// 선수 단계의 '팀' 셀렉트에서 기준 팀을 바꾼다.
  ///
  /// 선호 팀(`selectedTeamId`)을 함께 갱신하고, 새 팀 기준으로 선수 목록을
  /// 다시 불러온다. 이미 고른 선수 선택은 팀을 바꿔도 유지된다. 같은 팀이면
  /// 아무것도 하지 않는다.
  Future<void> changePlayerTeam(int id) async {
    if (id == _selectedTeamId) return;
    _selectedTeamId = id;
    _safeNotify();
    await loadPlayers();
  }

  void markNotificationDone() {
    if (_notificationDone) return;
    _notificationDone = true;
    _safeNotify();
  }

  /// 알림 권한을 요청한다. 영구 거부 상태면 앱 설정으로 보낸다.
  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    // 클릭 시점이 아니라 **OS 응답이 확정된 뒤** 찍는다. 앱 내 '나중에'
    // 버튼([denyNotification])은 OS 다이얼로그를 아예 띄우지 않으므로
    // OS 거부와 같은 값으로 묶지 않는다(설계 문서 22번).
    _trackPermissionResult(switch (status) {
      PermissionStatus.granted => AnalyticsPermissionResult.osGranted,
      PermissionStatus.permanentlyDenied =>
        AnalyticsPermissionResult.osPermanentlyDenied,
      _ => AnalyticsPermissionResult.osDenied,
    });
    if (status.isGranted) {
      markNotificationDone();
    } else if (status.isPermanentlyDenied) {
      // 설정 앱으로 앱을 벗어나는 이탈 지점이다.
      await openAppSettings();
    }
  }

  /// 앱 내 '나중에' — OS 권한 요청 없이 단계를 넘긴다.
  ///
  /// [markNotificationDone] 은 OS 허용 경로에서도 불리므로, 그쪽과 섞이지
  /// 않게 거부 전용 입구를 따로 둔다.
  void denyNotification() {
    _trackPermissionResult(AnalyticsPermissionResult.inAppDeny);
    markNotificationDone();
  }

  void _trackPermissionResult(String result) {
    Analytics.track(AnalyticsEvent.pushPermissionButtonClick, {
      AnalyticsProp.locationPage: AnalyticsPage.onboarding,
      AnalyticsProp.locationSection: AnalyticsSection.notification,
      AnalyticsProp.permissionResult: result,
    });
  }

  /// 설정 화면을 다녀온 뒤 권한 상태를 다시 확인한다.
  Future<void> recheckNotificationPermission() async {
    if (currentStep != OnboardingStep.notification || _notificationDone) {
      return;
    }
    final status = await Permission.notification.status;
    if (status.isGranted) {
      markNotificationDone();
    }
  }
}
