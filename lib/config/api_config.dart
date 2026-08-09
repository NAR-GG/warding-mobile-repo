class ApiConfig {
  ApiConfig._();

  static const String host = 'https://api.nar.kr';
  static const String apiBaseUrl = '$host/api';

  static const String kakaoNativeAppKey = '838b3def5acdd1dfbbe6b14e301ba05a';

  /// 카카오 access token을 백엔드로 보내 검증·자체 JWT 발급 (모바일 전용).
  static String get kakaoLoginUrl => '$apiBaseUrl/auth/mobile/kakao';

  /// Refresh Token으로 Access Token 재발급.
  /// [refreshToken] 은 query 파라미터로 전달한다 (백엔드 명세).
  static String refreshUrl(String refreshToken) =>
      '$apiBaseUrl/auth/refresh?refreshToken=${Uri.encodeQueryComponent(refreshToken)}';

  /// 로그인 회원 정보 조회 (인증 필요).
  static String get meUrl => '$apiBaseUrl/auth/me';

  /// 프로필 이미지 Cloudinary 서명 업로드용 파라미터 발급 (POST, 인증 필요).
  /// 응답값으로 Cloudinary 에 직접 업로드한 뒤 받은 secure_url 을
  /// [meUrl] PUT 의 profileImageUrl 로 저장한다.
  static String get profileImageSignatureUrl =>
      '$apiBaseUrl/auth/me/profile-image/signature';

  /// 네이버 access token을 백엔드로 보내 검증·자체 JWT 발급 (모바일 전용).
  static String get naverLoginUrl => '$apiBaseUrl/auth/mobile/naver';

  /// 구글 idToken을 백엔드로 보내 검증·자체 JWT 발급 (모바일 전용).
  static String get googleLoginUrl => '$apiBaseUrl/auth/mobile/google';

  /// 애플 identityToken을 백엔드로 보내 검증·자체 JWT 발급 (모바일 전용, iOS 전용).
  /// 구글과 동일하게 idToken 키로 전달한다: `{ "idToken": "<identityToken>" }`.
  /// 백엔드에 아직 이 엔드포인트가 없다면, 팀과 계약을 맞춘 뒤 이 URL/키를 조정한다.
  static String get appleLoginUrl => '$apiBaseUrl/auth/mobile/apple';

  /// 구글 OAuth "웹" 클라이언트 ID. idToken의 audience(serverClientId)로 쓰이며,
  /// 백엔드도 이 값으로 idToken을 검증한다. (Google Cloud Console에서 발급)
  static const String googleServerClientId =
      '12814317442-egra6e1lni0dmepp793sj5389qpsf1r0.apps.googleusercontent.com';

  /// 온보딩용 리그 목록 조회 (인증 불필요).
  static String get onboardingLeaguesUrl =>
      '$apiBaseUrl/auth/onboarding/leagues';

  /// 온보딩용 LCK 팀 목록 조회 (인증 불필요).
  static String get onboardingTeamsUrl => '$apiBaseUrl/auth/onboarding/teams';

  /// 온보딩용 선수 목록 조회 (인증 불필요).
  /// [teamId] 를 주면 해당 팀 선수만 조회한다.
  static String onboardingPlayersUrl({required int year, int? teamId}) {
    final query = StringBuffer('year=$year');
    if (teamId != null) query.write('&teamId=$teamId');
    return '$apiBaseUrl/auth/onboarding/players?$query';
  }

  /// 온보딩 완료 — 로그인 사용자의 선호 리그·팀·선수 서버 저장 (인증 필요).
  static String get onboardingUrl => '$apiBaseUrl/auth/onboarding';

  /// 모바일 월별 캘린더 마킹용 조회 (인증 불필요).
  /// 날짜별 경기 수와 칩에 쓸 대진 정보를 한 번에 내려준다.
  /// [month] 형식은 'yyyy-MM' (예: '2026-04').
  /// [leagues] 는 같은 키(`league`)를 반복해 배열로 보낸다 (백엔드가 `List<String>` 로 받음).
  static String mobileScheduleCalendarUrl({
    required String month,
    List<String> leagues = const ['LCK'],
    List<int>? teamIds,
  }) {
    final query = StringBuffer('month=$month')..write(_repeatedParam('league', leagues));
    if (teamIds != null && teamIds.isNotEmpty) {
      query.write(_repeatedParam('teamId', teamIds));
    }
    return '$apiBaseUrl/mobile/schedules/calendar?$query';
  }

  /// `league=ALL` 을 이 목록으로 치환할 때 쓰는 실제 리그 코드 전체.
  /// `/mobile/schedules/filters` 응답의 '전체'(ALL) 를 제외한 리그 목록과 동일해야 한다.
  static const List<String> _allRealLeagueCodes = [
    'LCK', 'LPL', 'LEC', 'LCS', 'MSI', 'WORLDS',
    'EWC', 'FIRST_STAND', 'KESPA', 'CBLOL', 'LCP',
  ];

  /// 모바일 선택 날짜의 경기 리스트 카드 조회 (인증 불필요).
  /// [date] 형식은 'yyyy-MM-dd' (예: '2026-04-01').
  /// [leagues] 는 같은 키(`league`)를 반복해 배열로 보낸다 (백엔드가 `List<String>` 로 받음).
  ///
  /// 이 엔드포인트는 캘린더 조회(`mobileScheduleCalendarUrl`)와 달리 일부 날짜에서
  /// `league=ALL` 자체를 400으로 거부하는 백엔드 버그가 있다(예: 2026-07-26·27).
  /// 그래서 [leagues] 가 'ALL' 하나뿐이면 실제 리그 코드 전체를 나열해 보낸다.
  static String mobileSchedulesUrl({
    required String date,
    List<String> leagues = const ['LCK'],
    List<int>? teamIds,
  }) {
    final effectiveLeagues =
        leagues.length == 1 && leagues.first == 'ALL' ? _allRealLeagueCodes : leagues;
    final query = StringBuffer('date=$date')
      ..write(_repeatedParam('league', effectiveLeagues));
    if (teamIds != null && teamIds.isNotEmpty) {
      query.write(_repeatedParam('teamId', teamIds));
    }
    return '$apiBaseUrl/mobile/schedules?$query';
  }

  /// [key] 를 반복하는 쿼리 파라미터 조각을 만든다. 예: `&league=LCK&league=LEC`.
  static String _repeatedParam(String key, List<Object> values) {
    final buffer = StringBuffer();
    for (final value in values) {
      buffer.write('&$key=${Uri.encodeQueryComponent(value.toString())}');
    }
    return buffer.toString();
  }

  /// 모바일 경기 리스트 커서 페이지 조회 (인증 불필요).
  /// 단일 요청으로 최신 날짜부터 [size] 개씩 받는다. [cursor] 는 첫 페이지에서 생략.
  ///
  /// [from] (`yyyy-MM-dd`) 을 주면 그 날짜(KST 00:00) 이후 경기를 과거→미래
  /// 오름차순으로 받는다. 정렬 방향은 서버가 [from] 유무로 정하므로 별도
  /// 파라미터는 없다. 방향이 바뀌면 커서도 이어 쓸 수 없으니 첫 페이지부터
  /// 다시 받아야 한다.
  static String matchesUrl({
    required String league,
    int size = 20,
    String? cursor,
    int? teamId,
    int? seasonYear,
    String? split,
    String? from,
  }) {
    final query = StringBuffer('league=$league&size=$size');
    if (cursor != null && cursor.isNotEmpty) {
      query.write('&cursor=${Uri.encodeQueryComponent(cursor)}');
    }
    if (teamId != null) query.write('&teamId=$teamId');
    if (seasonYear != null) query.write('&seasonYear=$seasonYear');
    if (split != null && split.isNotEmpty) query.write('&split=$split');
    if (from != null && from.isNotEmpty) query.write('&from=$from');
    return '$apiBaseUrl/mobile/matches?$query';
  }

  /// 모바일 일정/리스트 화면의 리그·팀 필터 옵션 조회 (인증 불필요).
  /// [league] 의 소속 팀 목록을 함께 내려준다.
  static String mobileScheduleFiltersUrl({String league = 'LCK'}) =>
      '$apiBaseUrl/mobile/schedules/filters?league=$league';

  /// 카테고리 트리(리그 > 시즌 > 팀) 조회 (인증 불필요).
  static String categoriesTreeUrl({required int year}) =>
      '$apiBaseUrl/categories/tree?year=$year';

  // ── 선수 구독 (인증 필요) ─────────────────────────────────────────

  /// 내 구독 선수 목록 조회 / 선수 구독 추가(POST {playerId}).
  static String get playerSubscriptionsUrl =>
      '$apiBaseUrl/mobile/me/player-subscriptions';

  /// 선수 구독 해제 (DELETE).
  static String playerSubscriptionUrl(int playerId) =>
      '$apiBaseUrl/mobile/me/player-subscriptions/$playerId';

  /// 구독 가능한 2026 LCK 선수 검색 (페이지네이션).
  static String availablePlayersUrl({
    String? query,
    int? teamId,
    int page = 0,
    int size = 20,
  }) {
    final q = StringBuffer('page=$page&size=$size');
    if (query != null && query.isNotEmpty) {
      q.write('&query=${Uri.encodeQueryComponent(query)}');
    }
    if (teamId != null) q.write('&teamId=$teamId');
    return '$apiBaseUrl/mobile/me/player-subscriptions/available-players?$q';
  }

  // ── 팀 알림 구독 (인증 필요) ───────────────────────────────────────

  /// 내 팀 알림 구독 목록 조회 / 팀 알림 구독 추가(POST {teamId}).
  static String get teamNotificationsUrl =>
      '$apiBaseUrl/mobile/me/notification-subscriptions';

  /// 팀별 알림 설정 변경(PUT) / 팀 알림 구독 삭제(DELETE).
  static String teamNotificationUrl(int teamId) =>
      '$apiBaseUrl/mobile/me/notification-subscriptions/$teamId';

  /// 구독 가능한 LCK 팀 목록 조회.
  static String get availableTeamsUrl =>
      '$apiBaseUrl/mobile/me/notification-subscriptions/available-teams';

  // ── 경기 예약 구독 (인증 필요) ─────────────────────────────────────

  /// 내 경기 예약 구독 목록 조회(GET, matchId 배열) / 구독 추가(POST {matchId}).
  static String get matchSubscriptionsUrl =>
      '$apiBaseUrl/mobile/me/match-subscriptions';

  /// 경기 예약 구독 해제(DELETE).
  static String matchSubscriptionUrl(String matchId) =>
      '$apiBaseUrl/mobile/me/match-subscriptions/$matchId';

  // ── 마이구독 알림 피드 (인증 필요) ────────────────────────────────

  /// 받은 알림 리스트 (type 필터·페이징). type 미지정 시 전체.
  static String notificationsUrl({String? type, int page = 0, int size = 20}) {
    final params = <String, String>{'page': '$page', 'size': '$size'};
    if (type != null) params['type'] = type;
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$apiBaseUrl/mobile/me/notifications?$query';
  }

  /// 알림 전체 읽음 처리(POST).
  static String get notificationsReadAllUrl =>
      '$apiBaseUrl/mobile/me/notifications/read';

  /// 알림 단건 읽음 처리(POST).
  static String notificationReadUrl(int id) =>
      '$apiBaseUrl/mobile/me/notifications/$id/read';

  /// 알림 단건 삭제(DELETE).
  static String notificationDeleteUrl(int id) =>
      '$apiBaseUrl/mobile/me/notifications/$id';

  /// 알림 전체 삭제(DELETE).
  static String get notificationsDeleteAllUrl =>
      '$apiBaseUrl/mobile/me/notifications';

  // ── 선수 평점 (인증 필요) ─────────────────────────────────────────

  /// 세트(게임) 전체 선수 평점 목록.
  static String gameRatingsUrl(String gameId, {String teamSide = 'ALL'}) =>
      '$apiBaseUrl/mobile/live/games/$gameId/ratings?teamSide=$teamSide';

  /// 선수 평점 상세 + 리뷰 (페이지네이션).
  static String playerRatingUrl(
    String gameId,
    int participantId, {
    int page = 0,
    int size = 20,
  }) =>
      '$apiBaseUrl/mobile/live/games/$gameId/participants/$participantId/ratings'
      '?page=$page&size=$size';

  /// 내 평가 작성·수정(PUT) / 삭제(DELETE).
  static String myRatingUrl(String gameId, int participantId) =>
      '$apiBaseUrl/mobile/live/games/$gameId/participants/$participantId/my-rating';

  /// 내가 작성한 평가 전체 목록 (페이지네이션, 인증 필요).
  static String myRatingsUrl({int page = 0, int size = 20}) =>
      '$apiBaseUrl/mobile/me/ratings?page=$page&size=$size';

  /// 게임 상세(밴픽·선수 스탯·골드 차 등) 조회. gameId 는 정수.
  static String gameRecordUrl(int gameId) =>
      '$apiBaseUrl/games/$gameId/record';

  // ── 경기 상세: 세트(게임)·챔피언 픽·라이브 이벤트 (인증 불필요) ──────────

  /// 단일 경기 정보 조회 (인증 불필요).
  static String matchUrl(String matchId) =>
      '$apiBaseUrl/mobile/matches/$matchId';

  /// 경기(matchId)의 세트별 게임 목록 조회. 세트 순서 → gameId 해석에 쓴다.
  static String matchGamesUrl(String matchId) =>
      '$apiBaseUrl/mobile/matches/$matchId/games';

  /// 세트(게임)의 챔피언 밴·픽 조회.
  static String gameChampionsUrl(String gameId) =>
      '$apiBaseUrl/mobile/live/games/$gameId/champions';

  /// 세트(게임)의 라이브 이벤트(킬·오브젝트) 조회. (최신순)
  static String gameEventsUrl(String gameId) =>
      '$apiBaseUrl/mobile/live/games/$gameId/events';

  // ── 공지사항 (인증 불필요) ─────────────────────────────────────────

  /// 공지사항 목록 (발행분만, 고정 공지 먼저, 최신순).
  static String noticesUrl({int page = 0, int size = 20}) =>
      '$apiBaseUrl/notices?page=$page&size=$size';

  /// 공지 조회수 +1 (POST, 본문 없음, 204). 목록 응답에 본문이 함께 오므로
  /// 상세 조회 요청이 없다 — 앱이 상세를 열 때 직접 알려줘야 조회수가 쌓인다.
  static String noticeViewUrl(int id) => '$apiBaseUrl/notices/$id/view';

  /// 캘린더 상단 띠배너용 공지 1건 (`promote_until > now`인 최신 발행 공지).
  /// 없으면 204.
  static String get promotedNoticeUrl => '$apiBaseUrl/notices/promoted';

  // ── Live Activity 푸시 토큰 (인증 필요) ──────────────────────────────

  /// 실시간 경기 카드 푸시 토큰 등록(POST {matchId, pushToken}).
  /// 카드 하나에 붙는 토큰이라 카드를 띄울 때마다 새로 발급된다.
  static String get liveActivitiesUrl =>
      '$apiBaseUrl/mobile/me/live-activities';

  /// push-to-start 토큰 등록(POST {pushToken}).
  ///
  /// [liveActivitiesUrl] 과 달리 앱 단위 토큰이라 카드가 없어도 존재한다.
  /// 서버는 이 토큰이 있어야 앱이 안 떠 있는 상태에서 카드를 새로 만들 수 있다.
  static String get liveActivityStartTokenUrl =>
      '$apiBaseUrl/mobile/me/live-activities/start-token';

  // ── FCM 기기 토큰 (인증 필요) ──────────────────────────────────────

  /// FCM 토큰 등록·갱신 (POST {fcmToken, platform}).
  static String get devicesUrl => '$apiBaseUrl/mobile/me/devices';

  /// 현재 기기 비활성화 (DELETE).
  static String deviceUrl(String deviceId) =>
      '$apiBaseUrl/mobile/me/devices/$deviceId';

  /// 로그아웃 — Refresh Token 폐기. [deviceId] 전달 시 해당 FCM 기기도 비활성화.
  static String logoutUrl({String? deviceId}) {
    final base = '$apiBaseUrl/auth/logout';
    return deviceId == null ? base : '$base?deviceId=$deviceId';
  }
}
