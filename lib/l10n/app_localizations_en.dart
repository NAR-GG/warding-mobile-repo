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
  String yearMonthDay(int year, int month, int day) {
    return '$month/$day/$year';
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
  String get spoilerBlock => 'Spoiler';

  @override
  String get clickToSeeScore => 'Tap to reveal score';

  @override
  String get spoilerPreventionOn => 'Spoiler ON';

  @override
  String get spoilerPreventionOff => 'Spoiler OFF';

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
  String get playerSortByPosition => 'Position';

  @override
  String get playerSortByName => 'Name (A–Z)';

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
    return '$playerName started a ranked game';
  }

  @override
  String rankStartBody(String champion, String particle, String queueType) {
    return 'Playing $queueType as $champion';
  }

  @override
  String rankEndTitle(String playerName) {
    return '$playerName finished a ranked game';
  }

  @override
  String rankEndBodyResult(String champion, String particle, String result) {
    return '$result with $champion';
  }

  @override
  String rankEndBodyNoResult(String champion) {
    return 'Game ended with $champion';
  }

  @override
  String get rankEndWin => 'Win';

  @override
  String get rankEndLose => 'Loss';

  @override
  String rankEndDurationMinutes(int minutes) {
    return '${minutes}m';
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
  String get myActivity => 'My Activity';

  @override
  String get screenSetting => 'Display Settings';

  @override
  String get generalSetting => 'General Settings';

  @override
  String get customerSupport => 'Support';

  @override
  String get account => 'Account';

  @override
  String get narWebsiteDescription =>
      'Analyze everything from player stats to detailed match data at a glance';

  @override
  String get quietHoursTitle => 'Do Not Disturb';

  @override
  String get quietHoursDescription =>
      'Notifications arrive silently in your in-app inbox during the set hours';

  @override
  String get mySubscriptionSetting => 'My Subscription Settings';

  @override
  String get matchListSetting => 'Match List Settings';

  @override
  String get calendarSetting => 'Calendar Settings';

  @override
  String get accountSetting => 'Account Settings';

  @override
  String get withdrawTitle => 'Delete Account';

  @override
  String withdrawHeadline(String nickname) {
    return '$nickname\nAre you leaving Warding.. You\'ll come back, right?..';
  }

  @override
  String get withdrawWarningData =>
      'Deleting your account erases all data including subscriptions, notifications, and ratings. This cannot be undone.';

  @override
  String get withdrawWarningImmediate =>
      'Tapping Done deletes your account immediately.';

  @override
  String get withdrawFeedback =>
      'Warding grows every day on your feedback.\nTell us what fell short and we\'ll fix it right away.';

  @override
  String get withdrawSubmit => 'Delete my Warding account';

  @override
  String get accountNickname => 'Nickname';

  @override
  String get accountEmail => 'Email';

  @override
  String get logoutConfirmTitle => 'Log out?';

  @override
  String logoutConfirmMessage(String email) {
    return 'You will be logged out of $email.';
  }

  @override
  String get logoutConfirmButton => 'Log out';

  @override
  String get calendarWeekStartDescription =>
      'Choose which day the week starts on (Monday/Sunday).';

  @override
  String get spoilerCard => 'Spoiler Guard Card';

  @override
  String get spoilerCardDescription =>
      'Turn the score spoiler guard card on or off';

  @override
  String get screenSettingMatchList => 'Match List';

  @override
  String get screenSettingCalendar => 'Calendar';

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
  String get noticeListButton => 'List';

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
  String get subscriptionAlarmDetailSettings => 'Subscription Alarm Details';

  @override
  String get soloRankStartAlarm => 'Solo Rank Start Alarm';

  @override
  String get soloRankEndAlarm => 'Solo Rank End Alarm';

  @override
  String get noSubscribedPlayer => 'No subscribed players.';

  @override
  String get subscriptionManage => 'Manage';

  @override
  String get teamPlayerSubscriptionManage => 'Team / Player Subscriptions';

  @override
  String get subscriptionManageDescription =>
      'Go to the My Subscription settings page.';

  @override
  String get noSubscribedTeam => 'No subscribed teams.';

  @override
  String get profileEditTitle => 'Edit Profile';

  @override
  String get profileTeamChangeConfirmTitle => 'Change your team?';

  @override
  String profileTeamChangeConfirmBody(String team) {
    return 'Switching to $team locks your team for 30 days.';
  }

  @override
  String get profileTeamChangeConfirmOk => 'Change';

  @override
  String get profileTeamChangeLockedTitle =>
      'You can change your team once every 30 days';

  @override
  String profileTeamChangeLockedBody(String date) {
    return 'You can change it again from $date.';
  }

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
      '1. Setting a cheer team adds a badge next to your nickname';

  @override
  String get cheerTeamDescriptionCalendar =>
      '2. You also get a cheer-team filter in the calendar';

  @override
  String get cumulativeReviewRating => 'Total Reviews/Ratings';

  @override
  String get reviewView => 'View';

  @override
  String get reviewDelete => 'Delete';

  @override
  String get deleteFailed2 => 'Failed to delete. Please try again later.';

  @override
  String get myCommunityActivity => 'My Activity';

  @override
  String get myCommunityPosts => 'My Posts';

  @override
  String get myCommunityComments => 'My Comments';

  @override
  String get myCommunityBadgeAll => 'All';

  @override
  String get myCommunityPostsEmpty => 'You haven\'t written any posts yet';

  @override
  String get myCommunityCommentsEmpty =>
      'You haven\'t written any comments yet';

  @override
  String get communityScrapEmpty => 'No saved posts yet';

  @override
  String myCommunityCommentMeta(String timeAgo, int likeCount) {
    return '$timeAgo · $likeCount likes';
  }

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
  String get navCommunity => 'Community';

  @override
  String get navSubscription => 'Subs';

  @override
  String get navMyPage => 'Me';

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
  String get noSearchResults => 'No search results';

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
  String get objectKill => 'Kill';

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
  String get objectNexus => 'Nexus';

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
  String get sortUpcoming => 'Upcoming';

  @override
  String get scheduleLoadFailed => 'Failed to load schedule';

  @override
  String get filterLoadFailed =>
      'Couldn\'t load filters. Please try again in a moment';

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
  String get teamAlarmSaveFailed => 'Failed to save team alarm settings';

  @override
  String get playerAlarmSaveFailed => 'Failed to save player alarm settings';

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

  @override
  String get quietHours => 'Quiet hours';

  @override
  String get quietHoursUse => 'Use quiet hours';

  @override
  String get quietHoursStart => 'From';

  @override
  String get quietHoursEnd => 'To';

  @override
  String get quietHoursOffHint =>
      'When enabled, notifications arrive silently and stay in your inbox.';

  @override
  String quietHoursOnHint(String start, String end) {
    return 'From $start to $end, all notifications arrive silently and stay in your inbox.';
  }

  @override
  String get quietHoursStartSheetTitle => 'Quiet hours start';

  @override
  String get quietHoursEndSheetTitle => 'Quiet hours end';

  @override
  String get quietHoursSameTimeError =>
      'Start and end can\'t be the same. Pick a different time.';

  @override
  String get quietHoursSaveFailed => 'Couldn\'t save your quiet hours.';

  @override
  String get quietHoursAm => 'AM';

  @override
  String get quietHoursPm => 'PM';

  @override
  String get quietHoursSave => 'Save';

  @override
  String get calendarWeekStartSetting => 'Calendar start day';

  @override
  String get calendarWeekStartRowLabel => 'Starts on';

  @override
  String get calendarWeekStartMonday => 'Monday';

  @override
  String get calendarWeekStartSunday => 'Sunday';

  @override
  String get guideExit => 'Exit guide';

  @override
  String get guide1Section => 'My Subscription';

  @override
  String get guide1Headline =>
      'Never miss your team\'s matches or your players\' solo queue';

  @override
  String get guide1Description =>
      'The teams and players you picked during onboarding are subscribed automatically.';

  @override
  String get guide1CalloutPage => '1. On the My Subscription page';

  @override
  String get guide1CalloutSettings => '2. Tap the settings icon!';

  @override
  String get guide2Description =>
      'Want to follow more teams or players? Add them anytime in My Subscription settings.';

  @override
  String get guide3Section => 'My Page';

  @override
  String get guide3Headline => 'Customize your match and solo queue alerts';

  @override
  String get guide3Description =>
      'Fine-tune notifications for the teams and players you follow.';

  @override
  String get guide5Headline => 'Make Warding work the way you want';

  @override
  String get guide5Description =>
      'Use Do Not Disturb, calendar start day, and more to tailor the app to you.';

  @override
  String get guide6Section => 'Home screen & live widgets';

  @override
  String get guide6Headline => 'Widgets for every screen';

  @override
  String get guide6Description =>
      'Get the most out of Warding with calendar, live, and home screen widgets.';

  @override
  String get guide6Footnote =>
      '(Image is for illustration only. Actual screens may differ.)';

  @override
  String get guide2CalloutAuto => '1. Teams you picked are subscribed';

  @override
  String get guide2CalloutAdd => '2. Add more teams anytime!';

  @override
  String get guide3CalloutMypage => '1. From My Page';

  @override
  String get guide3CalloutDisplay => '2. Display settings > My Subscription';

  @override
  String get guideMenu => 'Warding guide';

  @override
  String get guidePopupBadge => 'Get the most out of Warding';

  @override
  String get guidePopupTitle => 'Welcome! Here are some tips for using Warding';

  @override
  String get guidePopupMessage =>
      'You can always find this again under [My Page > Warding Guide].';

  @override
  String get guidePopupDismiss => 'Maybe later';

  @override
  String get guidePopupConfirm => 'View guide';

  @override
  String get communityTitle => 'Community';

  @override
  String get communityTabAll => 'All';

  @override
  String get communityTabTeam => 'Teams';

  @override
  String get communityWrite => 'Write';

  @override
  String communityWriteCooldown(int seconds) {
    return 'Wait ${seconds}s';
  }

  @override
  String get communityEmpty => 'No posts yet. Be the first to write one.';

  @override
  String communityLockedTitle(String team) {
    return 'Only $team fans can post here.';
  }

  @override
  String get communityLockedBody => 'Share it on the All board instead.';

  @override
  String get communityLockedAction => 'Go to All';

  @override
  String get communityNoTeamTitle => 'Pick a team to post on team boards.';

  @override
  String get communityNoTeamAction => 'Pick my team';

  @override
  String get communityCommentHint => 'Write a comment';

  @override
  String communityCommentLocked(String team) {
    return 'Only $team fans can comment';
  }

  @override
  String get communityCommentSubmit => 'Post';

  @override
  String communityCommentCount(int count) {
    return 'Comments $count';
  }

  @override
  String communityReplyCount(int count) {
    return '$count replies';
  }

  @override
  String get communityReply => 'Reply';

  @override
  String get communityLike => 'Like';

  @override
  String get communityScrap => 'Save';

  @override
  String communityViewCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Views $countString';
  }

  @override
  String get communityBoardAll => 'All board';

  @override
  String communityBoardTeam(String team) {
    return '$team board';
  }

  @override
  String get communityWriteTitleLabel => 'Title';

  @override
  String get communityWriteTitleHint => 'Enter a title';

  @override
  String get communityWriteBodyLabel => 'Body';

  @override
  String get communityWriteBodyHint =>
      'Matches, cheers, questions — anything goes.\nAbuse and spam will be reported.';

  @override
  String get communityWriteSubmit => 'Post';

  @override
  String get communityAddLink => 'Link';

  @override
  String get communityPollLabel => 'Poll';

  @override
  String get communityPollQuestionHint => 'Ask a question';

  @override
  String get communityPollOptionHint => 'Option';

  @override
  String get communityPollAddOption => 'Add option';

  @override
  String communityPollParticipants(int count) {
    return '$count votes';
  }

  @override
  String get communityPollVoteToSee => 'Vote to see the results';

  @override
  String get communityLinkDialogTitle => 'Add a link';

  @override
  String get communityLinkHint => 'Paste a URL';

  @override
  String get communityLinkConfirm => 'Add';

  @override
  String get communityLinkInvalid => 'That doesn\'t look like a valid link.';

  @override
  String get communityHeadingToggle => 'Heading';

  @override
  String get communityMoreReport => 'Report';

  @override
  String get communityMoreBlock => 'Block this user';

  @override
  String get communityReportTitle => 'Reason';

  @override
  String get communityReportAbuse => 'Abuse';

  @override
  String get communityReportObscene => 'Sexual content';

  @override
  String get communityReportAd => 'Advertising or selling';

  @override
  String get communityReportFraud => 'Leaks, impersonation, scams';

  @override
  String get communityReportSpam => 'Spam';

  @override
  String get communityReportEtc => 'Other';

  @override
  String get communityReportEtcHint => 'Tell us what the problem is';

  @override
  String get communityReportSubmit => 'Report';

  @override
  String get communityReportDone => 'Report submitted.';

  @override
  String get communityBlockDone => 'You will no longer see this user\'s posts.';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String loginConsentNotice(String terms, String privacy) {
    return 'By signing in you agree to the $terms and $privacy';
  }

  @override
  String get communityGuestWrite => 'Sign in and pick a team to start posting.';

  @override
  String get communityTabMyTeam => 'My Team';

  @override
  String get communityTabOtherTeams => 'Other Teams';

  @override
  String get communityRulesTitle => 'Community Rules';

  @override
  String get communityRulesSeeAll => 'Read the full community rules';

  @override
  String get communityLoadFailed => 'Couldn\'t load posts.';

  @override
  String get communityActionFailed => 'Couldn\'t complete the request.';

  @override
  String get communityWriteFailed => 'Couldn\'t post.';

  @override
  String get communityRetry => 'Retry';

  @override
  String get communityDeletedAuthor => 'Deleted user';

  @override
  String get communityCommentDeleted => 'This comment was deleted.';

  @override
  String get communityCommentBlocked => 'Comment from a blocked user.';

  @override
  String get communityCommentHidden => 'This comment is hidden.';

  @override
  String get communityBlockedPost => 'Post from a blocked user.';

  @override
  String get notificationReadAll => 'Mark all read';

  @override
  String get notificationInboxTitle => 'Notifications';

  @override
  String get communityNotificationTitle => 'Community notifications';

  @override
  String get notificationTabAll => 'All';

  @override
  String get notificationTabMatch => 'Matches';

  @override
  String get notificationTabCommunity => 'Community';

  @override
  String get notificationEmpty => 'No notifications yet';

  @override
  String get communityNotificationOn => 'Notifications on for this post';

  @override
  String get communityNotificationOff => 'Notifications off for this post';

  @override
  String get communityMoreEdit => 'Edit';

  @override
  String get communityEditingComment => 'Editing comment';

  @override
  String get communityMoreDelete => 'Delete';

  @override
  String get communityMoreComments => 'Show more comments';

  @override
  String get communityEdited => 'edited';

  @override
  String get communityWriteSubmitting => 'Posting…';

  @override
  String communityReplyingTo(String nickname) {
    return 'Replying to $nickname';
  }

  @override
  String get communityAttachPhoto => 'Photo';

  @override
  String communityPhotoCount(int count) {
    return '$count/5';
  }
}
