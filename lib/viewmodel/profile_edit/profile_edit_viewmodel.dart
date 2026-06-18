import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../model/team.dart';
import '../../model/user_profile.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/onboarding/onboarding_repository.dart';
import '../../repository/profile/profile_image_repository.dart';

/// 프로필 수정 화면 ViewModel.
///
/// `GET /api/auth/me` 로 현재 회원 정보를 불러와 폼을 채우고,
/// 응원 팀 선택지는 온보딩 팀 목록으로 채운다. 사용자가 갤러리에서
/// 새 프로필 사진을 고르면 로컬 파일로 미리 보여 주고, 완료 시
/// Firebase Storage 에 업로드해 받은 URL 과 함께
/// `PUT /api/auth/me` 로 닉네임·응원 팀·프로필 이미지를 저장한다.
class ProfileEditViewModel extends ChangeNotifier {
  ProfileEditViewModel({
    AuthService? auth,
    OnboardingRepository? onboarding,
    ProfileImageRepository? imageRepository,
    ImagePicker? picker,
  }) : _auth = auth ?? AuthService.instance,
       _onboarding = onboarding ?? OnboardingRepository.instance,
       _imageRepository = imageRepository ?? ProfileImageRepository.instance,
       _picker = picker ?? ImagePicker() {
    load();
  }

  final AuthService _auth;
  final OnboardingRepository _onboarding;
  final ProfileImageRepository _imageRepository;
  final ImagePicker _picker;
  bool _disposed = false;

  /// 초기 로드된 프로필 — 변경 여부 비교 기준이자, 저장 시 함께 보낼
  /// 프로필 이미지 URL 의 출처(미선택 시).
  UserProfile? _profile;
  UserProfile? get profile => _profile;

  /// 응원 팀 선택지.
  List<Team> _teams = const [];
  List<Team> get teams => _teams;

  String _nickname = '';
  String get nickname => _nickname;

  int? _favoriteTeamId;
  int? get favoriteTeamId => _favoriteTeamId;

  /// 사용자가 갤러리에서 새로 고른 이미지 파일 경로. 저장 전까지는 아직
  /// 업로드되지 않은 로컬 미리보기 상태다. 저장 성공 시 null 로 비운다.
  String? _pendingImagePath;
  String? get pendingImagePath => _pendingImagePath;

  /// 닉네임 옆 에러 메시지. null 이면 정상.
  String? _nicknameError;
  String? get nicknameError => _nicknameError;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  /// 초기값 대비 변경사항 존재 여부.
  bool get _dirty {
    final p = _profile;
    if (p == null) return false;
    return _nickname.trim() != p.nickname ||
        _favoriteTeamId != p.favoriteTeamId ||
        _pendingImagePath != null;
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
  /// 하지 않는다. 고른 파일은 [pendingImagePath] 에 보관되어 저장 시
  /// 업로드된다.
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

  /// 저장. 성공이면 true. 닉네임 충돌·업로드/저장 실패는 false 와 함께
  /// [nicknameError] 메시지에 표시된다.
  Future<bool> save() async {
    if (!canSubmit) return false;
    _isSaving = true;
    _nicknameError = null;
    _notify();
    try {
      var imageUrl = _profile?.profileImageUrl;
      // 새 사진을 골랐다면 Firebase Storage 에 먼저 업로드.
      final pending = _pendingImagePath;
      if (pending != null) {
        imageUrl = await _imageRepository.upload(
          userId: _profile!.id,
          file: File(pending),
        );
      }
      final updated = await _auth.updateProfile(
        nickname: _nickname.trim(),
        favoriteTeamId: _favoriteTeamId!,
        profileImageUrl: imageUrl,
      );
      _profile = updated;
      _pendingImagePath = null;
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
