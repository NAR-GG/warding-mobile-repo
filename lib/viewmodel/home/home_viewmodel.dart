import 'package:flutter/foundation.dart';

import '../../model/community_author.dart';
import '../../model/community_remote_post.dart';
import '../../model/home_models.dart';
import '../../model/schedule_match.dart';
import '../../repository/home/home_sources.dart';

/// 커뮤니티 섹션 정렬 기준.
enum HomeCommunitySort { latest, hot, review }

/// 콘텐츠 섹션 탭.
enum HomeContentTab { news, shorts }

/// 쇼츠 탭 필터.
enum HomeShortsFilter { all, player, team }

/// 홈 화면 상태.
///
/// 이 단계는 API 연동 없이 목업 그대로의 화면 구조만 재현한다 — 아래
/// `_mock*` 데이터는 전부 고정값이고, 이 클래스는 탭 전환·스와이프 인덱스·
/// 정렬 토글 같은 로컬 UI 상태만 갖는다.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel();

  // ---- 공지 배너 ----
  bool _bannerDismissed = false;
  bool get bannerVisible => !_bannerDismissed;

  void dismissBanner() {
    if (_bannerDismissed) return;
    _bannerDismissed = true;
    notifyListeners();
  }

  // ---- 섹션 1: 구독 선수 솔랭 상태 ----
  static const int mockSubscribedTotal = MockSoloRankSource.subscribedTotal;

  static const List<HomeLiveSoloPlayer> mockLiveNow = MockSoloRankSource.live;

  static const List<HomeFinishedSoloPlayer> mockFinishedToday =
      MockSoloRankSource.finished;

  int get soloHiddenCount =>
      mockSubscribedTotal - mockLiveNow.length - mockFinishedToday.length;

  int _soloSwipeIndex = 0;
  int get soloSwipeIndex => _soloSwipeIndex;

  void setSoloSwipeIndex(int index) {
    if (index == _soloSwipeIndex) return;
    _soloSwipeIndex = index;
    notifyListeners();
  }

  // ---- 섹션 2: 오늘 경기 ----
  static final List<ScheduleMatch> mockTodayMatches = [
    const ScheduleMatch(
      matchId: 'mock-1',
      scheduledTime: '14:00',
      leagueInfo: 'LCK',
      matchTitle: '플레이오프 | T1 vs HLE',
      matchStatus: 'inProgress',
      isSynced: true,
      teamA: MatchTeam(
        teamName: 'T1',
        teamCode: 'T1',
        teamImageUrl: '',
        score: 1,
      ),
      teamB: MatchTeam(
        teamName: 'Hanwha Life Esports',
        teamCode: 'HLE',
        teamImageUrl: '',
        score: 0,
      ),
    ),
    const ScheduleMatch(
      matchId: 'mock-2',
      scheduledTime: '00:00',
      leagueInfo: 'LEC',
      matchTitle: '플레이오프 | GX vs NAVI',
      matchStatus: 'completed',
      isSynced: true,
      teamA: MatchTeam(
        teamName: 'Giantx',
        teamCode: 'GX',
        teamImageUrl: '',
        score: 2,
      ),
      teamB: MatchTeam(
        teamName: 'Natus Vincere',
        teamCode: 'NAVI',
        teamImageUrl: '',
        score: 3,
      ),
    ),
    const ScheduleMatch(
      matchId: 'mock-3',
      scheduledTime: '18:00',
      leagueInfo: 'LPL',
      matchTitle: '플레이오프 | IG vs AL',
      matchStatus: 'unstarted',
      isSynced: false,
      teamA: MatchTeam(
        teamName: 'Invictus Gaming',
        teamCode: 'IG',
        teamImageUrl: '',
        score: 0,
      ),
      teamB: MatchTeam(
        teamName: 'Anyone\'s Legend',
        teamCode: 'AL',
        teamImageUrl: '',
        score: 0,
      ),
    ),
  ];

  /// 목업의 정렬 규칙 그대로 — 진행 중인 경기를 앞으로.
  List<ScheduleMatch> get todayMatchesSorted {
    final matches = [...mockTodayMatches];
    matches.sort((a, b) {
      final aLive = a.matchStatus == 'inProgress' ? 1 : 0;
      final bLive = b.matchStatus == 'inProgress' ? 1 : 0;
      return bLive - aLive;
    });
    return matches;
  }

  // ---- 섹션 3: 순위표 ----
  // 월즈는 리그 테이블과 다른 화면(스위스 전적·토너먼트 대진)이 필요해 이번
  // 스코프에서는 제외한다 — 칩만 노출하고 LPL/LEC/LCS 처럼 탭 비활성 상태로 둔다.
  static const List<HomeLeagueChip> leagueChips = [
    HomeLeagueChip(code: 'LCK', label: 'LCK', live: true),
    HomeLeagueChip(code: 'LPL', label: 'LPL', live: false),
    HomeLeagueChip(code: 'LEC', label: 'LEC', live: false),
    HomeLeagueChip(code: 'LCS', label: 'LCS', live: false),
    HomeLeagueChip(code: '월즈', label: '월즈', live: false),
  ];

  String _selectedLeague = 'LCK';
  String get selectedLeague => _selectedLeague;

  void selectLeague(String code) {
    final chip = leagueChips.where((c) => c.code == code).firstOrNull;
    if (chip == null || !chip.live || code == _selectedLeague) return;
    _selectedLeague = code;
    notifyListeners();
  }

  static const List<HomeStandingRow> mockLegendGroup = [
    HomeStandingRow(
      rank: 1,
      teamCode: 'GEN',
      teamName: '젠지',
      wins: 19,
      losses: 7,
      setDiff: 22,
    ),
    HomeStandingRow(
      rank: 2,
      teamCode: 'HLE',
      teamName: '한화생명e스포츠',
      wins: 19,
      losses: 7,
      setDiff: 22,
    ),
    HomeStandingRow(
      rank: 3,
      teamCode: 'T1',
      teamName: 'T1',
      wins: 17,
      losses: 9,
      setDiff: 17,
    ),
    HomeStandingRow(
      rank: 4,
      teamCode: 'DK',
      teamName: 'Dplus Kia',
      wins: 17,
      losses: 9,
      setDiff: 10,
    ),
    HomeStandingRow(
      rank: 5,
      teamCode: 'KT',
      teamName: 'kt 롤스터',
      wins: 15,
      losses: 11,
      setDiff: 6,
    ),
  ];

  static const List<HomeStandingRow> mockRiseGroup = [
    HomeStandingRow(
      rank: 1,
      teamCode: 'BRO',
      teamName: '한화생명e스포츠 챌린저스',
      wins: 12,
      losses: 14,
      setDiff: -4,
    ),
    HomeStandingRow(
      rank: 2,
      teamCode: 'DNF',
      teamName: '농심 레드포스',
      wins: 11,
      losses: 15,
      setDiff: -7,
    ),
    HomeStandingRow(
      rank: 3,
      teamCode: 'NS',
      teamName: '광동 프릭스',
      wins: 10,
      losses: 16,
      setDiff: -9,
    ),
  ];

  bool _standingsExpanded = false;
  bool get standingsExpanded => _standingsExpanded;

  void toggleStandingsExpanded() {
    _standingsExpanded = !_standingsExpanded;
    notifyListeners();
  }

  // ---- 섹션 4: 커뮤니티 ----
  HomeCommunitySort _communitySort = HomeCommunitySort.latest;
  HomeCommunitySort get communitySort => _communitySort;

  void setCommunitySort(HomeCommunitySort sort) {
    if (sort == _communitySort) return;
    _communitySort = sort;
    notifyListeners();
  }

  static final List<CommunityRemotePost> mockPosts = [
    CommunityRemotePost(
      id: 1,
      boardTeamId: null,
      title: '오늘 T1 경기 다들 어떻게 보셨나요',
      bodyPreview: '후반 한타 진짜 미쳤다...',
      author: const CommunityAuthor(
        memberId: 1,
        nickname: 'ABLY#1127',
        teamId: 1,
        teamCode: 'T1',
      ),
      viewCount: 3400,
      likeCount: 128,
      commentCount: 64,
      edited: false,
      createdAt: DateTime(2026, 9, 12, 19, 30),
    ),
    CommunityRemotePost(
      id: 2,
      boardTeamId: null,
      title: '젠지 이번 시즌 진짜 잘한다',
      bodyPreview: '세트 득실만 봐도 압도적...',
      author: const CommunityAuthor(
        memberId: 2,
        nickname: '젠지가족#4821',
        teamId: 2,
        teamCode: 'GEN',
      ),
      viewCount: 5200,
      likeCount: 210,
      commentCount: 95,
      edited: false,
      createdAt: DateTime(2026, 9, 12, 15, 0),
      thumbnailUrl: 'mock',
    ),
    CommunityRemotePost(
      id: 3,
      boardTeamId: null,
      title: '한화생명 로스터 분석',
      bodyPreview: '탑정글 시너지가 확실히...',
      author: const CommunityAuthor(
        memberId: 3,
        nickname: '한화보험왕#0930',
        teamId: 3,
        teamCode: 'HLE',
      ),
      viewCount: 1800,
      likeCount: 42,
      commentCount: 18,
      edited: false,
      createdAt: DateTime(2026, 9, 12, 10, 0),
    ),
    CommunityRemotePost(
      id: 4,
      boardTeamId: null,
      title: 'kt 원딜 폼 미쳤네요',
      bodyPreview: '오늘 캐리력 보고 놀랐다',
      author: const CommunityAuthor(
        memberId: 4,
        nickname: '원딜은거들뿐#5985',
        teamId: 4,
        teamCode: 'KT',
      ),
      viewCount: 980,
      likeCount: 30,
      commentCount: 9,
      edited: false,
      createdAt: DateTime(2026, 9, 12, 8, 0),
    ),
  ];

  List<CommunityRemotePost> get communityPostsSorted {
    final posts = [...mockPosts];
    if (_communitySort == HomeCommunitySort.hot) {
      posts.sort((a, b) {
        final scoreA = a.likeCount * 3 + a.commentCount * 2 + a.viewCount;
        final scoreB = b.likeCount * 3 + b.commentCount * 2 + b.viewCount;
        return scoreB - scoreA;
      });
    } else {
      posts.sort((a, b) {
        final atA = a.createdAt ?? DateTime(0);
        final atB = b.createdAt ?? DateTime(0);
        return atB.compareTo(atA);
      });
    }
    return posts.take(4).toList();
  }

  static const List<HomeReviewItem> mockReviews = MockReviewSource.reviews;

  // ---- 섹션 5: 콘텐츠 (뉴스 / 쇼츠) ----
  HomeContentTab _contentTab = HomeContentTab.news;
  HomeContentTab get contentTab => _contentTab;

  void setContentTab(HomeContentTab tab) {
    if (tab == _contentTab) return;
    _contentTab = tab;
    notifyListeners();
  }

  HomeShortsFilter _shortsFilter = HomeShortsFilter.all;
  HomeShortsFilter get shortsFilter => _shortsFilter;

  void setShortsFilter(HomeShortsFilter filter) {
    if (filter == _shortsFilter) return;
    _shortsFilter = filter;
    notifyListeners();
  }

  static const List<HomeNewsArticle> mockNews = MockNewsSource.articles;

  static const List<HomeShortsVideo> mockShorts = [
    HomeShortsVideo(
      title: '페이커 시즌 최고의 아리 플레이',
      teamCode: 'T1',
      views: 128000,
      matchedPlayer: 'Faker',
    ),
    HomeShortsVideo(
      title: '쵸비 신드라 원콤 하이라이트',
      teamCode: 'GEN',
      views: 84000,
      matchedPlayer: 'Chovy',
    ),
    HomeShortsVideo(title: 'T1 vs HLE 풀경기 요약', teamCode: 'T1', views: 45000),
    HomeShortsVideo(
      title: '제우스 그웬 원맨쇼',
      teamCode: 'HLE',
      views: 39000,
      matchedPlayer: 'Zeus',
    ),
    HomeShortsVideo(title: 'LCK 이주의 베스트 5', teamCode: 'GEN', views: 22000),
    HomeShortsVideo(title: 'kt 롤스터 인터뷰', teamCode: 'KT', views: 15000),
  ];

  static const String _myTeamCode = 'T1';

  List<HomeShortsVideo> get shortsFiltered {
    final list = mockShorts.where((v) {
      switch (_shortsFilter) {
        case HomeShortsFilter.all:
          return true;
        case HomeShortsFilter.player:
          return v.matchedPlayer != null;
        case HomeShortsFilter.team:
          return v.teamCode == _myTeamCode;
      }
    }).toList();

    if (_shortsFilter == HomeShortsFilter.all) {
      int rank(HomeShortsVideo v) {
        final matched = v.matchedPlayer != null ? 0 : 2;
        final mine = v.teamCode == _myTeamCode ? 0 : 1;
        return matched + mine;
      }

      list.sort((a, b) => rank(a).compareTo(rank(b)));
    }
    return list;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
