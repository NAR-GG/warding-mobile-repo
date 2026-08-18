import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/app_strings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/secure_storage.dart';

import '../../model/team.dart';
import '../../model/user_profile.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/onboarding/onboarding_repository.dart';
import '../../repository/rating/rating_repository.dart';

/// 마이페이지 ViewModel.
///
/// `GET /api/auth/me` 로 회원 정보를 받고, 응원 팀(`favoriteTeamId`)은
/// 온보딩 팀 목록에서 매칭해 이름·로고를 채운다.
class MypageViewModel extends ChangeNotifier {
  MypageViewModel({
    AuthService? auth,
    OnboardingRepository? onboarding,
    RatingRepository? rating,
  })  : _auth = auth ?? AuthService.instance,
        _onboarding = onboarding ?? OnboardingRepository.instance,
        _rating = rating ?? RatingRepository.instance {
    load();
    _loadTeamBanner();
    _loadVersion();
  }

  final AuthService _auth;
  final OnboardingRepository _onboarding;
  final RatingRepository _rating;
  bool _disposed = false;

  /// 로컬 저장(응원팀 자동설정 안내 배너 노출 여부 등). 이미 설치된
  /// [FlutterSecureStorage] 를 재사용한다(패키지 추가 불필요).
  final _storage = secureStorage;

  /// '설문 기반 응원팀 자동설정' 안내 배너를 **눌러 봤는지** 저장하는 키.
  ///
  /// 값이 남아 있는 저장소를 그대로 쓰면, 예전 규칙(노출만 해도 '봤음')으로
  /// 이미 true 가 찍힌 사용자에게 배너가 영영 안 뜬다. 그래서 키 이름을 바꿔
  /// 판정 기준이 달라졌음을 저장소에도 반영한다.
  static const _teamBannerTappedKey = 'mypage_team_banner_tapped';

  /// 응원팀 자동설정 안내 배너 노출 여부.
  /// 사용자가 배너를 한 번 누를 때까지 마이페이지에 들어올 때마다 계속 노출한다.
  bool _showTeamBanner = false;
  bool get showTeamBanner => _showTeamBanner;

  /// 저장된 '눌러 봤음' 플래그를 확인해 배너 노출 여부를 정한다.
  /// 아직 안 눌렀으면 노출한다 — 여기서는 저장하지 않는다.
  ///
  /// 배너 문구가 '설문 기반으로 자동 설정됐다'는 회원 전용 안내라
  /// 비회원(JWT 없음)에게는 띄우지 않는다.
  Future<void> _loadTeamBanner() async {
    final jwt = await _auth.jwt;
    if (jwt == null || jwt.isEmpty) return;
    final tapped = await _storage.read(key: _teamBannerTappedKey);
    if (tapped == 'true') return;
    _showTeamBanner = true;
    _notify();
  }

  /// 배너를 눌러 숨긴다. 이때만 '눌러 봤음'을 저장해 다시 뜨지 않게 한다.
  Future<void> dismissTeamBanner() async {
    if (!_showTeamBanner) return;
    _showTeamBanner = false;
    _notify();
    await _storage.write(key: _teamBannerTappedKey, value: 'true');
  }

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

  /// 내 리뷰/평점 누적 건수. 로딩 전 또는 조회 실패 시 null('N건' 미표시).
  int? _reviewCount;
  int? get reviewCount => _reviewCount;

  /// 앱 버전 (예: '1.0.2').
  String _appVersion = '';
  String get appVersion => _appVersion;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  /// 회원 정보와 응원 팀을 불러온다.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();
    // 리뷰 건수는 프로필·팀 로딩과 독립적이라 처음부터 같이 띄운다.
    final reviewCountFuture = _loadReviewCount();
    try {
      // teamId 를 알기 전에도 팀 목록은 미리 받아둔다 — fetchMe 와 겹쳐서
      // 왕복 한 번을 아낀다. (teamId 가 null 이면 결과는 버려진다.)
      final teamsFuture = _onboarding.fetchTeams();
      final me = await _auth.fetchMe();
      _profile = me;
      _notify(); // 닉네임 등은 먼저 보여 준다.

      final teamId = me.favoriteTeamId;
      final teams = await teamsFuture;
      if (teamId != null) {
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
      _error = appStrings?.profileLoadFailed ?? 'Failed to load profile';
      debugPrint('[Mypage] load 에러: $e\n$st');
    } finally {
      _isLoading = false;
      _notify();
    }
    await reviewCountFuture;
  }

  /// 내 리뷰/평점 누적 건수만 가볍게 조회한다(첫 페이지 메타의 totalElements).
  /// 프로필 로딩과 독립적이라 실패해도 화면 나머지에 영향이 없다.
  Future<void> _loadReviewCount() async {
    try {
      final ratings = await _rating.fetchMyRatings(page: 0, size: 1);
      _reviewCount = ratings.totalElements;
      _notify();
    } catch (e) {
      debugPrint('[Mypage] 리뷰 건수 로드 에러: $e');
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _notify();
    } catch (_) {}
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
