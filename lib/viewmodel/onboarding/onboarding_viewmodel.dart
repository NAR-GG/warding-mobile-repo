import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../model/league.dart';
import '../../model/onboarding_selection.dart';
import '../../model/player.dart';
import '../../model/team.dart';
import '../../repository/auth/auth_service.dart';
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
  })  : _repository = repository,
        _onFinish = onFinish,
        _teamPreferences =
            teamPreferences ?? TeamPreferenceRepository.instance,
        _onboardingPreferences =
            onboardingPreferences ?? OnboardingPreferenceRepository.instance,
        _authService = authService ?? AuthService.instance {
    loadLeagues();
    loadTeams();
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
      await goNext();
      return;
    }
    notifyListeners();
  }

  /// 이전 단계로. 첫 단계에서는 호출하지 않는다([canGoBack] 확인).
  void goBack() {
    if (!canGoBack) return;
    _stepIndex--;
    notifyListeners();
  }

  /// 온보딩 건너뛰기. 선호 팀·온보딩 selection 로컬 저장값을 지운 뒤 완료한다.
  Future<void> skip() async {
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
    notifyListeners();
    try {
      _leagues = await _repository.fetchLeagues();
    } catch (e) {
      _leaguesError = e;
    } finally {
      _leaguesLoading = false;
      notifyListeners();
    }
  }

  void selectLeague(String name) {
    _selectedLeagueName = name;
    notifyListeners();
  }

  /// 온보딩용 팀 목록을 불러온다.
  Future<void> loadTeams() async {
    _teamsLoading = true;
    _teamsError = null;
    notifyListeners();
    try {
      _teams = await _repository.fetchTeams();
    } catch (e) {
      _teamsError = e;
    } finally {
      _teamsLoading = false;
      notifyListeners();
    }
  }

  void selectTeam(int id) {
    _selectedTeamId = id;
    notifyListeners();
  }

  /// 온보딩용 선수 목록을 불러온다. 선택한 팀이 있으면 그 팀 선수만 조회한다.
  ///
  /// 팀이 바뀌어도 이미 고른 선수 선택은 유지한다(여러 팀에서 중복 선택 가능).
  Future<void> loadPlayers() async {
    final teamId = _selectedTeamId;
    _playersTeamId = teamId;
    _playersLoading = true;
    _playersError = null;
    notifyListeners();
    try {
      _players = await _repository.fetchPlayers(
        year: DateTime.now().year,
        teamId: teamId,
      );
      _playersLoaded = true;
    } catch (e) {
      _playersError = e;
    } finally {
      _playersLoading = false;
      notifyListeners();
    }
  }

  /// 선수 선택을 토글한다. 이미 선택돼 있으면 해제한다 (중복 선택 가능).
  void togglePlayer(int id) {
    if (!_selectedPlayerIds.add(id)) {
      _selectedPlayerIds.remove(id);
    }
    notifyListeners();
  }

  /// 선수 단계의 '팀' 셀렉트에서 기준 팀을 바꾼다.
  ///
  /// 선호 팀(`selectedTeamId`)을 함께 갱신하고, 새 팀 기준으로 선수 목록을
  /// 다시 불러온다. 이미 고른 선수 선택은 팀을 바꿔도 유지된다. 같은 팀이면
  /// 아무것도 하지 않는다.
  Future<void> changePlayerTeam(int id) async {
    if (id == _selectedTeamId) return;
    _selectedTeamId = id;
    notifyListeners();
    await loadPlayers();
  }

  void markNotificationDone() {
    if (_notificationDone) return;
    _notificationDone = true;
    notifyListeners();
  }

  /// 알림 권한을 요청한다. 영구 거부 상태면 앱 설정으로 보낸다.
  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      markNotificationDone();
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
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
