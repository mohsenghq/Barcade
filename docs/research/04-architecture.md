# 04 — Architecture: Flutter + Flame Offline-First Mini-Game Platform

Status: researched 2026-08-11. Versions verified live against `pub.flutter-io.cn`
(pub.dev is geo-blocked from this location, see `00-environment.md`) and GitHub
tags. Flutter SDK 3.44.9 / Dart 3.12.2 is installed locally (authoritative).

## TL;DR decisions

| Concern | Decision |
|---|---|
| State management | **Riverpod 3.4.2** at the hub/widget layer; game-loop state stays in the **Flame world**; games receive services by **constructor injection** |
| Primary persistence | **drift 2.34.3** (SQLite, via `drift_flutter 0.3.1`) |
| Fallback persistence | Plain JSON snapshot in app documents dir (atomic temp+rename+checksum) — doubles as cloud-save export and corruption recovery |
| Tiny settings | `shared_preferences 2.5.5` (mute, haptics, locale, last-run date) |
| Save strategy | SQLite transactions + WAL + `schemaVersion` + `MigrationStrategy`; `integrity_check` on open; corrupt file renamed aside, restore from JSON backup, else seed defaults |
| Game engine | **flame 1.38.0**, each mini-game is a `MiniGameController extends FlameGame` |
| Animations | `flutter_animate 4.5.2` + `google_fonts 8.2.1` |
| Localization | `flutter_localizations` (SDK) + `intl 0.20.3` + ARB via `gen_l10n`, English first |
| Tests | `flutter_test` + `flame_test 2.3.0` + golden + `integration_test`, drift in-memory |
| CI/CD | GitHub Actions matrix: ubuntu/macos/windows runners per OS; unsigned desktop, signed Android AAB |

---

## 1. State management

### Recommendation: Riverpod 3.x for the hub, constructor injection for games, Flame world for game state.

**Riverpod 3.4.2** (`flutter_riverpod` 3.4.2) is the current idiomatic, testable
choice for the hub layer. Riverpod 3 is stable; `Provider` (the older package)
is superseded by it and is not a start-any-new-project choice. Bloc 9 is fine
but adds event/state ceremony that buys nothing here: the only async flows are
"play a game → get a reward → update profile", which a `Notifier` + `.future`
handles in a third of the code. Games do not benefit from Bloc at all because
their real state never lives in widgets.

Key principle — **two-layer state, split by update frequency**:

- **Layer 1 (hot path, 60fps): lives entirely inside the Flame world.** Score,
  combo, player position, bullets, particles — these are component fields inside
  the `FlameGame`, never widgets, never rebuilt. Do not push them through
  Riverpod/Bloc; doing so is the classic Flutter-game mistake and forces a
  widget rebuild every frame.
- **Layer 2 (cold path, human-speed): Riverpod Notifiers.** Coins, gems, XP,
  level, achievements, daily-streak state, save status, settings. A game pushes
  one event ("game finished with result X") at the end of a session; the hub's
  `Notifier` processes it, calls services, and the UI rebuilds a few times per
  session — not per frame.

Crossing the boundary: the game holds a reference to a `GameResultSink`
(callback/Stream) injected at construction; the hub listens and updates
providers. Optional micro-optimization: expose a `ValueListenable<int>` for a
live HUD score if a game wants an in-game score readout without a rebuild per
point — otherwise keep HUD inside the Flame game itself (`TextComponent`).

Codegen (`@riverpod`) is optional; plain providers keep the build simpler for a
first release. Providers make the hub testable in pure Dart (`ProviderContainer`
with overrides) without pumping widgets.

## 2. Local persistence

| Option | Version | Verdict |
|---|---|---|
| **drift** | **2.34.3** (+ `drift_flutter 0.3.1`) | **Primary.** Type-safe SQLite, transactions (atomic), built-in `schemaVersion` + `MigrationStrategy`, `beforeOpen` hooks, reactive `watch()` streams, in-memory DB for tests, works on Android/iOS/Windows/macOS/Linux/web. |
| plain JSON file | — | **Fallback.** One snapshot file, write-temp+rename+checksum. Perfectly safe for a single small save, but no schema tooling, no transactions, no queries. |
| shared_preferences | 2.5.5 | Settings/prefs only (mute, haptics, locale, last daily-reward check). Async, lossy for large data, no schema versioning — never a save store. |
| sqflite | 2.4.3 | Raw SQLite, but mobile-first; desktop needs `sqflite_common_ffi` glue. Drift gives the same engine with codegen on top. No reason to use directly. |
| hive / hive_ce | 2.2.3 / 2.19.3 | Fast pure-Dart KV, but box versioning is manual, no cross-box transactions, single-file boxes corrupt silently. Original hive unmaintained; hive_ce is the fork. Middle ground, not chosen. |
| isar | 3.1.0+1 | **Do not use.** Original archived; `isar-community/isar` archived 2025-08-18. Dead end. |

**Why drift wins for a save that "must never lose the player":** SQLite's
`BEGIN/COMMIT` transactions make an atomic multi-row update a single unit (a
crash mid-write rolls back); WAL journaling makes crash recovery reliable; the
`schemaVersion` + `MigrationStrategy` pair is the schema-versioning mechanism
we want; `PRAGMA integrity_check` gives corruption detection; and the reactive
`watch()` gives the hub free "save changed → UI updates" behavior.

**Fallback rationale:** a single JSON snapshot file (documents dir via
`path_provider 2.1.6`) is the cheapest belt-and-braces: it is the export format
for future cloud save, it restores progress if the DB file is ever unreadable,
and it is trivial to inspect by hand.

## 3. Save design

Three cooperating stores:

1. **drift DB** — canonical save: `players`, `currencies`, `achievements`,
   `stats`, `unlocks`, `daily` tables.
2. **JSON snapshot** (`save.bak.json`) — periodic backup + export.
3. **shared_preferences** — settings + last-run timestamp for daily streaks.

### Atomic write strategy (drift)

Every mutation that touches multiple tables runs inside a **transaction**
(`await db.transaction(() async { ... })`). Commit point is the only place the
change becomes visible; crash/kill before commit = no partial write. Enable
WAL + foreign keys in `beforeOpen`:

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async { /* per-version steps, see below */ },
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON;');
    await customStatement('PRAGMA journal_mode = WAL;');
    if (!details.wasCreated) {
      final result = await customSelect('PRAGMA quick_check').get();
      if (result.first.data.values.first.toString() != 'ok') {
        throw CorruptDatabaseException();   // caught by SaveController
      }
    }
  },
);
```

`quick_check` (faster than full `integrity_check`) on every open on a
non-created DB; full `integrity_check` is fine for a save this small — use it
if build speed is irrelevant. On throw, `SaveController` treats the file as
corrupt (see recovery below).

### Schema versioning + migration

`schemaVersion` is the source of truth; the `meta` table stores a redundant
copy (`k/v`) so recovery code can validate without a DB open. Migrations are
explicit per step; never rewrite the version without adding the step:

```dart
@override
int get schemaVersion => 3;

onUpgrade: (m, from, to) async {
  if (from < 2) await m.addColumn(player, player.xp);        // v2: added xp
  if (from < 3) { await m.createTable(achievements); /* ... */ } // v3: achievements
}
```

### Safe defaults on corruption (recovery ladder, no data loss)

`SaveController.load()` runs this ladder:

1. Open DB. If `CorruptDatabaseException` (integrity check failed) or open
   throws → **rename the corrupt file** to `save.corrupt.<timestamp>.db` (never
   delete — support/cloud-sync may recover it later), create a fresh DB.
2. If JSON snapshot exists and checksum passes → restore it into the fresh DB.
3. Else → seed the fresh DB with defaults (new-player state).
4. Write a fresh JSON snapshot immediately after successful load.

Any unrecoverable file is preserved, never silently wiped. This guarantees
"corrupt save → player starts over at worst, but their last known good state
restores in the common case."

### JSON snapshot format

```
{
  "schemaVersion": 3,                    // matches drift schemaVersion
  "savedAt": "2026-08-11T12:00:00Z",     // UTC ISO-8601
  "checksum": "<sha256 of payload hex>", // computed over payload field only
  "payload": { ...entire save as JSON... }
}
```

Write = serialize → write `save.bak.json.tmp` → `flushSync()` → `rename()` to
`save.bak.json`. Rename is atomic on POSIX and NTFS, so readers never see a
half-written file. Load = read → verify checksum → parse → on any failure treat
as missing. SHA-256 via `crypto` (pure Dart, no platform deps).

### Preventing data loss on crash/kill

- **Flush on meaningful events, not per tick:** end of game, reward claim,
  achievement unlock, settings change, daily-streak rollover. A drift write per
  event is microseconds.
- **App-lifecycle flush:** `WidgetsBindingObserver.didChangeAppLifecycleState`
  on `paused` / `inactive` / `detached` → `saveNow()` then allow the DB to
  close naturally. Also `pauseEngine()` all running games here (Flame's
  `Bgm` already pauses music on app background automatically).
- **Reward idempotency:** every reward grant carries a `rewardId`
  (`"{gameId}:{sessionId}:{rule}"`); grants are recorded in the DB inside the
  same transaction as the currency update. Replaying a "game finished" event
  after a crash must be a no-op, never double-pay. This is the single most
  important correctness rule for the economy.
- Serialize writes through one `SaveController` so two events can't interleave
  a transaction.

## 4. Modular mini-game architecture (Flame)

### Package layout

```
lib/
  app/            # main(), bootstrap, composition root
  core/           # services: player, currency, rewards, achievements,
                  #   stats, save, audio, haptics, analytics, settings
  hub/            # hub UI, navigation, providers (Riverpod)
  games/
    memory/       # one folder per mini-game, fully self-contained
    grid_move/
    ...
  l10n/           # gen_l10n output + ARB files
assets/
  ui/             # shared hub assets
  audio/          # shared SFX/music
  games/
    memory/       # each game owns its assets subfolder
```

### MiniGame interface

A game is **a `FlameGame`** (so the hub embeds it in a `GameWidget` with zero
glue) plus a descriptor and a lifecycle contract. Games import `core` services,
never `hub/`.

```dart
/// Registry descriptor — static facts the hub needs before the game exists.
abstract class MiniGameDescriptor {
  String get id;        // stable, snake_case — used in saves/achievements/stats
  String get title;
  String get description;
  bool get isNew;       // for the "NEW" badge
  Widget buildIcon();   // hub grid icon
}

/// Result pushed once when a session ends (win/lose/quit).
class GameResult {
  const GameResult({required this.outcome, this.score = 0, this.meta = const {}});
  final GameOutcome outcome;        // victory | defeat | abandoned
  final int score;
  final Map<String, Object?> meta;  // game-specific stats for the stats table
}

/// Lifecycle a Flame game must expose to the hub. Constructor takes the
/// composition-root services — no global service locator.
abstract class MiniGameController extends FlameGame {
  MiniGameController(this.services, this.descriptor);

  final MiniGameServices services;          // composition root (below)
  final MiniGameDescriptor descriptor;

  /// Called by hub when app backgrounds or user hits pause.
  void onGamePause() => pauseEngine();
  void onGameResume() => resumeEngine();

  /// End a session with a result; hub credits rewards + saves, then disposes.
  void finish(GameResult result);           // implementation pushes to services.gameEvents
  void abort() => finish(GameResult(outcome: GameOutcome.abandoned));

  /// Convenience: haptics + SFX that respect global settings.
  void playSfx(String key) => services.audio.playSfx(key);
  void haptic(HapticType t) => services.haptics.trigger(t);
}

/// Composition root — one object, built once at app boot, injected everywhere.
class MiniGameServices {
  MiniGameServices({
    required this.save, required this.player, required this.currency,
    required this.rewards, required this.achievements, required this.stats,
    required this.audio, required this.haptics, required this.analytics,
    required this.gameEvents,   // StreamController<GameEvent> hub listens to
  });
  final SaveController save;       final PlayerRepository player;
  final CurrencyService currency;  final RewardService rewards;
  final AchievementService achievements; final StatsService stats;
  final AudioService audio;        final HapticsService haptics;
  final AnalyticsService analytics; // interface; no-op impl in offline build
  final StreamController<GameEvent> gameEvents;
}
```

**Flame lifecycle mapping** (verified against Flame 1.38 docs):

| Hub action | Flame hook | Notes |
|---|---|---|
| Navigate into game | `GameWidget(game: controller)` → `onGameResize` then `onLoad` | `onLoad` loads assets, builds systems, shows "tap to start" |
| Start | game-internal (after user taps start) | not a framework hook |
| Pause (user / background) | `pauseEngine()` | stop update/render; `Bgm` auto-pauses music on app background |
| Resume | `resumeEngine()` | |
| Finish (win/lose/quit) | `finish(GameResult)` → hub credits/saves → remove `GameWidget` | removal triggers `onRemove` |
| Dispose | `onRemove()` | dispose components, audio pools, subscriptions |

### Why constructor injection, not a service locator

- Games are **plain-Dart testable**: `MemoryGame(services)` in a unit test with
  fakes — no Riverpod container, no widget pump, no global state to reset.
- Dependencies are **explicit**: a game's constructor documents what it touches.
- Riverpod still powers the hub: the composition root is *built by* providers at
  boot, then handed to games. "Providers at the edges, constructor injection in
  the middle" — the idiomatic Flutter/Firebase pattern too.
- **Decoupling:** games never import `hub/`; the hub registers them in a
  `List<MiniGameDescriptor> + Map<id, GameFactory>` registry. Adding a game =
  add one folder + one registry entry. Shared systems are untouched. If a game
  needs a new service, add it to the composition root — old games' constructors
  don't change (named optional params) and shared systems still don't change.

### Shared asset/audio management

- **Assets:** Flame keeps a global `AssetsCache`; games load through it under
  `assets/games/<id>/...`. Shared hub assets live in `assets/ui`. Preload the
  next game's bundle in the hub during the transition (see §5 loading screens).
- **Audio:** SFX/music go through the injected `AudioService`, which wraps
  `FlameAudio`: `AudioPool` for rapid/reused SFX (e.g. taps, `createPool` with
  min/max players), `FlameAudio.bgm` for music (auto-pauses on background).
  `AudioService` owns **global mute + per-channel volume**, so games can't
  bypass settings; a game simply calls `services.audio.playSfx('match')`.

## 5. Performance

Verified against Flame's own performance docs (object pooling, batching,
allocation avoidance):

- **Object pooling:** Flame's `Pool<T>` (e.g. bullets, particles, floating
  score labels). Reuse instead of allocate+destroy on a hot spawn path.
- **Zero per-frame allocation in update/render:** reuse `Vector2`, `Paint`,
  `Rect` instances; cache `TextRenderer`s; avoid `print`/string building in the
  loop. This is Flame's #1 documented perf rule.
- **Batching:** single texture atlas per game; `HasAutoBatchedChildren` groups
  same-atlas sprites into one draw call; `SpriteBatch` / `SpriteBatchComponent`
  for many static sprites (e.g. a board background with hundreds of cells).
- **Particles:** use `ParticlesComponent` with finite lifetimes and a hard cap;
  pool particles; prefer a pre-rendered glow sprite over per-particle blur or
  shadow (the expensive ops).
- **Widget rebuild minimization:** HUD values flow through `ValueListenable` /
  `ref.watch` on small notifiers; wrap `GameWidget` in `RepaintBoundary`; prefer
  `const` widgets everywhere in the hub.
- **Isolates:** only for heavy one-shot CPU work (large procedural generation,
  save serialization) via `Isolate.run`. Never run game logic in an isolate that
  talks to the game loop — no shared state. Mini-game-scale generation needs
  this rarely; keep it out of v1 unless profiling says otherwise.
- **Memory leaks:** `onRemove` must dispose audio pools, timers, stream
  subscriptions; games never capture `BuildContext`; hub clears references when
  a `GameWidget` is removed.
- **Loading screens / lazy-loading:** never construct all games at boot — build
  the controller on navigation (heavy work is in `onLoad`, not the constructor).
  Show a short animated loading state in the hub while the game's assets
  preload; preload the *next* expected game behind the scenes if cheap.

## 6. Responsive UI (phone / tablet / desktop)

- **Breakpoints:** Material 3 buckets via `LayoutBuilder` — `compact < 600dp`,
  `medium 600–840dp`, `expanded > 840dp`. Hub grid: 1 column (compact portrait),
  2–3 (compact landscape / medium), 4–6 (expanded). One `Breakpoints` helper
  returning a small enum + the resolved grid; no layout packages needed.
- **Orientation:** hub supports both. Landscape-only games either adapt or show
  a "rotate your device" gate (design games to adapt where cheap).
- **Safe areas / notches:** `SafeArea` for hub chrome; pass real insets into
  the game (`MediaQuery.paddingOf`) so `GameWidget` content avoids notches —
  don't let the game draw under a notch on phones or under nothing on desktop.
- **Text scaling:** never hardcode sizes where the OS scale matters; set
  `MaterialApp.builder` once to apply `MediaQuery.textScaler` (default),
  `colorScheme`, `disableAnimations` for reduced-motion, and test at
  `textScaler 1.0–2.0`.
- **Desktop:** window resizing re-runs `LayoutBuilder` naturally; cap the hub
  content width (e.g. 1400px) and center — a full-width wall of cards looks
  wrong on a 4K monitor. `wakelock_plus 1.7.0` to keep the screen on during
  play on mobile (opt-in setting).

## 7. Accessibility

- **Reduced motion:** gate via `MediaQuery.disableAnimationsOf(context)`
  (Flutter exposes the OS `prefers-reduced-motion`). Skip particle bursts,
  parallax, and big 300ms+ transitions when enabled; keep short fades (<150ms)
  for legibility. `flutter_animate` supports `Animate`-level disabling or you
  branch at the source of the effect.
- **Contrast:** design tokens enforce WCAG AA pairs (hub text/buttons; game HUD
  text). Verify colored text on gradients; game-specific palettes get checked in
  the design system doc.
- **Audio/haptics controls:** settings screen toggles SFX, music, haptics
  independently — persisted in shared_preferences, honored inside `AudioService`
  / `HapticsService` (games cannot bypass). Gate `HapticFeedback` on
  `HapticFeedback.isSupported`.
- **Text scaling:** covered in §6; games must tolerate scaled text in menus.

## 8. Localization

**Use the real thing, minimal scope: `flutter_localizations` (SDK) + `intl
0.20.3` + ARB via `gen_l10n`** — no extra package, no hand-rolled map. It gives
plurals, `String` interpolation, locale tooling, and one-file-per-locale.

- v1: `l10n/app_en.arb` only; `supportedLocales: [Locale('en')]`;
  `localizationsDelegates: AppLocalizations.localizationsDelegates`.
- Adding Persian (a likely second locale here) = add `app_fa.arb`, rerun
  `flutter gen-l10n`, add `Locale('fa')`. No code changes.
- Games get strings through a per-game `GameTexts` object built from
  `AppLocalizations` at the hub boundary and injected (short, gameplay-facing
  strings may stay in a `strings.dart` map in v1 — game text is the *last* thing
  to localize; hub/menus first).

Hand-rolled `Map<String, String>` maps are rejected: they break plurals and
gender, drift from the platform standard, and are the #1 excuse apps use to
never actually ship a second locale. `gen_l10n` costs ~15 lines of pubspec.

## 9. Testing strategy (tier list)

| Tier | Scope | Tooling |
|---|---|---|
| **T1 Unit** (highest ROI) | pure-Dart logic: save repository round-trip/corruption/migration/defaults, currency + reward math + **grant idempotency**, achievement conditions, daily-streak/rollover logic, XP/level math, per-game pure logic (scoring, combo, procedural gen with a **seeded RNG**). Games unit-tested with fake services. | `package:test` / `flutter_test`; drift via `NativeDatabase.memory()` + `DatabaseConnection(closeStreamsSynchronously: true)`; `flame_test 2.3.0` `FlameTester` for component logic on a real loop |
| **T2 Widget** | hub screens (game grid, settings, daily-rewards popup, reward-claim flow), "tap game → GameWidget appears", reduced-motion smoke, compact/expanded layout renders | `flutter_test` |
| **T3 Golden** | visual regression for hub + shared HUD + 1–2 key screens | `matchesGoldenFile`; store goldens in repo, generate on Linux (single stable rasterizer); update via `--update-goldens` on a dedicated PR |
| **T4 Integration** | full flow on a device: boot → play a game to completion → collect reward → **restart app → verify persistence**; also daily-rollover + corrupt-save-recovery E2E | `integration_test` (SDK) on Android emulator + Linux desktop in CI |

Must-test for save/currency/rewards, even at T1:
1. Reward grant twice (same `rewardId`) → second is a no-op, balance unchanged.
2. Corrupt DB file → recovery ladder runs, corrupt file preserved, defaults or
   backup applied.
3. Migration v1→v3 produces the same data as a fresh v3 create (and doesn't
   crash).
4. `saveNow()` under concurrent events → last-writer-wins, no interleaved
   partial transaction.
5. Crash-during-write simulation (kill a transaction mid-way / corrupt tail
   byte of the JSON) → state rolls back or recovers.

## 10. CI/CD + build matrix (GitHub Actions)

One workflow on push/PR (`fail-fast: false`), one on tag (release artifacts).

```yaml
jobs:
  test:                     # runs everywhere, cheap
    runs-on: ubuntu-latest
    steps: [checkout, flutter-action@v3, flutter test]
    # unit + widget + golden (Linux goldens are the canonical baseline)

  integration-android:      # full-flow + persistence-across-restart
    runs-on: ubuntu-latest
    steps: [checkout, flutter-action, reactivecircus/android-emulator-runner@v2
            -> flutter test integration_test -d <emulator>]

  build-android:            # ubuntu can build Android
    runs-on: ubuntu-latest
    env: { KEYSTORE_B64, KEYSTORE_PASS, ... }   # from GitHub Secrets
    steps: [checkout, flutter-action, flutter build apk --release, flutter build appbundle]
    # upload APK (debug-key for sideload) + signed AAB as artifacts

  build-ios:      runs-on: macos-latest     # flutter build ios --no-codesign (unsigned v1)
  build-macos:    runs-on: macos-latest     # flutter build macos (unsigned v1)
  build-windows:  runs-on: windows-latest   # flutter build windows (unsigned v1)
  build-linux:    runs-on: ubuntu-latest    # apt install libgtk-3-dev ninja-build clang; flutter build linux
  build-web:      runs-on: ubuntu-latest    # flutter build web --wasm → preview per PR
```

- **Signing:** Android signs with a keystore from GitHub Secrets (base64).
  iOS/macOS signing+notarization requires an Apple Dev account — ship
  `--no-codesign` builds first, add a signed lane when the account exists.
  Windows: unsigned MSIX/zip first, code-signing later. Linux: unsigned.
- **No cross-compilation:** each OS builds on its native runner (Flutter does
  not cross-compile desktop/mobile).
- **Caching:** `subosito/flutter-action` caches the Flutter SDK and pub; cache
  `.dart_tool` and `build/` per-OS with `actions/cache` keyed on `pubspec.lock`.
- **Note for this repo:** runners are *not* geo-blocked (see
  `00-environment.md`), so CI uses default pub.dev. Local machines keep using
  `tool/env.sh`. If CI ever needs the mirror, export `PUB_HOSTED_URL` +
  `FLUTTER_STORAGE_BASE_URL` as the env script does.
- Publish per-PR web preview + test report + goldens diff as artifacts; release
  artifacts attached to the tag via `softprops/action-gh-release`.

---

## Sources

- Flame docs (lifecycle, GameWidget, performance, audio): https://docs.flame-engine.org/latest/ and flame-engine/flame repo docs (performance.md, rendering/images.md, bridge_packages/flame_audio)
- Drift docs (tables, migrations, testing, drift_flutter): https://drift.simonbinder.eu/
- Versions verified live from pub.dev API via China mirror (pub.dev is geo-blocked here): `pub.flutter-io.cn/api/packages/{flame,riverpod,drift,drift_flutter,shared_preferences,sqflite,hive,hive_ce,isar,intl,path_provider,google_fonts,flutter_animate,flame_test,flutter_lints}`
- isar maintenance status: `isar-community/isar` GitHub repo (archived 2025-08-18)
- Flutter SDK 3.44.9 / Dart 3.12.2: installed locally (see `00-environment.md`)
