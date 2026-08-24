# Changelog

All notable changes to **Starcade** are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/); versions follow
[SemVer](https://semver.org/).

## [Unreleased]

## [1.0.0] — 2026-08-12

First production release. An offline-first, cross-platform hub of polished
mini-games built with Flutter + Flame.

### Added

- **Central hub** — a game grid with player greeting, XP/level header, and
  coins/gems balances, all driven by one shared profile (Riverpod).
- **6 mini-games**, each with a distinct mechanic and its own meta contract:
  - Gravity Bloom — one-touch vine climbing, height-scored.
  - Combo Kitchen — chain-based combo matching.
  - Circuit Surge — endless runner, distance-scored.
  - Colony Hex — hex-grid territory capture.
  - Neon Gauntlet — timed survival against hazards.
  - Echo Beat — rhythm/beat timing.
- **Progression** — lifetime XP with a frozen level curve, coins + premium
  gems currencies, and a 7-day daily-reward calendar with streak bonuses.
- **16 achievements**, each granting gems on unlock, with in-game progress
  tracking and result-overlay celebration.
- **6 boosters** — timed (coin doubler, XP booster, slow-mo) and stock
  (extra heart, streak freeze, undo).
- **Atomic save system (D3/D4/D15)** — checksum-verified envelope, schema
  versioning with migration, corruption recovery ladder (canonical → backup →
  fresh defaults), backup + corrupt-data preservation, and a durable
  idempotency ledger for every reward.
- **Offline-first service seams** — ads, IAP, analytics, network, cloud-save,
  auth, and leaderboard as interfaces with deterministic Mock impls, so the
  game is fully playable with zero connectivity.
- **Settings** — sound, music, haptics, and reduce-motion toggles persisted
  via SharedPreferences and enforced at the service gate.
- **Audio** — procedurally generated, license-clean WAV SFX + ambient music
  loaded once at boot.
- **Localization scaffolding** — gen_l10n with an English catalog.
- **CI/CD** — GitHub Actions pipeline that verifies (analyze + 89 tests) and
  produces web, Android (APK + AAB), Linux, Windows, macOS, and iOS builds.
- **Docs** — architecture, technical decisions, environment research, and a
  Cosmic Toybox UI design system.

### Changed

- Core foundation, economy, save layer, services, UI, polish, and tests were
  all built on top of the initial research phase; see
  `docs/TECHNICAL_DECISIONS.md` for the decision trail.

### Fixed

- Save migration never silently downgrades a newer schema (throws instead),
  and the schema version's single source of truth lives in the envelope.
- Every reward grant is idempotent — a rewardId may be granted at most once,
  even across app restarts.

[1.0.0]: https://github.com/mohsenghq/starcade/releases/tag/v1.0.0
