// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Warding';

  @override
  String get logoutFailed => 'Logout failed. Please try again later.';

  @override
  String get mainScreenPlaceholder => 'Main screen (coming soon)';

  @override
  String get matchList => 'Match List';

  @override
  String get season => 'Season';

  @override
  String get league => 'League';

  @override
  String get loading => 'Loading...';

  @override
  String get select => 'Select';

  @override
  String get noMatches => 'No matches found';

  @override
  String setInProgress(int setNumber) {
    return 'SET $setNumber In Progress';
  }

  @override
  String setWinner(int setNumber, String teamCode) {
    return 'SET $setNumber $teamCode Win';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String monthDay(int month, int day) {
    return '$month/$day';
  }

  @override
  String get setStartAlarm => 'Set Start Alarm';

  @override
  String get setEndAlarm => 'Set End Alarm';

  @override
  String get liveEventAlarm => 'Live Event Alarm';

  @override
  String get confirm => 'OK';

  @override
  String get matchAlarmSettings => 'Match Alarm Settings';

  @override
  String get matchAlarmRemoved => 'Match alarm has been removed';

  @override
  String get matchAlarmRemoveFailed =>
      'Failed to remove alarm. Please try again.';

  @override
  String get matchAlarmRegistered => 'Match alarm has been registered';

  @override
  String get matchAlarmRegisterFailed =>
      'Failed to register alarm. Please try again.';

  @override
  String get spoilerBlock => 'Spoiler Block';

  @override
  String get clickToSeeScore => 'Tap to reveal score';

  @override
  String get spoilerPreventionOn => 'Spoiler Protection ON';

  @override
  String get spoilerPreventionOff => 'Spoiler Protection OFF';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get filter => 'Filter';

  @override
  String get team => 'Team';

  @override
  String get all => 'All';

  @override
  String get monthlyScheduleSummary => 'Monthly Schedule Summary';

  @override
  String get ratingSaveFailed =>
      'Failed to save rating. Please try again later.';

  @override
  String get deleteMyRatingConfirm => 'Delete your rating?';

  @override
  String get deleteMyRatingMessage =>
      'Deleted comments cannot be restored. You can edit comments using the edit feature.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get ratingDeleteFailed =>
      'Failed to delete rating. Please try again later.';

  @override
  String get playerRating => 'Player Rating';

  @override
  String get me => 'Me';

  @override
  String get leaveRating => 'Rate';

  @override
  String get myComment => 'My Comment';

  @override
  String get ratingAndComment => 'Ratings & Comments';

  @override
  String totalCount(int count) {
    return '$count total';
  }

  @override
  String get leaveRatingAndComment => 'Leave Rating & Comment';

  @override
  String get ratingCommentHint =>
      'Share your thoughts on the player\'s performance.';

  @override
  String get ratingCommentWarning =>
      'Excessive criticism or inappropriate language may be removed without prior notice per our policy.';

  @override
  String get submit => 'Submit';

  @override
  String totalParticipants(int count) {
    return '$count participants';
  }

  @override
  String get subscribedPlayer => 'Your subscribed player';

  @override
  String get leaveRatingForPlayer => ' — rate now!';

  @override
  String get championPick => 'Champion Pick';

  @override
  String get liveEvent => 'Live Event';

  @override
  String get tabPlayerRating => 'Player Rating';

  @override
  String setLabel(int order) {
    return 'Set $order';
  }

  @override
  String get inProgress => 'In Progress';

  @override
  String get broadcastChannelSelect => 'Select Broadcast Channel';

  @override
  String get watchOnPlatform => 'Continue watching on your preferred platform';

  @override
  String get official => 'Official';

  @override
  String get matchDetail => 'Match Detail';

  @override
  String get playerRatingAfterMatch =>
      'Player ratings are available after the match!';

  @override
  String get watchBroadcast => 'Watch';

  @override
  String get rewatch => 'Replay';

  @override
  String get matchEnded => 'Ended';

  @override
  String get preparing => 'Preparing';

  @override
  String get liveEventAfterMatch =>
      'Live events are available after the match starts!';

  @override
  String get championPickAfterMatch =>
      'Champion picks are available after the match starts!';

  @override
  String get championPickAfterMatchAlt =>
      'Champion picks can be viewed after the match starts!';

  @override
  String get eventDuringMatch => 'Events are available during the match!';

  @override
  String get loadingLiveEvents => 'Loading live events...';

  @override
  String get matchScheduled => 'Scheduled';

  @override
  String get matchInProgress => 'In Progress';

  @override
  String allPlayerRatingForSet(String setTitle) {
    return '$setTitle All Player Ratings';
  }

  @override
  String setEndedLeaveRating(String setText) {
    return '$setText has ended! Rate each player now';
  }

  @override
  String get totalPrefix => 'Total ';

  @override
  String get participantsSuffix => ' participants';

  @override
  String playerRatingWithCount(String rating, int count) {
    return '$rating ($count)';
  }

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String hoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get eventTypeAll => 'All';

  @override
  String get eventTypeSetStart => 'Set Start';

  @override
  String get eventTypeSetEnd => 'Set End';

  @override
  String get deleteSwipe => 'Delete';

  @override
  String get deleteFailed => 'Failed to delete.';

  @override
  String get deleteAllAlarms => 'Delete All Notifications';

  @override
  String get deleteAllAlarmsMessage => 'Delete all received notifications?';

  @override
  String get enableNotificationPermission =>
      'Please enable notification permission to receive alerts.';

  @override
  String get noNotifications => 'No notifications.';

  @override
  String get mySubscription => 'My Subscription';

  @override
  String get subscribedTeams => 'Subscribed Teams';

  @override
  String get subscribedPlayers => 'Subscribed Players';

  @override
  String get subscriptionSettings => 'Subscription Settings';

  @override
  String get fullList => 'Full List';

  @override
  String get tabTeam => 'Team';

  @override
  String get tabPlayer => 'Player';

  @override
  String get dateLabel => 'Date';

  @override
  String get allPlayers => 'All Players';

  @override
  String get player => 'Player';

  @override
  String get playerSelect => 'Select Player';

  @override
  String get subscribedPlayerList => 'Subscribed Players';

  @override
  String get subscribing => 'Subscribed';

  @override
  String get subscribe => 'Subscribe';

  @override
  String liveEventNotificationTitle(String teamA, String teamB) {
    return '$teamA VS $teamB Live Event!';
  }

  @override
  String liveEventNotificationBody(String season, String teamA, String teamB) {
    return '$season _ $teamA VS $teamB — Check the live event now';
  }

  @override
  String get foldDetail => 'Collapse';

  @override
  String get showDetail => 'Details';

  @override
  String matchEndNotificationTitle(String teamA, String teamB) {
    return '$teamA VS $teamB match has ended.';
  }

  @override
  String matchEndNotificationBody(String season, String teamA, String teamB) {
    return '$season _ $teamA VS $teamB match has ended. Rate the players now!';
  }

  @override
  String get leaveMatchRating => 'Rate Match';

  @override
  String matchStartNotificationTitle(String teamA, String teamB) {
    return '$teamA VS $teamB match is starting!';
  }

  @override
  String matchStartNotificationBody(String season, String teamA, String teamB) {
    return '$season _ Your team $teamA vs $teamB match is starting.';
  }

  @override
  String get soloRank => 'Solo Rank';

  @override
  String rankStartTitle(String playerName) {
    return '$playerName ranked game detected!';
  }

  @override
  String rankStartBody(
    String playerName,
    String champion,
    String particle,
    String queueType,
  ) {
    return '$playerName has started a $queueType game as $champion';
  }

  @override
  String get withdraw => 'Delete Account';

  @override
  String get withdrawConfirmTitle => 'Delete Account';

  @override
  String get withdrawConfirmMessage =>
      'Your account and all data including subscriptions,\nnotifications, and ratings will be permanently deleted.';

  @override
  String get withdrawConfirmButton => 'Delete';

  @override
  String get withdrawFailed =>
      'Account deletion failed. Please try again later.';

  @override
  String get teamAutoSetBanner =>
      'Your cheer team has been automatically set based on your survey!';

  @override
  String get myReviewRating => 'My Reviews/Ratings';

  @override
  String get customerService => 'Support/Inquiry';

  @override
  String get notice => 'Notices';

  @override
  String get noticeAdmin => 'Admin';

  @override
  String get noticeEmpty => 'No notices yet';

  @override
  String get noticeLoadFailed => 'Couldn\'t load notices';

  @override
  String get noticePinned => '📌 Pinned';

  @override
  String get noticeDraft => 'Draft';

  @override
  String get narWebsite => 'NAR.GG Website';

  @override
  String get latestVersion => 'You\'re up to date.';

  @override
  String currentVersion(String version) {
    return '(Version $version)';
  }

  @override
  String get logout => 'Log Out';

  @override
  String get myPage => 'My Page';

  @override
  String get nicknamePlaceholder => 'Nickname';

  @override
  String get profileEdit => 'Edit Profile';

  @override
  String countUnit(int count) {
    return '$count';
  }

  @override
  String get appInfo => 'App Info';

  @override
  String get languageSetting => 'Language';

  @override
  String get languageKo => '한국어';

  @override
  String get languageEn => 'English';

  @override
  String get subscriptionTeamAlarmSettings => 'Team Alarm Settings';

  @override
  String get subscriptionManage => 'Manage';

  @override
  String get noSubscribedTeam => 'No subscribed teams.';

  @override
  String get profileEditTitle => 'Edit Profile';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameHint => 'Enter your name';

  @override
  String get tagLabel => 'Tag';

  @override
  String get tagHint => '#Tag';

  @override
  String get done => 'Done';

  @override
  String get cheerTeamSetting => 'Cheer Team';

  @override
  String get cheerTeamDescription =>
      'Setting a cheer team adds a badge next to your nickname';

  @override
  String get cumulativeReviewRating => 'Total Reviews/Ratings';

  @override
  String get reviewView => 'View';

  @override
  String get reviewDelete => 'Delete';

  @override
  String get deleteFailed2 => 'Failed to delete. Please try again later.';

  @override
  String get loginFailed => 'Login failed. Please try again later.';

  @override
  String get appleLogin => 'Sign in with Apple';

  @override
  String get kakaoLogin => 'Sign in with Kakao';

  @override
  String get naverLogin => 'Sign in with Naver';

  @override
  String get googleLogin => 'Sign in with Google';

  @override
  String get guestStart => 'Continue as Guest';

  @override
  String get easyLogin => 'Sign In';

  @override
  String get skipButton => 'Skip';

  @override
  String get startWarding => 'Start Warding';

  @override
  String get next => 'Next';

  @override
  String get preferredLeague => 'Preferred League';

  @override
  String get preferredTeam => 'Preferred Team';

  @override
  String get preferredPlayer => 'Preferred Player';

  @override
  String get notificationPermission => 'Notifications';

  @override
  String get favoriteLeagueQuestion => 'Which leagues do you watch?';

  @override
  String get leagueLoadFailed => 'Failed to load leagues';

  @override
  String get favoriteTeamQuestion => 'Select your favorite team';

  @override
  String get domesticTeamNote => 'Based on LCK domestic teams.';

  @override
  String get teamLoadFailed => 'Failed to load teams';

  @override
  String get favoritePlayerQuestion => 'Select your favorite players';

  @override
  String get domesticPlayerNote =>
      'Based on LCK domestic teams. (Multiple selection)';

  @override
  String get playerLoadFailed => 'Failed to load players';

  @override
  String get noPlayerInfo => 'No player info available';

  @override
  String get teamSelect => 'Select Team';

  @override
  String get notificationQuestion =>
      'Would you like to receive events and notifications from Warding?';

  @override
  String get notificationConsentMessage =>
      'By opting in, you can receive notifications about events, matches, teams, and players.';

  @override
  String get readyComplete => 'All Set!';

  @override
  String get enjoyMessage =>
      'Never miss a match from\nyour favorite teams and players.';

  @override
  String get deny => 'Deny';

  @override
  String get allow => 'Allow';

  @override
  String get retry => 'Retry';

  @override
  String get selected => 'Selected';

  @override
  String get matchSchedule => 'Match Schedule';

  @override
  String get matchLoadFailed => 'Failed to load matches';

  @override
  String get navSchedule => 'Schedule';

  @override
  String get navMatchList => 'Matches';

  @override
  String get navSubscription => 'My Sub';

  @override
  String get navMyPage => 'My Page';

  @override
  String get defaultCancel => 'Cancel';

  @override
  String get defaultConfirm => 'OK';

  @override
  String get filterApply => 'Apply';

  @override
  String get searchHint => 'Search teams or players..';

  @override
  String get selectHint => 'Select';

  @override
  String get searchInputHint => 'Enter search term...';

  @override
  String get loginRequired => 'Login required';

  @override
  String get fallbackPlayer => 'Player';

  @override
  String get fallbackChampionInfo => 'Loading champion info';

  @override
  String get liveMatchNotification => 'Live Match Notification';

  @override
  String get watchBroadcastFallback => 'Watch';

  @override
  String get objectDragon => 'Dragon';

  @override
  String objectSubDragon(String sub) {
    return '$sub Dragon';
  }

  @override
  String get objectBaron => 'Baron';

  @override
  String get objectTower => 'Tower';

  @override
  String get objectInhibitor => 'Inhibitor';

  @override
  String get notificationChannelName => 'Subscription Alerts';

  @override
  String get notificationChannelDesc =>
      'Notifications for subscribed players and teams';

  @override
  String get duplicateNickname => 'This nickname is already in use';

  @override
  String get sortRecent => 'Recent';

  @override
  String get sortOldest => 'Oldest';

  @override
  String get scheduleLoadFailed => 'Failed to load schedule';

  @override
  String get playerRatingLoadFailed => 'Failed to load player ratings';

  @override
  String get noPlayerRecordInSet => 'No player record in this set';

  @override
  String get setRatingLoadFailed => 'Failed to load set ratings';

  @override
  String get setInfoNotFound => 'Set info not found';

  @override
  String get championPickLoadFailed => 'Failed to load champion picks';

  @override
  String get liveEventLoadFailed => 'Failed to load live events';

  @override
  String get playerRatingLoadFailed2 => 'Failed to load player ratings';

  @override
  String get subscriptionLoadFailed => 'Failed to load subscriptions';

  @override
  String get notificationLoadFailed => 'Failed to load notifications.';

  @override
  String get teamAlarmLoadFailed => 'Failed to load team alarm settings';

  @override
  String get profileLoadFailed => 'Failed to load profile';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get tagFormatError => '2-5 alphanumeric characters required.';

  @override
  String get duplicateNicknameError => 'This nickname is already in use.';

  @override
  String get saveFailed => 'Failed to save. Please try again later.';

  @override
  String get myReviewLoadFailed => 'Failed to load reviews';

  @override
  String get laneTop => 'Top';

  @override
  String get laneJungle => 'Jungle';

  @override
  String get laneMid => 'Mid';

  @override
  String get laneBot => 'ADC';

  @override
  String get laneBotAlt => 'Bot';

  @override
  String get laneSupport => 'Support';

  @override
  String get laneSupportAlt => 'Support';

  @override
  String weekRound(int week) {
    return 'Week $week';
  }

  @override
  String nthRound(int n) {
    return 'Top $n';
  }

  @override
  String get stagePlayIn => 'Play-In';

  @override
  String get stagePlayInTournament => 'Play-In Tournament Stage';

  @override
  String get stageGroup => 'Group';

  @override
  String get stageSwiss => 'Swiss';

  @override
  String get stageTournament => 'Tournament Stage';

  @override
  String get stagePlayoff => 'Playoff';

  @override
  String get stageFinal => 'Final';

  @override
  String get updateAvailableTitle => 'Update Available';

  @override
  String get updateAvailableMessage =>
      'A new version is available.\nPlease update to the latest version.';

  @override
  String get updateNow => 'Update';
}
