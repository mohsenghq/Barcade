# AGENTS.md — mini_games (the app)

This file tells agentic tools (Claude Code, etc.) what this repo is and how it
relates to its sibling. Read it before doing work here.

## What this repo is

**Starcade** — a Flutter game launcher. Chess is the current game; future
games plug into the same launcher seam. The app is **native-only** for chess
(Android/iOS/desktop); the web target builds but shows a coming-soon card.

## The sibling project (important)

- **RL_game_train** at `/home/mohsenghq/Documents/RL_game_train` (Python) trains
  the chess AI with supervised warm-start + async self-play RL, then exports an
  ONNX model this app runs on-device.
- **The app does NOT train, and has NO classical search fallback.** The AI
  opponent is always the trained model. During development the `ChessAI`
  interface has a legal-random placeholder so vs-AI stays usable.
- Any request to improve AI strength, change the network, or retrain = work for
  **RL_game_train**, not here. Do not reimplement chess AI logic in this repo.
- The two repos couple ONLY through the model artifact (below).

## The model contract

- **Source of truth:** `RL_game_train/docs/CHESS_AI_CONTRACT.md` (az119 network
  format v1, plane order, policy index mapping, manifest schema). This repo
  mirrors it at `docs/CHESS_AI_CONTRACT.md`.
- **Artifact:** `chess_net.onnx` (fp32, opset 17, IR 8) + `manifest.json`
  (versioning lives in the manifest, NOT ONNX metadata).
- **Delivery:** RL_game_train tags a `net-v*` GitHub Release; this repo pins the
  URL + `model_sha256` and fetches into `assets/ai/` via CI (`dart run tool/fetch_net.dart`)
  before every build. The model is embedded in all app bundles.
- **Gating:** `lib/core/chess/ai/` carries a compiled-in
  `expectedNetworkFormatVersion`; the app refuses to run (or shows an update
  banner) on mismatch.
- **Anti-drift:** golden fixtures (FEN → expected 119-plane tensor + legal moves
  + policy index map) are committed under `test/` — do not edit them without
  regenerating from the trainer. If they drift, fix the trainer first.

## Conventions inherited from the codebase

- Constructor injection for services (no service locator); the launcher is the
  only Riverpod consumer.
- Atomic JSON save layer in `lib/core/save/` — reuse it, don't invent a new
  persistence path.
- Cosmic Toybox chrome in `lib/ui/theme/`; chess board themes live in
  `lib/ui/chess/themes/board_theme.dart`.
- l10n via gen_l10n (`l10n/app_en.arb`); add strings there, run `flutter gen-l10n`.
- `dartchess` and `chessground` are pinned in `pubspec.yaml` — do not bump
  casually; they are the Lichess-mobile pair and the contract with their GPL
  license is deliberate.
- CI: `.github/workflows/build.yml` must stay green on all platforms.

## Play modes (v1)

1. vs AI (gated on the model asset; placeholder otherwise)
2. Local multiplayer over WiFi LAN (TCP + QR/manual pairing)
3. Hotseat
4. Online — locked "coming soon"; the `GameProtocol` wire format is the seam.

Bluetooth is a documented secondary transport, deliberately not in v1.
