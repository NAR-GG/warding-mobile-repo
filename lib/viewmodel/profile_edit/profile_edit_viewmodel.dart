import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../model/team.dart';
import '../../model/user_profile.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/onboarding/onboarding_repository.dart';

/// 프로필 수정 화면 ViewModel.
///
/// `GET /api/auth/me` 로 현재 회원 정보를 불러와 폼을 채우고,
/// 응원 팀 선택지는 온보딩 팀 목록으로 채운다. 갤러리에서 고른 사진은
/// 화면 안에서만 미리보기로 보여 주고, 저장 시에는 닉네임·응원 팀만
/// `PUT /api/auth/me` 로 반영한다 (사진 서버 업로드는 미연결 상태).
class ProfileEditViewModel extends ChangeNotifier {
  ProfileEditViewModel({
    AuthService? auth,
    OnboardingRepository? onboarding,
    ImagePicker? picker,
  }) : _auth = auth ?? AuthService.instance,
       _onboarding = onboarding ?? OnboardingRepository.instance,
       _picker = picker ?? ImagePicker() {
    load();
  }

  final AuthService _auth;
  final OnboardingRepository _onboarding;
  final ImagePicker _picker;
  bool _disposed = false;

  /// 초기 로드된 프로필 — 변경 여부 비교 기준이자 PUT 시 기존
  /// 프로필 이미지 URL 의 출처.
  UserProfile? _profile;
  UserProfile? get profile => _profile;

  /// 응원 팀 선택지.
  List<Team> _teams = const [];
  List<Team> get teams => _teams;

  String _nickname = '';
  String get nickname => _nickname;

  int? _favoriteTeamId;
  int? get favoriteTeamId => _favoriteTeamId;

  /// 갤러리에서 고른 로컬 미리보기 경로. 서버 업로드를 하지 않으므로
  /// 화면 안에서만 보인다. 화면을 벗어나면 사라진다.
  String? _pendingImagePath;
  String? get pendingImagePath => _pendingImagePath;

  /// 닉네임 옆 에러 메시지. null 이면 정상.
  String? _nicknameError;
  String? get nicknameError => _nicknameError;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  /// 서버에 실제로 반영되는 변경만 dirty 로 본다. 사진은 미리보기만
  /// 되므로 dirty 에 포함하지 않는다(사진만 골라도 완료 버튼은 비활성).
  bool get _dirty {
    final p = _profile;
    if (p == null) return false;
    return _nickname.trim() != p.nickname ||
        _favoriteTeamId != p.favoriteTeamId;
  }

  /// 완료 버튼 활성 조건.
  bool get canSubmit {
    if (_isSaving) return false;
    return _dirty &&
        _nickname.trim().isNotEmpty &&
        _nicknameError == null &&
        _favoriteTeamId != null;
  }

  Future<void> load() async {
    _isLoading = true;
    _notify();
    try {
      final results = await Future.wait([
        _auth.fetchMe(),
        _onboarding.fetchTeams(),
      ]);
      _profile = results[0] as UserProfile;
      _teams = results[1] as List<Team>;
      _nickname = _profile!.nickname;
      _favoriteTeamId = _profile!.favoriteTeamId;
      _nicknameError = null;
    } catch (e, st) {
      debugPrint('[ProfileEdit] load 에러: $e\n$st');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void updateNickname(String value) {
    _nickname = value;
    _nicknameError = value.trim().isEmpty ? '필수 입력 항목입니다.' : null;
    _notify();
  }

  void selectTeam(int teamId) {
    if (_favoriteTeamId == teamId) return;
    _favoriteTeamId = teamId;
    _notify();
  }

  /// 갤러리를 열어 새 프로필 사진을 고른다. 사용자가 취소하면 아무 일도
  /// 하지 않는다. 고른 파일은 [pendingImagePath] 에 미리보기로만 보관된다.
  Future<void> pickProfileImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (picked == null) return;
      _pendingImagePath = picked.path;
      _notify();
    } catch (e, st) {
      debugPrint('[ProfileEdit] pickImage 에러: $e\n$st');
    }
  }

  /// 저장. 닉네임·응원 팀만 PUT 한다. 프로필 이미지 URL 은
  /// 기존 값(서버가 알고 있는 값)을 그대로 다시 보낸다.
  Future<bool> save() async {
    if (!canSubmit) return false;
    _isSaving = true;
    _nicknameError = null;
    _notify();
    try {
      final updated = await _auth.updateProfile(
        nickname: _nickname.trim(),
        favoriteTeamId: _favoriteTeamId!,
        profileImageUrl: _profile?.profileImageUrl,
      );
      _profile = updated;
      return true;
    } on NicknameConflictException {
      _nicknameError = '이미 사용 중인 닉네임입니다';
      return false;
    } catch (e, st) {
      debugPrint('[ProfileEdit] save 에러: $e\n$st');
      _nicknameError = '저장에 실패했어요. 잠시 후 다시 시도해 주세요.';
      return false;
    } finally {
      _isSaving = false;
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
