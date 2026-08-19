import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'Warding'**
  String get appTitle;

  /// No description provided for @logoutFailed.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃에 실패했습니다. 잠시 후 다시 시도해주세요.'**
  String get logoutFailed;

  /// No description provided for @mainScreenPlaceholder.
  ///
  /// In ko, this message translates to:
  /// **'메인 화면 (작업 예정)'**
  String get mainScreenPlaceholder;

  /// No description provided for @matchList.
  ///
  /// In ko, this message translates to:
  /// **'경기리스트'**
  String get matchList;

  /// No description provided for @season.
  ///
  /// In ko, this message translates to:
  /// **'시즌'**
  String get season;

  /// No description provided for @league.
  ///
  /// In ko, this message translates to:
  /// **'리그'**
  String get league;

  /// No description provided for @loading.
  ///
  /// In ko, this message translates to:
  /// **'불러오는 중...'**
  String get loading;

  /// No description provided for @select.
  ///
  /// In ko, this message translates to:
  /// **'선택'**
  String get select;

  /// No description provided for @noMatches.
  ///
  /// In ko, this message translates to:
  /// **'경기가 없어요'**
  String get noMatches;

  /// No description provided for @setInProgress.
  ///
  /// In ko, this message translates to:
  /// **'SET {setNumber} 진행중'**
  String setInProgress(int setNumber);

  /// No description provided for @setWinner.
  ///
  /// In ko, this message translates to:
  /// **'SET {setNumber} {teamCode} 승'**
  String setWinner(int setNumber, String teamCode);

  /// No description provided for @today.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ko, this message translates to:
  /// **'어제'**
  String get yesterday;

  /// No description provided for @tomorrow.
  ///
  /// In ko, this message translates to:
  /// **'내일'**
  String get tomorrow;

  /// No description provided for @monthDay.
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일'**
  String monthDay(int month, int day);

  /// No description provided for @yearMonthDay.
  ///
  /// In ko, this message translates to:
  /// **'{year}년 {month}월 {day}일'**
  String yearMonthDay(int year, int month, int day);

  /// No description provided for @setStartAlarm.
  ///
  /// In ko, this message translates to:
  /// **'세트 시작 알림'**
  String get setStartAlarm;

  /// No description provided for @setEndAlarm.
  ///
  /// In ko, this message translates to:
  /// **'세트 종료 알림'**
  String get setEndAlarm;

  /// No description provided for @liveEventAlarm.
  ///
  /// In ko, this message translates to:
  /// **'라이브 이벤트 알림'**
  String get liveEventAlarm;

  /// No description provided for @confirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get confirm;

  /// No description provided for @matchAlarmSettings.
  ///
  /// In ko, this message translates to:
  /// **'경기 알림 설정'**
  String get matchAlarmSettings;

  /// No description provided for @matchAlarmRemoved.
  ///
  /// In ko, this message translates to:
  /// **'경기 알림이 해제되었어요'**
  String get matchAlarmRemoved;

  /// No description provided for @matchAlarmRemoveFailed.
  ///
  /// In ko, this message translates to:
  /// **'알림 해제에 실패했어요. 다시 시도해주세요'**
  String get matchAlarmRemoveFailed;

  /// No description provided for @matchAlarmRegistered.
  ///
  /// In ko, this message translates to:
  /// **'경기 알림이 등록되었어요'**
  String get matchAlarmRegistered;

  /// No description provided for @matchAlarmRegisterFailed.
  ///
  /// In ko, this message translates to:
  /// **'알림 등록에 실패했어요. 다시 시도해주세요'**
  String get matchAlarmRegisterFailed;

  /// No description provided for @spoilerBlock.
  ///
  /// In ko, this message translates to:
  /// **'스포방지'**
  String get spoilerBlock;

  /// No description provided for @clickToSeeScore.
  ///
  /// In ko, this message translates to:
  /// **'클릭시 스코어 확인 가능'**
  String get clickToSeeScore;

  /// No description provided for @spoilerPreventionOn.
  ///
  /// In ko, this message translates to:
  /// **'스포방지 ON'**
  String get spoilerPreventionOn;

  /// No description provided for @spoilerPreventionOff.
  ///
  /// In ko, this message translates to:
  /// **'스포방지 OFF'**
  String get spoilerPreventionOff;

  /// No description provided for @weekdayMon.
  ///
  /// In ko, this message translates to:
  /// **'월'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In ko, this message translates to:
  /// **'화'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In ko, this message translates to:
  /// **'수'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In ko, this message translates to:
  /// **'목'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In ko, this message translates to:
  /// **'금'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In ko, this message translates to:
  /// **'토'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In ko, this message translates to:
  /// **'일'**
  String get weekdaySun;

  /// No description provided for @filter.
  ///
  /// In ko, this message translates to:
  /// **'필터'**
  String get filter;

  /// No description provided for @team.
  ///
  /// In ko, this message translates to:
  /// **'팀'**
  String get team;

  /// No description provided for @all.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get all;

  /// No description provided for @monthlyScheduleSummary.
  ///
  /// In ko, this message translates to:
  /// **'월간 경기 일정 요약'**
  String get monthlyScheduleSummary;

  /// No description provided for @ratingSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'평점 저장에 실패했어요. 잠시 후 다시 시도해주세요.'**
  String get ratingSaveFailed;

  /// No description provided for @deleteMyRatingConfirm.
  ///
  /// In ko, this message translates to:
  /// **'내 평점을 삭제하시겠습니까?'**
  String get deleteMyRatingConfirm;

  /// No description provided for @deleteMyRatingMessage.
  ///
  /// In ko, this message translates to:
  /// **'삭제된 댓글은 복구되지 않습니다. 댓글은 수정 기능을 통해 편집할 수 있습니다.'**
  String get deleteMyRatingMessage;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get delete;

  /// No description provided for @ratingDeleteFailed.
  ///
  /// In ko, this message translates to:
  /// **'평점 삭제에 실패했어요. 잠시 후 다시 시도해주세요.'**
  String get ratingDeleteFailed;

  /// No description provided for @playerRating.
  ///
  /// In ko, this message translates to:
  /// **'선수 평점'**
  String get playerRating;

  /// No description provided for @me.
  ///
  /// In ko, this message translates to:
  /// **'나'**
  String get me;

  /// No description provided for @leaveRating.
  ///
  /// In ko, this message translates to:
  /// **'평점 남기기'**
  String get leaveRating;

  /// No description provided for @myComment.
  ///
  /// In ko, this message translates to:
  /// **'내 댓글'**
  String get myComment;

  /// No description provided for @ratingAndComment.
  ///
  /// In ko, this message translates to:
  /// **'평점·코멘트'**
  String get ratingAndComment;

  /// No description provided for @totalCount.
  ///
  /// In ko, this message translates to:
  /// **'총 {count}개'**
  String totalCount(int count);

  /// No description provided for @leaveRatingAndComment.
  ///
  /// In ko, this message translates to:
  /// **'평점·코멘트 남기기'**
  String get leaveRatingAndComment;

  /// No description provided for @ratingCommentHint.
  ///
  /// In ko, this message translates to:
  /// **'선수의 활약에 대한 의견을 남겨보세요.'**
  String get ratingCommentHint;

  /// No description provided for @ratingCommentWarning.
  ///
  /// In ko, this message translates to:
  /// **'선수에 대한 지나친 비방 및 부적절한 표현은 운영 정책에 따라 사전 안내 없이 삭제될 수 있습니다.'**
  String get ratingCommentWarning;

  /// No description provided for @submit.
  ///
  /// In ko, this message translates to:
  /// **'등록하기'**
  String get submit;

  /// No description provided for @totalParticipants.
  ///
  /// In ko, this message translates to:
  /// **'총 {count}명 참여'**
  String totalParticipants(int count);

  /// No description provided for @subscribedPlayer.
  ///
  /// In ko, this message translates to:
  /// **'회원님이 구독한 선수'**
  String get subscribedPlayer;

  /// No description provided for @leaveRatingForPlayer.
  ///
  /// In ko, this message translates to:
  /// **'님에게 평점를 남겨보세요!'**
  String get leaveRatingForPlayer;

  /// No description provided for @championPick.
  ///
  /// In ko, this message translates to:
  /// **'챔피언 픽'**
  String get championPick;

  /// No description provided for @liveEvent.
  ///
  /// In ko, this message translates to:
  /// **'라이브 이벤트'**
  String get liveEvent;

  /// No description provided for @tabPlayerRating.
  ///
  /// In ko, this message translates to:
  /// **'선수 평점'**
  String get tabPlayerRating;

  /// No description provided for @setLabel.
  ///
  /// In ko, this message translates to:
  /// **'세트 {order}'**
  String setLabel(int order);

  /// No description provided for @inProgress.
  ///
  /// In ko, this message translates to:
  /// **'진행중'**
  String get inProgress;

  /// No description provided for @broadcastChannelSelect.
  ///
  /// In ko, this message translates to:
  /// **'중계 채널 선택'**
  String get broadcastChannelSelect;

  /// No description provided for @watchOnPlatform.
  ///
  /// In ko, this message translates to:
  /// **'보고 싶은 플랫폼에서 이어서 시청하세요'**
  String get watchOnPlatform;

  /// No description provided for @official.
  ///
  /// In ko, this message translates to:
  /// **'공식'**
  String get official;

  /// No description provided for @matchDetail.
  ///
  /// In ko, this message translates to:
  /// **'경기 상세'**
  String get matchDetail;

  /// No description provided for @playerRatingAfterMatch.
  ///
  /// In ko, this message translates to:
  /// **'선수 평점은 경기 종료 후 남길 수 있어요!'**
  String get playerRatingAfterMatch;

  /// No description provided for @watchBroadcast.
  ///
  /// In ko, this message translates to:
  /// **'중계 보기'**
  String get watchBroadcast;

  /// No description provided for @rewatch.
  ///
  /// In ko, this message translates to:
  /// **'다시보기'**
  String get rewatch;

  /// No description provided for @matchEnded.
  ///
  /// In ko, this message translates to:
  /// **'경기 종료'**
  String get matchEnded;

  /// No description provided for @preparing.
  ///
  /// In ko, this message translates to:
  /// **'준비중'**
  String get preparing;

  /// No description provided for @liveEventAfterMatch.
  ///
  /// In ko, this message translates to:
  /// **'라이브 이벤트는 경기 시작 후 볼 수 있어요!'**
  String get liveEventAfterMatch;

  /// No description provided for @championPickAfterMatch.
  ///
  /// In ko, this message translates to:
  /// **'챔피언 픽은 경기 시작 후 볼 수 있어요!'**
  String get championPickAfterMatch;

  /// No description provided for @championPickAfterMatchAlt.
  ///
  /// In ko, this message translates to:
  /// **'챔피언 픽은 경기 시작 후 확인할 수 있어요!'**
  String get championPickAfterMatchAlt;

  /// No description provided for @eventDuringMatch.
  ///
  /// In ko, this message translates to:
  /// **'이벤트는 경기 중에 확인할 수 있어요!'**
  String get eventDuringMatch;

  /// No description provided for @loadingLiveEvents.
  ///
  /// In ko, this message translates to:
  /// **'라이브 이벤트를 가져오는 중이에요...'**
  String get loadingLiveEvents;

  /// No description provided for @matchScheduled.
  ///
  /// In ko, this message translates to:
  /// **'경기 예정'**
  String get matchScheduled;

  /// No description provided for @matchInProgress.
  ///
  /// In ko, this message translates to:
  /// **'경기 진행 중'**
  String get matchInProgress;

  /// No description provided for @allPlayerRatingForSet.
  ///
  /// In ko, this message translates to:
  /// **'{setTitle} 전체 선수 평점'**
  String allPlayerRatingForSet(String setTitle);

  /// No description provided for @setEndedLeaveRating.
  ///
  /// In ko, this message translates to:
  /// **'{setText} 경기가 끝났어요! 각 선수 평점을 남겨보세요'**
  String setEndedLeaveRating(String setText);

  /// No description provided for @totalPrefix.
  ///
  /// In ko, this message translates to:
  /// **'총 '**
  String get totalPrefix;

  /// No description provided for @participantsSuffix.
  ///
  /// In ko, this message translates to:
  /// **'명 참여'**
  String get participantsSuffix;

  /// No description provided for @playerRatingWithCount.
  ///
  /// In ko, this message translates to:
  /// **'{rating} ({count}명)'**
  String playerRatingWithCount(String rating, int count);

  /// No description provided for @justNow.
  ///
  /// In ko, this message translates to:
  /// **'방금 전'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분 전'**
  String minutesAgo(int minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In ko, this message translates to:
  /// **'{hours}시간 전'**
  String hoursAgo(int hours);

  /// No description provided for @daysAgo.
  ///
  /// In ko, this message translates to:
  /// **'{days}일 전'**
  String daysAgo(int days);

  /// No description provided for @eventTypeAll.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get eventTypeAll;

  /// No description provided for @eventTypeSetStart.
  ///
  /// In ko, this message translates to:
  /// **'세트 시작'**
  String get eventTypeSetStart;

  /// No description provided for @eventTypeSetEnd.
  ///
  /// In ko, this message translates to:
  /// **'세트 종료'**
  String get eventTypeSetEnd;

  /// No description provided for @deleteSwipe.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get deleteSwipe;

  /// No description provided for @deleteFailed.
  ///
  /// In ko, this message translates to:
  /// **'삭제하지 못했습니다.'**
  String get deleteFailed;

  /// No description provided for @deleteAllAlarms.
  ///
  /// In ko, this message translates to:
  /// **'알림 모두 삭제'**
  String get deleteAllAlarms;

  /// No description provided for @deleteAllAlarmsMessage.
  ///
  /// In ko, this message translates to:
  /// **'받은 알림을 모두 삭제할까요?'**
  String get deleteAllAlarmsMessage;

  /// No description provided for @enableNotificationPermission.
  ///
  /// In ko, this message translates to:
  /// **'알림을 받으려면 알림 권한을 허용해주세요.'**
  String get enableNotificationPermission;

  /// No description provided for @noNotifications.
  ///
  /// In ko, this message translates to:
  /// **'받은 알림이 없습니다.'**
  String get noNotifications;

  /// No description provided for @mySubscription.
  ///
  /// In ko, this message translates to:
  /// **'마이 구독'**
  String get mySubscription;

  /// No description provided for @subscribedTeams.
  ///
  /// In ko, this message translates to:
  /// **'구독중인 팀'**
  String get subscribedTeams;

  /// No description provided for @subscribedPlayers.
  ///
  /// In ko, this message translates to:
  /// **'구독중인 선수'**
  String get subscribedPlayers;

  /// No description provided for @subscriptionSettings.
  ///
  /// In ko, this message translates to:
  /// **'구독 설정'**
  String get subscriptionSettings;

  /// No description provided for @fullList.
  ///
  /// In ko, this message translates to:
  /// **'전체 목록'**
  String get fullList;

  /// No description provided for @tabTeam.
  ///
  /// In ko, this message translates to:
  /// **'팀'**
  String get tabTeam;

  /// No description provided for @tabPlayer.
  ///
  /// In ko, this message translates to:
  /// **'선수'**
  String get tabPlayer;

  /// No description provided for @dateLabel.
  ///
  /// In ko, this message translates to:
  /// **'날짜'**
  String get dateLabel;

  /// No description provided for @allPlayers.
  ///
  /// In ko, this message translates to:
  /// **'선수전체'**
  String get allPlayers;

  /// No description provided for @player.
  ///
  /// In ko, this message translates to:
  /// **'선수'**
  String get player;

  /// No description provided for @playerSelect.
  ///
  /// In ko, this message translates to:
  /// **'선수 선택'**
  String get playerSelect;

  /// No description provided for @subscribedPlayerList.
  ///
  /// In ko, this message translates to:
  /// **'구독한 선수'**
  String get subscribedPlayerList;

  /// No description provided for @playerSortByPosition.
  ///
  /// In ko, this message translates to:
  /// **'포지션순'**
  String get playerSortByPosition;

  /// No description provided for @playerSortByName.
  ///
  /// In ko, this message translates to:
  /// **'이름순'**
  String get playerSortByName;

  /// No description provided for @subscribing.
  ///
  /// In ko, this message translates to:
  /// **'구독중'**
  String get subscribing;

  /// No description provided for @subscribe.
  ///
  /// In ko, this message translates to:
  /// **'구독'**
  String get subscribe;

  /// No description provided for @liveEventNotificationTitle.
  ///
  /// In ko, this message translates to:
  /// **'{teamA} VS {teamB} 라이브 이벤트 발생!'**
  String liveEventNotificationTitle(String teamA, String teamB);

  /// No description provided for @liveEventNotificationBody.
  ///
  /// In ko, this message translates to:
  /// **'{season} _ {teamA} VS {teamB} 경기 실시간 이벤트를 확인해보세요'**
  String liveEventNotificationBody(String season, String teamA, String teamB);

  /// No description provided for @foldDetail.
  ///
  /// In ko, this message translates to:
  /// **'접어두기'**
  String get foldDetail;

  /// No description provided for @showDetail.
  ///
  /// In ko, this message translates to:
  /// **'상세보기'**
  String get showDetail;

  /// No description provided for @matchEndNotificationTitle.
  ///
  /// In ko, this message translates to:
  /// **'{teamA} VS {teamB} 경기가 종료되었습니다.'**
  String matchEndNotificationTitle(String teamA, String teamB);

  /// No description provided for @matchEndNotificationBody.
  ///
  /// In ko, this message translates to:
  /// **'{season} _ {teamA} VS {teamB} 경기가 종료되었습니다. 지금 바로 평점을 남겨보세요!'**
  String matchEndNotificationBody(String season, String teamA, String teamB);

  /// No description provided for @leaveMatchRating.
  ///
  /// In ko, this message translates to:
  /// **'경기 평점 남기기'**
  String get leaveMatchRating;

  /// No description provided for @matchStartNotificationTitle.
  ///
  /// In ko, this message translates to:
  /// **'{teamA} VS {teamB} 경기가 시작됩니다!'**
  String matchStartNotificationTitle(String teamA, String teamB);

  /// No description provided for @matchStartNotificationBody.
  ///
  /// In ko, this message translates to:
  /// **'{season} _ 응원중인 팀 {teamA} 과 {teamB}의 경기가 시작됩니다.'**
  String matchStartNotificationBody(String season, String teamA, String teamB);

  /// No description provided for @soloRank.
  ///
  /// In ko, this message translates to:
  /// **'솔로 랭크'**
  String get soloRank;

  /// No description provided for @rankStartTitle.
  ///
  /// In ko, this message translates to:
  /// **'{playerName} 선수 랭크 시작 감지!'**
  String rankStartTitle(String playerName);

  /// No description provided for @rankStartBody.
  ///
  /// In ko, this message translates to:
  /// **'지금 {playerName} 선수가 {champion}{particle} {queueType}를 시작했습니다'**
  String rankStartBody(
    String playerName,
    String champion,
    String particle,
    String queueType,
  );

  /// No description provided for @rankEndTitle.
  ///
  /// In ko, this message translates to:
  /// **'{playerName} 선수가 솔랭 한 판을 마쳤어요'**
  String rankEndTitle(String playerName);

  /// 승패를 아는 종료 알림. result 는 승리/패배. KDA 는 위젯에서 ' · 18/1/11' 로 덧붙인다
  ///
  /// In ko, this message translates to:
  /// **'{champion}{particle} {result}'**
  String rankEndBodyResult(String champion, String particle, String result);

  /// match-v5 결과를 못 읽어 승패를 모르는 종료 알림
  ///
  /// In ko, this message translates to:
  /// **'{champion} 경기 종료'**
  String rankEndBodyNoResult(String champion);

  /// No description provided for @rankEndWin.
  ///
  /// In ko, this message translates to:
  /// **'승리'**
  String get rankEndWin;

  /// No description provided for @rankEndLose.
  ///
  /// In ko, this message translates to:
  /// **'패배'**
  String get rankEndLose;

  /// 경기 길이. 본문 끝에 ' · 28분' 으로 덧붙는다. 초는 솔랭 결과에서 쓸모가 없어 분만 쓴다
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분'**
  String rankEndDurationMinutes(int minutes);

  /// No description provided for @withdraw.
  ///
  /// In ko, this message translates to:
  /// **'회원탈퇴'**
  String get withdraw;

  /// No description provided for @withdrawConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'회원탈퇴'**
  String get withdrawConfirmTitle;

  /// No description provided for @withdrawConfirmMessage.
  ///
  /// In ko, this message translates to:
  /// **'계정과 구독·알림·평점 등 모든 데이터가\n삭제되며 되돌릴 수 없습니다.'**
  String get withdrawConfirmMessage;

  /// No description provided for @withdrawConfirmButton.
  ///
  /// In ko, this message translates to:
  /// **'탈퇴'**
  String get withdrawConfirmButton;

  /// No description provided for @withdrawFailed.
  ///
  /// In ko, this message translates to:
  /// **'회원탈퇴에 실패했습니다. 잠시 후 다시 시도해주세요.'**
  String get withdrawFailed;

  /// No description provided for @teamAutoSetBanner.
  ///
  /// In ko, this message translates to:
  /// **'설문 기반으로 응원하는 팀이 자동으로 설정됐어요!'**
  String get teamAutoSetBanner;

  /// No description provided for @myActivity.
  ///
  /// In ko, this message translates to:
  /// **'내 활동'**
  String get myActivity;

  /// No description provided for @screenSetting.
  ///
  /// In ko, this message translates to:
  /// **'화면 설정'**
  String get screenSetting;

  /// No description provided for @generalSetting.
  ///
  /// In ko, this message translates to:
  /// **'일반 설정'**
  String get generalSetting;

  /// No description provided for @customerSupport.
  ///
  /// In ko, this message translates to:
  /// **'고객 지원'**
  String get customerSupport;

  /// No description provided for @account.
  ///
  /// In ko, this message translates to:
  /// **'계정'**
  String get account;

  /// No description provided for @narWebsiteDescription.
  ///
  /// In ko, this message translates to:
  /// **'선수 스탯부터 상세 경기 데이터까지, 한눈에 분석해 보세요'**
  String get narWebsiteDescription;

  /// No description provided for @quietHoursTitle.
  ///
  /// In ko, this message translates to:
  /// **'방해 금지 모드'**
  String get quietHoursTitle;

  /// No description provided for @quietHoursDescription.
  ///
  /// In ko, this message translates to:
  /// **'설정된 시간 동안 푸시 알림 없이 앱 내 알림함에만 쌓입니다'**
  String get quietHoursDescription;

  /// No description provided for @mySubscriptionSetting.
  ///
  /// In ko, this message translates to:
  /// **'마이 구독 설정'**
  String get mySubscriptionSetting;

  /// No description provided for @matchListSetting.
  ///
  /// In ko, this message translates to:
  /// **'경기리스트 설정'**
  String get matchListSetting;

  /// No description provided for @calendarSetting.
  ///
  /// In ko, this message translates to:
  /// **'캘린더 설정'**
  String get calendarSetting;

  /// No description provided for @accountSetting.
  ///
  /// In ko, this message translates to:
  /// **'계정 설정'**
  String get accountSetting;

  /// No description provided for @withdrawTitle.
  ///
  /// In ko, this message translates to:
  /// **'회원 탈퇴'**
  String get withdrawTitle;

  /// No description provided for @withdrawHeadline.
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님\n와딩을 떠나시는건가요.. 다시 돌아오실거죠?..'**
  String withdrawHeadline(String nickname);

  /// No description provided for @withdrawWarningData.
  ///
  /// In ko, this message translates to:
  /// **'계정을 탈퇴하면 구독,알림,평점 등 모든 데이터가 삭제되며 되돌릴 수 없습니다.'**
  String get withdrawWarningData;

  /// No description provided for @withdrawWarningImmediate.
  ///
  /// In ko, this message translates to:
  /// **'완료를 누를시 즉시 탈퇴됩니다.'**
  String get withdrawWarningImmediate;

  /// No description provided for @withdrawFeedback.
  ///
  /// In ko, this message translates to:
  /// **'와딩은 소중한 피드백으로 매일 성장하고 있어요.\n아쉬웠던 점을 알려주시면 바로 해결해 드릴게요.'**
  String get withdrawFeedback;

  /// No description provided for @withdrawSubmit.
  ///
  /// In ko, this message translates to:
  /// **'와딩 회원 탈퇴하기'**
  String get withdrawSubmit;

  /// No description provided for @accountNickname.
  ///
  /// In ko, this message translates to:
  /// **'닉네임'**
  String get accountNickname;

  /// No description provided for @accountEmail.
  ///
  /// In ko, this message translates to:
  /// **'이메일'**
  String get accountEmail;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃 하시겠습니까?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In ko, this message translates to:
  /// **'현재 로그인된 {email} 계정에서 로그아웃됩니다.'**
  String logoutConfirmMessage(String email);

  /// No description provided for @logoutConfirmButton.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get logoutConfirmButton;

  /// No description provided for @calendarWeekStartDescription.
  ///
  /// In ko, this message translates to:
  /// **'주 시작 요일(월요일/일요일)을 설정합니다.'**
  String get calendarWeekStartDescription;

  /// No description provided for @spoilerCard.
  ///
  /// In ko, this message translates to:
  /// **'스포 방지 카드'**
  String get spoilerCard;

  /// No description provided for @spoilerCardDescription.
  ///
  /// In ko, this message translates to:
  /// **'스코어 스포 방지 카드를 ON/OFF 할 수 있습니다'**
  String get spoilerCardDescription;

  /// No description provided for @screenSettingMatchList.
  ///
  /// In ko, this message translates to:
  /// **'경기 리스트'**
  String get screenSettingMatchList;

  /// No description provided for @screenSettingCalendar.
  ///
  /// In ko, this message translates to:
  /// **'캘린더'**
  String get screenSettingCalendar;

  /// No description provided for @myReviewRating.
  ///
  /// In ko, this message translates to:
  /// **'내 리뷰/평점'**
  String get myReviewRating;

  /// No description provided for @customerService.
  ///
  /// In ko, this message translates to:
  /// **'고객센터/문의'**
  String get customerService;

  /// No description provided for @notice.
  ///
  /// In ko, this message translates to:
  /// **'공지사항'**
  String get notice;

  /// No description provided for @noticeAdmin.
  ///
  /// In ko, this message translates to:
  /// **'관리자'**
  String get noticeAdmin;

  /// No description provided for @noticeEmpty.
  ///
  /// In ko, this message translates to:
  /// **'공지사항이 없어요'**
  String get noticeEmpty;

  /// No description provided for @noticeLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'공지사항을 불러오지 못했어요'**
  String get noticeLoadFailed;

  /// No description provided for @noticePinned.
  ///
  /// In ko, this message translates to:
  /// **'📌 고정'**
  String get noticePinned;

  /// No description provided for @noticeDraft.
  ///
  /// In ko, this message translates to:
  /// **'임시저장'**
  String get noticeDraft;

  /// No description provided for @noticeListButton.
  ///
  /// In ko, this message translates to:
  /// **'목록'**
  String get noticeListButton;

  /// No description provided for @narWebsite.
  ///
  /// In ko, this message translates to:
  /// **'나르지지 웹사이트'**
  String get narWebsite;

  /// No description provided for @latestVersion.
  ///
  /// In ko, this message translates to:
  /// **'최신 버전입니다.'**
  String get latestVersion;

  /// No description provided for @currentVersion.
  ///
  /// In ko, this message translates to:
  /// **'(현재 버전 {version})'**
  String currentVersion(String version);

  /// No description provided for @logout.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get logout;

  /// No description provided for @myPage.
  ///
  /// In ko, this message translates to:
  /// **'마이 페이지'**
  String get myPage;

  /// No description provided for @nicknamePlaceholder.
  ///
  /// In ko, this message translates to:
  /// **'닉네임'**
  String get nicknamePlaceholder;

  /// No description provided for @profileEdit.
  ///
  /// In ko, this message translates to:
  /// **'프로필 수정'**
  String get profileEdit;

  /// No description provided for @countUnit.
  ///
  /// In ko, this message translates to:
  /// **'{count}건'**
  String countUnit(int count);

  /// No description provided for @appInfo.
  ///
  /// In ko, this message translates to:
  /// **'앱정보'**
  String get appInfo;

  /// No description provided for @languageSetting.
  ///
  /// In ko, this message translates to:
  /// **'언어 설정'**
  String get languageSetting;

  /// No description provided for @languageKo.
  ///
  /// In ko, this message translates to:
  /// **'한국어'**
  String get languageKo;

  /// No description provided for @languageEn.
  ///
  /// In ko, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @subscriptionTeamAlarmSettings.
  ///
  /// In ko, this message translates to:
  /// **'구독 팀 알림 설정'**
  String get subscriptionTeamAlarmSettings;

  /// No description provided for @subscriptionAlarmDetailSettings.
  ///
  /// In ko, this message translates to:
  /// **'구독 알림 세부 설정'**
  String get subscriptionAlarmDetailSettings;

  /// No description provided for @soloRankStartAlarm.
  ///
  /// In ko, this message translates to:
  /// **'솔랭 시작 알림'**
  String get soloRankStartAlarm;

  /// No description provided for @soloRankEndAlarm.
  ///
  /// In ko, this message translates to:
  /// **'솔랭 종료 알림'**
  String get soloRankEndAlarm;

  /// No description provided for @noSubscribedPlayer.
  ///
  /// In ko, this message translates to:
  /// **'구독중인 선수가 없어요.'**
  String get noSubscribedPlayer;

  /// No description provided for @subscriptionManage.
  ///
  /// In ko, this message translates to:
  /// **'구독 관리'**
  String get subscriptionManage;

  /// No description provided for @teamPlayerSubscriptionManage.
  ///
  /// In ko, this message translates to:
  /// **'팀/ 선수 구독 관리'**
  String get teamPlayerSubscriptionManage;

  /// No description provided for @subscriptionManageDescription.
  ///
  /// In ko, this message translates to:
  /// **'마이구독 설정 페이지로 이동합니다.'**
  String get subscriptionManageDescription;

  /// No description provided for @noSubscribedTeam.
  ///
  /// In ko, this message translates to:
  /// **'구독중인 팀이 없어요.'**
  String get noSubscribedTeam;

  /// No description provided for @profileEditTitle.
  ///
  /// In ko, this message translates to:
  /// **'프로필 수정'**
  String get profileEditTitle;

  /// No description provided for @nameLabel.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get nameLabel;

  /// No description provided for @nameHint.
  ///
  /// In ko, this message translates to:
  /// **'이름을 입력하세요'**
  String get nameHint;

  /// No description provided for @tagLabel.
  ///
  /// In ko, this message translates to:
  /// **'태그'**
  String get tagLabel;

  /// No description provided for @tagHint.
  ///
  /// In ko, this message translates to:
  /// **'#태그'**
  String get tagHint;

  /// No description provided for @done.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get done;

  /// No description provided for @cheerTeamSetting.
  ///
  /// In ko, this message translates to:
  /// **'응원 팀 설정'**
  String get cheerTeamSetting;

  /// No description provided for @cheerTeamDescription.
  ///
  /// In ko, this message translates to:
  /// **'1. 응원 팀 설정시 닉네임 옆에 뱃지가 생겨요'**
  String get cheerTeamDescription;

  /// No description provided for @cheerTeamDescriptionCalendar.
  ///
  /// In ko, this message translates to:
  /// **'2. 캘린더 일정에서 응원 팀 전용 필터가 생겨요'**
  String get cheerTeamDescriptionCalendar;

  /// No description provided for @cumulativeReviewRating.
  ///
  /// In ko, this message translates to:
  /// **'누적 리뷰/평점'**
  String get cumulativeReviewRating;

  /// No description provided for @reviewView.
  ///
  /// In ko, this message translates to:
  /// **'리뷰보기'**
  String get reviewView;

  /// No description provided for @reviewDelete.
  ///
  /// In ko, this message translates to:
  /// **'리뷰삭제'**
  String get reviewDelete;

  /// No description provided for @deleteFailed2.
  ///
  /// In ko, this message translates to:
  /// **'삭제에 실패했어요. 잠시 후 다시 시도해주세요.'**
  String get deleteFailed2;

  /// No description provided for @loginFailed.
  ///
  /// In ko, this message translates to:
  /// **'로그인에 실패했습니다. 잠시 후 다시 시도해주세요.'**
  String get loginFailed;

  /// No description provided for @appleLogin.
  ///
  /// In ko, this message translates to:
  /// **'Apple 로그인'**
  String get appleLogin;

  /// No description provided for @kakaoLogin.
  ///
  /// In ko, this message translates to:
  /// **'카카오 로그인'**
  String get kakaoLogin;

  /// No description provided for @naverLogin.
  ///
  /// In ko, this message translates to:
  /// **'네이버 로그인'**
  String get naverLogin;

  /// No description provided for @googleLogin.
  ///
  /// In ko, this message translates to:
  /// **'Google 로그인'**
  String get googleLogin;

  /// No description provided for @guestStart.
  ///
  /// In ko, this message translates to:
  /// **'비회원으로 시작하기'**
  String get guestStart;

  /// No description provided for @easyLogin.
  ///
  /// In ko, this message translates to:
  /// **'간편 로그인'**
  String get easyLogin;

  /// No description provided for @skipButton.
  ///
  /// In ko, this message translates to:
  /// **'건너뛰기'**
  String get skipButton;

  /// No description provided for @startWarding.
  ///
  /// In ko, this message translates to:
  /// **'와딩 시작하기'**
  String get startWarding;

  /// No description provided for @next.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get next;

  /// No description provided for @preferredLeague.
  ///
  /// In ko, this message translates to:
  /// **'선호 리그'**
  String get preferredLeague;

  /// No description provided for @preferredTeam.
  ///
  /// In ko, this message translates to:
  /// **'선호 팀'**
  String get preferredTeam;

  /// No description provided for @preferredPlayer.
  ///
  /// In ko, this message translates to:
  /// **'선호 선수'**
  String get preferredPlayer;

  /// No description provided for @notificationPermission.
  ///
  /// In ko, this message translates to:
  /// **'알림 권한'**
  String get notificationPermission;

  /// No description provided for @favoriteLeagueQuestion.
  ///
  /// In ko, this message translates to:
  /// **'즐겨 시청하는 리그는 무엇인가요?'**
  String get favoriteLeagueQuestion;

  /// No description provided for @leagueLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'리그 목록을 불러오지 못했어요'**
  String get leagueLoadFailed;

  /// No description provided for @favoriteTeamQuestion.
  ///
  /// In ko, this message translates to:
  /// **'가장 응원하는 팀을 선택해주세요'**
  String get favoriteTeamQuestion;

  /// No description provided for @domesticTeamNote.
  ///
  /// In ko, this message translates to:
  /// **'LCK 국내 팀 기준입니다.'**
  String get domesticTeamNote;

  /// No description provided for @teamLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'팀 목록을 불러오지 못했어요'**
  String get teamLoadFailed;

  /// No description provided for @favoritePlayerQuestion.
  ///
  /// In ko, this message translates to:
  /// **'응원하는 선수를 선택해주세요'**
  String get favoritePlayerQuestion;

  /// No description provided for @domesticPlayerNote.
  ///
  /// In ko, this message translates to:
  /// **'LCK 국내 팀 기준입니다. (중복 가능)'**
  String get domesticPlayerNote;

  /// No description provided for @playerLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'선수 목록을 불러오지 못했어요'**
  String get playerLoadFailed;

  /// No description provided for @noPlayerInfo.
  ///
  /// In ko, this message translates to:
  /// **'선수 정보가 없어요'**
  String get noPlayerInfo;

  /// No description provided for @teamSelect.
  ///
  /// In ko, this message translates to:
  /// **'팀 선택'**
  String get teamSelect;

  /// No description provided for @notificationQuestion.
  ///
  /// In ko, this message translates to:
  /// **'\'Warding\'에서 보내는 이벤트 및 알림을 받아보시겠습니까?'**
  String get notificationQuestion;

  /// No description provided for @notificationConsentMessage.
  ///
  /// In ko, this message translates to:
  /// **'수신 동의 시 이벤트, 경기/팀/선수 등 다양한 정보에 대한 알림을 받아보실 수 있습니다.'**
  String get notificationConsentMessage;

  /// No description provided for @readyComplete.
  ///
  /// In ko, this message translates to:
  /// **'준비 완료!'**
  String get readyComplete;

  /// No description provided for @enjoyMessage.
  ///
  /// In ko, this message translates to:
  /// **'응원하는 팀과 선수의 경기,\n이제 놓치지 말고 즐겨보세요.'**
  String get enjoyMessage;

  /// No description provided for @deny.
  ///
  /// In ko, this message translates to:
  /// **'허용 안 함'**
  String get deny;

  /// No description provided for @allow.
  ///
  /// In ko, this message translates to:
  /// **'허용'**
  String get allow;

  /// No description provided for @retry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get retry;

  /// No description provided for @selected.
  ///
  /// In ko, this message translates to:
  /// **'선택됨'**
  String get selected;

  /// No description provided for @matchSchedule.
  ///
  /// In ko, this message translates to:
  /// **'경기 일정'**
  String get matchSchedule;

  /// No description provided for @matchLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'경기를 불러오지 못했어요'**
  String get matchLoadFailed;

  /// No description provided for @navSchedule.
  ///
  /// In ko, this message translates to:
  /// **'경기일정'**
  String get navSchedule;

  /// No description provided for @navMatchList.
  ///
  /// In ko, this message translates to:
  /// **'경기리스트'**
  String get navMatchList;

  /// No description provided for @navSubscription.
  ///
  /// In ko, this message translates to:
  /// **'마이 구독'**
  String get navSubscription;

  /// No description provided for @navMyPage.
  ///
  /// In ko, this message translates to:
  /// **'마이페이지'**
  String get navMyPage;

  /// No description provided for @defaultCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get defaultCancel;

  /// No description provided for @defaultConfirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get defaultConfirm;

  /// No description provided for @filterApply.
  ///
  /// In ko, this message translates to:
  /// **'조회하기'**
  String get filterApply;

  /// No description provided for @searchHint.
  ///
  /// In ko, this message translates to:
  /// **'팀 또는 선수 검색..'**
  String get searchHint;

  /// No description provided for @selectHint.
  ///
  /// In ko, this message translates to:
  /// **'선택'**
  String get selectHint;

  /// No description provided for @searchInputHint.
  ///
  /// In ko, this message translates to:
  /// **'검색어를 입력...'**
  String get searchInputHint;

  /// No description provided for @noSearchResults.
  ///
  /// In ko, this message translates to:
  /// **'검색 결과가 없어요'**
  String get noSearchResults;

  /// No description provided for @loginRequired.
  ///
  /// In ko, this message translates to:
  /// **'로그인 후 사용 가능'**
  String get loginRequired;

  /// No description provided for @fallbackPlayer.
  ///
  /// In ko, this message translates to:
  /// **'선수'**
  String get fallbackPlayer;

  /// No description provided for @fallbackChampionInfo.
  ///
  /// In ko, this message translates to:
  /// **'챔피언 정보 확인 중'**
  String get fallbackChampionInfo;

  /// No description provided for @liveMatchNotification.
  ///
  /// In ko, this message translates to:
  /// **'라이브 경기 알림'**
  String get liveMatchNotification;

  /// No description provided for @watchBroadcastFallback.
  ///
  /// In ko, this message translates to:
  /// **'중계 보기'**
  String get watchBroadcastFallback;

  /// No description provided for @objectKill.
  ///
  /// In ko, this message translates to:
  /// **'킬'**
  String get objectKill;

  /// No description provided for @objectDragon.
  ///
  /// In ko, this message translates to:
  /// **'드래곤'**
  String get objectDragon;

  /// No description provided for @objectSubDragon.
  ///
  /// In ko, this message translates to:
  /// **'{sub}드래곤'**
  String objectSubDragon(String sub);

  /// No description provided for @objectBaron.
  ///
  /// In ko, this message translates to:
  /// **'바론'**
  String get objectBaron;

  /// No description provided for @objectTower.
  ///
  /// In ko, this message translates to:
  /// **'타워'**
  String get objectTower;

  /// No description provided for @objectInhibitor.
  ///
  /// In ko, this message translates to:
  /// **'억제기'**
  String get objectInhibitor;

  /// No description provided for @objectNexus.
  ///
  /// In ko, this message translates to:
  /// **'넥서스'**
  String get objectNexus;

  /// No description provided for @notificationChannelName.
  ///
  /// In ko, this message translates to:
  /// **'구독 알림'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDesc.
  ///
  /// In ko, this message translates to:
  /// **'구독 선수·팀의 경기/이벤트 알림'**
  String get notificationChannelDesc;

  /// No description provided for @duplicateNickname.
  ///
  /// In ko, this message translates to:
  /// **'이미 사용 중인 닉네임입니다'**
  String get duplicateNickname;

  /// No description provided for @sortRecent.
  ///
  /// In ko, this message translates to:
  /// **'최근순'**
  String get sortRecent;

  /// No description provided for @sortOldest.
  ///
  /// In ko, this message translates to:
  /// **'오래된 순'**
  String get sortOldest;

  /// No description provided for @sortUpcoming.
  ///
  /// In ko, this message translates to:
  /// **'오늘 이후'**
  String get sortUpcoming;

  /// No description provided for @scheduleLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'경기 일정을 불러오지 못했어요'**
  String get scheduleLoadFailed;

  /// No description provided for @playerRatingLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'선수 평점을 불러오지 못했어요'**
  String get playerRatingLoadFailed;

  /// No description provided for @noPlayerRecordInSet.
  ///
  /// In ko, this message translates to:
  /// **'이 세트에는 해당 선수 기록이 없어요'**
  String get noPlayerRecordInSet;

  /// No description provided for @setRatingLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'세트 평점을 불러오지 못했어요'**
  String get setRatingLoadFailed;

  /// No description provided for @setInfoNotFound.
  ///
  /// In ko, this message translates to:
  /// **'세트 정보를 찾을 수 없어요'**
  String get setInfoNotFound;

  /// No description provided for @championPickLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'챔피언 픽을 불러오지 못했어요'**
  String get championPickLoadFailed;

  /// No description provided for @liveEventLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'라이브 이벤트를 불러오지 못했어요'**
  String get liveEventLoadFailed;

  /// No description provided for @playerRatingLoadFailed2.
  ///
  /// In ko, this message translates to:
  /// **'선수 평점을 불러오지 못했어요'**
  String get playerRatingLoadFailed2;

  /// No description provided for @subscriptionLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'구독 정보를 불러오지 못했어요'**
  String get subscriptionLoadFailed;

  /// No description provided for @notificationLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'알림을 불러오지 못했습니다.'**
  String get notificationLoadFailed;

  /// No description provided for @teamAlarmLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'팀 알림 정보를 불러오지 못했어요'**
  String get teamAlarmLoadFailed;

  /// No description provided for @teamAlarmSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'팀 알림 설정을 저장하지 못했어요'**
  String get teamAlarmSaveFailed;

  /// No description provided for @playerAlarmSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'선수 알림 설정을 저장하지 못했어요'**
  String get playerAlarmSaveFailed;

  /// No description provided for @profileLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'프로필을 불러오지 못했어요'**
  String get profileLoadFailed;

  /// No description provided for @requiredField.
  ///
  /// In ko, this message translates to:
  /// **'필수 입력 항목입니다.'**
  String get requiredField;

  /// No description provided for @tagFormatError.
  ///
  /// In ko, this message translates to:
  /// **'영문/숫자 2~5자로 입력하세요.'**
  String get tagFormatError;

  /// No description provided for @duplicateNicknameError.
  ///
  /// In ko, this message translates to:
  /// **'이미 사용 중인 닉네임입니다.'**
  String get duplicateNicknameError;

  /// No description provided for @saveFailed.
  ///
  /// In ko, this message translates to:
  /// **'저장에 실패했어요. 잠시 후 다시 시도해 주세요.'**
  String get saveFailed;

  /// No description provided for @myReviewLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'내 평가를 불러오지 못했어요'**
  String get myReviewLoadFailed;

  /// No description provided for @laneTop.
  ///
  /// In ko, this message translates to:
  /// **'탑'**
  String get laneTop;

  /// No description provided for @laneJungle.
  ///
  /// In ko, this message translates to:
  /// **'정글'**
  String get laneJungle;

  /// No description provided for @laneMid.
  ///
  /// In ko, this message translates to:
  /// **'미드'**
  String get laneMid;

  /// No description provided for @laneBot.
  ///
  /// In ko, this message translates to:
  /// **'원딜'**
  String get laneBot;

  /// No description provided for @laneBotAlt.
  ///
  /// In ko, this message translates to:
  /// **'바텀'**
  String get laneBotAlt;

  /// No description provided for @laneSupport.
  ///
  /// In ko, this message translates to:
  /// **'서폿'**
  String get laneSupport;

  /// No description provided for @laneSupportAlt.
  ///
  /// In ko, this message translates to:
  /// **'서포터'**
  String get laneSupportAlt;

  /// No description provided for @weekRound.
  ///
  /// In ko, this message translates to:
  /// **'{week}주 차'**
  String weekRound(int week);

  /// No description provided for @nthRound.
  ///
  /// In ko, this message translates to:
  /// **'{n}강'**
  String nthRound(int n);

  /// No description provided for @stagePlayIn.
  ///
  /// In ko, this message translates to:
  /// **'플레이-인'**
  String get stagePlayIn;

  /// No description provided for @stagePlayInTournament.
  ///
  /// In ko, this message translates to:
  /// **'플레이-인 토너먼트 스테이지'**
  String get stagePlayInTournament;

  /// No description provided for @stageGroup.
  ///
  /// In ko, this message translates to:
  /// **'그룹'**
  String get stageGroup;

  /// No description provided for @stageSwiss.
  ///
  /// In ko, this message translates to:
  /// **'스위스'**
  String get stageSwiss;

  /// No description provided for @stageTournament.
  ///
  /// In ko, this message translates to:
  /// **'토너먼트 스테이지'**
  String get stageTournament;

  /// No description provided for @stagePlayoff.
  ///
  /// In ko, this message translates to:
  /// **'플레이오프'**
  String get stagePlayoff;

  /// No description provided for @stageFinal.
  ///
  /// In ko, this message translates to:
  /// **'결승'**
  String get stageFinal;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 안내'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableMessage.
  ///
  /// In ko, this message translates to:
  /// **'새로운 버전이 출시되었습니다.\n최신 버전으로 업데이트해주세요.'**
  String get updateAvailableMessage;

  /// No description provided for @updateNow.
  ///
  /// In ko, this message translates to:
  /// **'업데이트'**
  String get updateNow;

  /// No description provided for @quietHours.
  ///
  /// In ko, this message translates to:
  /// **'방해 금지 모드 설정'**
  String get quietHours;

  /// No description provided for @quietHoursUse.
  ///
  /// In ko, this message translates to:
  /// **'방해 금지 모드 사용'**
  String get quietHoursUse;

  /// No description provided for @quietHoursStart.
  ///
  /// In ko, this message translates to:
  /// **'시작'**
  String get quietHoursStart;

  /// No description provided for @quietHoursEnd.
  ///
  /// In ko, this message translates to:
  /// **'종료'**
  String get quietHoursEnd;

  /// No description provided for @quietHoursOffHint.
  ///
  /// In ko, this message translates to:
  /// **'사용하면 정한 시간엔 알림이 소리 없이 알림함에만 쌓입니다.'**
  String get quietHoursOffHint;

  /// No description provided for @quietHoursOnHint.
  ///
  /// In ko, this message translates to:
  /// **'{start}부터 {end}까지 모든 알림이 소리 없이 알림함에만 쌓입니다.'**
  String quietHoursOnHint(String start, String end);

  /// No description provided for @quietHoursStartSheetTitle.
  ///
  /// In ko, this message translates to:
  /// **'잠자기 시작 시간'**
  String get quietHoursStartSheetTitle;

  /// No description provided for @quietHoursEndSheetTitle.
  ///
  /// In ko, this message translates to:
  /// **'잠자기 종료 시간'**
  String get quietHoursEndSheetTitle;

  /// No description provided for @quietHoursSameTimeError.
  ///
  /// In ko, this message translates to:
  /// **'시작과 종료가 같으면 안 됩니다. 다른 시간을 골라주세요.'**
  String get quietHoursSameTimeError;

  /// No description provided for @quietHoursSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'알림 잠자기 설정을 저장하지 못했습니다.'**
  String get quietHoursSaveFailed;

  /// No description provided for @quietHoursAm.
  ///
  /// In ko, this message translates to:
  /// **'오전'**
  String get quietHoursAm;

  /// No description provided for @quietHoursPm.
  ///
  /// In ko, this message translates to:
  /// **'오후'**
  String get quietHoursPm;

  /// No description provided for @quietHoursSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get quietHoursSave;

  /// No description provided for @calendarWeekStartSetting.
  ///
  /// In ko, this message translates to:
  /// **'캘린더 시작 요일'**
  String get calendarWeekStartSetting;

  /// No description provided for @calendarWeekStartRowLabel.
  ///
  /// In ko, this message translates to:
  /// **'시작 요일'**
  String get calendarWeekStartRowLabel;

  /// No description provided for @calendarWeekStartMonday.
  ///
  /// In ko, this message translates to:
  /// **'월요일'**
  String get calendarWeekStartMonday;

  /// No description provided for @calendarWeekStartSunday.
  ///
  /// In ko, this message translates to:
  /// **'일요일'**
  String get calendarWeekStartSunday;

  /// No description provided for @guideExit.
  ///
  /// In ko, this message translates to:
  /// **'가이드 종료하기'**
  String get guideExit;

  /// No description provided for @guide1Section.
  ///
  /// In ko, this message translates to:
  /// **'마이 구독'**
  String get guide1Section;

  /// No description provided for @guide1Headline.
  ///
  /// In ko, this message translates to:
  /// **'좋아하는 팀 경기, 선수 솔랭 놓치지 않고 챙겨보세요'**
  String get guide1Headline;

  /// No description provided for @guide1Description.
  ///
  /// In ko, this message translates to:
  /// **'온보딩에서 선택한 팀, 선수가 자동으로 구독돼요.'**
  String get guide1Description;

  /// No description provided for @guide1CalloutPage.
  ///
  /// In ko, this message translates to:
  /// **'1. 마이구독 페이지에서'**
  String get guide1CalloutPage;

  /// No description provided for @guide1CalloutSettings.
  ///
  /// In ko, this message translates to:
  /// **'2. 구독 설정 아이콘 클릭!'**
  String get guide1CalloutSettings;

  /// No description provided for @guide2Description.
  ///
  /// In ko, this message translates to:
  /// **'응원하는 팀,선수가 더 있다면 마이구독 설정에서 언제든 추가할 수 있어요.'**
  String get guide2Description;

  /// No description provided for @guide3Section.
  ///
  /// In ko, this message translates to:
  /// **'마이 페이지'**
  String get guide3Section;

  /// No description provided for @guide3Headline.
  ///
  /// In ko, this message translates to:
  /// **'경기, 솔랭 알림을 커스텀 해보세요'**
  String get guide3Headline;

  /// No description provided for @guide3Description.
  ///
  /// In ko, this message translates to:
  /// **'응원하는 팀,선수에 대한 알림 세부 설정을 커스텀 할 수 있어요.'**
  String get guide3Description;

  /// No description provided for @guide5Headline.
  ///
  /// In ko, this message translates to:
  /// **'와딩 사용자 편의성 맞춤 설정'**
  String get guide5Headline;

  /// No description provided for @guide5Description.
  ///
  /// In ko, this message translates to:
  /// **'방해 금지 모드, 캘린더 시작 요일 설정 등을 이용하여 더 편리하게 앱을 사용해 보세요'**
  String get guide5Description;

  /// No description provided for @guide6Section.
  ///
  /// In ko, this message translates to:
  /// **'배경화면 위젯, 라이브 위젯'**
  String get guide6Section;

  /// No description provided for @guide6Headline.
  ///
  /// In ko, this message translates to:
  /// **'다양한 와딩 위젯 제공'**
  String get guide6Headline;

  /// No description provided for @guide6Description.
  ///
  /// In ko, this message translates to:
  /// **'캘린더 위젯 ,라이브 위젯, 배경화면 위젯을 활용하여 와딩앱을 100% 활용해보세요.'**
  String get guide6Description;

  /// No description provided for @guide6Footnote.
  ///
  /// In ko, this message translates to:
  /// **'(위 이미지는 연출된 이미지 입니다. 실제 적용 화면은 상이할 수 있습니다.)'**
  String get guide6Footnote;

  /// No description provided for @guide2CalloutAuto.
  ///
  /// In ko, this message translates to:
  /// **'1. 온보딩에서 선택한 팀 자동 구독'**
  String get guide2CalloutAuto;

  /// No description provided for @guide2CalloutAdd.
  ///
  /// In ko, this message translates to:
  /// **'2. 원하는 팀 추가 구독 설정 가능!'**
  String get guide2CalloutAdd;

  /// No description provided for @guide3CalloutMypage.
  ///
  /// In ko, this message translates to:
  /// **'1. 마이페이지에서'**
  String get guide3CalloutMypage;

  /// No description provided for @guide3CalloutDisplay.
  ///
  /// In ko, this message translates to:
  /// **'2. 화면설정> 마이구독 클릭!'**
  String get guide3CalloutDisplay;

  /// No description provided for @guideMenu.
  ///
  /// In ko, this message translates to:
  /// **'와딩 사용가이드'**
  String get guideMenu;

  /// No description provided for @guidePopupBadge.
  ///
  /// In ko, this message translates to:
  /// **'와딩 200% 즐기기'**
  String get guidePopupBadge;

  /// No description provided for @guidePopupTitle.
  ///
  /// In ko, this message translates to:
  /// **'환영해요! 와딩 사용 꿀팁이 도착했어요'**
  String get guidePopupTitle;

  /// No description provided for @guidePopupMessage.
  ///
  /// In ko, this message translates to:
  /// **'지금 보지 않아도 [마이페이지 > 와딩 사용가이드]에서 언제든 다시 볼 수 있어요.'**
  String get guidePopupMessage;

  /// No description provided for @guidePopupDismiss.
  ///
  /// In ko, this message translates to:
  /// **'다음에 볼게요'**
  String get guidePopupDismiss;

  /// No description provided for @guidePopupConfirm.
  ///
  /// In ko, this message translates to:
  /// **'가이드 보기'**
  String get guidePopupConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
