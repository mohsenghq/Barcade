# 🎮 Starcade

An **offline-first, cross-platform hub of polished mini-games** built with
Flutter + Flame. One shared player profile ties the whole vault together:
coins, gems, XP/levels, achievements, daily streaks, and boosters — all
**100% offline**, with clean seams for ads/IAP/analytics when you want them.

> Status: **v1.0.0** — first production release. Verified: `flutter analyze`
> clean, 89 automated tests passing, web/Android/Linux/Windows/macOS/iOS
> buildable via CI.

---

## Features

- **Central hub** — a game grid with a player header (level, XP, coin/gem
  balances) that stays in sync with every round you play.
- **6 mini-games, 6 distinct mechanics** — climb, chain, run, conquer,
  survive, and groove. See the table below.
- **Shared progression** — lifetime XP with a frozen level curve, coins
  (soft currency) + gems (premium), and a 7-day daily-reward calendar with
  streak bonuses and reset-on-gap logic.
- **16 achievements** — each grants gems once, tracks progress in-game, and
  celebrates in the result overlay.
- **6 boosters** — timed (coin doubler, XP booster, slow-mo) and stock
  (extra heart, streak freeze, undo).
- **Atomic, corruption-proof save** — checksum-verified envelope, schema
  versioning + migration, and a recovery ladder (canonical → backup → fresh
  defaults) so a torn write never costs a player their progress. Every reward
  is idempotent at-most-once.
- **Settings** — sound, music, haptics, and reduce-motion toggles persisted
  and enforced at the service layer.
- **License-clean audio** — procedurally generated WAV SFX + ambient music.
- **Localization-ready** — `gen_l10n` with an English catalog.

## The games

| Game | Mechanic | Meta |
|------|----------|------|
| **Gravity Bloom** | One-touch vine climbing | height |
| **Combo Kitchen** | Chain-based combo matching | combo |
| **Circuit Surge** | Endless runner | distance |
| **Colony Hex** | Hex-grid territory capture | territories |
| **Neon Gauntlet** | Timed survival | survival |
| **Echo Beat** | Rhythm timing | beats |

Each game emits a `GameFinished` result whose meta feeds the shared
achievement/stats layer — see `test/game_contract_test.dart`, which drives
every game headless to verify the contract holds.

## Architecture

Layered, offline-first, testable:

- **Core** (`lib/core/`) — models, economy, save system, and service seams
  (ads, IAP, analytics, network, cloud-save, auth, leaderboard) behind
  interfaces with deterministic Mock implementations.
- **UI** (`lib/ui/`) — the hub, per-game Flame screens, and the "Cosmic
  Toybox" design system (see `docs/UI_DESIGN_SYSTEM.md`).
- **App** (`lib/app/`) — Riverpod wiring that boots real services and
  composes everything.

The save is one atomic JSON aggregate (D3) behind a `SaveController` that
runs the corruption recovery ladder (D4); rewards route through a single
idempotency-gated grant path (D5).

## Documentation

| Doc | What it covers |
|-----|----------------|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System design, seams, data flow |
| [`docs/TECHNICAL_DECISIONS.md`](docs/TECHNICAL_DECISIONS.md) | Why each choice was made |
| [`docs/UI_DESIGN_SYSTEM.md`](docs/UI_DESIGN_SYSTEM.md) | Cosmic Toybox design language |
| [`docs/research/`](docs/research/) | Phase-0 research (engines, UX, monetization, architecture, critique) |
| [`CHANGELOG.md`](CHANGELOG.md) | Release history |

## Getting started

```bash
# Install Flutter 3.44+ (Dart 3.12+), then:
flutter pub get
flutter run          # pick a device (web, desktop, mobile)
```

> Packages are pinned: `flame 1.38.0`, `flame_audio 2.12.2` — Flame ships
> breaking changes, so the lockfile is part of the release contract.

## Testing

```bash
flutter analyze
flutter test         # 89 tests: unit + widget + headless game-contract
```

## Building for release

```bash
flutter build web --release
flutter build apk --release        # Android (needs the Android SDK)
flutter build linux --release      # Linux (needs ninja + libgtk-3)
flutter build macos --release      # macOS only
flutter build windows --release    # Windows only
flutter build ios --release        # iOS only (macOS)
```

A GitHub Actions pipeline (`.github/workflows/build.yml`) runs analyze + tests
and produces **all six** platform builds on push to `main` / PR — the
development machine itself has no Android SDK or mobile toolchains, so CI is
the canonical build path. See `docs/research/00-environment.md`.

## Contributing

Add a game? Every game must: live in `lib/ui/games/<id>/`, emit a
`GameFinished` whose `meta` carries the key the achievements layer reads, and
pass `test/game_contract_test.dart`. Polish pass: follow
`docs/UI_DESIGN_SYSTEM.md`.

## License

[MIT](LICENSE). All audio is procedurally generated; fonts are Nunito and
Inter (SIL Open Font License).
