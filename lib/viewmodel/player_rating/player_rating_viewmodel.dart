import 'package:flutter/foundation.dart';

import '../../model/game_rating.dart';
import '../../model/match_game.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/onboarding/onboarding_repository.dart';
import '../../repository/rating/rating_repository.dart';
import '../../repository/subscription/subscription_repository.dart';

/// 선수 평점 상세 화면 상태·로직.
///
/// (gameId, participantId) 로 상세(헤더·평균·분포·내평점·리뷰)를 로드하고,
/// 리뷰 페이지네이션·세트 전환·내 평가 작성/삭제를 처리한다.
/// 세트 전환 시 게임마다 participantId 가 다르므로 [playerId] 로 재해석한다.
class PlayerRatingViewModel extends ChangeNotifier {
  PlayerRatingViewModel({
    required String gameId,
    required int participantId,
    required this.playerId,
    required this.games,
    required int currentSet,
    RatingRepository? repository,
    AuthService? auth,
    OnboardingRepository? onboarding,
    SubscriptionRepository? subscription,
  })  : _gameId = gameId,
        _participantId = participantId,
        _currentSet = currentSet,
        _repository = repository ?? RatingRepository.instance,
        _auth = auth ?? AuthService.instance,
        _onboarding = onboarding ?? OnboardingRepository.instance,
        _subscription = subscription ?? SubscriptionRepository.instance {
    _loadMyProfile();
    _loadSubscription();
  }

  final int playerId;
  final List<MatchGame> games;
  final RatingRepository _repository;
  final AuthService _auth;
  final OnboardingRepository _onboarding;
  final SubscriptionRepository _subscription;

  /// 이 선수를 구독 중인지. 구독 배너 노출 여부 판단에 쓴다.
  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  /// 구독 선수 목록을 받아 현재 [playerId] 포함 여부로 구독 상태를 정한다.
  /// 평점 로딩과 독립이라 실패해도 화면 나머지에 영향이 없다(구독 아님으로 둠).
  Future<void> _loadSubscription() async {
    try {
      final players = await _subscription.fetchSubscribedPlayers();
      _isSubscribed = players.any((p) => p.playerId == playerId);
      _safeNotify();
    } catch (e) {
      debugPrint('[PlayerRatingVM] 구독 여부 로드 실패: $e');
    }
  }

  String _gameId;
  int _participantId;

  int _currentSet;
  int get currentSet => _currentSet;

  PlayerRatingDetail? _detail;
  PlayerRatingDetail? get detail => _detail;

  /// 내 댓글 카드에 표시할 현재 유저 프로필 이미지·응원팀 로고. 없으면 null.
  String? _myProfileImageUrl;
  String? get myProfileImageUrl => _myProfileImageUrl;
  String? _myTeamImageUrl;
  String? get myTeamImageUrl => _myTeamImageUrl;

  final List<Review> _reviews = [];
  List<Review> get reviews => List.unmodifiable(_reviews);

  bool _loading = false;
  bool get loading => _loading;
  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;
  bool _submitting = false;
  bool get submitting => _submitting;
  String? _error;
  String? get error => _error;

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  bool get hasMore => _detail?.hasMore ?? false;

  /// 내 댓글 카드용 — 현재 유저 프로필 이미지·응원팀 로고를 로드한다.
  /// 평점 로딩과 독립이라 실패해도 화면 나머지에 영향이 없다.
  Future<void> _loadMyProfile() async {
    try {
      final me = await _auth.fetchMe();
      _myProfileImageUrl = me.profileImageUrl;
      final teamId = me.favoriteTeamId;
      if (teamId != null) {
        final teams = await _onboarding.fetchTeams();
        for (final t in teams) {
          if (t.id == teamId) {
            _myTeamImageUrl = t.imageUrl;
            break;
          }
        }
      }
      _safeNotify();
    } catch (e) {
      debugPrint('[PlayerRatingVM] 내 프로필 로드 실패: $e');
    }
  }

  /// 첫 페이지 로드(또는 세트 전환 후 재로드).
  Future<void> load() async {
    _loading = true;
    _error = null;
    _safeNotify();
    try {
      final detail = await _repository.fetchPlayerRating(
        _gameId,
        _participantId,
        page: 0,
      );
      _detail = detail;
      _reviews
        ..clear()
        ..addAll(detail.reviews);
    } catch (e) {
      debugPrint('[PlayerRatingVM] load failed: $e');
      _error = '선수 평점을 불러오지 못했어요';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  /// 다음 리뷰 페이지를 누적한다.
  Future<void> loadMoreReviews() async {
    final current = _detail;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    _safeNotify();
    try {
      final next = await _repository.fetchPlayerRating(
        _gameId,
        _participantId,
        page: current.page + 1,
      );
      _detail = next;
      _reviews.addAll(next.reviews);
    } catch (e) {
      debugPrint('[PlayerRatingVM] loadMore failed: $e');
    } finally {
      _loadingMore = false;
      _safeNotify();
    }
  }

  /// 세트 전환. 해당 세트 gameId 로 평점목록을 받아 같은 playerId 의
  /// participantId 를 찾은 뒤 상세를 다시 로드한다.
  Future<void> selectSet(int setNumber) async {
    if (setNumber == _currentSet) return;
    final game = games.where((g) => g.gameOrder == setNumber).firstOrNull;
    if (game == null || game.gameId.isEmpty) return;

    _currentSet = setNumber;
    _loading = true;
    _error = null;
    _detail = null;
    _reviews.clear();
    _safeNotify();

    try {
      final list = await _repository.fetchGameRatings(game.gameId);
      final player =
          list.players.where((p) => p.playerId == playerId).firstOrNull;
      if (player == null) {
        _error = '이 세트에는 해당 선수 기록이 없어요';
        _loading = false;
        _safeNotify();
        return;
      }
      _gameId = game.gameId;
      _participantId = player.participantId;
    } catch (e) {
      debugPrint('[PlayerRatingVM] selectSet failed: $e');
      _error = '세트 평점을 불러오지 못했어요';
      _loading = false;
      _safeNotify();
      return;
    }
    await load();
  }

  /// 내 평점·코멘트 작성/수정. 성공 시 상세 재로드.
  /// 호출 전 View 가 로그인 여부를 확인한다(미로그인 시 호출하지 않음).
  Future<void> saveMyRating(int rating, String? comment) async {
    _submitting = true;
    _safeNotify();
    try {
      await _repository.putMyRating(
        _gameId,
        _participantId,
        rating: rating,
        comment: (comment != null && comment.isEmpty) ? null : comment,
      );
      await load();
    } catch (e) {
      debugPrint('[PlayerRatingVM] save failed: $e');
      rethrow;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }

  /// 내 평점 삭제. 성공 시 상세 재로드.
  Future<void> deleteMyRating() async {
    _submitting = true;
    _safeNotify();
    try {
      await _repository.deleteMyRating(_gameId, _participantId);
      await load();
    } catch (e) {
      debugPrint('[PlayerRatingVM] delete failed: $e');
      rethrow;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
