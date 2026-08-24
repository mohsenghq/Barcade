/// Chess screen hotseat tests: two humans on one board. Fool's mate
/// (f2f3 e7e5 g2g4 d8h4) is deterministic from the standard start, so a
/// failure here is a wiring bug in the screen, not the line.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:starcade/core/services/audio_service.dart';
import 'package:starcade/core/services/chess_services.dart';
import 'package:starcade/core/services/haptics_service.dart';
import 'package:starcade/core/services/save_controller.dart';
import 'package:starcade/core/services/settings_service.dart';
import 'package:starcade/l10n/app_localizations.dart';
import 'package:starcade/ui/chess/chess_screen.dart';
import 'package:starcade/ui/chess/play_mode_sheet.dart';

import 'memory_save_repository.dart';

Future<ChessServices> _services() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsService(prefs)..load();
  await settings.setSoundEnabled(false);
  await settings.setHapticsEnabled(false);
  return ChessServices(
    save: SaveController(repository: MemorySaveRepository())..load(),
    settings: settings,
    audio: AudioService(settings),
    haptics: HapticsService(settings),
  );
}

Widget _screen(ChessServices services) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChessScreen(services: services, mode: PlayMode.hotseat),
    );

/// The screen wraps everything in [CosmicBackground], whose mote field
/// animates forever, so pumpAndSettle would time out. Explicit pumps only.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 4}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Taps a board square. The keyed squares sit in a hit-test-transparent
/// overlay, so warnIfMissed is suppressed (the tap still lands on the
/// chessground board underneath, which is what must receive it).
Future<void> _tapSquare(WidgetTester tester, String square) async {
  await tester.tap(
    find.byKey(ValueKey('sq-$square')),
    warnIfMissed: false,
  );
}

void main() {
  testWidgets('hotseat: two humans reach checkmate and see the result dialog',
      (tester) async {
    final services = await _services();
    await tester.pumpWidget(_screen(services));

    // 1. f3
    await _tapSquare(tester, 'f2');
    await _tapSquare(tester, 'f3');
    await _pumpFrames(tester);
    // 1... e5
    await _tapSquare(tester, 'e7');
    await _tapSquare(tester, 'e5');
    await _pumpFrames(tester);
    // 2. g4
    await _tapSquare(tester, 'g2');
    await _tapSquare(tester, 'g4');
    await _pumpFrames(tester);
    // 2... Qh4#
    await _tapSquare(tester, 'd8');
    await _tapSquare(tester, 'h4');
    await _pumpFrames(tester);

    expect(find.text('Checkmate'), findsOneWidget,
        reason: 'fool\'s mate must end the game');
    expect(find.text('Black wins'), findsOneWidget,
        reason: 'fool\'s mate mates White, so Black wins');
    expect(find.text('2 moves'), findsOneWidget);
    expect(services.save.profile.losses, 0,
        reason: 'hotseat results are not credited — both sides are human, '
            'there is no owner to credit');
    expect(services.save.profile.wins, 0);
    expect(services.save.profile.aiWins, 0);
  });

  testWidgets('hotseat: undo reverts the last move', (tester) async {
    final services = await _services();
    await tester.pumpWidget(_screen(services));

    await _tapSquare(tester, 'e2');
    await _tapSquare(tester, 'e4');
    await _pumpFrames(tester);
    expect(find.text('1. e2e4'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _pumpFrames(tester);

    expect(find.text('1. e2e4'), findsNothing,
        reason: 'the move list must be empty after undo');
    // The board accepted a fresh white move again, so e2e4 is playable.
    await _tapSquare(tester, 'd2');
    await _tapSquare(tester, 'd4');
    await _pumpFrames(tester);
    expect(find.text('1. d2d4'), findsOneWidget);
  });

  testWidgets('hotseat: draw agreement ends the game with a result dialog',
      (tester) async {
    final services = await _services();
    await tester.pumpWidget(_screen(services));

    await _tapSquare(tester, 'e2');
    await _tapSquare(tester, 'e4');
    await _pumpFrames(tester);

    await tester.tap(find.text('Draw'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Confirm'));
    await _pumpFrames(tester);

    expect(find.text('Rematch'), findsOneWidget,
        reason: 'the result dialog must appear');
    expect(find.text('Draw'), findsWidgets);
    expect(services.save.profile.draws, 0,
        reason: 'hotseat results are not credited — both sides are human, '
            'there is no owner to credit');
    expect(services.save.profile.wins, 0);
    expect(services.save.profile.losses, 0);
  });

  testWidgets('hotseat: resign confirms, then rematch resets the game',
      (tester) async {
    final services = await _services();
    await tester.pumpWidget(_screen(services));

    await _tapSquare(tester, 'e2');
    await _tapSquare(tester, 'e4');
    await _pumpFrames(tester);
    await _tapSquare(tester, 'e7');
    await _tapSquare(tester, 'e5');
    await _pumpFrames(tester);

    // It is White to move again, so the resignation is White's.
    await tester.tap(find.text('Resign'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Confirm'));
    await _pumpFrames(tester);

    expect(find.text('Black wins'), findsOneWidget,
        reason: 'white resigned, so black wins');
    expect(find.text('1 move'), findsOneWidget);
    expect(services.save.profile.losses, 0,
        reason: 'hotseat results are not credited — both sides are human, '
            'there is no owner to credit');

    // Arm the Rematch button (1s delay), then restart.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Rematch'));
    await _pumpFrames(tester);

    expect(find.text('Black wins'), findsNothing);
    expect(find.text('1. e2e4'), findsNothing,
        reason: 'rematch must clear the move list');
    expect(services.save.profile.losses, 0,
        reason: 'hotseat never records, and rematch must not add a result');
  });

  testWidgets('hotseat: the board live region announces moves and the result',
      (tester) async {
    final services = await _services();
    await tester.pumpWidget(_screen(services));

    final region = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.liveRegion == true,
    );

    // 1. f3 — the region announces the move, not just whose turn it is.
    await _tapSquare(tester, 'f2');
    await _tapSquare(tester, 'f3');
    await _pumpFrames(tester);
    var label = tester.widget<Semantics>(region).properties.label;
    expect(label, contains('Last move: f2f3'));

    // Fool's mate to the end — the region announces the outcome too.
    await _tapSquare(tester, 'e7');
    await _tapSquare(tester, 'e5');
    await _pumpFrames(tester);
    await _tapSquare(tester, 'g2');
    await _tapSquare(tester, 'g4');
    await _pumpFrames(tester);
    await _tapSquare(tester, 'd8');
    await _tapSquare(tester, 'h4');
    await _pumpFrames(tester);

    label = tester.widget<Semantics>(region).properties.label;
    expect(label, contains('Last move: d8h4'));
    expect(label, contains('Checkmate'));
  });
}
