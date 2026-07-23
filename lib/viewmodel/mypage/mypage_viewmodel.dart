import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/app_strings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  final _storage = const FlutterSecureStorage();

  /// '설문 기반 응원팀 자동설정' 안내 배너를 한 번이라도 노출했는지 저장하는 키.
  static const _teamBannerSeenKey = 'mypage_team_banner_seen';

  /// 응원팀 자동설정 안내 배너 노출 여부.
  /// 최초 진입 시 한 번만 노출하고, 노출과 동시에 '봤음'으로 저장해 다시 뜨지 않는다.
  bool _showTeamBanner = false;
  bool get showTeamBanner => _showTeamBanner;

  /// 저장된 '봤음' 플래그를 확인해 배너 노출 여부를 정한다.
  /// 아직 안 봤으면 이번에 노출하고, 즉시 '봤음'으로 저장한다(다음 진입부턴 숨김).
  Future<void> _loadTeamBanner() async {
    final seen = await _storage.read(key: _teamBannerSeenKey);
    if (seen == 'true') return;
    _showTeamBanner = true;
    _notify();
    await _storage.write(key: _teamBannerSeenKey, value: 'true');
  }

  /// 배너를 탭/닫아 즉시 숨긴다. (노출 시 이미 '봤음' 저장되어 재진입에도 안 뜬다.)
  void dismissTeamBanner() {
    if (!_showTeamBanner) return;
    _showTeamBanner = false;
    _notify();
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
      _error = appStrings?.profileLoadFailed ?? 'Failed to load profile';
      debugPrint('[Mypage] load 에러: $e\n$st');
    } finally {
      _isLoading = false;
      _notify();
    }
    await _loadReviewCount();
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
