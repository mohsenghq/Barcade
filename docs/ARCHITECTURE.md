# Architecture — Starcade

The companion to `TECHNICAL_DECISIONS.md`. Where decisions state *what* and
*why*, this document states *how* — the concrete structure, contracts, and flow
of the implementation. Status: **draft** (monetization sections pending research
completion).

---

## 1. High-level shape

```
                    ┌──────────────────────────────┐
                    │           HUB (Flutter)       │
                    │  Riverpod providers + widgets │
                    └───────┬──────────────┬────────┘
                            │ GameResult    │ events (GameEvent stream)
                            ▼              │
                    ┌──────────────┐        │
                    │ GameWidget   │◄───────┘
                    │  (Flame)     │
                    └──────┬──────┘
                           │ MiniGameServices (composition root)
                           ▼
                    ┌──────────────────────────────┐
                    │  core/ services (Flutter-agnostic) │
                    └──────────────────────────────┘
```

- **Hub** — Flutter widgets + Riverpod. Grid, profile, shop, daily rewards,
  settings, results. Never touches the game loop.
- **Games** — Flame `FlameGame`s in `GameWidget`s. Hot state lives in Flame
  components; one `GameResult` at the end crosses into the hub.
- **Core** — plain Dart services (no Flutter imports except where storage
  needs it). Save, currency, rewards, achievements, stats, audio, haptics,
  analytics. Games and hub both depend on core; core depends on nothing above it.

## 2. Directory layout

```
lib/
  main.dart                 # bootstrap, composition root assembly
  app.dart                  # MaterialApp, theming, locale, routes
  core/
    services/
      save_controller.dart      # D4: the recovery ladder, owns save/load
      save_repository.dart      # ILocalSaveRepository + File/Web impls (D12)
      player_repository.dart    # player profile aggregate
      currency_service.dart     # coins + gems, transfer rules
      reward_service.dart       # D5: rewardId idempotency
      achievement_service.dart  # conditions, grant, progress
      stats_service.dart        # per-game stats, totals
      audio_service.dart        # flame_audio wrapper, mute/volume (D8)
      haptics_service.dart      # settings-gated haptic triggers
      analytics_service.dart    # IAnalyticsService (no-op offline)
      ad_service.dart           # IAdvertisementService (no-op offline)
      iap_service.dart          # IInAppPurchaseService (no-op offline)
      settings_service.dart     # prefs: mute, haptics, locale, reduced-motion
      game_events.dart          # StreamController<GameEvent>
    model/
      player.dart, currency.dart, achievement.dart, stats.dart,
      daily_reward.dart, booster.dart, game_result.dart, unlock.dart
    economy/
      xp_curve.dart             # xpToNext(L) = round(100·L^1.4/10)·10
      rewards.dart              # reward rules, multipliers (first-win, 3-star, streak)
      daily_calendar.dart       # 7-day streak calendar
      achievements.dart         # ~16 achievement definitions
    save/
      envelope.dart             # schemaVersion/savedAt/checksum/payload
      checksum.dart             # sha256 (package:crypto)
      migration.dart            # migrate(payload, from, to)
      defaults.dart             # new-player seed state
  hub/
    providers/                  # Riverpod: player, currency, daily, settings
    screens/                    # hub_grid, game_launcher, profile, shop, daily, settings, results
    widgets/                    # animated buttons, cards, counters, celebrations
    routes.dart
  games/
    gravity_bloom/              # ← vertical slice game (first) — physics
      gravity_bloom_game.dart   # MiniGameController subclass
      gravity_bloom_descriptor.dart
      game.dart                 # widgets: GameWidget host, HUD, pause, results
      components/               # stalk, petals, physics helpers
      physics/                  # D13: spring-damper torque model (no Forge2D)
      strings.dart
    combo_kitchen/              # score/combo (match-merge)
    circuit_surge/              # procedural endless runner
    colony_hex/                 # turn-based strategy
    neon_gauntlet/              # progressive-difficulty dodge arena
    echo_beat/                  # rhythm — visual beat-line timing (D14)
assets/
  ui/          # shared hub art (gradients, glows, icons) — procedural
  audio/       # 28 procedural WAVs
  fonts/       # Nunito-Variable.ttf, Inter-Variable.ttf + OFL licenses
  games/gravity_bloom/   # per-game assets
l10n/          # app_en.arb (+ app_fa.arb later), gen_l10n output
test/
  core/        # T1 unit: save, currency, rewards idempotency, streaks, XP, migration
  games/       # T1: game logic with fakes + flame_test
  hub/         # T2 widget tests, T3 golden
  integration/ # T4 full-flow persistence (integration_test)
```

## 3. The composition root (`main.dart`)

Built once at boot, no globals, everything injected:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsService();            // shared_preferences
  final saveRepo = await SaveRepositoryFactory.create();  // File or Web (D12)
  final save = SaveController(repo: saveRepo, migrate: migrate, defaults: seed);
  await save.load();                              // recovery ladder, D4
  final events = StreamController<GameEvent>.broadcast();
  final services = MiniGameServices(
    save: save, player: PlayerRepository(save),
    currency: CurrencyService(save), rewards: RewardService(save),
    achievements: AchievementService(save), stats: StatsService(save),
    audio: AudioService(), haptics: HapticsService(settings),
    analytics: const NoopAnalytics(), ads: const NoopAds(),
    iap: const NoopIap(), gameEvents: events,
  );
  runApp(StarcadeApp(services: services));
}
```

`StarcadeApp` creates the Riverpod container with a `servicesProvider` (the
composition root) and all UI providers on top. Games never construct services —
they receive them.

## 4. Core service contracts (offline-first, online-ready)

Every service that will eventually touch the network is an **interface with an
offline implementation**, so a future online layer swaps the implementation
without touching callers (the "no rewrite" guarantee from the master brief):

| Service | Interface | Offline impl (v1) | Future online |
|---|---|---|---|
| `PlayerRepository` | `IPlayerRepository` | reads/writes save envelope | cloud profile |
| `LocalSaveRepository` | `ILocalSaveRepository` | File / Web | — |
| `CloudSaveRepository` | `ICloudSaveRepository` | **not implemented** (interface exists) | remote save |
| `RewardService` | `IRewardService` | grants + idempotency ledger (D5/D10), local | server-verified grants |
| `AdvertisementService` | `IAdvertisementService` | `MockAdvertisementService` (deterministic, `isMock`) | AdMob rewarded (SSV + UMP); AppLovin MAX upgrade |
| `PurchaseService` | `IPurchaseService` | `MockPurchaseService` (test dev-grant) | RevenueCat (`purchases_flutter`) |
| `AnalyticsService` | `IAnalyticsService` | `MockAnalyticsService` (log-to-console) | Firebase GA4 mobile; `ambilytics`/Mock desktop |
| `LeaderboardService` | `ILeaderboardService` | **not implemented** (interface exists) | online boards |
| `AuthenticationService` | `IAuthenticationService` | **not implemented** (interface exists) | sign-in |
| `NetworkService` | `INetworkService` | reports offline | connectivity |

Note: the generic **grant ledger** (D5/D10) is one service, not per-feature. Ads,
IAP, daily rewards, and achievements all route through `RewardService.grant` with
a nonce/`rewardId` key — a crash between "earned" and "persisted" never
double-pays.

Interfaces for the not-yet-implemented services live in
`core/services/interfaces/` with documentation, so the seam is real without
unused production code. The offline build never references a network SDK.

## 5. Save pipeline (D4 + D5)

- **Write** (`SaveController.saveNow()`): snapshot all aggregates → envelope
  (schemaVersion, savedAt UTC, sha256 checksum over payload, payload) →
  repo.write → previous good file becomes `.bak`.
- **Load** (`SaveController.load()`): repo.read → checksum verify → parse →
  `migrate(payload, stored.schemaVersion, current)` → hydrate services. On any
  failure: `.bak` → else defaults; corrupt file preserved as
  `save.corrupt.<ts>.json`.
- **Idempotency**: `RewardService.grant(rewardId, ...)` checks the
  `rewardLog` in the same atomic write that credits currency/XP. Re-grant =
  no-op. All reward flows (win, achievement, daily, boost) go through this one
  method.
- **Flush triggers**: game finish, achievement unlock, reward claim, settings
  change, daily rollover, `AppLifecycleState.paused/detached`.

## 6. Mini-game contract (D6)

```dart
abstract class MiniGameDescriptor {
  String get id;            // snake_case, stable — save/achievement key
  String get title;
  String get description;
  bool get isNew;
  Widget buildIcon(BuildContext);
  int get minLevel;         // unlock level (0 = immediate)
  int get minStars;         // unlock stars
}

enum GameOutcome { victory, defeat, abandoned }

class GameResult {
  final GameOutcome outcome;
  final int score;
  final Map<String, Object?> meta;   // per-game stats
}

abstract class MiniGameController extends FlameGame {
  MiniGameController(this.services, this.descriptor);
  final MiniGameServices services;
  final MiniGameDescriptor descriptor;
  void onGamePause() => pauseEngine();
  void onGameResume() => resumeEngine();
  void finish(GameResult result);    // → services.gameEvents
  void abort() => finish(GameResult(outcome: abandoned));
  void playSfx(String key);          // → services.audio (settings-aware)
  void haptic(HapticType t);         // → services.haptics (settings-aware)
}
```

**Hub flow for one session:** tap game → check unlock (level + stars) →
construct controller via `GameFactory` → `GameWidget` route → `onLoad` loads
assets + shows "tap to start" → play → `finish(result)` → hub: compute rewards
(with multipliers: first-win-of-day ×2, 3-star ×1.5, streak ≥2 +10%/day capped
+50%), `RewardService.grant`, `AchievementService.check`, `StatsService.record`,
`saveNow()` → show result screen (staged celebration) → back to grid. Unlock
progression re-evaluated; next game's assets preloaded during the transition.

## 7. Game template (shared shape every game implements)

Each game folder provides, via the hub's `GameLauncher`:

- **Tutorial**: first play = guided win (short, skippable after first clear).
- **Pause**: overlay (resume / restart / quit), `pauseEngine()`.
- **Restart**: fresh round, same seeded RNG if procedural.
- **Result screen**: outcome, score, stars (1–3), rewards breakdown with animated
  counters, "play again" / "hub".
- **Rewards**: granted once via `RewardService` (idempotent).
- **Animations / SFX / haptics**: per design system (D7/D8), settings-gated.

## 7b. Game-specific plans (critic corrections, `05-synthesis-critique.md`)

- **Gravity Bloom (physics, D13):** no Forge2D. Custom spring-damper torque
  model (`games/gravity_bloom/physics/`) — segment sway angles, restoring +
  damping + gravity torque `m·g·r·sinθ`, impact impulse from drop momentum,
  wind as slowly-varying external torque, topple when equilibrium is
  unreachable. Deterministic at fixed dt → unit-testable. Rationale + reverse
  condition in `TECHNICAL_DECISIONS.md` D13.
- **Echo Beat (rhythm, D14):** the visual beat-line is the timing reference
  (60fps Flame loop, no audio-latency problem); audio is live-composed output
  from the hit streak. Metronome tick decorative, quantized to the visual grid.
- **Circuit Surge (procedural, seeded):** the generator takes a `seed`; RNG is
  the game's single injected source (`services.rng` or a per-run seed) so tests
  and replays are deterministic. Difficulty ramps on independent axes (speed,
  gap width, biome) with named per-run goals. Level-balance table lives in the
  game folder, not scattered in code.

## 8. Performance budget

- 60 fps on the reference device (web release build, headless Chrome on this
  machine; CI `flutter build web`).
- No per-frame allocation in `update`/`render` (reuse `Vector2`/`Paint`/`Rect`).
- `Pool<T>` for hot-spawn objects (petals, particles, score labels).
- Texture atlas per game; `SpriteBatch` for static-heavy boards.
- `RepaintBoundary` around `GameWidget`; `const` widgets in hub.
- `onRemove` disposes pools, timers, stream subscriptions (no `BuildContext`
  captured in games).
- Isolates only for one-shot heavy CPU (large procedural gen / serialization),
  out of v1 unless profiling demands it.

## 9. Responsive + accessibility

- Breakpoints: `compact <600dp`, `medium 600–840`, `expanded >840` via
  `LayoutBuilder`. Hub grid 1 / 2–3 / 4–6 columns. No layout packages.
- `SafeArea` + real insets passed into games (`MediaQuery.paddingOf`).
- Reduce Motion via `MediaQuery.disableAnimationsOf` → fades only, no springs,
  no particle bursts.
- Text scaling honored (test 1.0–2.0); tabular figures on counters.
- Haptics off by default on desktop; independent SFX/music/haptics toggles.

## 10. Testing tiers (mapped to `test/`)

- **T1 unit** — `test/core/`: save round-trip, checksum corruption, migration
  vN→vN+1, recovery ladder (corrupt → bak → defaults), reward idempotency,
  XP curve, daily streak/rollover, multiplier math, achievement conditions.
  Games: `test/games/` with fake services + `flame_test`.
- **T2 widget** — `test/hub/`: grid renders, unlock gating, settings, daily
  popup, reward-claim flow, "tap game → GameWidget appears", reduced-motion,
  compact/expanded layouts.
- **T3 golden** — hub + HUD goldens on Linux (single rasterizer), checked into
  repo.
- **T4 integration** — `test/integration/`: boot → play → reward → save →
  **restart app → verify persistence**; daily-rollover + corrupt-save recovery
  on Android emulator (CI) + Linux desktop.

## 11. CI/CD (D11) — see `.github/workflows/build.yml`

verify → build-web/android/linux/windows/macos/ios as separate matrix jobs.
Native builds produce artifacts only in CI (this machine cannot build APK or
desktop, per `00-environment.md`).

---

## Critic corrections applied

All actionable findings from `05-synthesis-critique.md` are folded in here and
in TECHNICAL_DECISIONS.md (D3/D7/D10/D13/D14/D15). Summary of what changed:

- **XP curve** — formula rejected; frozen table is the source of truth (D15).
- **Physics** — custom torque model planned for Gravity Bloom, Forge2D
  documented as the reverse-condition upgrade (D13).
- **Rhythm timing** — visual beat-line is the timing reference; audio is output
  (D14).
- **Monetization** — `IAdvertisementService` + `IPurchaseService` in
  `MiniGameServices` (composition root above includes them); SSV + Play
  Integrity explicitly deferred to a backend era (D10 rule 7).
- **Analytics** — best-effort, non-blocking, Mock default (D10 rule 9).
- **Placeholders** — game folders renamed to the six designed games (§7b).
