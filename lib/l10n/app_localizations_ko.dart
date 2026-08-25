// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Warding';

  @override
  String get logoutFailed => '로그아웃에 실패했습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get mainScreenPlaceholder => '메인 화면 (작업 예정)';

  @override
  String get matchList => '경기리스트';

  @override
  String get season => '시즌';

  @override
  String get league => '리그';

  @override
  String get loading => '불러오는 중...';

  @override
  String get select => '선택';

  @override
  String get noMatches => '경기가 없어요';

  @override
  String setInProgress(int setNumber) {
    return 'SET $setNumber 진행중';
  }

  @override
  String setWinner(int setNumber, String teamCode) {
    return 'SET $setNumber $teamCode 승';
  }

  @override
  String get today => '오늘';

  @override
  String get yesterday => '어제';

  @override
  String get tomorrow => '내일';

  @override
  String monthDay(int month, int day) {
    return '$month월 $day일';
  }

  @override
  String yearMonthDay(int year, int month, int day) {
    return '$year년 $month월 $day일';
  }

  @override
  String get setStartAlarm => '세트 시작 알림';

  @override
  String get setEndAlarm => '세트 종료 알림';

  @override
  String get liveEventAlarm => '라이브 이벤트 알림';

  @override
  String get confirm => '확인';

  @override
  String get matchAlarmSettings => '경기 알림 설정';

  @override
  String get matchAlarmRemoved => '경기 알림이 해제되었어요';

  @override
  String get matchAlarmRemoveFailed => '알림 해제에 실패했어요. 다시 시도해주세요';

  @override
  String get matchAlarmRegistered => '경기 알림이 등록되었어요';

  @override
  String get matchAlarmRegisterFailed => '알림 등록에 실패했어요. 다시 시도해주세요';

  @override
  String get spoilerBlock => '스포방지';

  @override
  String get clickToSeeScore => '클릭시 스코어 확인 가능';

  @override
  String get spoilerPreventionOn => '스포방지 ON';

  @override
  String get spoilerPreventionOff => '스포방지 OFF';

  @override
  String get weekdayMon => '월';

  @override
  String get weekdayTue => '화';

  @override
  String get weekdayWed => '수';

  @override
  String get weekdayThu => '목';

  @override
  String get weekdayFri => '금';

  @override
  String get weekdaySat => '토';

  @override
  String get weekdaySun => '일';

  @override
  String get filter => '필터';

  @override
  String get team => '팀';

  @override
  String get all => '전체';

  @override
  String get monthlyScheduleSummary => '월간 경기 일정 요약';

  @override
  String get ratingSaveFailed => '평점 저장에 실패했어요. 잠시 후 다시 시도해주세요.';

  @override
  String get deleteMyRatingConfirm => '내 평점을 삭제하시겠습니까?';

  @override
  String get deleteMyRatingMessage =>
      '삭제된 댓글은 복구되지 않습니다. 댓글은 수정 기능을 통해 편집할 수 있습니다.';

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get ratingDeleteFailed => '평점 삭제에 실패했어요. 잠시 후 다시 시도해주세요.';

  @override
  String get playerRating => '선수 평점';

  @override
  String get me => '나';

  @override
  String get leaveRating => '평점 남기기';

  @override
  String get myComment => '내 댓글';

  @override
  String get ratingAndComment => '평점·코멘트';

  @override
  String totalCount(int count) {
    return '총 $count개';
  }

  @override
  String get leaveRatingAndComment => '평점·코멘트 남기기';

  @override
  String get ratingCommentHint => '선수의 활약에 대한 의견을 남겨보세요.';

  @override
  String get ratingCommentWarning =>
      '선수에 대한 지나친 비방 및 부적절한 표현은 운영 정책에 따라 사전 안내 없이 삭제될 수 있습니다.';

  @override
  String get submit => '등록하기';

  @override
  String totalParticipants(int count) {
    return '총 $count명 참여';
  }

  @override
  String get subscribedPlayer => '회원님이 구독한 선수';

  @override
  String get leaveRatingForPlayer => '님에게 평점를 남겨보세요!';

  @override
  String get championPick => '챔피언 픽';

  @override
  String get liveEvent => '라이브 이벤트';

  @override
  String get tabPlayerRating => '선수 평점';

  @override
  String setLabel(int order) {
    return '세트 $order';
  }

  @override
  String get inProgress => '진행중';

  @override
  String get broadcastChannelSelect => '중계 채널 선택';

  @override
  String get watchOnPlatform => '보고 싶은 플랫폼에서 이어서 시청하세요';

  @override
  String get official => '공식';

  @override
  String get matchDetail => '경기 상세';

  @override
  String get playerRatingAfterMatch => '선수 평점은 경기 종료 후 남길 수 있어요!';

  @override
  String get watchBroadcast => '중계 보기';

  @override
  String get rewatch => '다시보기';

  @override
  String get matchEnded => '경기 종료';

  @override
  String get preparing => '준비중';

  @override
  String get liveEventAfterMatch => '라이브 이벤트는 경기 시작 후 볼 수 있어요!';

  @override
  String get championPickAfterMatch => '챔피언 픽은 경기 시작 후 볼 수 있어요!';

  @override
  String get championPickAfterMatchAlt => '챔피언 픽은 경기 시작 후 확인할 수 있어요!';

  @override
  String get eventDuringMatch => '이벤트는 경기 중에 확인할 수 있어요!';

  @override
  String get loadingLiveEvents => '라이브 이벤트를 가져오는 중이에요...';

  @override
  String get matchScheduled => '경기 예정';

  @override
  String get matchInProgress => '경기 진행 중';

  @override
  String allPlayerRatingForSet(String setTitle) {
    return '$setTitle 전체 선수 평점';
  }

  @override
  String setEndedLeaveRating(String setText) {
    return '$setText 경기가 끝났어요! 각 선수 평점을 남겨보세요';
  }

  @override
  String get totalPrefix => '총 ';

  @override
  String get participantsSuffix => '명 참여';

  @override
  String playerRatingWithCount(String rating, int count) {
    return '$rating ($count명)';
  }

  @override
  String get justNow => '방금 전';

  @override
  String minutesAgo(int minutes) {
    return '$minutes분 전';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours시간 전';
  }

  @override
  String daysAgo(int days) {
    return '$days일 전';
  }

  @override
  String get eventTypeAll => '전체';

  @override
  String get eventTypeSetStart => '세트 시작';

  @override
  String get eventTypeSetEnd => '세트 종료';

  @override
  String get deleteSwipe => '삭제';

  @override
  String get deleteFailed => '삭제하지 못했습니다.';

  @override
  String get deleteAllAlarms => '알림 모두 삭제';

  @override
  String get deleteAllAlarmsMessage => '받은 알림을 모두 삭제할까요?';

  @override
  String get enableNotificationPermission => '알림을 받으려면 알림 권한을 허용해주세요.';

  @override
  String get noNotifications => '받은 알림이 없습니다.';

  @override
  String get mySubscription => '마이 구독';

  @override
  String get subscribedTeams => '구독중인 팀';

  @override
  String get subscribedPlayers => '구독중인 선수';

  @override
  String get subscriptionSettings => '구독 설정';

  @override
  String get fullList => '전체 목록';

  @override
  String get tabTeam => '팀';

  @override
  String get tabPlayer => '선수';

  @override
  String get dateLabel => '날짜';

  @override
  String get allPlayers => '선수전체';

  @override
  String get player => '선수';

  @override
  String get playerSelect => '선수 선택';

  @override
  String get subscribedPlayerList => '구독한 선수';

  @override
  String get playerSortByPosition => '포지션순';

  @override
  String get playerSortByName => '이름순';

  @override
  String get subscribing => '구독중';

  @override
  String get subscribe => '구독';

  @override
  String liveEventNotificationTitle(String teamA, String teamB) {
    return '$teamA VS $teamB 라이브 이벤트 발생!';
  }

  @override
  String liveEventNotificationBody(String season, String teamA, String teamB) {
    return '$season _ $teamA VS $teamB 경기 실시간 이벤트를 확인해보세요';
  }

  @override
  String get foldDetail => '접어두기';

  @override
  String get showDetail => '상세보기';

  @override
  String matchEndNotificationTitle(String teamA, String teamB) {
    return '$teamA VS $teamB 경기가 종료되었습니다.';
  }

  @override
  String matchEndNotificationBody(String season, String teamA, String teamB) {
    return '$season _ $teamA VS $teamB 경기가 종료되었습니다. 지금 바로 평점을 남겨보세요!';
  }

  @override
  String get leaveMatchRating => '경기 평점 남기기';

  @override
  String matchStartNotificationTitle(String teamA, String teamB) {
    return '$teamA VS $teamB 경기가 시작됩니다!';
  }

  @override
  String matchStartNotificationBody(String season, String teamA, String teamB) {
    return '$season _ 응원중인 팀 $teamA 과 $teamB의 경기가 시작됩니다.';
  }

  @override
  String get soloRank => '솔로 랭크';

  @override
  String rankStartTitle(String playerName) {
    return '$playerName 선수가 솔랭을 시작했어요';
  }

  @override
  String rankStartBody(String champion, String particle, String queueType) {
    return '$champion$particle $queueType 플레이 중';
  }

  @override
  String rankEndTitle(String playerName) {
    return '$playerName 선수가 솔랭을 끝냈어요';
  }

  @override
  String rankEndBodyResult(String champion, String particle, String result) {
    return '$champion$particle $result';
  }

  @override
  String rankEndBodyNoResult(String champion) {
    return '$champion 경기 종료';
  }

  @override
  String get rankEndWin => '승리';

  @override
  String get rankEndLose => '패배';

  @override
  String rankEndDurationMinutes(int minutes) {
    return '$minutes분';
  }

  @override
  String get withdraw => '회원탈퇴';

  @override
  String get withdrawConfirmTitle => '회원탈퇴';

  @override
  String get withdrawConfirmMessage =>
      '계정과 구독·알림·평점 등 모든 데이터가\n삭제되며 되돌릴 수 없습니다.';

  @override
  String get withdrawConfirmButton => '탈퇴';

  @override
  String get withdrawFailed => '회원탈퇴에 실패했습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get teamAutoSetBanner => '설문 기반으로 응원하는 팀이 자동으로 설정됐어요!';

  @override
  String get myActivity => '내 활동';

  @override
  String get screenSetting => '화면 설정';

  @override
  String get generalSetting => '일반 설정';

  @override
  String get customerSupport => '고객 지원';

  @override
  String get account => '계정';

  @override
  String get narWebsiteDescription => '선수 스탯부터 상세 경기 데이터까지, 한눈에 분석해 보세요';

  @override
  String get quietHoursTitle => '방해 금지 모드';

  @override
  String get quietHoursDescription => '설정된 시간 동안 푸시 알림 없이 앱 내 알림함에만 쌓입니다';

  @override
  String get mySubscriptionSetting => '마이 구독 설정';

  @override
  String get matchListSetting => '경기리스트 설정';

  @override
  String get calendarSetting => '캘린더 설정';

  @override
  String get accountSetting => '계정 설정';

  @override
  String get withdrawTitle => '회원 탈퇴';

  @override
  String withdrawHeadline(String nickname) {
    return '$nickname님\n와딩을 떠나시는건가요.. 다시 돌아오실거죠?..';
  }

  @override
  String get withdrawWarningData =>
      '계정을 탈퇴하면 구독,알림,평점 등 모든 데이터가 삭제되며 되돌릴 수 없습니다.';

  @override
  String get withdrawWarningImmediate => '완료를 누를시 즉시 탈퇴됩니다.';

  @override
  String get withdrawFeedback =>
      '와딩은 소중한 피드백으로 매일 성장하고 있어요.\n아쉬웠던 점을 알려주시면 바로 해결해 드릴게요.';

  @override
  String get withdrawSubmit => '와딩 회원 탈퇴하기';

  @override
  String get accountNickname => '닉네임';

  @override
  String get accountEmail => '이메일';

  @override
  String get logoutConfirmTitle => '로그아웃 하시겠습니까?';

  @override
  String logoutConfirmMessage(String email) {
    return '현재 로그인된 $email 계정에서 로그아웃됩니다.';
  }

  @override
  String get logoutConfirmButton => '로그아웃';

  @override
  String get calendarWeekStartDescription => '주 시작 요일(월요일/일요일)을 설정합니다.';

  @override
  String get spoilerCard => '스포 방지 카드';

  @override
  String get spoilerCardDescription => '스코어 스포 방지 카드를 ON/OFF 할 수 있습니다';

  @override
  String get screenSettingMatchList => '경기 리스트';

  @override
  String get screenSettingCalendar => '캘린더';

  @override
  String get myReviewRating => '내 리뷰/평점';

  @override
  String get customerService => '고객센터/문의';

  @override
  String get notice => '공지사항';

  @override
  String get noticeAdmin => '관리자';

  @override
  String get noticeEmpty => '공지사항이 없어요';

  @override
  String get noticeLoadFailed => '공지사항을 불러오지 못했어요';

  @override
  String get noticePinned => '📌 고정';

  @override
  String get noticeDraft => '임시저장';

  @override
  String get noticeListButton => '목록';

  @override
  String get narWebsite => '나르지지 웹사이트';

  @override
  String get latestVersion => '최신 버전입니다.';

  @override
  String currentVersion(String version) {
    return '(현재 버전 $version)';
  }

  @override
  String get logout => '로그아웃';

  @override
  String get myPage => '마이 페이지';

  @override
  String get nicknamePlaceholder => '닉네임';

  @override
  String get profileEdit => '프로필 수정';

  @override
  String countUnit(int count) {
    return '$count건';
  }

  @override
  String get appInfo => '앱정보';

  @override
  String get languageSetting => '언어 설정';

  @override
  String get languageKo => '한국어';

  @override
  String get languageEn => 'English';

  @override
  String get subscriptionTeamAlarmSettings => '구독 팀 알림 설정';

  @override
  String get subscriptionAlarmDetailSettings => '구독 알림 세부 설정';

  @override
  String get soloRankStartAlarm => '솔랭 시작 알림';

  @override
  String get soloRankEndAlarm => '솔랭 종료 알림';

  @override
  String get noSubscribedPlayer => '구독중인 선수가 없어요.';

  @override
  String get subscriptionManage => '구독 관리';

  @override
  String get teamPlayerSubscriptionManage => '팀/ 선수 구독 관리';

  @override
  String get subscriptionManageDescription => '마이구독 설정 페이지로 이동합니다.';

  @override
  String get noSubscribedTeam => '구독중인 팀이 없어요.';

  @override
  String get profileEditTitle => '프로필 수정';

  @override
  String get nameLabel => '이름';

  @override
  String get nameHint => '이름을 입력하세요';

  @override
  String get tagLabel => '태그';

  @override
  String get tagHint => '#태그';

  @override
  String get done => '완료';

  @override
  String get cheerTeamSetting => '응원 팀 설정';

  @override
  String get cheerTeamDescription => '1. 응원 팀 설정시 닉네임 옆에 뱃지가 생겨요';

  @override
  String get cheerTeamDescriptionCalendar => '2. 캘린더 일정에서 응원 팀 전용 필터가 생겨요';

  @override
  String get cumulativeReviewRating => '누적 리뷰/평점';

  @override
  String get reviewView => '리뷰보기';

  @override
  String get reviewDelete => '리뷰삭제';

  @override
  String get deleteFailed2 => '삭제에 실패했어요. 잠시 후 다시 시도해주세요.';

  @override
  String get loginFailed => '로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get appleLogin => 'Apple 로그인';

  @override
  String get kakaoLogin => '카카오 로그인';

  @override
  String get naverLogin => '네이버 로그인';

  @override
  String get googleLogin => 'Google 로그인';

  @override
  String get guestStart => '비회원으로 시작하기';

  @override
  String get easyLogin => '간편 로그인';

  @override
  String get skipButton => '건너뛰기';

  @override
  String get startWarding => '와딩 시작하기';

  @override
  String get next => '다음';

  @override
  String get preferredLeague => '선호 리그';

  @override
  String get preferredTeam => '선호 팀';

  @override
  String get preferredPlayer => '선호 선수';

  @override
  String get notificationPermission => '알림 권한';

  @override
  String get favoriteLeagueQuestion => '즐겨 시청하는 리그는 무엇인가요?';

  @override
  String get leagueLoadFailed => '리그 목록을 불러오지 못했어요';

  @override
  String get favoriteTeamQuestion => '가장 응원하는 팀을 선택해주세요';

  @override
  String get domesticTeamNote => 'LCK 국내 팀 기준입니다.';

  @override
  String get teamLoadFailed => '팀 목록을 불러오지 못했어요';

  @override
  String get favoritePlayerQuestion => '응원하는 선수를 선택해주세요';

  @override
  String get domesticPlayerNote => 'LCK 국내 팀 기준입니다. (중복 가능)';

  @override
  String get playerLoadFailed => '선수 목록을 불러오지 못했어요';

  @override
  String get noPlayerInfo => '선수 정보가 없어요';

  @override
  String get teamSelect => '팀 선택';

  @override
  String get notificationQuestion => '\'Warding\'에서 보내는 이벤트 및 알림을 받아보시겠습니까?';

  @override
  String get notificationConsentMessage =>
      '수신 동의 시 이벤트, 경기/팀/선수 등 다양한 정보에 대한 알림을 받아보실 수 있습니다.';

  @override
  String get readyComplete => '준비 완료!';

  @override
  String get enjoyMessage => '응원하는 팀과 선수의 경기,\n이제 놓치지 말고 즐겨보세요.';

  @override
  String get deny => '허용 안 함';

  @override
  String get allow => '허용';

  @override
  String get retry => '다시 시도';

  @override
  String get selected => '선택됨';

  @override
  String get matchSchedule => '경기 일정';

  @override
  String get matchLoadFailed => '경기를 불러오지 못했어요';

  @override
  String get navSchedule => '일정';

  @override
  String get navMatchList => '리스트';

  @override
  String get navCommunity => '커뮤니티';

  @override
  String get navSubscription => '구독';

  @override
  String get navMyPage => '내정보';

  @override
  String get defaultCancel => '취소';

  @override
  String get defaultConfirm => '확인';

  @override
  String get filterApply => '조회하기';

  @override
  String get searchHint => '팀 또는 선수 검색..';

  @override
  String get selectHint => '선택';

  @override
  String get searchInputHint => '검색어를 입력...';

  @override
  String get noSearchResults => '검색 결과가 없어요';

  @override
  String get loginRequired => '로그인 후 사용 가능';

  @override
  String get fallbackPlayer => '선수';

  @override
  String get fallbackChampionInfo => '챔피언 정보 확인 중';

  @override
  String get liveMatchNotification => '라이브 경기 알림';

  @override
  String get watchBroadcastFallback => '중계 보기';

  @override
  String get objectKill => '킬';

  @override
  String get objectDragon => '드래곤';

  @override
  String objectSubDragon(String sub) {
    return '$sub드래곤';
  }

  @override
  String get objectBaron => '바론';

  @override
  String get objectTower => '타워';

  @override
  String get objectInhibitor => '억제기';

  @override
  String get objectNexus => '넥서스';

  @override
  String get notificationChannelName => '구독 알림';

  @override
  String get notificationChannelDesc => '구독 선수·팀의 경기/이벤트 알림';

  @override
  String get duplicateNickname => '이미 사용 중인 닉네임입니다';

  @override
  String get sortRecent => '최근순';

  @override
  String get sortOldest => '오래된 순';

  @override
  String get sortUpcoming => '오늘 이후';

  @override
  String get scheduleLoadFailed => '경기 일정을 불러오지 못했어요';

  @override
  String get filterLoadFailed => '필터를 불러오지 못했어요. 잠시 후 다시 시도해 주세요';

  @override
  String get playerRatingLoadFailed => '선수 평점을 불러오지 못했어요';

  @override
  String get noPlayerRecordInSet => '이 세트에는 해당 선수 기록이 없어요';

  @override
  String get setRatingLoadFailed => '세트 평점을 불러오지 못했어요';

  @override
  String get setInfoNotFound => '세트 정보를 찾을 수 없어요';

  @override
  String get championPickLoadFailed => '챔피언 픽을 불러오지 못했어요';

  @override
  String get liveEventLoadFailed => '라이브 이벤트를 불러오지 못했어요';

  @override
  String get playerRatingLoadFailed2 => '선수 평점을 불러오지 못했어요';

  @override
  String get subscriptionLoadFailed => '구독 정보를 불러오지 못했어요';

  @override
  String get notificationLoadFailed => '알림을 불러오지 못했습니다.';

  @override
  String get teamAlarmLoadFailed => '팀 알림 정보를 불러오지 못했어요';

  @override
  String get teamAlarmSaveFailed => '팀 알림 설정을 저장하지 못했어요';

  @override
  String get playerAlarmSaveFailed => '선수 알림 설정을 저장하지 못했어요';

  @override
  String get profileLoadFailed => '프로필을 불러오지 못했어요';

  @override
  String get requiredField => '필수 입력 항목입니다.';

  @override
  String get tagFormatError => '영문/숫자 2~5자로 입력하세요.';

  @override
  String get duplicateNicknameError => '이미 사용 중인 닉네임입니다.';

  @override
  String get saveFailed => '저장에 실패했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get myReviewLoadFailed => '내 평가를 불러오지 못했어요';

  @override
  String get laneTop => '탑';

  @override
  String get laneJungle => '정글';

  @override
  String get laneMid => '미드';

  @override
  String get laneBot => '원딜';

  @override
  String get laneBotAlt => '바텀';

  @override
  String get laneSupport => '서폿';

  @override
  String get laneSupportAlt => '서포터';

  @override
  String weekRound(int week) {
    return '$week주 차';
  }

  @override
  String nthRound(int n) {
    return '$n강';
  }

  @override
  String get stagePlayIn => '플레이-인';

  @override
  String get stagePlayInTournament => '플레이-인 토너먼트 스테이지';

  @override
  String get stageGroup => '그룹';

  @override
  String get stageSwiss => '스위스';

  @override
  String get stageTournament => '토너먼트 스테이지';

  @override
  String get stagePlayoff => '플레이오프';

  @override
  String get stageFinal => '결승';

  @override
  String get updateAvailableTitle => '업데이트 안내';

  @override
  String get updateAvailableMessage => '새로운 버전이 출시되었습니다.\n최신 버전으로 업데이트해주세요.';

  @override
  String get updateNow => '업데이트';

  @override
  String get quietHours => '방해 금지 모드 설정';

  @override
  String get quietHoursUse => '방해 금지 모드 사용';

  @override
  String get quietHoursStart => '시작';

  @override
  String get quietHoursEnd => '종료';

  @override
  String get quietHoursOffHint => '사용하면 정한 시간엔 알림이 소리 없이 알림함에만 쌓입니다.';

  @override
  String quietHoursOnHint(String start, String end) {
    return '$start부터 $end까지 모든 알림이 소리 없이 알림함에만 쌓입니다.';
  }

  @override
  String get quietHoursStartSheetTitle => '잠자기 시작 시간';

  @override
  String get quietHoursEndSheetTitle => '잠자기 종료 시간';

  @override
  String get quietHoursSameTimeError => '시작과 종료가 같으면 안 됩니다. 다른 시간을 골라주세요.';

  @override
  String get quietHoursSaveFailed => '알림 잠자기 설정을 저장하지 못했습니다.';

  @override
  String get quietHoursAm => '오전';

  @override
  String get quietHoursPm => '오후';

  @override
  String get quietHoursSave => '저장';

  @override
  String get calendarWeekStartSetting => '캘린더 시작 요일';

  @override
  String get calendarWeekStartRowLabel => '시작 요일';

  @override
  String get calendarWeekStartMonday => '월요일';

  @override
  String get calendarWeekStartSunday => '일요일';

  @override
  String get guideExit => '가이드 종료하기';

  @override
  String get guide1Section => '마이 구독';

  @override
  String get guide1Headline => '좋아하는 팀 경기, 선수 솔랭 놓치지 않고 챙겨보세요';

  @override
  String get guide1Description => '온보딩에서 선택한 팀, 선수가 자동으로 구독돼요.';

  @override
  String get guide1CalloutPage => '1. 마이구독 페이지에서';

  @override
  String get guide1CalloutSettings => '2. 구독 설정 아이콘 클릭!';

  @override
  String get guide2Description => '응원하는 팀,선수가 더 있다면 마이구독 설정에서 언제든 추가할 수 있어요.';

  @override
  String get guide3Section => '마이 페이지';

  @override
  String get guide3Headline => '경기, 솔랭 알림을 커스텀 해보세요';

  @override
  String get guide3Description => '응원하는 팀,선수에 대한 알림 세부 설정을 커스텀 할 수 있어요.';

  @override
  String get guide5Headline => '와딩 사용자 편의성 맞춤 설정';

  @override
  String get guide5Description =>
      '방해 금지 모드, 캘린더 시작 요일 설정 등을 이용하여 더 편리하게 앱을 사용해 보세요';

  @override
  String get guide6Section => '배경화면 위젯, 라이브 위젯';

  @override
  String get guide6Headline => '다양한 와딩 위젯 제공';

  @override
  String get guide6Description =>
      '캘린더 위젯 ,라이브 위젯, 배경화면 위젯을 활용하여 와딩앱을 100% 활용해보세요.';

  @override
  String get guide6Footnote => '(위 이미지는 연출된 이미지 입니다. 실제 적용 화면은 상이할 수 있습니다.)';

  @override
  String get guide2CalloutAuto => '1. 온보딩에서 선택한 팀 자동 구독';

  @override
  String get guide2CalloutAdd => '2. 원하는 팀 추가 구독 설정 가능!';

  @override
  String get guide3CalloutMypage => '1. 마이페이지에서';

  @override
  String get guide3CalloutDisplay => '2. 화면설정> 마이구독 클릭!';

  @override
  String get guideMenu => '와딩 사용가이드';

  @override
  String get guidePopupBadge => '와딩 200% 즐기기';

  @override
  String get guidePopupTitle => '환영해요! 와딩 사용 꿀팁이 도착했어요';

  @override
  String get guidePopupMessage =>
      '지금 보지 않아도 [마이페이지 > 와딩 사용가이드]에서 언제든 다시 볼 수 있어요.';

  @override
  String get guidePopupDismiss => '다음에 볼게요';

  @override
  String get guidePopupConfirm => '가이드 보기';

  @override
  String get communityTitle => '커뮤니티';

  @override
  String get communityTabAll => '전체';

  @override
  String get communityTabTeam => '팀';

  @override
  String get communityWrite => '글쓰기';

  @override
  String get communityEmpty => '아직 글이 없어요. 첫 글을 남겨보세요.';

  @override
  String communityLockedTitle(String team) {
    return '$team 팬만 글을 쓸 수 있어요.';
  }

  @override
  String get communityLockedBody => '하고 싶은 말이 있으면 전체 게시판에서 나눠보세요.';

  @override
  String get communityLockedAction => '전체로 가기';

  @override
  String get communityNoTeamTitle => '응원팀을 정하면 팀 게시판에 글을 쓸 수 있어요.';

  @override
  String get communityNoTeamAction => '응원팀 정하기';

  @override
  String get communityCommentHint => '댓글을 입력하세요';

  @override
  String communityCommentLocked(String team) {
    return '$team 팬만 댓글을 쓸 수 있어요';
  }

  @override
  String get communityCommentSubmit => '등록';

  @override
  String communityCommentCount(int count) {
    return '댓글 $count';
  }

  @override
  String communityReplyCount(int count) {
    return '답글 $count개';
  }

  @override
  String get communityReply => '답글';

  @override
  String get communityLike => '추천';

  @override
  String get communityScrap => '스크랩';

  @override
  String communityViewCount(String count) {
    return '조회 $count';
  }

  @override
  String get communityBoardAll => '전체 게시판';

  @override
  String communityBoardTeam(String team) {
    return '$team 게시판';
  }

  @override
  String get communityWriteTitleLabel => '제목';

  @override
  String get communityWriteTitleHint => '제목을 입력하세요';

  @override
  String get communityWriteBodyLabel => '내용';

  @override
  String get communityWriteBodyHint =>
      '경기 이야기, 응원, 질문 무엇이든 좋아요.\n비방·도배는 신고 대상입니다.';

  @override
  String get communityWriteSubmit => '등록하기';

  @override
  String get communityMoreReport => '신고하기';

  @override
  String get communityMoreBlock => '이 사용자 차단';

  @override
  String get communityReportTitle => '신고 사유';

  @override
  String get communityReportAbuse => '욕설·비방';

  @override
  String get communityReportObscene => '음란물 유포';

  @override
  String get communityReportAd => '상업적 광고 및 판매';

  @override
  String get communityReportFraud => '유출·사칭·사기';

  @override
  String get communityReportSpam => '도배';

  @override
  String get communityReportEtc => '기타';

  @override
  String get communityReportEtcHint => '어떤 점이 문제인지 알려주세요';

  @override
  String get communityReportSubmit => '신고하기';

  @override
  String get communityReportDone => '신고가 접수되었어요.';

  @override
  String get communityBlockDone => '이 사용자의 글이 보이지 않아요.';

  @override
  String get termsOfService => '이용약관';

  @override
  String get privacyPolicy => '개인정보처리방침';

  @override
  String loginConsentNotice(String terms, String privacy) {
    return '로그인 시 $terms 및 $privacy에 동의합니다';
  }

  @override
  String get communityGuestWrite => '로그인하고 응원팀을 정하면 글을 쓸 수 있어요.';

  @override
  String get communityTabMyTeam => '우리팀';

  @override
  String get communityTabOtherTeams => '다른팀';

  @override
  String get communityRulesTitle => '커뮤니티 이용규칙';

  @override
  String get communityRulesSeeAll => '커뮤니티 이용규칙 전체 보기';

  @override
  String get communityAttachPhoto => '사진';

  @override
  String get communityAttachPoll => '투표';

  @override
  String communityPhotoCount(int count) {
    return '$count/5';
  }

  @override
  String get communityPollQuestionHint => '투표 주제를 입력하세요';

  @override
  String communityPollOptionHint(int index) {
    return '항목 $index';
  }

  @override
  String get communityPollAddOption => '항목 추가 (최대 5개)';

  @override
  String get communityPollHideResults => '투표해야 결과 보기';

  @override
  String get communityPollRemove => '투표 삭제';

  @override
  String communityPollPrompt(int count) {
    return '$count명 참여 · 투표하면 결과가 보여요';
  }

  @override
  String communityPollVoted(int count) {
    return '$count명 참여';
  }
}
