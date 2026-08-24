import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The app display name.
  ///
  /// In en, this message translates to:
  /// **'Starcade'**
  String get appTitle;

  /// No description provided for @launcherTitle.
  ///
  /// In en, this message translates to:
  /// **'Starcade'**
  String get launcherTitle;

  /// No description provided for @launcherChess.
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get launcherChess;

  /// No description provided for @launcherMoreSoon.
  ///
  /// In en, this message translates to:
  /// **'More games coming soon'**
  String get launcherMoreSoon;

  /// Win counter shown on the chess card.
  ///
  /// In en, this message translates to:
  /// **'Wins: {count}'**
  String launcherWins(int count);

  /// No description provided for @chessComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Chess is coming soon on web.'**
  String get chessComingSoon;

  /// No description provided for @chessAiModelMissing.
  ///
  /// In en, this message translates to:
  /// **'The chess AI model isn\'t installed. Fetch it with `dart run tool/fetch_net.dart`, then restart the app.'**
  String get chessAiModelMissing;

  /// No description provided for @chessModeHotseat.
  ///
  /// In en, this message translates to:
  /// **'Hotseat'**
  String get chessModeHotseat;

  /// No description provided for @chessModeVsAi.
  ///
  /// In en, this message translates to:
  /// **'vs AI'**
  String get chessModeVsAi;

  /// No description provided for @chessModeVsAiNote.
  ///
  /// In en, this message translates to:
  /// **'Training model — basic opponent'**
  String get chessModeVsAiNote;

  /// No description provided for @chessModeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local multiplayer'**
  String get chessModeLocal;

  /// No description provided for @chessModeLocalSoon.
  ///
  /// In en, this message translates to:
  /// **'Next update'**
  String get chessModeLocalSoon;

  /// No description provided for @chessModeOnlineLocked.
  ///
  /// In en, this message translates to:
  /// **'Online — locked'**
  String get chessModeOnlineLocked;

  /// No description provided for @chessNewGame.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get chessNewGame;

  /// No description provided for @chessRematch.
  ///
  /// In en, this message translates to:
  /// **'Rematch'**
  String get chessRematch;

  /// No description provided for @chessUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get chessUndo;

  /// No description provided for @chessHint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get chessHint;

  /// No description provided for @chessDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get chessDraw;

  /// No description provided for @chessResign.
  ///
  /// In en, this message translates to:
  /// **'Resign'**
  String get chessResign;

  /// No description provided for @chessWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get chessWhite;

  /// No description provided for @chessBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get chessBlack;

  /// No description provided for @chessYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chessYou;

  /// No description provided for @chessAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get chessAi;

  /// No description provided for @chessWins.
  ///
  /// In en, this message translates to:
  /// **'wins'**
  String get chessWins;

  /// No description provided for @chessResultMate.
  ///
  /// In en, this message translates to:
  /// **'Checkmate'**
  String get chessResultMate;

  /// No description provided for @chessResultStalemate.
  ///
  /// In en, this message translates to:
  /// **'Stalemate'**
  String get chessResultStalemate;

  /// No description provided for @chessResultDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get chessResultDraw;

  /// No description provided for @chessResultYouWon.
  ///
  /// In en, this message translates to:
  /// **'You won'**
  String get chessResultYouWon;

  /// No description provided for @chessResultAiWon.
  ///
  /// In en, this message translates to:
  /// **'AI won'**
  String get chessResultAiWon;

  /// Draw modifier, e.g. 'by repetition'.
  ///
  /// In en, this message translates to:
  /// **'by {reason}'**
  String chessDrawReason(String reason);

  /// Suggested move shown when the player asks for a hint.
  ///
  /// In en, this message translates to:
  /// **'Hint: {move}'**
  String chessHintMove(String move);

  /// Moves played when the game ended.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} move} other{{count} moves}}'**
  String chessMoveCount(int count);

  /// No description provided for @chessConfirmDraw.
  ///
  /// In en, this message translates to:
  /// **'Agree to a draw?'**
  String get chessConfirmDraw;

  /// No description provided for @chessConfirmResign.
  ///
  /// In en, this message translates to:
  /// **'Resign the game?'**
  String get chessConfirmResign;

  /// No description provided for @chessCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chessCancel;

  /// No description provided for @chessConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get chessConfirm;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
