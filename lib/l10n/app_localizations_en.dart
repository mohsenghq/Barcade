// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Starcade';

  @override
  String get launcherTitle => 'Starcade';

  @override
  String get launcherChess => 'Chess';

  @override
  String get launcherMoreSoon => 'More games coming soon';

  @override
  String launcherWins(int count) {
    return 'Wins: $count';
  }

  @override
  String get chessComingSoon => 'Chess is coming soon on web.';

  @override
  String get chessAiModelMissing =>
      'The chess AI model isn\'t installed. Fetch it with `dart run tool/fetch_net.dart`, then restart the app.';

  @override
  String get chessModeHotseat => 'Hotseat';

  @override
  String get chessModeVsAi => 'vs AI';

  @override
  String get chessModeVsAiNote => 'Training model — basic opponent';

  @override
  String get chessModeLocal => 'Local multiplayer';

  @override
  String get chessModeLocalSoon => 'Next update';

  @override
  String get chessModeOnlineLocked => 'Online — locked';

  @override
  String get chessNewGame => 'New game';

  @override
  String get chessRematch => 'Rematch';

  @override
  String get chessUndo => 'Undo';

  @override
  String get chessHint => 'Hint';

  @override
  String get chessDraw => 'Draw';

  @override
  String get chessResign => 'Resign';

  @override
  String get chessWhite => 'White';

  @override
  String get chessBlack => 'Black';

  @override
  String get chessYou => 'You';

  @override
  String get chessAi => 'AI';

  @override
  String get chessWins => 'wins';

  @override
  String get chessResultMate => 'Checkmate';

  @override
  String get chessResultStalemate => 'Stalemate';

  @override
  String get chessResultDraw => 'Draw';

  @override
  String get chessResultYouWon => 'You won';

  @override
  String get chessResultAiWon => 'AI won';

  @override
  String chessDrawReason(String reason) {
    return 'by $reason';
  }

  @override
  String chessHintMove(String move) {
    return 'Hint: $move';
  }

  @override
  String chessMoveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count moves',
      one: '$count move',
    );
    return '$_temp0';
  }

  @override
  String get chessConfirmDraw => 'Agree to a draw?';

  @override
  String get chessConfirmResign => 'Resign the game?';

  @override
  String get chessCancel => 'Cancel';

  @override
  String get chessConfirm => 'Confirm';
}
