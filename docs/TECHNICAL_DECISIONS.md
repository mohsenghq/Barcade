# Technical Decisions

Status: **in progress** (monetization decision pending research completion).

This document records the deliberate technical decisions for the Starcade
mini-game platform, why each was made, what was rejected, and what would make us
reverse a decision. It is the source of truth for the implementation in
`ARCHITECTURE.md`; every decision here traces to the research reports in
`docs/research/`.

| # | Decision | Status |
|---|---|---|
| D1 | Engine: Flutter 3.44 + Flame 1.38 | ✅ locked |
| D2 | State: two-layer — Riverpod 3.4.2 (hub) + Flame world (games) | ✅ locked |
| D3 | Persistence: single JSON envelope (primary), *not* drift | ✅ locked (deviation) |
| D4 | Save integrity: atomic write + SHA-256 checksum + .bak + recovery ladder | ✅ locked |
| D5 | Reward idempotency via `rewardId`, recorded in the same write | ✅ locked |
| D6 | Mini-game architecture: `MiniGameController extends FlameGame` + constructor-injected services | ✅ locked |
| D7 | UI: "Cosmic Toybox" design system, vendored Nunito + Inter, flutter_animate | ✅ locked |
| D8 | Audio: procedural WAVs + flame_audio; all license-clean | ✅ locked |
| D9 | l10n: gen_l10n + ARB, English first, Persian second | ✅ locked |
| D10 | Monetization: rewarded ads + IAP + analytics behind interfaces; AdMob + RevenueCat production impls; Mock default | ✅ locked |
| D11 | CI/CD: GitHub Actions matrix (verify, web, android, linux, windows, macos, ios); pin Flutter 3.44.x | ✅ locked |
| D12 | Save store backend: dart:io file (native) + localStorage (web) via one interface | ✅ locked |
| D13 | Gravity Bloom physics: **custom spring-damper torque model**, *not* Forge2D | ✅ locked (deviation) |
| D14 | Echo Beat timing: **visual beat-line is the timing reference**; audio is live-composed output, not the sync source | ✅ locked |
| D15 | XP curve: **frozen table** as sole source of truth (formula rejected — critic §5) | ✅ locked (deviation) |

---

## D1 — Engine: Flutter 3.44.9 + Flame 1.38.0

**Decision.** Build the platform in Flutter, with every mini-game as a Flame
`FlameGame` embedded in the widget tree via `GameWidget`. Flutter widgets are
the *entire* UI layer; Flame is only the game runtime.

**Why.** The product's soul is the hub + UI shell: animated buttons, transitions,
particles, reward counters, a coherent design system. `docs/research/01-engine-comparison.md`
scores Flutter as the strongest candidate on exactly that axis (5/5 UI system,
best-in-class widget + golden UI-regression testing), plus native builds for all
six targets and 100% offline-first by construction. Flame adds the game loop,
components, effects/tweens, particles, and audio that Flutter lacks, and lives
*inside* Flutter (`GameWidget`), so a mini-game is just another route. The
open-source `flame-games` hub (18 mini-games in one Flutter app) is a working
precedent for exactly this shape.

**Rejected.**

| Candidate | Why rejected |
|---|---|
| Godot 4 | Excellent 2D engine, but Control-node theming needs far more hand-work to reach commercial mobile-game UI polish, and it has no golden/pixel UI-regression story comparable to Flutter. Falls to 2nd place. |
| Unity 6 | Closed-source seat licensing, required CI license activation, 2023 runtime-fee trust damage, uGUI/UI Toolkit split. Overkill for a UI-heavy casual product. |
| Unreal 5.8 | Not a 2D engine (Paper2D bolt-on); 400MB+ mobile builds, worst power draw. |
| Phaser 4 | Web-only; native feel, haptics, offline save, and store-grade ads/IAP all second-class through the wrapper tax. |

**Risks accepted.** Flame is community-maintained and still ships breaking
changes — **pin the exact versions** (`flame: 1.38.0`, `flame_audio: 2.12.2`).
Flutter team layoffs (2024) are a longevity caveat but Flutter remains the
largest cross-platform UI ecosystem.

**Reverse if.** Flame's physics/game-loop needs outgrow what it provides for a
specific game; then that game breaks out to a native side-channel or we revisit
Godot. Not expected in v1.

---

## D2 — State: two layers, split by update frequency

**Decision.** Two-layer state:

1. **Hot path (60 fps) — lives entirely inside the Flame world.** Score, combo,
   player position, particles are component fields on the `FlameGame`. Never
   pushed through Riverpod; never causes widget rebuilds per frame.
2. **Cold path (human-speed) — Riverpod 3.4.2 Notifiers.** Coins, gems, XP,
   level, achievements, daily-streak, save status, settings. A game pushes one
   `GameResult` at session end; the hub's notifier processes it, calls services,
   and the UI rebuilds a few times per session.

**Crossing the boundary.** The game receives a `GameResultSink` (callback) at
construction; the hub listens and updates providers. Optional `ValueListenable`
for a live HUD score readout if a game wants one without per-frame rebuilds.

**Why Riverpod 3.4.2 (not Bloc, not provider).** Riverpod 3 is the current
idiomatic choice with `Notifier` + `.future` handling the only real async flow
(play → reward → update profile) in a third of Bloc's code. Bloc's
event/state ceremony buys nothing here. Plain providers (no `@riverpod`
codegen) keep the build simple. Games don't use Riverpod at all — their real
state never lives in widgets.

**Tests.** Hub providers are testable in pure Dart via `ProviderContainer` with
overrides — no widget pump required for logic.

---

## D3 — Persistence: single JSON envelope (primary) — *deviation from research*

**Decision.** The canonical save is **one JSON envelope**, written atomically to
a `LocalSaveRepository`. **We deliberately do not use drift/SQLite**, despite
the architecture research report (`04-architecture.md`) recommending it.

**The envelope:**

```json
{
  "schemaVersion": 1,
  "savedAt": "2026-08-11T12:00:00Z",
  "checksum": "<sha256 of payload hex>",
  "payload": { "player": {...}, "currencies": {...}, "achievements": [...], "stats": {...}, "unlocks": [...], "daily": {...} }
}
```

**Why we deviate.** The research report's own words: *"plain JSON file — perfectly
safe for a single small save."* This save **is** one small object — a single
player profile, not a relational dataset. The requirements it lists that drift
satisfies — atomic writes, schema versioning, corruption detection, migration —
all have a simpler equivalent in a single-file envelope:

| Requirement | drift | Our JSON envelope |
|---|---|---|
| Atomic write | SQLite transaction | write `save.tmp` → `flushSync()` → rename (atomic on POSIX/NTFS) |
| Corruption detection | `PRAGMA quick_check` | SHA-256 checksum over `payload` |
| Schema versioning | `schemaVersion` + `MigrationStrategy` | `schemaVersion` field + `migrate()` switch |
| Crash recovery | WAL journal | temp+rename; `.bak` from previous good save |
| Cloud-save export | *must serialize DB → JSON anyway* | **the JSON is already the export format** |

The decisive point: the research report *itself* uses a JSON snapshot as the
cloud-sync/backup/export format. With drift, the JSON export layer is still
required — so we keep the DB and a parallel serializer that must be kept in
sync. With JSON-as-primary there is **one format, one write path, one migration
story** — the save, its backup, its cloud export, and its test fixtures are all
the same thing. Fewer concepts, fewer failure modes, provably atomic for a
single-writer single-file save.

**Costs we accept.** No relational queries (not needed — the hub re-reads the
profile on events), no `watch()` streams (Riverpod re-reads on events instead),
no in-memory SQLite for tests (the repo interface takes an in-memory
implementation instead).

**Reverse if.** The save grows relational (per-game high-score tables, per-level
statistics with queries) or gains a second concurrent writer. Then the
`ILocalSaveRepository` interface we build now makes swapping in drift a
drop-in — this is the "no rewrite" guarantee.

---

## D4 — Save integrity: atomic write + checksum + .bak + recovery ladder

**Decision.** `SaveController` owns all save/load. The write path is:

1. Build payload from current state.
2. Write `save.json.tmp`, `flushSync()`, rename to `save.json` (atomic).
3. Copy previous good `save.json` to `save.bak.json` before overwriting.
4. SHA-256 checksum over payload stored in envelope; verified on load.

The load path is a **recovery ladder** (never silent data loss):

1. Read envelope; verify checksum.
2. Checksum fails or file unreadable → **rename to `save.corrupt.<ts>.json`**
   (never delete — support/cloud recovery may need it), try `.bak`.
3. `.bak` good → restore it, mark save as "recovered" (a notification to the
   player, not silent).
4. No good backup → seed fresh defaults (new-player state), write immediately.
5. On success, write a fresh `.bak` so the last good state is always one write away.

**Backends (D12).** `ILocalSaveRepository` interface with two implementations:
`FileSaveRepository` (dart:io, app documents dir via `path_provider`) for
Android/iOS/Linux/macOS/Windows, and `WebSaveRepository` (localStorage via
`shared_preferences`) for web. The web path has no rename atomicity, so it does
checksum-then-swap with a parity copy under a second key.

**Flush cadence.** On meaningful events only (game end, reward claim,
achievement unlock, settings change, daily rollover) plus
`didChangeAppLifecycleState` (paused/detached). Not per tick.

---

## D5 — Reward idempotency (the economy's #1 correctness rule)

**Decision.** Every reward grant carries a `rewardId = "{gameId}:{sessionId}:{rule}"`.
Grants are recorded in the save inside the **same write** as the currency/XP
change. Replaying a "game finished" event after a crash — or double-tapping a
claim button — is a no-op because the `rewardId` is already in the log.

**Why.** The worst economy bug is double-pay. A crash between "grant coin" and
"mark granted" must never exist. Because the save is one atomic JSON write,
currency-update + grant-record land together or not at all.

---

## D6 — Mini-game architecture: `MiniGameController extends FlameGame`

**Decision.** Each mini-game is one self-contained folder in `lib/games/`:

- `MiniGameController extends FlameGame` — the game. Constructor takes
  `MiniGameServices` (composition root) + `MiniGameDescriptor`. No service
  locator, no globals.
- `MiniGameDescriptor` — registry facts (id, title, icon, isNew).
- `GameResult` — `{outcome, score, meta}` pushed once per session end.
- Games import `core/`, never `hub/`. Adding a game = one folder + one registry
  entry; shared systems untouched.

`MiniGameServices` is one object built at boot (composition root) and injected
everywhere: save, player, currency, rewards, achievements, stats, audio,
haptics, analytics, plus a `gameEvents` stream the hub listens to.

**Why constructor injection.** Games become plain-Dart testable with fakes (no
Riverpod container, no widget pump), dependencies are explicit, and Riverpod
stays at the edges. The hub registers games in a `List<MiniGameDescriptor>` +
`Map<id, GameFactory>`.

**Pause/lifecycle mapping (Flame 1.38).** Navigate-in → `GameWidget` →
`onLoad` (assets, systems, "tap to start"); pause → `pauseEngine()`; resume →
`resumeEngine()`; finish → `finish(GameResult)` → hub credits + saves → remove
`GameWidget` → `onRemove()` disposes pools/subscriptions.

---

## D7 — UI: "Cosmic Toybox" design system

**Decision.** One constant visual frame around variable game worlds
(`docs/research/02-ux-game-design.md` §2.1):

- **Palette:** deep indigo base `#1B1533→#241A45`; action coral `#FF5A5F`;
  cyan `#29E0E0`; reward gold `#FFC53D`; success mint `#3DDC97`; danger ember
  `#FF4D6D`. Per-game candy accent pairs for in-game elements only — chrome stays
  constant.
- **Type:** Nunito (display, extra-bold, tabular figures for all counters) +
  Inter (body). **Vendored** as static assets — `google_fonts` fetches at
  runtime from `fonts.gstatic.com`, which is geo-blocked here and violates
  offline-first. Both fonts are SIL OFL 1.1 licensed, downloaded from the
  `google/fonts` GitHub repo; licenses bundled in `assets/fonts/`.
- **Shape:** pill buttons, 24–32px card radius, full-round chips; slightly
  sharper + higher-contrast for in-game HUD.
- **Motion:** overshoot springs (easeOutBack 200–300ms), squash-stretch press
  (0.92 scale / 60ms), staged celebrations (freeze → particles → counter tick →
  reveal, 500–700ms), incoming-screen-only transitions (200ms fade+scale),
  60fps, **honor system Reduce Motion** (fades only), no motion on currency
  *spending*.
- **Audio/haptics:** one soft-synth pluck instrument family across all SFX;
  haptics scaled to reward size; both gated by settings, off by default on
  desktop.

---

## D8 — Audio: procedural, license-clean

**Decision.** All SFX + music are procedurally synthesized (`tools/generate_audio.py`,
numpy, deterministic seed `20260811`) into 28 WAVs in `assets/audio/`. Nothing
sampled or copied → zero licensing risk. Playback via `flame_audio 2.12.2`
(`AudioPool` for rapid SFX, `FlameAudio.bgm` for music, auto-pause on app
background). `AudioService` owns global mute + per-channel volume so games
cannot bypass settings.

---

## D9 — Localization

**Decision.** `flutter_localizations` (SDK) + `intl 0.20.3` + ARB via `gen_l10n`.
v1 ships `app_en.arb`; Persian (`app_fa.arb`) is added by dropping in one file
+ adding `Locale('fa')` — no code changes. Hand-rolled string maps are rejected
(no plurals, no tooling). Game-internal strings may stay in a per-game
`strings.dart` for v1; hub/menus are localized first.

---

## D10 — Monetization: rewarded ads + IAP + analytics, behind interfaces

**Decision** (`docs/research/03-monetization.md`). Three narrow interfaces —
`IAdvertisementService`, `IPurchaseService`, `IAnalyticsService` — each with a
**`Mock*` implementation that is the default build** (offline/dev/desktop).
Production implementations are opt-in plugins wired at the composition root;
gameplay never calls a network SDK and never depends on monetization.

| Concern | v1 (offline default) | Production impl (later, drop-in) |
|---|---|---|
| Rewarded ads | `MockAdvertisementService` (deterministic "ad complete" after a delay; `isMock=true`) | `AdMobAdvertisementService` (`google_mobile_ads` v9.x, UMP consent in-plugin, SSV); `AppLovinMaxAdvertisementService` as the higher-eCPM upgrade path |
| IAP | `MockPurchaseService` (test-only dev grant) | `RevenueCatPurchaseService` (`purchases_flutter`) — absorbs Play Billing v8/v9 + StoreKit churn, local entitlement cache, restore |
| Analytics | `MockAnalyticsService` (log-to-console) | Firebase GA4 on mobile (queues offline events); Mock/`ambilytics` on Windows/Linux desktop |

**Why this provider set.** The 2026 rewarded-ads landscape consolidated: Unity
killed ironSource direct demand (Apr 2026), Vungle no longer exists (folded into
Liftoff, IPO Jun 2026), Meta's iOS inventory collapsed post-ATT. That leaves
**AdMob** (best-maintained first-party Flutter plugin, built-in mediation) and
**AppLovin MAX** (highest gaming rewarded eCPMs, but carries an ad-fraud/SEC
short-report risk). Unity LevelPlay is mid-restructuring — not for a fresh app.
IAP: RevenueCat is the recommended default because Play Billing v8 is mandatory
and v9 is in prep; it also makes the Play "user-choice billing" (fee changes
Jun 30, 2026) and iOS StoreKit 2 work ours by default. Google's expanded billing
rules and both stores' account-deletion policies are sidestepped by shipping
**no accounts in v1** — offline-first means no account model, hence no in-app +
web deletion requirement until the online layer exists.

**Correctness rules (non-negotiable):**

1. **Availability is a query, not a crash.** `isRewardedAvailable` returns
   `false` when offline / SDK not init / no consent / load failed / Mock. The
   in-game reward button hides or shows a "no ads — come back online" tooltip.
   Gameplay and progression **never call into the ad SDK.**
2. **Preload, don't block.** Preload one rewarded ad after start when online +
   consent; exponential backoff + jitter, cap ~5 retries, then unavailable.
   Never await init/load/consent on any game path.
3. **Grant only after verified completion.** AdMob grants in
   `onUserEarnedReward` **only** (never on `show()`).
4. **Idempotent claims everywhere.** Before showing an ad, write a claim record
   `{claimId nonce, placement, state: pending}` to the save; grant once, flip to
   `claimed`; reconcile `pending` records on startup. Purchases key grants on the
   store `orderId`/purchase token. This is the **same grant-ledger pattern as
   D5** — one generic ledger service, reused by ads, IAP, daily rewards, and
   achievements. A crash between "reward earned" and "grant persisted" never
   double-pays.
5. **Consent must not block the game.** UMP consent update at startup; whatever
   the outcome, the game runs. No consent → no personalized ads (and no rewarded
   ads until consent or a consent-walled mode). Firebase Analytics gated on the
   same outcome; ATT requested on iOS before any ad-tracking identifiers.
6. **No forced ads, no stacking.** No rewarded ad required for progress, no
   auto-play interstitials during gameplay, no ad on result screens within the
   cooldown window. Rewarded is the only format in v1.
7. **v1 anti-fraud ceiling (corrected from research).** The offline-first design
   has **no backend**, so two research recommendations — AdMob **SSV** (a
   postback to your server) and **Play Integrity** attestation (needs Play
   services + network) — are **deferred**. v1 ceiling (critic §4b): rewarded-ads
   grant on client `onUserEarnedReward` + the idempotency ledger; purchases
   validated by **RevenueCat's hosted backend** (legitimate server-side
   validation without owning a server). Locally-forged free currencies are an
   accepted ceiling (critic agrees). SSV + Play Integrity arrive only with a
   backend (the future-online layer). Obfuscate builds (`--obfuscate
   --split-debug-info`, R8) as a deterrent, never as the protection.
8. **Mock is fully testable.** The whole reward pipeline (claim → complete →
   grant → ledger) is testable with `MockAdvertisementService` and zero network.
9. **Analytics is best-effort, non-blocking.** In the target region the Google
   hosts are geo-blocked (00-environment.md), so GA4's queued events may never
   flush in production — that is *policy*, not a bug. `MockAnalyticsService` is
   the v1 build everywhere; GA4 (mobile) wires in behind the interface when a
   region-reachable analytics endpoint is chosen. A "0 events sent" week must
   never be treated as a defect.

**Event taxonomy (analytics, v1):** `game_start`, `game_end{game,score,result}`,
`level_up{level}`, `reward_claimed{placement,source}`, `ad_reward_earned`,
`ad_offered`, `purchase_started/completed{product}`, `session_start/end`,
`save_failed`. Keep it small.

---

## D11 — CI/CD

**Decision.** GitHub Actions (`tool/.github/workflows/build.yml`) — single
workflow, matrix runners: verify (analyze + test on ubuntu), build-web,
build-android (APK + AAB, temurin JDK 21), build-linux, build-windows,
build-macos, build-ios (`--no-codesign`). Runners are not geo-blocked so CI uses
default pub.dev; local machines use `tool/env.sh` mirrors. No build is claimed
that wasn't produced (see `00-environment.md` honest matrix).

---

## D12 — Save store backend

Covered under D4: one `ILocalSaveRepository` interface, two implementations.
Rationale: web has no `dart:io`, so a shared-preferences/localStorage backend
is required there; native gets the atomic file path. The interface is the seam.

---

## D13 — Gravity Bloom physics: custom spring-damper torque model (deviation)

**Decision.** Gravity Bloom's "wobbly flower-tower" is simulated with a small,
self-contained physics model — **not** Forge2D/Box2D. The architecture research
report (04) never planned a physics engine, and the critic (05 §3a, §6 risk 1)
flagged that as the top vertical-slice risk. We close it deliberately:

- The stalk is a chain of segments; each carries accumulated petal mass. The
  system state is a stack of **sway angles** per segment. Each segment has a
  **restoring torque** (spring toward vertical, Hooke), **damping**, and a
  **gravity torque** `m·g·r·sin(θ)` from the mass above its pivot.
- A segment **topples** when its angle exceeds a tipping threshold or when the
  combined restoring torque can no longer balance the load above.
- Petals are dropped with a small horizontal offset + drop momentum that inject
  torque on impact (impact impulse scales with drop height).
- Wind gusts add a slowly-varying external torque, ramping with difficulty.

**Why not Forge2D.** (1) Full rigid-body stacks are notoriously fiddly to
tune (jitter, contact thresholds) and the game wants a *specific* wobbly feel,
not generic physics. (2) `flame_forge2d` is a wrapper on Flame with its own
breaking-change cadence (Flame 1.38 is itself breaking) — version-pinning risk
for one game's mechanic. (3) A custom spring-damper torque model is ~100 lines,
deterministic (unit-testable with a fixed dt), and gives us exact control of the
"bloom" feel. This is a deliberate small-engine-for-one-game trade.

**What physics we still demonstrate:** rigid-ish body stack (mass/center of
mass), torque equilibrium, damping, spring restoring force, impulse response,
and a stability/topple condition — the master brief's "physics" requirement is
satisfied by a real simulation, just a purpose-built one.

**Reverse if.** A later game genuinely needs contacts/collisions/constraints
(e.g. a marble or jenga game) → adopt `flame_forge2d` pinned against the Flame
version then, with Forge2D integration planned at that game's start, not retro.

---

## D14 — Echo Beat timing: visual beat-line is the source of truth

**Decision.** Echo Beat's core mechanic is timing accuracy, but the audio stack
(`flame_audio`/`audioplayers`) has platform-variable playback latency — the
critic (05 §3b, §6 risk 2) correctly flagged that wall-clock-based timing against
latent audio makes a rhythm game unfinishable by design. Resolution:

- The **visual beat-line** (a note scrolling toward a target line on a 60fps
  Flame loop) is the timing reference. Hit windows are measured against the
  **visual** position, which has no audio-latency problem.
- Audio is **live-composed output**, not the sync source: each hit adds a note
  to the evolving track (the "your streak composes the soundtrack" hook). The
  music reflects the player's hits rather than demanding them. Playback latency
  shifts the *music*, never the *target line*.
- A metronome tick is decorative and quantized to the visual grid, so a
  100–300ms latency shift cannot move the hit window.

**Reverse if.** A future game needs true audio-synced charting → add an
audio-position timing source (the audio engine must expose reliable position +
latency calibration) at that game's design, with device profiling first.

---

## D15 — XP curve: frozen table (deviation)

**Decision.** The XP curve's **source of truth is the published table** from the
UX report (levels 1–30), linearly interpolated between anchors and
extrapolated past 30. The report's `round(100·L^1.4/10)·10` **formula is
rejected**: critic §5 verified by arithmetic that it diverges from the table by
~5–6× at mid levels (L=2 → formula 260 vs table 140). Since levels drive the
unlock tree (D6 games), gem grants (every 5th level), and achievement
conditions, an inconsistent curve would silently drift all of them. Frozen now,
before any save exists, so no migration is needed. `xp_curve.dart` implements
the table; unit tests pin every anchor.

---

## Sources

- `docs/research/01-engine-comparison.md` — engine matrix + verdict.
- `docs/research/02-ux-game-design.md` — design system, economy, games.
- `docs/research/04-architecture.md` — architecture research (deviated on D3,
  reasons above).
- `docs/research/00-environment.md` — build feasibility + mirrors.
- `docs/research/05-synthesis-critique.md` — adversarial review; D3/D7/D10/D13/
  D14/D15 fold in its corrections (XP table, physics plan, rhythm timing,
  monetization ceiling, version pinning).
