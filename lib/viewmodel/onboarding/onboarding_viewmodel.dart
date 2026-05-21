import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../model/team.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/onboarding/onboarding_repository.dart';
import '../../repository/preference/team_preference_repository.dart';

/// 온보딩 단계.
enum OnboardingStep { league, team, player, notification }

/// 온보딩 화면 ViewModel.
///
/// 단계 이동, 팀 선택, 알림 권한 등 온보딩의 상태와 로직을 담당한다.
/// 화면 전환(Navigator)은 [onFinish] 콜백을 통해 View 에 위임한다.
class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel({
    required OnboardingRepository repository,
    required VoidCallback onFinish,
    TeamPreferenceRepository? teamPreferences,
    AuthService? authService,
  })  : _repository = repository,
        _onFinish = onFinish,
        _teamPreferences =
            teamPreferences ?? TeamPreferenceRepository.instance,
        _authService = authService ?? AuthService.instance {
    loadTeams();
  }

  final OnboardingRepository _repository;
  final VoidCallback _onFinish;
  final TeamPreferenceRepository _teamPreferences;
  final AuthService _authService;

  // ── 단계 ──────────────────────────────────────────────
  int _stepIndex = 0;

  int get stepIndex => _stepIndex;
  OnboardingStep get currentStep => OnboardingStep.values[_stepIndex];
  int get totalSteps => OnboardingStep.values.length;
  bool get isLastStep => _stepIndex == totalSteps - 1;
  bool get canGoBack => _stepIndex > 0;

  // ── 팀 ────────────────────────────────────────────────
  List<Team> _teams = const [];
  bool _teamsLoading = false;
  Object? _teamsError;
  int? _selectedTeamId;

  List<Team> get teams => _teams;
  bool get teamsLoading => _teamsLoading;
  Object? get teamsError => _teamsError;
  int? get selectedTeamId => _selectedTeamId;

  // ── 알림 ──────────────────────────────────────────────
  bool _notificationDone = false;

  bool get notificationDone => _notificationDone;

  /// 현재 단계에서 '다음'으로 진행할 수 있는지.
  bool get canProceed {
    switch (currentStep) {
      case OnboardingStep.team:
        return _selectedTeamId != null;
      case OnboardingStep.notification:
        return _notificationDone;
      case OnboardingStep.league:
      case OnboardingStep.player:
        return true;
    }
  }

  /// 다음 단계로. 마지막 단계면 선호 팀을 저장하고 온보딩을 완료한다.
  Future<void> goNext() async {
    if (!canProceed) return;
    if (isLastStep) {
      await _savePreferredTeam();
      _onFinish();
    } else {
      _stepIndex++;
      notifyListeners();
    }
  }

  /// 이전 단계로. 첫 단계에서는 호출하지 않는다([canGoBack] 확인).
  void goBack() {
    if (!canGoBack) return;
    _stepIndex--;
    notifyListeners();
  }

  /// 온보딩 건너뛰기. 선호 팀을 저장하지 않고, 혹시 남아 있던 이전
  /// 저장값도 지운 뒤 완료한다.
  Future<void> skip() async {
    await _teamPreferences.clearPreferredTeam();
    _onFinish();
  }

  /// 선택한 팀을 저장한다. 선택 안 했으면 아무것도 하지 않는다.
  ///
  /// 회원(JWT 보유)은 서버에도 저장하고(`POST /api/auth/onboarding`),
  /// 회원·비회원 모두 로컬에 캐싱해 경기 일정 헤더가 바로 읽게 한다.
  Future<void> _savePreferredTeam() async {
    final id = _selectedTeamId;
    if (id == null) return;

    Team? team;
    for (final t in _teams) {
      if (t.id == id) {
        team = t;
        break;
      }
    }

    // 회원이면 서버에 저장.
    final jwt = await _authService.jwt;
    if (jwt != null) {
      try {
        await _repository.completeOnboarding(favoriteTeamId: id, jwt: jwt);
      } catch (e) {
        debugPrint('[Onboarding] 서버 온보딩 저장 실패: $e');
      }
    }

    // 회원·비회원 모두 로컬에 캐싱 (헤더가 로컬에서 읽음).
    if (team != null) {
      await _teamPreferences.savePreferredTeam(team);
    }
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
