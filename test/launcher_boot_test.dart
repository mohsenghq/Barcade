/// Launcher boot test: the whole UI boots against a real [ChessServices] graph
/// over an in-memory save repo (mirrors the removed arcade boot smoke test).
/// Explicit pumps only — the mote field animates forever, so pumpAndSettle
/// would time out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:starcade/app/app_providers.dart';
import 'package:starcade/app/starcade_app.dart';
import 'package:starcade/core/services/audio_service.dart';
import 'package:starcade/core/services/chess_services.dart';
import 'package:starcade/core/services/haptics_service.dart';
import 'package:starcade/core/services/save_controller.dart';
import 'package:starcade/core/services/settings_service.dart';

import 'memory_save_repository.dart';

Future<ChessServices> buildTestServices() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsService(prefs)..load();
  final save = SaveController(repository: MemorySaveRepository());
  await save.load(); // empty repo → fresh chess defaults
  return ChessServices(
    save: save,
    settings: settings,
    audio: AudioService(settings),
    haptics: HapticsService(settings),
  );
}

Widget _app(ChessServices services) => ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const StarcadeApp(),
    );

Future<void> _pumpFrames(WidgetTester tester, {int frames = 4}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapSquare(WidgetTester tester, String square) async {
  await tester.tap(
    find.byKey(ValueKey('sq-$square')),
    warnIfMissed: false,
  );
}

/// Opens the mode sheet from the launcher and picks Hotseat.
Future<void> _openHotseat(WidgetTester tester) async {
  await tester.tap(find.text('Chess'));
  await tester.pump(); // start the sheet entrance
  await tester.pump(const Duration(milliseconds: 400));

  await tester.tap(find.text('Hotseat'));
  await tester.pump(); // start the sheet exit
  await tester.pump(const Duration(milliseconds: 350)); // sheet pops → route pushes
  await tester.pump(const Duration(milliseconds: 400)); // route transition
}

void main() {
  testWidgets('launcher boots: chess card, more-soon slot, and win counter',
      (tester) async {
    final services = await buildTestServices();
    await tester.pumpWidget(_app(services));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Chess'), findsOneWidget);
    expect(find.text('More games coming soon'), findsOneWidget);
    expect(find.text('Wins: 0'), findsOneWidget);
  });

  testWidgets('tapping the chess card opens the play-mode sheet, and choosing '
      'a mode starts a game', (tester) async {
    final services = await buildTestServices();
    await tester.pumpWidget(_app(services));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Chess'));
    await tester.pump(); // start the sheet entrance
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Hotseat'), findsOneWidget);
    expect(find.text('vs AI'), findsOneWidget);
    expect(find.text('Local multiplayer'), findsOneWidget);

    await tester.tap(find.text('Hotseat'));
    await tester.pump(); // start the sheet exit
    await tester.pump(const Duration(milliseconds: 350)); // sheet pops → route pushes
    await tester.pump(const Duration(milliseconds: 400)); // route transition

    // The io gate pushed the real chess screen.
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Resign'), findsOneWidget);
  });

  testWidgets('new game after a result returns to the play-mode sheet',
      (tester) async {
    final services = await buildTestServices();
    await tester.pumpWidget(_app(services));
    await tester.pump(const Duration(milliseconds: 100));
    await _openHotseat(tester);

    // Play 1. e4 e5, then resign as White (it is White to move).
    await _tapSquare(tester, 'e2');
    await _tapSquare(tester, 'e4');
    await _pumpFrames(tester);
    await _tapSquare(tester, 'e7');
    await _tapSquare(tester, 'e5');
    await _pumpFrames(tester);
    expect(find.text('1. e2e4 e7e5'), findsOneWidget);

    await tester.tap(find.text('Resign'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Confirm'));
    await _pumpFrames(tester);
    expect(find.text('Black wins'), findsOneWidget,
        reason: 'white resigned, so black wins');

    // Arm the result-dialog buttons (1s delay), then start a new game.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('New game'));
    await _pumpFrames(tester, frames: 6); // dialog + screen exit
    await _pumpFrames(tester, frames: 6); // mode sheet re-entrance

    expect(find.text('Hotseat'), findsOneWidget,
        reason: 'new game must land back on the play-mode sheet');
    expect(find.text('vs AI'), findsOneWidget);
    expect(find.text('Undo'), findsNothing,
        reason: 'the chess screen must have been popped');
  });
}
