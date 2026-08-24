/// Chess screen AI-mode tests: the human (White) moves, the injected fake AI
/// replies after the scheduled turn delay, and the reply lands in the move
/// list (only successfully-applied moves ever reach it, so its presence is
/// the legality check).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:starcade/core/chess/game_state.dart';
import 'package:starcade/core/services/audio_service.dart';
import 'package:starcade/core/services/chess_services.dart';
import 'package:starcade/core/services/haptics_service.dart';
import 'package:starcade/core/services/save_controller.dart';
import 'package:starcade/core/services/settings_service.dart';
import 'package:starcade/l10n/app_localizations.dart';
import 'package:starcade/ui/chess/chess_ai.dart';
import 'package:starcade/ui/chess/chess_screen.dart';
import 'package:starcade/ui/chess/play_mode_sheet.dart';

import 'memory_save_repository.dart';

/// Deterministic fake: always answers 1.d4 with the legal 1... e5.
class _FakeAi implements ChessAI {
  int calls = 0;

  @override
  Future<String?> chooseMove(GameState game, {int simBudget = 200}) async {
    calls++;
    return 'e7e5';
  }
}

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

Widget _screen(ChessServices services, {ChessAI? ai}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChessScreen(services: services, mode: PlayMode.ai, ai: ai),
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
  testWidgets('ai mode: a human move schedules a legal AI reply in the list',
      (tester) async {
    final services = await _services();
    final ai = _FakeAi();
    await tester.pumpWidget(_screen(services, ai: ai));

    // Human (White) plays 1. d4.
    await _tapSquare(tester, 'd2');
    await _tapSquare(tester, 'd4');
    await tester.pump();
    expect(find.text('1. d2d4'), findsOneWidget);

    // Advance past the AI turn delay, then let the board settle.
    await tester.pump(const Duration(milliseconds: 400));
    await _pumpFrames(tester);

    expect(ai.calls, 1, reason: 'the AI must be consulted exactly once');
    expect(find.text('1. d2d4 e7e5'), findsOneWidget,
        reason: 'the AI reply must be applied and listed');
  });

  testWidgets('ai mode: undo is disabled (only hotseat can take back moves)',
      (tester) async {
    final services = await _services();
    await tester.pumpWidget(_screen(services, ai: _FakeAi()));

    final undoButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Undo'),
    );
    expect(undoButton.onPressed, isNull);
  });

  testWidgets('ai mode: the board is frozen while the AI thinks',
      (tester) async {
    final services = await _services();
    await tester.pumpWidget(_screen(services, ai: _FakeAi()));

    await _tapSquare(tester, 'd2');
    await _tapSquare(tester, 'd4');
    await tester.pump(); // AI turn scheduled, not yet applied

    // A second human tap on a white piece must not move anything.
    await _tapSquare(tester, 'e2');
    await _tapSquare(tester, 'e4');
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 400));
    await _pumpFrames(tester);

    expect(find.text('1. d2d4 e7e5'), findsOneWidget,
        reason: 'the only white move is the first one; the frozen board '
            'rejected the extra tap');
  });

  testWidgets(
      'ai mode: resigning during the AI think window still awards the AI the '
      'win', (tester) async {
    final services = await _services();
    await tester.pumpWidget(_screen(services, ai: _FakeAi()));

    // Human plays 1. d4; the AI turn is scheduled but not yet applied, so
    // sideToMove is Black while the human is the one who can press Resign.
    await _tapSquare(tester, 'd2');
    await _tapSquare(tester, 'd4');
    await tester.pump();

    // Resign immediately — the two pumps below stay under the 400ms AI
    // delay, so the resignation lands while _isAiTurn is still true.
    await tester.tap(find.text('Resign'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Confirm'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('AI won'), findsOneWidget,
        reason: 'the human resigned, so the AI must win — even during its turn');
    expect(services.save.profile.losses, 1,
        reason: 'the human lost, so losses increments');
    expect(services.save.profile.aiWins, 1,
        reason: 'a human loss is an AI win');
    expect(services.save.profile.wins, 0,
        reason: 'ai* counters mirror the human result; wins stays untouched');

    // The atomic save must have landed: a fresh controller over the same
    // repository sees the recorded result.
    final reloaded = SaveController(repository: services.save.repository);
    final result = await reloaded.load();
    expect(result.profile.losses, 1);
    expect(result.profile.aiWins, 1);
  });
}
