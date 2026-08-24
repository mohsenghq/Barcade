# Chess Shell + App Pivot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strip the arcade platform to a lean launcher and ship a playable, testable chess game (hotseat + placeholder vs-AI) on native platforms, web showing a coming-soon card.

**Architecture:** Delete the Flame-arcade layer and economy; retype the existing atomic save layer to a small `ChessProfile`; add the Lichess pair (`dartchess` rules + `chessground` board) behind a thin `GameState`/`ChessBoard` wrapper; a `ChessAI` interface with a legal-random placeholder stands in for the RL model until the trainer ships one; a conditional-import gate keeps the web build green (chess is native-only).

**Tech Stack:** Flutter 3.44 / Dart 3.12, `dartchess` 0.13.1, `chessground` 10.1.1, `flutter_riverpod`, `shared_preferences`, gen_l10n, existing Cosmic Toybox chrome.

## Global Constraints

- pubspec version → **2.0.0+1**.
- Pin exactly: `dartchess: 0.13.1`, `chessground: 10.1.1`. Remove `flame_test` (dev). **Keep** `flame` + `flame_audio` (audio_service depends on them). Remove all game/economy/model/service code; delete their tests.
- **Every flutter command after any pubspec/arb change needs the mirror env:** `source tool/env.sh` first, else pub.dev is geo-blocked and `flutter pub get` fails.
- After editing `l10n/app_en.arb`, run `flutter gen-l10n` (generated output lands in `lib/l10n/`).
- Chess is **native-only**: chess code must never be imported on web — use the conditional-import gate. The web build (`flutter build web`) must stay green and show a coming-soon card.
- Constructor injection; the launcher is the only Riverpod consumer. Reuse the atomic save layer — do not invent persistence.
- `flutter analyze` and `flutter test` must be clean at the end of every task.
- Board prefs (`themeId`, `pieceSetId`, `flipBoard`) and win/loss/draw counters live in `ChessProfile` (atomic save). Sound/haptics stay in `SettingsService` (prefs) — untouched.
- The chess screen is the Lichess-mobile layout: top player bar → 1:1 board with coordinates → bottom player bar → move list + controls (undo/hint/draw/resign), result dialog with reason + rematch/new game.
- Piece assets (cburnett/merida) are **not** procured in this plan — use chessground's built-in rendering (letter pieces guaranteed). `pieceSetId` is the contract field for later asset sets.

---

### Task 1: Strip the arcade layers → lean launcher boots (web-safe)

Remove all game/economy/model/doomed-service code and their tests, retype the save layer to `ChessProfile`, rebuild boot to a lean `ChessServices`, and stand up the launcher with a Chess card gated by a conditional-import `ChessGate` (both impls return a "coming soon" placeholder this task).

**Files:**
- Delete: `lib/ui/games/` (whole dir), `lib/core/economy/` (whole dir), `lib/core/model/` (whole dir), `lib/core/services/achievement_service.dart`, `lib/core/services/currency_service.dart`, `lib/core/services/reward_service.dart`, `lib/core/services/stats_service.dart`, `lib/core/services/game_events.dart`, `lib/core/services/player_repository.dart`, `lib/core/services/monetization.dart`, `lib/core/services/interfaces/` (whole dir), `lib/core/services/mini_game_services.dart`
- Delete tests: `test/app_boot_test.dart`, `test/core_smoke_test.dart`, `test/game_chrome_test.dart`, `test/game_contract_test.dart`, `test/monetization_test.dart`, `test/persistence_test.dart`, `test/progression_test.dart`, `test/qa_coverage_test.dart`, `test/result_overlay_test.dart`, `test/reward_flow_test.dart`, `test/support/` (whole dir)
- Modify: `pubspec.yaml`, `lib/app/starcade_app.dart`, `lib/app/bootstrap.dart`, `lib/app/app_providers.dart`, `lib/core/save/defaults.dart`, `lib/core/save/migration.dart`, `lib/core/save/envelope.dart`, `lib/core/services/save_controller.dart`
- Create: `lib/core/model/chess_profile.dart`, `lib/core/services/chess_services.dart`, `lib/ui/launcher/launcher_screen.dart`, `lib/ui/chess/chess_gate.dart`, `lib/ui/chess/chess_gate_io.dart`, `lib/ui/chess/chess_gate_web.dart`
- Test: `test/launcher_boot_test.dart`, `test/chess_profile_save_test.dart`

**Interfaces:**
- Consumes: existing `SaveController` (typed to `PlayerProfile` — must be retyped), `SaveRepository`/`MemorySaveRepository`, `SettingsService`, `AudioService`, `HapticsService`, `SaveEnvelope.currentVersion`.
- Produces: `ChessProfile` (model), `ChessServices` (composition root), `ChessGate.open(context)` (void, opens chess entry — stub this task), `launcherScreen` (widget), `chessProfileProvider` (StreamProvider<ChessProfile>).

- [ ] **Step 1: Delete the doomed code and tests**

```bash
git rm -r lib/ui/games lib/core/economy lib/core/model
git rm lib/core/services/achievement_service.dart lib/core/services/currency_service.dart \
       lib/core/services/reward_service.dart lib/core/services/stats_service.dart \
       lib/core/services/game_events.dart lib/core/services/player_repository.dart \
       lib/core/services/monetization.dart lib/core/services/interfaces \
       lib/core/services/mini_game_services.dart
git rm test/app_boot_test.dart test/core_smoke_test.dart test/game_chrome_test.dart \
       test/game_contract_test.dart test/monetization_test.dart test/persistence_test.dart \
       test/progression_test.dart test/qa_coverage_test.dart test/result_overlay_test.dart \
       test/reward_flow_test.dart test/support
```

Keep `test/settings_audio_test.dart` — it tests settings+audio, which survive. Keep `lib/ui/theme/`, `lib/core/services/settings_service.dart`, `audio_service.dart`, `haptics_service.dart`, `save_repository.dart`, `checksum.dart`.

- [ ] **Step 2: Update pubspec**

`pubspec.yaml`: `version: 2.0.0+1`; description → "Starcade — a launcher of RL-AI games, starting with chess."; remove `flame_test` from dev_dependencies; keep `flame`, `flame_audio`, `flutter_animate`, `flutter_riverpod`, `shared_preferences`, `path_provider`, `crypto`, `intl`.

- [ ] **Step 3: Create ChessProfile model**

`lib/core/model/chess_profile.dart`:

```dart
/// Player-facing chess state persisted atomically (theme, piece set, board
/// orientation, and match counters). v2 of the save schema (the v1 arcade
/// profile is discarded on migration).
class ChessProfile {
  const ChessProfile({
    this.themeId = 'nebula',
    this.pieceSetId = 'letter',
    this.flipBoard = false,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.aiWins = 0,
    this.aiLosses = 0,
    this.aiDraws = 0,
  });

  final String themeId;
  final String pieceSetId;
  final bool flipBoard;
  final int wins;
  final int losses;
  final int draws;
  final int aiWins;
  final int aiLosses;
  final int aiDraws;

  ChessProfile copyWith({String? themeId, String? pieceSetId, bool? flipBoard,
      int? wins, int? losses, int? draws, int? aiWins, int? aiLosses, int? aiDraws}) =>
      ChessProfile(
        themeId: themeId ?? this.themeId,
        pieceSetId: pieceSetId ?? this.pieceSetId,
        flipBoard: flipBoard ?? this.flipBoard,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
        draws: draws ?? this.draws,
        aiWins: aiWins ?? this.aiWins,
        aiLosses: aiLosses ?? this.aiLosses,
        aiDraws: aiDraws ?? this.aiDraws,
      );

  factory ChessProfile.fromJson(Map<String, Object?> json) => ChessProfile(
        themeId: json['themeId'] as String? ?? 'nebula',
        pieceSetId: json['pieceSetId'] as String? ?? 'letter',
        flipBoard: json['flipBoard'] as bool? ?? false,
        wins: json['wins'] as int? ?? 0,
        losses: json['losses'] as int? ?? 0,
        draws: json['draws'] as int? ?? 0,
        aiWins: json['aiWins'] as int? ?? 0,
        aiLosses: json['aiLosses'] as int? ?? 0,
        aiDraws: json['aiDraws'] as int? ?? 0,
      );

  Map<String, Object?> toJson() => {
        'themeId': themeId,
        'pieceSetId': pieceSetId,
        'flipBoard': flipBoard,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'aiWins': aiWins,
        'aiLosses': aiLosses,
        'aiDraws': aiDraws,
      };
}
```

- [ ] **Step 4: Retype the save layer to ChessProfile**

- `lib/core/save/defaults.dart` — replace body:

```dart
import '../model/chess_profile.dart';

/// A fresh profile: Nebula theme, letter pieces, no counters.
ChessProfile newChessProfile() => const ChessProfile();
```

- `lib/core/save/envelope.dart` — bump `SaveEnvelope.currentVersion` to `2` (read the file first; it is the single source of truth for schema version).
- `lib/core/save/migration.dart` — add the v1→v2 step:

```dart
// v1 (arcade profile) → v2 (chess profile): the old profile is meaningless
// after the pivot; reset to an empty payload so fromJson fills defaults.
if (v < 2) out = _resetToDefaults(out);
// ...
v = 2;
```

with `Map<String, Object?> _resetToDefaults(Map<String, Object?> _) => {};`
- `lib/core/services/save_controller.dart` — change the profile field/type from `PlayerProfile` to `ChessProfile` everywhere it is referenced (load, save, `changes`, getters). It constructs the profile via `newChessProfile()` for defaults and via `ChessProfile.fromJson` on load. Run `grep -rn PlayerProfile lib/` to catch every remaining reference (there should be none after the delete; if any remain, delete that file too).

- [ ] **Step 5: Rebuild boot + composition root**

`lib/core/services/chess_services.dart`:

```dart
import 'audio_service.dart';
import 'haptics_service.dart';
import 'save_controller.dart';
import 'settings_service.dart';

/// Lean composition root (replaces MiniGameServices): constructor-injected
/// into the launcher and chess screens.
class ChessServices {
  ChessServices({
    required this.save,
    required this.settings,
    required this.audio,
    required this.haptics,
  });

  final SaveController save;
  final SettingsService settings;
  final AudioService audio;
  final HapticsService haptics;
}
```

`lib/app/bootstrap.dart` — rewrite to build the lean set (mirror the old shape):

```dart
Future<ChessServices> bootstrap() async {
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsService(prefs)..load();
  final save = SaveController(repository: await createSaveRepository());
  await save.load(); // recovery ladder: canonical → .bak → defaults
  final services = ChessServices(
    save: save,
    settings: settings,
    audio: AudioService(settings),
    haptics: HapticsService(settings),
  );
  await services.audio.init();
  return services;
}
```

(Keep the imports that still exist; drop achievement/currency/reward/stats/player/monetization/network/events imports.)

`lib/app/app_providers.dart` — rewrite:

```dart
final servicesProvider = Provider<ChessServices>(
  (ref) => throw UnimplementedError('servicesProvider must be overridden at boot'),
);

final chessProfileProvider = StreamProvider<ChessProfile>(
  (ref) => ref.watch(servicesProvider).save.changes,
);
```

- [ ] **Step 6: Launcher + chess gate (both impls are placeholders this task)**

`lib/ui/launcher/launcher_screen.dart` — Cosmic Toybox chrome (reuse `Ct`, `CosmicBackground`, `FadeSlideIn`, `GlowButton`, `PopIn` from `lib/ui/theme/`), a title row, one **Chess** card (`Icons.chess`, accent `Ct.mint`) that calls `ChessGate.open(context)`, and a muted "More games coming soon" slot. A Riverpod `ConsumerStatefulWidget` reading `chessProfileProvider` to show the win counter on the card (so the provider is exercised).

`lib/ui/chess/chess_gate.dart`:

```dart
/// Conditional-import seam: chess is native-only (dartchess has no web
/// support). Web builds resolve the stub; io builds resolve the real gate.
import 'chess_gate_stub.dart'
    if (dart.library.io) 'chess_gate_io.dart' as impl;

/// Opens the chess entry point for the current platform.
void openChess(BuildContext context) => impl.openChess(context);
```

Create `lib/ui/chess/chess_gate_stub.dart` with `void openChess(BuildContext context) => throw UnsupportedError('chess unavailable');` — wait, do not throw in a web build: show the coming-soon card instead. Name it `chess_gate_web.dart` to be explicit, and have the stub show a SnackBar:

```dart
void openChess(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Chess is coming soon on web.'),
  ));
}
```

`lib/ui/chess/chess_gate_io.dart` — same signature; this task it shows a "Chess coming soon" SnackBar too (Task 4 replaces it with the real mode-select).

The launcher imports `chess_gate.dart` only — never `chess_gate_io.dart` — so the web build compiles.

- [ ] **Step 7: Add launcher + chess strings to l10n**

In `l10n/app_en.arb` replace the arcade strings with at least: `appTitle`, `launcherTitle`, `launcherChess`, `launcherMoreSoon`, `launcherWins`, `chessComingSoon`. Keep the keys that `lib/ui/theme/widgets.dart` and `lib/l10n` still reference (check via `grep -rn 'AppLocalizations' lib/` and `grep -rn '\.' l10n/app_en.arb` for used keys). Then `source tool/env.sh && flutter gen-l10n`.

- [ ] **Step 8: Write the failing tests**

`test/chess_profile_save_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starcade/core/model/chess_profile.dart';
import 'package:starcade/core/save/defaults.dart';
import 'package:starcade/core/services/save_controller.dart';
import 'package:starcade/core/services/save_repository.dart';

void main() {
  test('ChessProfile json roundtrip preserves every field', () {
    const p = ChessProfile(themeId: 'wood', pieceSetId: 'letter',
        flipBoard: true, wins: 3, losses: 1, draws: 2,
        aiWins: 5, aiLosses: 4, aiDraws: 1);
    final back = ChessProfile.fromJson(p.toJson());
    expect(back.themeId, 'wood');
    expect(back.flipBoard, isTrue);
    expect(back.wins, 3);
    expect(back.aiLosses, 4);
  });

  test('defaults produce an empty, unearned profile', () {
    expect(newChessProfile().wins, 0);
    expect(newChessProfile().themeId, 'nebula');
  });

  test('save roundtrip through SaveController survives a reload', () async {
    final repo = MemorySaveRepository();
    final a = SaveController(repository: repo);
    await a.load();
    a.profile = a.profile.copyWith(wins: 7);
    await a.saveNow();
    final b = SaveController(repository: repo);
    final r = await b.load();
    expect(r.profile.wins, 7, reason: 'atomic save must persist ChessProfile');
  });
}
```

`test/launcher_boot_test.dart` — boot the app (mirror the removed `app_boot_test.dart` pattern: override `servicesProvider` with a `ChessServices` built over a `MemorySaveRepository`, pump `StarcadeApp`, expect the Chess card text and the win counter). Use `SettingsService(SharedPreferences)` with `SharedPreferences.setMockInitialValues({})`.

- [ ] **Step 9: Run tests to verify the new ones fail**

Run: `source tool/env.sh && flutter test test/chess_profile_save_test.dart test/launcher_boot_test.dart`
Expected: FAIL — `ChessProfile`/`ChessServices`/launcher do not exist yet.

- [ ] **Step 10: Run analyze + full suite, fix until green**

Run: `source tool/env.sh && flutter analyze && flutter test`
Expected: analyze clean; the two new tests pass; `test/settings_audio_test.dart` still passes; no reference to deleted symbols anywhere (`grep -rn 'PlayerProfile\|MiniGameServices\|GameResult\|achievement\|economy' lib/ test/` is empty).

- [ ] **Step 11: Verify web still compiles**

Run: `source tool/env.sh && flutter build web --release`
Expected: builds green (the gate keeps chess off the web tree).

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "refactor!: strip arcade layers, retype save to ChessProfile, lean launcher

2.0.0 pivot. Deletes the 6 games, economy, Flame game host and their tests;
retypes the atomic save layer to a ChessProfile (v2 schema, v1 reset on
migration); rebuilds boot as ChessServices; adds the web-safe conditional
ChessGate. audio_service keeps flame_audio.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: Chess rules layer — GameState (draw detection + result resolution)

Add `dartchess` + `chessground`, and build `GameState`: a stateful wrapper owning the position, the move list, repetition + 50/75-move draw detection (which dartchess does **not** do), and result resolution.

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/chess/game_state.dart`
- Test: `test/game_state_test.dart`

**Interfaces:**
- Consumes: `dartchess` (`Game`, `Move`, `Board`, `PlayGameResult` as exposed by dartchess 0.13 — read its API surface when implementing).
- Produces: `GameState` with: `Game get game`, `List<Move> get legalMoves`, `List<String> get pgnMoves`, `bool get isGameOver`, `GameStatus get status`, `String? get drawReason`, `bool makeMove(String uci)`, `void undoLast()`, `String? get fen`, `bool get isThreefoldRepetition`, `bool get isFiftyMoveRule`, `String get sideToMove`. `GameStatus` enum: `playing, checkmate, stalemate, draw` (draw covers agreement/repetition/50-move/insufficient — `drawReason` names it).

- [ ] **Step 1: Add the pinned deps**

`pubspec.yaml` dependencies block:

```yaml
  # Chess rules + board (Lichess-mobile pair, deliberately GPL — see AGENTS.md)
  dartchess: 0.13.1
  chessground: 10.1.1
```

Then `source tool/env.sh && flutter pub get`.

- [ ] **Step 2: Write the failing tests**

`test/game_state_test.dart` — the load-bearing cases (repetition + 50-move are the silent-correctness traps dartchess does not cover):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starcade/core/chess/game_state.dart';

void main() {
  test('threefold repetition is detected and ends the game as a draw', () {
    final s = GameState();
    // The classic repetition line: Nf3 Nf6 Ng1 Ng8 Nf3 Nf6 Ng1 Ng8
    // (each pair returns to the start position 3 times).
    const moves = ['g1f3', 'g8f6', 'f3g1', 'f6g8',
                   'g1f3', 'g8f6', 'f3g1', 'f6g8'];
    for (final m in moves) {
      expect(s.makeMove(m), isTrue, reason: 'illegal move in the line: $m');
    }
    expect(s.isThreefoldRepetition, isTrue);
    expect(s.isGameOver, isTrue);
    expect(s.drawReason, contains('repetition'));
  });

  test('50-move rule ends the game as a draw', () {
    final s = GameState();
    // 50 half-moves with no capture or pawn move: shuffle knights back and
    // forth for 50 plies. Each Ng1-f3/g8-f6 pair is 4 plies; 13 pairs = 52.
    for (var i = 0; i < 13; i++) {
      for (final m in ['g1f3', 'g8f6', 'f3g1', 'f6g8']) {
        expect(s.makeMove(m), isTrue);
      }
    }
    expect(s.isFiftyMoveRule, isTrue);
    expect(s.isGameOver, isTrue);
  });

  test('checkmate resolves a winner', () {
    final s = GameState();
    // Fool's mate: f3 e5 g4 Qh4#
    for (final m in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      expect(s.makeMove(m), isTrue);
    }
    expect(s.status, GameStatus.checkmate);
    expect(s.isGameOver, isTrue);
  });

  test('stalemate is detected', () {
    final s = GameState.fromFen('k7/8/1Q6/8/8/8/8/7K b - - 0 1');
    expect(s.isGameOver, isTrue);
    expect(s.status, GameStatus.stalemate);
  });

  test('undo restores the previous position', () {
    final s = GameState();
    expect(s.makeMove('e2e4'), isTrue);
    expect(s.pgnMoves.length, 1);
    s.undoLast();
    expect(s.pgnMoves, isEmpty);
    expect(s.makeMove('g1f3'), isTrue, reason: 'e4 was undone');
  });

  test('illegal moves are rejected and state is untouched', () {
    final s = GameState();
    expect(s.makeMove('e2e5'), isFalse, reason: 'pawn cannot jump two-from-first');
    expect(s.pgnMoves, isEmpty);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `source tool/env.sh && flutter test test/game_state_test.dart`
Expected: FAIL — `lib/core/chess/game_state.dart` does not exist.

- [ ] **Step 4: Implement GameState**

`lib/core/chess/game_state.dart`:

```dart
import 'dart:collection';

import 'package:dartchess/dartchess.dart' as dc;

enum GameStatus { playing, checkmate, stalemate, draw }

/// Stateful game wrapper around dartchess. dartchess validates moves and
/// reports check/mate, but does NOT auto-detect repetition or the 50/75-move
/// rules — that is this layer's job (silent-correctness trap).
class GameState {
  GameState() : this.fromFen(dc.standard.startFen);
  GameState.fromFen(String fen) : game = dc.Game.fromFen(fen);

  dc.Game game;
  final List<String> _fenHistory = <String>[];
  String? drawReason;

  String get fen => game.fen;
  String get sideToMove => game.turn;
  bool get isGameOver => status != GameStatus.playing;
  List<String> get pgnMoves => game.history.map(dc.moveToUci).toList();
  List<dc.Move> get legalMoves => game.legalMoves;

  GameStatus get status {
    if (game.isCheckmate) return GameStatus.checkmate;
    if (game.isStalemate) return GameStatus.stalemate;
    if (isThreefoldRepetition || isFiftyMoveRule) return GameStatus.draw;
    return GameStatus.playing;
  }

  bool get isThreefoldRepetition {
    // Count how many times the current position has occurred in the history
    // (including the current position). >= 3 ends the game.
    final counts = HashMap<String, int>();
    for (final f in _fenHistory) {
      counts[f] = (counts[f] ?? 0) + 1;
    }
    return (counts[game.fen] ?? 0) >= 3;
  }

  bool get isFiftyMoveRule {
    // The halfmove clock counts plies since the last capture or pawn move;
    // 100 plies = 50 full moves = the rule-50 draw. dartchess exposes it as
    // `game.halfmoves` (confirm the 0.13 field name when implementing).
    final halfmoves = game.halfmoves;
    return halfmoves != null && halfmoves >= 100;
  }

  bool makeMove(String uci) {
    final m = dc.Move.fromUci(uci);
    final ok = game.isLegal(m);
    if (!ok) return false;
    _fenHistory.add(game.fen);
    game.playMove(m);
    if (isThreefoldRepetition) drawReason = 'repetition';
    if (isFiftyMoveRule) drawReason = '50-move rule';
    return true;
  }

  void undoLast() {
    if (_fenHistory.isEmpty) return;
    _fenHistory.removeLast();
    game.undoMove();
    drawReason = null;
  }
}
```

> Note: confirm dartchess 0.13's exact API for `game.halfmoves`/halfmove clock, `game.legalMoves`, `Move.fromUci`, `moveToUci`, `dc.standard.startFen` when implementing — the plan's intent is: legal-move validation via dartchess, repetition + 50-move tracked in this wrapper. Adjust identifiers to the real API, keep the tests' *behavior* identical.

- [ ] **Step 5: Run tests to verify they pass**

Run: `source tool/env.sh && flutter test test/game_state_test.dart`
Expected: PASS (5/5).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/chess/game_state.dart test/game_state_test.dart
git commit -m "feat: chess rules layer — GameState with repetition + 50-move draw detection

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Board themes + ChessBoard widget (chessground, a11y, keys)

**Files:**
- Create: `lib/ui/chess/themes/board_theme.dart`, `lib/ui/chess/chess_board.dart`
- Test: `test/board_theme_test.dart`, `test/chess_board_widget_test.dart`

**Interfaces:**
- Consumes: `chessground` (`Board`, `ChessboardColorScheme`, `Controller` — read 10.1.1's API surface), `GameState` (Task 2), `ChessProfile` theme fields (Task 1).
- Produces: `BoardTheme` (data: id, displayName, `ChessboardColorScheme`), `kBoardThemes` (List<BoardTheme>, first = Nebula default), `ChessBoard` widget with `ChessBoard({required Controller controller, required String sideToMove, required void Function(String uci) onUserMove, required bool isAiTurn})` that renders a 1:1 board with coordinates and stamps each square with `ValueKey('sq-$square')` for tests, wrapped in a `Semantics` live region announcing moves.

- [ ] **Step 1: Write the failing theme test**

`test/board_theme_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starcade/ui/chess/themes/board_theme.dart';

void main() {
  test('Nebula is the default theme and defines the palette', () {
    expect(kBoardThemes.first.id, 'nebula');
    final neb = kBoardThemes.first;
    expect(neb.lightSquare, const Color(0xFF2E2454));
    expect(neb.darkSquare, const Color(0xFF191238));
  });

  test('wood and blue are present with their documented colors', () {
    final wood = kBoardThemes.firstWhere((t) => t.id == 'wood');
    expect(wood.lightSquare, const Color(0xFFF0D9B6));
    expect(wood.darkSquare, const Color(0xFFB58863));
    final blue = kBoardThemes.firstWhere((t) => t.id == 'blue');
    expect(blue.lightSquare, const Color(0xFFDEE3E6));
    expect(blue.darkSquare, const Color(0xFF8CA2AD));
  });

  test('every theme maps to a chessground color scheme', () {
    for (final t in kBoardThemes) {
      expect(t.colorScheme, isNotNull, reason: t.id);
    }
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `source tool/env.sh && flutter test test/board_theme_test.dart`
Expected: FAIL — `board_theme.dart` missing.

- [ ] **Step 3: Implement board_theme.dart**

```dart
import 'package:chessground/chessground.dart' as cg;
import 'package:flutter/material.dart';

/// A named board palette. `colorScheme` is the chessground theme; the light/
/// dark square colors are derived from it for the test contract.
class BoardTheme {
  const BoardTheme({required this.id, required this.displayName,
      required this.colorScheme});
  final String id;
  final String displayName;
  final cg.ChessboardColorScheme colorScheme;
  Color get lightSquare => colorScheme.squareLight;
  Color get darkSquare => colorScheme.squareDark;
}

/// Default = Nebula (bespoke dark). Order matters: index 0 is the default.
final List<BoardTheme> kBoardThemes = [
  BoardTheme(id: 'nebula', displayName: 'Nebula', colorScheme: _nebula()),
  BoardTheme(id: 'wood', displayName: 'Classic Wood', colorScheme: _wood()),
  BoardTheme(id: 'blue', displayName: 'Ice Blue', colorScheme: _blue()),
];

cg.ChessboardColorScheme _nebula() => const cg.ChessboardColorScheme(
      squareLight: Color(0xFF2E2454),
      squareDark: Color(0xFF191238),
      selected: Color(0xFFF2C14E),
      lastMove: Color(0xFF22D3EE),
      check: Color(0xFFF43F5E),
    );

cg.ChessboardColorScheme _wood() => const cg.ChessboardColorScheme(
      squareLight: Color(0xFFF0D9B6),
      squareDark: Color(0xFFB58863),
    );

cg.ChessboardColorScheme _blue() => const cg.ChessboardColorScheme(
      squareLight: Color(0xFFDEE3E6),
      squareDark: Color(0xFF8CA2AD),
    );
```

> If chessground's field names differ (`squareLight` vs `lightSquare`, etc.), read the pinned 10.1.1 `ChessboardColorScheme` and adapt — the tests assert the *values*, and `BoardTheme.lightSquare`/`darkSquare` getters keep the app-facing contract stable.

- [ ] **Step 4: Write the failing widget test**

`test/chess_board_widget_test.dart`:

```dart
import 'package:chessground/chessground.dart' as cg;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcade/ui/chess/chess_board.dart';

void main() {
  testWidgets('board renders 64 keyed squares and a live Semantics region',
      (tester) async {
    final ctrl = cg.Controller();
    await tester.pumpWidget(MaterialApp(
      home: ChessBoard(controller: ctrl, sideToMove: 'w',
          onUserMove: (_) {}, isAiTurn: false),
    ));
    expect(find.byKey(const ValueKey('sq-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('sq-e4')), findsOneWidget);
    expect(find.byKey(const ValueKey('sq-h8')), findsOneWidget);
    final region = tester.widget<Semantics>(find.byType(Semantics));
    expect(region.liveRegion, isTrue);
  });
}
```

- [ ] **Step 5: Run it to verify it fails**

Run: `source tool/env.sh && flutter test test/chess_board_widget_test.dart`
Expected: FAIL — `chess_board.dart` missing.

- [ ] **Step 6: Implement ChessBoard**

```dart
import 'package:chessground/chessground.dart' as cg;
import 'package:flutter/material.dart';

/// 1:1 chess board backed by chessground, themed, with keyed squares for
/// tests and a Semantics live region for screen readers (chessground has no
/// built-in a11y — the live region is where move announcements land).
class ChessBoard extends StatelessWidget {
  const ChessBoard({super.key, required this.controller,
      required this.sideToMove, required this.onUserMove,
      required this.isAiTurn});

  final cg.Controller controller;
  final String sideToMove;
  final void Function(String uci) onUserMove;
  final bool isAiTurn;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Chess board. $sideToMove to move.',
      child: AspectRatio(
        aspectRatio: 1,
        child: cg.Board(
          controller: controller,
          onUserMove: (move) => onUserMove(move.uci),
          squareBuilder: (square, size) =>
              KeyedSubtree(key: ValueKey('sq-$square'), child: const SizedBox()),
        ),
      ),
    );
  }
}
```

> If chessground 10.1.1's `squareBuilder` signature differs (or is absent), fall back to wrapping `cg.Board` in a `Stack` of `Positioned` keyed squares computed from the controller's position — the contract that matters is: `ValueKey('sq-<square>')` exists for every square on screen, and `onUserMove(String uci)` fires on a completed user move.

- [ ] **Step 7: Run tests to verify they pass**

Run: `source tool/env.sh && flutter test test/board_theme_test.dart test/chess_board_widget_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/chess/themes/board_theme.dart lib/ui/chess/chess_board.dart \
        test/board_theme_test.dart test/chess_board_widget_test.dart
git commit -m "feat: chess board themes (Nebula/wood/blue) + keyed, a11y ChessBoard widget

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Chess screen — playable game (hotseat + placeholder AI)

**Files:**
- Create: `lib/ui/chess/chess_ai.dart`, `lib/ui/chess/chess_clock.dart`, `lib/ui/chess/move_list.dart`, `lib/ui/chess/result_dialog.dart`, `lib/ui/chess/play_mode_sheet.dart`, `lib/ui/chess/chess_screen.dart`
- Modify: `lib/ui/chess/chess_gate_io.dart` (wire the real mode-select + screen), `lib/ui/launcher/launcher_screen.dart` (record results into the profile — optional; keep counter display), `l10n/app_en.arb` (+`flutter gen-l10n`)
- Test: `test/chess_ai_test.dart`, `test/chess_screen_hotseat_test.dart`, `test/chess_screen_ai_test.dart`

**Interfaces:**
- Consumes: `GameState` (Task 2), `ChessBoard` + `kBoardThemes` (Task 3), `ChessServices` (Task 1), `ChessProfile` (Task 1), Cosmic Toybox chrome (`Ct`, `GlowButton`, `CosmicBackground`).
- Produces: `enum PlayMode { ai, hotseat }`, `abstract class ChessAI { Future<String?> chooseMove(GameState s, {int simBudget}); }`, `LegalRandomAI` (impl), `ChessScreen({required ChessServices services, required PlayMode mode})`, and `chess_gate_io.openChess` (real).

- [ ] **Step 1: Write the failing AI test**

`test/chess_ai_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starcade/core/chess/game_state.dart';
import 'package:starcade/ui/chess/chess_ai.dart';

void main() {
  test('LegalRandomAI only ever returns legal moves', () async {
    final ai = LegalRandomAI();
    final s = GameState();
    for (var ply = 0; ply < 40; ply++) {
      final move = await ai.chooseMove(s);
      expect(move, isNotNull, reason: 'a legal move must exist at ply $ply');
      final uci = s.makeMove(move!);
      expect(uci, isTrue, reason: 'AI proposed an illegal move at ply $ply');
    }
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `source tool/env.sh && flutter test test/chess_ai_test.dart`
Expected: FAIL — `chess_ai.dart` missing.

- [ ] **Step 3: Implement ChessAI + LegalRandomAI**

`lib/ui/chess/chess_ai.dart`:

```dart
import 'dart:math';

import 'package:dartchess/dartchess.dart' as dc;

import '../../core/chess/game_state.dart';

/// AI seam. The RL model (RL_game_train) plugs in behind this interface once
/// trained; until then [LegalRandomAI] keeps vs-AI playable.
abstract class ChessAI {
  Future<String?> chooseMove(GameState game, {int simBudget = 200});
}

/// Placeholder: uniformly random among legal moves. Never illegal.
class LegalRandomAI implements ChessAI {
  final Random _rng = Random();

  @override
  Future<String?> chooseMove(GameState game, {int simBudget = 200}) async {
    final legal = game.legalMoves;
    if (legal.isEmpty) return null;
    return dc.moveToUci(legal[_rng.nextInt(legal.length)]);
  }
}
```

- [ ] **Step 4: Implement the clock + move list + result dialog**

`lib/ui/chess/chess_clock.dart` — a `dart:async Timer` count-up widget per side: `ChessClock({required String side, required bool active, required Duration elapsed})` displaying `mm:ss`; the screen owns the timers. Keep it a plain widget (no package).

`lib/ui/chess/move_list.dart` — a scrollable pane rendering `pgnMoves` in pairs (`1. e4 e5 2. Nf3 …`), auto-scrolls to the end.

`lib/ui/chess/result_dialog.dart` — a dialog given the `GameStatus`, `drawReason`, and a winner string; shows headline (Checkmate / Stalemate / Draw / You won / AI won / Draw by <reason>), the move count, and **Rematch** + **New game** buttons with a ~1s activation delay (a `Timer` that enables the buttons after 1s).

- [ ] **Step 5: Implement PlayModeSheet + ChessScreen + wire the gate**

`lib/ui/chess/play_mode_sheet.dart` — a bottom sheet: **Hotseat** (enabled), **vs AI** (enabled, label notes "training model — basic opponent"), **Local multiplayer** (disabled, "next update"), **Online** (locked). Returns `PlayMode?`.

`lib/ui/chess/chess_screen.dart` — a `ConsumerStatefulWidget`:
- Builds `GameState` + a `chessground.Controller` bound to it (on `onUserMove` → `_gameState.makeMove(uci)`).
- `PlayMode.ai`: player is White; after a human move, if the game isn't over, set `isAiTurn`, start a ~400ms `Future.delayed`, run `services`-injected `ChessAI.chooseMove`, apply it.
- `PlayMode.hotseat`: both sides are human; flip `sideToMove` turns naturally; `flipBoard` from the profile applies when White is not to move.
- Layout: `CosmicBackground` → top player bar (name, `ChessClock`, captured material computed from `game`'s taken pieces) → `ChessBoard` with the profile's `kBoardThemes[themeId]` → bottom player bar → `MoveList` + control row (Undo, Hint, Draw, Resign). Undo disabled in ai mode. Draw/Resign → confirm dialog → `GameStatus.draw`/resign result. Result dialog on `isGameOver`; on Rematch re-seed `GameState`; on New game pop to the mode sheet.
- The screen injects `ChessAI` via constructor with a default of `LegalRandomAI` so tests can substitute a fake.

`lib/ui/chess/chess_gate_io.dart` — replace the stub body:

```dart
void openChess(BuildContext context) {
  showModalBottomSheet<PlayMode>(
    context: context,
    builder: (_) => const PlayModeSheet(),
  ).then((mode) {
    if (mode == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Consumer(
        builder: (_, ref, __) => ChessScreen(
          services: ref.read(servicesProvider),
          mode: mode,
        ),
      ),
    ));
  });
}
```

- [ ] **Step 6: Add chess strings to l10n**

Add to `l10n/app_en.arb`: `chessModeHotseat`, `chessModeVsAi`, `chessModeLocal`, `chessModeLocalSoon`, `chessModeOnlineLocked`, `chessNewGame`, `chessRematch`, `chessUndo`, `chessHint`, `chessDraw`, `chessResign`, `chessWhite`, `chessBlack`, `chessResultMate`, `chessResultStalemate`, `chessResultDraw`, `chessResultYouWon`, `chessResultAiWon`, `chessDrawReason`. Run `source tool/env.sh && flutter gen-l10n`.

- [ ] **Step 7: Write the failing widget tests**

`test/chess_screen_hotseat_test.dart` — play **Fool's mate** (the fastest legal checkmate, deterministic) by tapping keyed squares in a pumped `ChessScreen(mode: hotseat)` (services over `MemorySaveRepository`; `SharedPreferences.setMockInitialValues({})`). Line: `1.f3 e5 2.g4 Qh4#` → `f2f3 e7e5 g2g4 d8h4`:

```dart
testWidgets('hotseat: two humans reach checkmate and see the result dialog',
    (tester) async {
  final services = ChessServices(
    save: SaveController(repository: MemorySaveRepository())..load(),
    settings: SettingsService(await SharedPreferences.getInstance())..load(),
    audio: _stubAudio(),    // see "Note on test services" below
    haptics: _stubHaptics(),
  );
  await tester.pumpWidget(MaterialApp(
    home: ChessScreen(services: services, mode: PlayMode.hotseat),
  ));
  // 1. f3
  await tester.tap(find.byKey(const ValueKey('sq-f2')));
  await tester.tap(find.byKey(const ValueKey('sq-f3')));
  await tester.pumpAndSettle();
  // 1... e5
  await tester.tap(find.byKey(const ValueKey('sq-e7')));
  await tester.tap(find.byKey(const ValueKey('sq-e5')));
  await tester.pumpAndSettle();
  // 2. g4
  await tester.tap(find.byKey(const ValueKey('sq-g2')));
  await tester.tap(find.byKey(const ValueKey('sq-g4')));
  await tester.pumpAndSettle();
  // 2... Qh4#
  await tester.tap(find.byKey(const ValueKey('sq-d8')));
  await tester.tap(find.byKey(const ValueKey('sq-h4')));
  await tester.pumpAndSettle();
  expect(find.text('Checkmate'), findsOneWidget, reason: 'fool\'s mate must end the game');
});
```

> Fool's mate is 100% deterministic from the standard start — if the test fails, the bug is in the screen wiring, not the line. (The move list/result dialog text key is whatever `chessResultMate` resolves to; assert on that value instead of the literal if you prefer.)

`test/chess_screen_ai_test.dart` — pump `ChessScreen(mode: ai)` with a fake `ChessAI` that always returns `e2e4`'s legal reply `e7e5`; make a human `d2d4` move, `pump` the delayed AI turn, and expect the move list shows two moves and the AI move is legal.

- [ ] **Step 8: Run the widget tests, iterate the mating line until green**

Run: `source tool/env.sh && flutter test test/chess_screen_hotseat_test.dart test/chess_screen_ai_test.dart test/chess_ai_test.dart`
Expected: FAIL first (screen missing), then iterate — the hotseat test fails until the implementer lands a verified mating line; the AI test fails until `ChessScreen` schedules the AI turn. All three must pass with analyze clean.

> Note on test services: `ChessServices` needs real `AudioService`/`HapticsService` instances in tests. `AudioService` touches `FlameAudio` — install the shared `bgm`/`audioCache` stub in `setUpAll` exactly as `test/settings_audio_test.dart` does, or construct `ChessServices` with `audio: null`/a no-op in the test if the screen tolerates it. Prefer matching the existing settings_audio stub pattern; do not silence a real failure.

- [ ] **Step 9: Full verification**

Run: `source tool/env.sh && flutter analyze && flutter test && flutter build web --release`
Expected: analyze clean; all tests pass (settings_audio + the 7 new files); web build green (gate keeps chess off the web tree).

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: playable chess — hotseat + placeholder AI, Lichess-style screen

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:** Strip ✓ (Task 1) · lean launcher ✓ (Task 1) · dartchess+chessground pinned ✓ (Task 2) · GameState draw detection ✓ (Task 2) · Nebula/wood/blue themes ✓ (Task 3) · keyed board + Semantics a11y ✓ (Task 3) · Lichess-mobile screen layout ✓ (Task 4) · clock ✓ (Task 4) · undo/hint/draw/resign ✓ (Task 4) · result dialog + rematch ✓ (Task 4) · ChessAI seam + placeholder ✓ (Task 4) · web coming-soon gate ✓ (Task 1+4) · ChessProfile atomic persistence ✓ (Task 1). Explicitly **out of scope** (their own plans): RL trainer, real RLNetChessAI/MCTS + model fetch + golden fixtures, local multiplayer (TCP/QR/GameProtocol), Bluetooth, online.

**Placeholder scan:** no TBD/TODO. The only deliberate looseness is the chessground/dartchess API-field adaptation notes and the scholar's-mate line to be verified by the implementer — both flagged inline, both with the contract pinned by tests.

**Type consistency:** `ChessProfile` fields used in Task 1 match Task 3's theme lookup and Task 4's `kBoardThemes[themeId]`; `GameState.makeMove/legalMoves/pgnMoves/status/drawReason` names are identical across Tasks 2-4; `ChessServices` shape is fixed in Task 1 and consumed as-is in Tasks 3-4; `ChessBoard.onUserMove(String uci)` matches `GameState.makeMove(String uci)`. No drift.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-12-chess-shell-app-pivot.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?

**Successor plans (separate files, written on request):**
- **Plan B — RL_game_train** (trainer: az119 encoder, supervised warm-start, self-play, ONNX export + fixtures) — the GPU track; start it in parallel.
- **Plan C — App AI integration** (real RLNetChessAI + MCTS isolate + model fetch + anti-drift tests; depends on a trainer-produced net).
- **Plan D — Local multiplayer** (TCP + QR/manual pairing + GameProtocol + state_sync; online-locked seam).
