import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ne.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
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
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

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
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('ja'),
    Locale('ko'),
    Locale('ne'),
    Locale('pt'),
    Locale('ru'),
    Locale('zh')
  ];

  /// App name shown on settings + share text
  ///
  /// In en, this message translates to:
  /// **'Football Fan Hub 2026'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navFixtures.
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get navFixtures;

  /// No description provided for @navPredictor.
  ///
  /// In en, this message translates to:
  /// **'Predictor'**
  String get navPredictor;

  /// No description provided for @navTrivia.
  ///
  /// In en, this message translates to:
  /// **'Trivia'**
  String get navTrivia;

  /// No description provided for @navBracket.
  ///
  /// In en, this message translates to:
  /// **'Bracket'**
  String get navBracket;

  /// No description provided for @navStandings.
  ///
  /// In en, this message translates to:
  /// **'Standings'**
  String get navStandings;

  /// No description provided for @navFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get navFormat;

  /// No description provided for @navNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get navNews;

  /// No description provided for @actionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionSubmit;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get actionUpdate;

  /// No description provided for @actionPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get actionPlay;

  /// No description provided for @actionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get actionStart;

  /// No description provided for @actionFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get actionFinish;

  /// No description provided for @actionViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get actionViewAll;

  /// No description provided for @actionMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get actionMore;

  /// No description provided for @statusLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get statusLive;

  /// No description provided for @statusFinished.
  ///
  /// In en, this message translates to:
  /// **'FT'**
  String get statusFinished;

  /// No description provided for @statusFullTime.
  ///
  /// In en, this message translates to:
  /// **'Full Time'**
  String get statusFullTime;

  /// No description provided for @statusHalfTime.
  ///
  /// In en, this message translates to:
  /// **'Half-time'**
  String get statusHalfTime;

  /// No description provided for @statusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get statusUpcoming;

  /// No description provided for @statusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get statusScheduled;

  /// No description provided for @statusToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statusToday;

  /// No description provided for @statusTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get statusTomorrow;

  /// No description provided for @statusYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get statusYesterday;

  /// No description provided for @sectionTodayMatches.
  ///
  /// In en, this message translates to:
  /// **'Today\'s matches'**
  String get sectionTodayMatches;

  /// No description provided for @sectionFavoriteTeams.
  ///
  /// In en, this message translates to:
  /// **'Your favorite teams'**
  String get sectionFavoriteTeams;

  /// No description provided for @sectionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get sectionComingSoon;

  /// No description provided for @sectionUpcomingMatches.
  ///
  /// In en, this message translates to:
  /// **'Upcoming matches'**
  String get sectionUpcomingMatches;

  /// No description provided for @sectionRecentForm.
  ///
  /// In en, this message translates to:
  /// **'Recent form'**
  String get sectionRecentForm;

  /// No description provided for @sectionStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get sectionStats;

  /// No description provided for @sectionSquad.
  ///
  /// In en, this message translates to:
  /// **'Squad'**
  String get sectionSquad;

  /// No description provided for @sectionClubInfo.
  ///
  /// In en, this message translates to:
  /// **'Club info'**
  String get sectionClubInfo;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @sectionGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get sectionGoals;

  /// No description provided for @sectionMatchInfo.
  ///
  /// In en, this message translates to:
  /// **'Match info'**
  String get sectionMatchInfo;

  /// No description provided for @sectionLineups.
  ///
  /// In en, this message translates to:
  /// **'Lineups'**
  String get sectionLineups;

  /// No description provided for @sectionH2H.
  ///
  /// In en, this message translates to:
  /// **'Head to head'**
  String get sectionH2H;

  /// No description provided for @sectionStandings.
  ///
  /// In en, this message translates to:
  /// **'Standings'**
  String get sectionStandings;

  /// No description provided for @sectionSubstitutes.
  ///
  /// In en, this message translates to:
  /// **'Substitutes'**
  String get sectionSubstitutes;

  /// No description provided for @sectionStartingXI.
  ///
  /// In en, this message translates to:
  /// **'Starting XI'**
  String get sectionStartingXI;

  /// No description provided for @sectionBench.
  ///
  /// In en, this message translates to:
  /// **'Bench'**
  String get sectionBench;

  /// No description provided for @sectionAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get sectionAchievements;

  /// No description provided for @sectionStarPlayers.
  ///
  /// In en, this message translates to:
  /// **'Star players'**
  String get sectionStarPlayers;

  /// No description provided for @sectionCountryProfile.
  ///
  /// In en, this message translates to:
  /// **'Country profile'**
  String get sectionCountryProfile;

  /// No description provided for @sectionMomentum.
  ///
  /// In en, this message translates to:
  /// **'Momentum'**
  String get sectionMomentum;

  /// No description provided for @sectionStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get sectionStatistics;

  /// No description provided for @sectionTimeline.
  ///
  /// In en, this message translates to:
  /// **'Match timeline'**
  String get sectionTimeline;

  /// No description provided for @sectionLiveTicker.
  ///
  /// In en, this message translates to:
  /// **'Live ticker'**
  String get sectionLiveTicker;

  /// No description provided for @positionGoalkeepers.
  ///
  /// In en, this message translates to:
  /// **'Goalkeepers'**
  String get positionGoalkeepers;

  /// No description provided for @positionDefenders.
  ///
  /// In en, this message translates to:
  /// **'Defenders'**
  String get positionDefenders;

  /// No description provided for @positionMidfielders.
  ///
  /// In en, this message translates to:
  /// **'Midfielders'**
  String get positionMidfielders;

  /// No description provided for @positionForwards.
  ///
  /// In en, this message translates to:
  /// **'Forwards'**
  String get positionForwards;

  /// No description provided for @positionOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get positionOther;

  /// No description provided for @tabSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get tabSummary;

  /// No description provided for @tabLineups.
  ///
  /// In en, this message translates to:
  /// **'Lineups'**
  String get tabLineups;

  /// No description provided for @tabStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get tabStats;

  /// No description provided for @tabH2H.
  ///
  /// In en, this message translates to:
  /// **'H2H'**
  String get tabH2H;

  /// No description provided for @tabStandings.
  ///
  /// In en, this message translates to:
  /// **'Standings'**
  String get tabStandings;

  /// No description provided for @tabPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get tabPitch;

  /// No description provided for @tabList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get tabList;

  /// No description provided for @labelDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get labelDate;

  /// No description provided for @labelKickoff.
  ///
  /// In en, this message translates to:
  /// **'Kick-off'**
  String get labelKickoff;

  /// No description provided for @labelCompetition.
  ///
  /// In en, this message translates to:
  /// **'Competition'**
  String get labelCompetition;

  /// No description provided for @labelStage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get labelStage;

  /// No description provided for @labelGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get labelGroup;

  /// No description provided for @labelVenue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get labelVenue;

  /// No description provided for @labelStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get labelStatus;

  /// No description provided for @labelFounded.
  ///
  /// In en, this message translates to:
  /// **'Founded'**
  String get labelFounded;

  /// No description provided for @labelManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get labelManager;

  /// No description provided for @labelCoach.
  ///
  /// In en, this message translates to:
  /// **'Head coach'**
  String get labelCoach;

  /// No description provided for @labelCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get labelCountry;

  /// No description provided for @labelColours.
  ///
  /// In en, this message translates to:
  /// **'Colours'**
  String get labelColours;

  /// No description provided for @labelWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get labelWebsite;

  /// No description provided for @labelConfederation.
  ///
  /// In en, this message translates to:
  /// **'Confederation'**
  String get labelConfederation;

  /// No description provided for @labelPlayed.
  ///
  /// In en, this message translates to:
  /// **'Played'**
  String get labelPlayed;

  /// No description provided for @labelWins.
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get labelWins;

  /// No description provided for @labelDraws.
  ///
  /// In en, this message translates to:
  /// **'Draws'**
  String get labelDraws;

  /// No description provided for @labelLosses.
  ///
  /// In en, this message translates to:
  /// **'Losses'**
  String get labelLosses;

  /// No description provided for @labelGoalsFor.
  ///
  /// In en, this message translates to:
  /// **'Goals for'**
  String get labelGoalsFor;

  /// No description provided for @labelGoalsAgainst.
  ///
  /// In en, this message translates to:
  /// **'Goals against'**
  String get labelGoalsAgainst;

  /// No description provided for @labelGoalDiff.
  ///
  /// In en, this message translates to:
  /// **'Goal diff'**
  String get labelGoalDiff;

  /// No description provided for @labelPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get labelPoints;

  /// No description provided for @labelPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get labelPosition;

  /// No description provided for @labelNationality.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get labelNationality;

  /// No description provided for @labelAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get labelAge;

  /// No description provided for @labelHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get labelHeight;

  /// No description provided for @labelWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get labelWeight;

  /// No description provided for @labelShirt.
  ///
  /// In en, this message translates to:
  /// **'Shirt'**
  String get labelShirt;

  /// No description provided for @labelTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get labelTeam;

  /// No description provided for @predictorTitle.
  ///
  /// In en, this message translates to:
  /// **'Predictor'**
  String get predictorTitle;

  /// No description provided for @predictorRules.
  ///
  /// In en, this message translates to:
  /// **'Exact = 5 pts • Correct winner = 3 pts'**
  String get predictorRules;

  /// No description provided for @predictorYourPoints.
  ///
  /// In en, this message translates to:
  /// **'Your points'**
  String get predictorYourPoints;

  /// No description provided for @predictorPredicted.
  ///
  /// In en, this message translates to:
  /// **'Predicted'**
  String get predictorPredicted;

  /// No description provided for @predictorSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get predictorSettled;

  /// No description provided for @predictorSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit prediction'**
  String get predictorSubmit;

  /// No description provided for @predictorUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update prediction'**
  String get predictorUpdate;

  /// No description provided for @predictorNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No upcoming matches in this league'**
  String get predictorNoMatches;

  /// No description provided for @predictorSwitchLeague.
  ///
  /// In en, this message translates to:
  /// **'Switch competition to predict other matches.'**
  String get predictorSwitchLeague;

  /// No description provided for @predictorShareIntro.
  ///
  /// In en, this message translates to:
  /// **'MY PREDICTION'**
  String get predictorShareIntro;

  /// No description provided for @predictorBeatMe.
  ///
  /// In en, this message translates to:
  /// **'Think you can beat me?'**
  String get predictorBeatMe;

  /// No description provided for @triviaTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Football Trivia'**
  String get triviaTitle;

  /// No description provided for @triviaStart.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz'**
  String get triviaStart;

  /// No description provided for @triviaCorrect.
  ///
  /// In en, this message translates to:
  /// **'correct'**
  String get triviaCorrect;

  /// No description provided for @triviaQuestionCount.
  ///
  /// In en, this message translates to:
  /// **'10 questions • 15s per question'**
  String get triviaQuestionCount;

  /// No description provided for @triviaStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get triviaStreak;

  /// No description provided for @triviaBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get triviaBest;

  /// No description provided for @triviaToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get triviaToday;

  /// No description provided for @triviaPerfect.
  ///
  /// In en, this message translates to:
  /// **'PERFECT ROUND!'**
  String get triviaPerfect;

  /// No description provided for @triviaGreatJob.
  ///
  /// In en, this message translates to:
  /// **'Great job!'**
  String get triviaGreatJob;

  /// No description provided for @triviaFinalScore.
  ///
  /// In en, this message translates to:
  /// **'FINAL SCORE'**
  String get triviaFinalScore;

  /// No description provided for @triviaTeamsToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s teams'**
  String get triviaTeamsToday;

  /// No description provided for @triviaGeneral.
  ///
  /// In en, this message translates to:
  /// **'General football trivia today'**
  String get triviaGeneral;

  /// No description provided for @triviaCategoryTeamToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s teams'**
  String get triviaCategoryTeamToday;

  /// No description provided for @triviaCategoryStage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get triviaCategoryStage;

  /// No description provided for @triviaCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get triviaCategoryGeneral;

  /// No description provided for @triviaHintCta.
  ///
  /// In en, this message translates to:
  /// **'Watch ad → Eliminate 2 wrong'**
  String get triviaHintCta;

  /// No description provided for @triviaComeBack.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for a new round!'**
  String get triviaComeBack;

  /// No description provided for @triviaQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit quiz?'**
  String get triviaQuit;

  /// No description provided for @triviaQuitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Your progress will be lost.'**
  String get triviaQuitConfirm;

  /// No description provided for @triviaStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get triviaStay;

  /// No description provided for @triviaQuitAction.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get triviaQuitAction;

  /// No description provided for @triviaScoring.
  ///
  /// In en, this message translates to:
  /// **'Earn 10 pts per correct answer + 5 pts speed bonus.'**
  String get triviaScoring;

  /// No description provided for @triviaScoring50.
  ///
  /// In en, this message translates to:
  /// **'50 pts for a perfect round!'**
  String get triviaScoring50;

  /// No description provided for @stageGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get stageGroup;

  /// No description provided for @stageRoundOf32.
  ///
  /// In en, this message translates to:
  /// **'Round of 32'**
  String get stageRoundOf32;

  /// No description provided for @stageRoundOf16.
  ///
  /// In en, this message translates to:
  /// **'Round of 16'**
  String get stageRoundOf16;

  /// No description provided for @stageQuarterFinal.
  ///
  /// In en, this message translates to:
  /// **'Quarter-Final'**
  String get stageQuarterFinal;

  /// No description provided for @stageSemiFinal.
  ///
  /// In en, this message translates to:
  /// **'Semi-Final'**
  String get stageSemiFinal;

  /// No description provided for @stageFinal.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get stageFinal;

  /// No description provided for @stageThirdPlace.
  ///
  /// In en, this message translates to:
  /// **'Third Place'**
  String get stageThirdPlace;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupport;

  /// No description provided for @settingsFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get settingsFeedback;

  /// No description provided for @settingsRateUs.
  ///
  /// In en, this message translates to:
  /// **'Rate us'**
  String get settingsRateUs;

  /// No description provided for @settingsShareApp.
  ///
  /// In en, this message translates to:
  /// **'Share app'**
  String get settingsShareApp;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get settingsTerms;

  /// No description provided for @settingsRemoveAds.
  ///
  /// In en, this message translates to:
  /// **'Remove ads'**
  String get settingsRemoveAds;

  /// No description provided for @settingsRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get settingsRestorePurchases;

  /// No description provided for @settingsAdsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Ads removed'**
  String get settingsAdsRemoved;

  /// No description provided for @settingsAdsRemovedThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for supporting!'**
  String get settingsAdsRemovedThanks;

  /// No description provided for @settingsRemoveAdsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Monthly subscription. No banner ads or interstitials while active.'**
  String get settingsRemoveAdsBlurb;

  /// No description provided for @settingsRemoveAdsBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get settingsRemoveAdsBuy;

  /// No description provided for @settingsLanguageDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get settingsLanguageDialogTitle;

  /// No description provided for @settingsLanguageDialogSub.
  ///
  /// In en, this message translates to:
  /// **'Restart the app for some translations to take full effect.'**
  String get settingsLanguageDialogSub;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get errorOffline;

  /// No description provided for @errorOfflineDesc.
  ///
  /// In en, this message translates to:
  /// **'Showing cached data — connect to refresh.'**
  String get errorOfflineDesc;

  /// No description provided for @errorLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load data'**
  String get errorLoad;

  /// No description provided for @errorTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get errorTryAgain;

  /// No description provided for @errorNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get errorNoMatches;

  /// No description provided for @errorNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get errorNoData;

  /// No description provided for @errorTeamData.
  ///
  /// In en, this message translates to:
  /// **'Limited team data available'**
  String get errorTeamData;

  /// No description provided for @errorSquadNotAnnounced.
  ///
  /// In en, this message translates to:
  /// **'Squad not yet announced'**
  String get errorSquadNotAnnounced;

  /// No description provided for @errorSquadHint.
  ///
  /// In en, this message translates to:
  /// **'Squads typically appear closer to kick-off.'**
  String get errorSquadHint;

  /// No description provided for @errorLineupsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Lineups not published yet.'**
  String get errorLineupsUnavailable;

  /// No description provided for @errorLineupsHint.
  ///
  /// In en, this message translates to:
  /// **'Lineups usually appear ~1 hour before kick-off.'**
  String get errorLineupsHint;

  /// No description provided for @errorStatsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No stats yet.'**
  String get errorStatsUnavailable;

  /// No description provided for @errorStatsHint.
  ///
  /// In en, this message translates to:
  /// **'Statistics appear once the match starts.'**
  String get errorStatsHint;

  /// No description provided for @favoriteAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get favoriteAdd;

  /// No description provided for @favoriteRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get favoriteRemove;

  /// No description provided for @homeWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back — last seen {time}'**
  String homeWelcomeBack(String time);

  /// No description provided for @homeFinishedSince.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# match finished} other{# matches finished}} while you were away:'**
  String homeFinishedSince(int count);

  /// No description provided for @homeLiveNow.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# match LIVE now} other{# matches LIVE now}}'**
  String homeLiveNow(int count);

  /// No description provided for @homeDidYouKnow.
  ///
  /// In en, this message translates to:
  /// **'Did you know?'**
  String get homeDidYouKnow;

  /// No description provided for @homeOnThisDay.
  ///
  /// In en, this message translates to:
  /// **'On this day'**
  String get homeOnThisDay;

  /// No description provided for @homeXpDailyBonus.
  ///
  /// In en, this message translates to:
  /// **'+10 XP daily login bonus'**
  String get homeXpDailyBonus;

  /// No description provided for @newFanModeTitle.
  ///
  /// In en, this message translates to:
  /// **'New Fan Mode'**
  String get newFanModeTitle;

  /// No description provided for @newFanModeCta.
  ///
  /// In en, this message translates to:
  /// **'New to football?'**
  String get newFanModeCta;

  /// No description provided for @compareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare teams'**
  String get compareTitle;

  /// No description provided for @compareTeamA.
  ///
  /// In en, this message translates to:
  /// **'Team A'**
  String get compareTeamA;

  /// No description provided for @compareTeamB.
  ///
  /// In en, this message translates to:
  /// **'Team B'**
  String get compareTeamB;

  /// No description provided for @comparePickTeams.
  ///
  /// In en, this message translates to:
  /// **'Pick two teams to compare'**
  String get comparePickTeams;

  /// No description provided for @comparePickTeamsDesc.
  ///
  /// In en, this message translates to:
  /// **'Stats, recent form, head-to-head.'**
  String get comparePickTeamsDesc;

  /// No description provided for @compareSearchTeams.
  ///
  /// In en, this message translates to:
  /// **'Search teams'**
  String get compareSearchTeams;

  /// No description provided for @qualSimTitle.
  ///
  /// In en, this message translates to:
  /// **'Qualification Simulator'**
  String get qualSimTitle;

  /// No description provided for @qualSimDesc.
  ///
  /// In en, this message translates to:
  /// **'Pick your team and toggle hypothetical results to see if they\'d advance.'**
  String get qualSimDesc;

  /// No description provided for @qualSimYourTeam.
  ///
  /// In en, this message translates to:
  /// **'Your team'**
  String get qualSimYourTeam;

  /// No description provided for @qualSimPickTeam.
  ///
  /// In en, this message translates to:
  /// **'Tap to pick'**
  String get qualSimPickTeam;

  /// No description provided for @qualSimRemainingMatches.
  ///
  /// In en, this message translates to:
  /// **'Remaining matches'**
  String get qualSimRemainingMatches;

  /// No description provided for @qualSimWin.
  ///
  /// In en, this message translates to:
  /// **'Win'**
  String get qualSimWin;

  /// No description provided for @qualSimDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get qualSimDraw;

  /// No description provided for @qualSimLose.
  ///
  /// In en, this message translates to:
  /// **'Lose'**
  String get qualSimLose;

  /// No description provided for @qualSimAutomatic.
  ///
  /// In en, this message translates to:
  /// **'AUTOMATIC QUALIFICATION'**
  String get qualSimAutomatic;

  /// No description provided for @qualSimThirdPlace.
  ///
  /// In en, this message translates to:
  /// **'BEST-3RD-PLACE RACE'**
  String get qualSimThirdPlace;

  /// No description provided for @qualSimEliminated.
  ///
  /// In en, this message translates to:
  /// **'ELIMINATED'**
  String get qualSimEliminated;

  /// No description provided for @qualSimProjectedTable.
  ///
  /// In en, this message translates to:
  /// **'Projected final table'**
  String get qualSimProjectedTable;

  /// No description provided for @qualSimReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get qualSimReset;

  /// No description provided for @qualSimComplete.
  ///
  /// In en, this message translates to:
  /// **'Group stage complete for this team.'**
  String get qualSimComplete;

  /// No description provided for @offlinePackTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Match Pack'**
  String get offlinePackTitle;

  /// No description provided for @offlinePackHeading.
  ///
  /// In en, this message translates to:
  /// **'Watch without data'**
  String get offlinePackHeading;

  /// No description provided for @offlinePackDesc.
  ///
  /// In en, this message translates to:
  /// **'Download fixtures, scores, standings, and team data for a competition so you can use the app offline.'**
  String get offlinePackDesc;

  /// No description provided for @offlinePackSelectComp.
  ///
  /// In en, this message translates to:
  /// **'Select competition'**
  String get offlinePackSelectComp;

  /// No description provided for @offlinePackDownload.
  ///
  /// In en, this message translates to:
  /// **'Download {league} pack'**
  String offlinePackDownload(String league);

  /// No description provided for @offlinePackDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get offlinePackDownloading;

  /// No description provided for @offlinePackStatus.
  ///
  /// In en, this message translates to:
  /// **'Cache status'**
  String get offlinePackStatus;

  /// No description provided for @offlinePackLastNever.
  ///
  /// In en, this message translates to:
  /// **'Never downloaded'**
  String get offlinePackLastNever;

  /// No description provided for @offlinePackLastAt.
  ///
  /// In en, this message translates to:
  /// **'Last downloaded {time}'**
  String offlinePackLastAt(String time);

  /// No description provided for @offlinePackCachedItems.
  ///
  /// In en, this message translates to:
  /// **'{count} cached items'**
  String offlinePackCachedItems(int count);

  /// No description provided for @offlinePackClear.
  ///
  /// In en, this message translates to:
  /// **'Clear offline data'**
  String get offlinePackClear;

  /// No description provided for @offlinePackClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear offline data?'**
  String get offlinePackClearConfirm;

  /// No description provided for @offlinePackClearDesc.
  ///
  /// In en, this message translates to:
  /// **'This will delete all cached fixtures, scores, standings, and team data.'**
  String get offlinePackClearDesc;

  /// No description provided for @matchHeatTitle.
  ///
  /// In en, this message translates to:
  /// **'MATCH HEAT'**
  String get matchHeatTitle;

  /// No description provided for @matchHeatBlockbuster.
  ///
  /// In en, this message translates to:
  /// **'Blockbuster'**
  String get matchHeatBlockbuster;

  /// No description provided for @matchHeatHot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get matchHeatHot;

  /// No description provided for @matchHeatAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get matchHeatAverage;

  /// No description provided for @matchHeatCold.
  ///
  /// In en, this message translates to:
  /// **'Cold'**
  String get matchHeatCold;

  /// No description provided for @rivalryTitle.
  ///
  /// In en, this message translates to:
  /// **'CLASSIC RIVALRY'**
  String get rivalryTitle;

  /// No description provided for @rivalryMoments.
  ///
  /// In en, this message translates to:
  /// **'Memorable moments'**
  String get rivalryMoments;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'INSIGHTS'**
  String get insightsTitle;

  /// No description provided for @insightsFooter.
  ///
  /// In en, this message translates to:
  /// **'Generated locally from recent match data — not predictions.'**
  String get insightsFooter;

  /// No description provided for @fanPollTitle.
  ///
  /// In en, this message translates to:
  /// **'FAN POLL'**
  String get fanPollTitle;

  /// No description provided for @fanPollWhoWins.
  ///
  /// In en, this message translates to:
  /// **'Who wins this match?'**
  String get fanPollWhoWins;

  /// No description provided for @fanPollVotes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# vote} other{# votes}}'**
  String fanPollVotes(int count);

  /// No description provided for @fanPollTapToVote.
  ///
  /// In en, this message translates to:
  /// **'Tap to vote'**
  String get fanPollTapToVote;

  /// No description provided for @debutantSpotlight.
  ///
  /// In en, this message translates to:
  /// **'DEBUTANT SPOTLIGHT'**
  String get debutantSpotlight;

  /// No description provided for @debutantSpotlightDesc.
  ///
  /// In en, this message translates to:
  /// **'First-ever global tournament appearances in 2026'**
  String get debutantSpotlightDesc;

  /// No description provided for @debutantBadge.
  ///
  /// In en, this message translates to:
  /// **'2026 DEBUTANT'**
  String get debutantBadge;

  /// No description provided for @journeyTitle.
  ///
  /// In en, this message translates to:
  /// **'TOURNAMENT JOURNEY'**
  String get journeyTitle;

  /// No description provided for @journeyQualified.
  ///
  /// In en, this message translates to:
  /// **'Qualified'**
  String get journeyQualified;

  /// No description provided for @bracketTitle.
  ///
  /// In en, this message translates to:
  /// **'Bracket Simulator'**
  String get bracketTitle;

  /// No description provided for @bracketTapToBuild.
  ///
  /// In en, this message translates to:
  /// **'Tap teams to build your bracket'**
  String get bracketTapToBuild;

  /// No description provided for @bracketChampion.
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get bracketChampion;

  /// No description provided for @bracketRunnerUp.
  ///
  /// In en, this message translates to:
  /// **'Runner-up'**
  String get bracketRunnerUp;

  /// No description provided for @bracketReset.
  ///
  /// In en, this message translates to:
  /// **'Reset bracket'**
  String get bracketReset;

  /// No description provided for @formatGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Format Guide'**
  String get formatGuideTitle;

  /// No description provided for @formatGuideTeams48.
  ///
  /// In en, this message translates to:
  /// **'48 teams · 12 groups · 16 host cities'**
  String get formatGuideTeams48;

  /// No description provided for @formatGuide3rdRule.
  ///
  /// In en, this message translates to:
  /// **'Top 2 from each group PLUS the 8 best 3rd-placed teams advance.'**
  String get formatGuide3rdRule;

  /// No description provided for @newsTitle.
  ///
  /// In en, this message translates to:
  /// **'Football News'**
  String get newsTitle;

  /// No description provided for @newsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh feed'**
  String get newsRefresh;

  /// No description provided for @newsOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get newsOpenInBrowser;

  /// No description provided for @playerTitle.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerTitle;

  /// No description provided for @playerProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get playerProfile;

  /// No description provided for @playerBiography.
  ///
  /// In en, this message translates to:
  /// **'Biography'**
  String get playerBiography;

  /// No description provided for @playerLimitedInfo.
  ///
  /// In en, this message translates to:
  /// **'Limited info available'**
  String get playerLimitedInfo;

  /// No description provided for @playerNoBio.
  ///
  /// In en, this message translates to:
  /// **'No public bio for this player.'**
  String get playerNoBio;

  /// No description provided for @shareYourSelection.
  ///
  /// In en, this message translates to:
  /// **'I picked'**
  String get shareYourSelection;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'de',
        'en',
        'es',
        'fr',
        'hi',
        'ja',
        'ko',
        'ne',
        'pt',
        'ru',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppL10nAr();
    case 'de':
      return AppL10nDe();
    case 'en':
      return AppL10nEn();
    case 'es':
      return AppL10nEs();
    case 'fr':
      return AppL10nFr();
    case 'hi':
      return AppL10nHi();
    case 'ja':
      return AppL10nJa();
    case 'ko':
      return AppL10nKo();
    case 'ne':
      return AppL10nNe();
    case 'pt':
      return AppL10nPt();
    case 'ru':
      return AppL10nRu();
    case 'zh':
      return AppL10nZh();
  }

  throw FlutterError(
      'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
