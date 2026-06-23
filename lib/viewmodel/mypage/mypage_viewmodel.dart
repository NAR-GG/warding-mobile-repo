import 'package:flutter/foundation.dart';

import '../../model/team.dart';
import '../../model/user_profile.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/onboarding/onboarding_repository.dart';

/// 마이페이지 ViewModel.
///
/// `GET /api/auth/me` 로 회원 정보를 받고, 응원 팀(`favoriteTeamId`)은
/// 온보딩 팀 목록에서 매칭해 이름·로고를 채운다.
class MypageViewModel extends ChangeNotifier {
  MypageViewModel({
    AuthService? auth,
    OnboardingRepository? onboarding,
  })  : _auth = auth ?? AuthService.instance,
        _onboarding = onboarding ?? OnboardingRepository.instance {
    load();
  }

  final AuthService _auth;
  final OnboardingRepository _onboarding;
  bool _disposed = false;

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  /// 회원 닉네임. 로딩 전이면 빈 문자열.
  String get nickname => _profile?.nickname ?? '';

  /// 회원 이메일. 로딩 전 또는 소셜에서 받지 못한 경우 null.
  String? get email => _profile?.email;

  /// 프로필 이미지 URL. 미설정이면 null (기본 이미지로 대체).
  String? get profileImageUrl => _profile?.profileImageUrl;

  /// 응원 팀(이름·로고 포함). 없으면 null.
  Team? _favoriteTeam;
  Team? get favoriteTeam => _favoriteTeam;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  /// 회원 정보와 응원 팀을 불러온다.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final me = await _auth.fetchMe();
      _profile = me;
      _notify(); // 닉네임 등은 먼저 보여 준다.

      final teamId = me.favoriteTeamId;
      if (teamId != null) {
        final teams = await _onboarding.fetchTeams();
        for (final t in teams) {
          if (t.id == teamId) {
            _favoriteTeam = t;
            break;
          }
        }
      } else {
        _favoriteTeam = null;
      }
    } catch (e, st) {
      _error = e;
      debugPrint('[Mypage] load 에러: $e\n$st');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
