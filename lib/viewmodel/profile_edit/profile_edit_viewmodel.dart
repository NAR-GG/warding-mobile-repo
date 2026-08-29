import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';
import 'package:image_picker/image_picker.dart';

import '../../model/team.dart';
import '../../model/user_profile.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/onboarding/onboarding_repository.dart';
import '../../repository/profile/profile_image_repository.dart';

/// 프로필 수정 화면 ViewModel.
///
/// `GET /api/auth/me` 로 현재 회원 정보를 불러와 폼(이름·태그·응원 팀·프로필
/// 이미지)을 채우고, 응원 팀 선택지는 온보딩 팀 목록으로 채운다.
/// 저장 시 새 사진을 골랐다면 Cloudinary 에 먼저 업로드해 `secure_url` 을 얻고,
/// 이름·태그·응원 팀·이미지 URL 을 `PUT /api/auth/me` 로 반영한다.
class ProfileEditViewModel extends ChangeNotifier {
  ProfileEditViewModel({
    AuthService? auth,
    OnboardingRepository? onboarding,
    ProfileImageRepository? imageRepo,
    ImagePicker? picker,
  })  : _auth = auth ?? AuthService.instance,
        _onboarding = onboarding ?? OnboardingRepository.instance,
        _imageRepo = imageRepo ?? ProfileImageRepository.instance,
        _picker = picker ?? ImagePicker() {
    load();
  }

  /// 태그 규칙 — 영문/숫자 2~5자.
  static final RegExp _tagPattern = RegExp(r'^[A-Za-z0-9]{2,5}$');

  final AuthService _auth;
  final OnboardingRepository _onboarding;
  final ProfileImageRepository _imageRepo;
  final ImagePicker _picker;
  bool _disposed = false;

  /// 초기 로드된 프로필 — 변경 여부 비교 기준이자 PUT 시 기존
  /// 프로필 이미지 URL 의 출처.
  UserProfile? _profile;
  UserProfile? get profile => _profile;

  /// 응원 팀 선택지.
  List<Team> _teams = const [];
  List<Team> get teams => _teams;

  String _name = '';
  String get name => _name;

  String _tag = '';
  String get tag => _tag;

  int? _favoriteTeamId;
  int? get favoriteTeamId => _favoriteTeamId;

  /// 응원팀을 다시 바꿀 수 있는 시각. null 이면 지금 바꿀 수 있다.
  ///
  /// 응원팀은 30일에 한 번만 바꿀 수 있다(팀 갈아타며 게시판을 옮겨 다니는 걸
  /// 막는 규칙). 쿨다운을 **바꾸기 전에** 알려줘야 한다 — 바꾼 뒤에 알려주면
  /// 되돌릴 수가 없다.
  DateTime? get teamChangeAvailableFrom =>
      _profile?.favoriteTeamChangeAvailableFrom;

  bool get teamChangeLocked => teamChangeAvailableFrom != null;

  /// 저장하면 응원팀이 실제로 바뀌는가. 확인 팝업을 띄울 기준이다.
  bool get teamChanged =>
      _profile != null && _favoriteTeamId != _profile!.favoriteTeamId;

  /// 갤러리에서 고른 로컬 미리보기 경로. 저장 시 Cloudinary 로 업로드된다.
  String? _pendingImagePath;
  String? get pendingImagePath => _pendingImagePath;

  /// 이름 옆 에러 메시지. null 이면 정상.
  String? _nameError;
  String? get nameError => _nameError;

  /// 태그 옆 에러 메시지. null 이면 정상.
  String? _tagError;
  String? get tagError => _tagError;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  /// 서버에 실제로 반영되는 변경만 dirty 로 본다. 새 사진을 고른 경우도
  /// 업로드 후 저장되므로 dirty 에 포함한다.
  bool get _dirty {
    final p = _profile;
    if (p == null) return false;
    return _name.trim() != p.name ||
        _tag.trim() != p.tag ||
        _favoriteTeamId != p.favoriteTeamId ||
        _pendingImagePath != null;
  }

  /// 완료 버튼 활성 조건.
  bool get canSubmit {
    if (_isSaving) return false;
    return _dirty &&
        _name.trim().isNotEmpty &&
        _tagPattern.hasMatch(_tag.trim()) &&
        _nameError == null &&
        _tagError == null &&
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
      _name = _profile!.name;
      _tag = _profile!.tag;
      _favoriteTeamId = _profile!.favoriteTeamId;
      _nameError = null;
      _tagError = null;
    } catch (e, st) {
      debugPrint('[ProfileEdit] load 에러: $e\n$st');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void updateName(String value) {
    _name = value;
    _nameError = value.trim().isEmpty ? (appStrings?.requiredField ?? 'This field is required.') : null;
    _notify();
  }

  void updateTag(String value) {
    _tag = value;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _tagError = appStrings?.requiredField ?? 'This field is required.';
    } else if (!_tagPattern.hasMatch(trimmed)) {
      _tagError = appStrings?.tagFormatError ?? '2-5 alphanumeric characters required.';
    } else {
      _tagError = null;
    }
    _notify();
  }

  /// 팀 선택. 쿨다운 중이면 원래 팀 말고는 고를 수 없다 — 고르게 두고 저장에서
  /// 막으면 사용자는 이미 바뀐 줄 안다. 막혔다는 걸 알리는 건 화면 몫이라
  /// 성공 여부를 돌려준다.
  bool selectTeam(int teamId) {
    if (_favoriteTeamId == teamId) return true;
    if (teamChangeLocked && teamId != _profile?.favoriteTeamId) return false;
    _favoriteTeamId = teamId;
    _notify();
    return true;
  }

  /// 갤러리를 열어 새 프로필 사진을 고른다. 사용자가 취소하면 아무 일도
  /// 하지 않는다. 고른 파일은 [pendingImagePath] 에 미리보기로 보관되고
  /// 저장 시 Cloudinary 로 업로드된다. (512px 로 리사이즈)
  Future<void> pickProfileImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) return;
      _pendingImagePath = picked.path;
      _notify();
    } catch (e, st) {
      debugPrint('[ProfileEdit] pickImage 에러: $e\n$st');
    }
  }

  /// 저장. 새 사진을 골랐다면 먼저 Cloudinary 에 업로드해 URL 을 얻고,
  /// 이름·태그·응원 팀·이미지 URL 을 PUT 한다. 사진을 안 골랐다면 기존
  /// 이미지 URL 을 그대로 다시 보낸다.
  Future<bool> save() async {
    if (!canSubmit) return false;
    _isSaving = true;
    _nameError = null;
    _tagError = null;
    _notify();
    try {
      var imageUrl = _profile?.profileImageUrl;
      final pending = _pendingImagePath;
      if (pending != null && pending.isNotEmpty) {
        imageUrl = await _imageRepo.upload(File(pending));
      }
      final updated = await _auth.updateProfile(
        name: _name.trim(),
        tag: _tag.trim(),
        favoriteTeamId: _favoriteTeamId!,
        profileImageUrl: imageUrl,
      );
      _profile = updated;
      _pendingImagePath = null;
      return true;
    } on NicknameConflictException {
      _tagError = appStrings?.duplicateNicknameError ?? 'This nickname is already in use.';
      return false;
    } catch (e, st) {
      debugPrint('[ProfileEdit] save 에러: $e\n$st');
      _nameError = appStrings?.saveFailed ?? 'Failed to save. Please try again later.';
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
