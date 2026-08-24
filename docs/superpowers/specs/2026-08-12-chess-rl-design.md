# Chess v1 + RL Trainer — Design

**Date:** 2026-08-12
**Status:** Approved
**App version bump:** 2.0.0 (product-breaking pivot: arcade mini-games removed, chess added)

## Summary

The app pivots from a 6-game arcade platform to a chess-first game launcher. All
arcade games, the economy, and the Flame game-host layer are removed. Chess v1
ships: play-vs-AI (an RL self-play model trained in a sibling project), local
multiplayer over WiFi LAN (Bluetooth deferred), and an online mode that is
present but locked behind a transport-agnostic protocol seam.

Two repositories, coupled by one artifact (a versioned ONNX model + manifest):

- **mini_games** (this repo, Flutter) — the game app. Consumes the model.
- **RL_game_train** (`/home/mohsenghq/Documents/RL_game_train`, Python) — trains
  the chess AI with supervised warm-start + async self-play RL on the dev's GPU,
  exports the model, and is the source of truth for the model contract.

## Locked decisions

| Decision | Choice |
|---|---|
| Game stack | Lichess GPL pair: `dartchess`0.13.1 + `chessground`10.1.1 (pinned) |
| App chrome license | MIT (only the two chess libs are GPL-3.0) |
| AI | RL-only. Trained+tested in `RL_game_train`, model ships with the app. No classical fallback engine, no in-app training |
| Local multiplayer | WiFi LAN TCP first; Bluetooth documented secondary transport (iOS cannot advertise a custom service UUID) |
| Online | Locked "coming soon"; protocol seam so a server relay slots in with zero rewrite |
| Web | Chess is native-only v1 (dartchess has no web support); web target still builds, shows a coming-soon card |
| GPU | 1080 Ti (Pascal sm_61): pin `torch==2.13.0+cu126`, verify `torch.cuda.get_arch_list()` |
| v1 AI strength | ~1800-2200 (solid club). Difficulty = MCTS sim budget, not net size |

## Strip (what is deleted)

- `lib/ui/games/**` — 6 games, `flame_game_host`, `catalog`, `game_screen`, `reward_flow`
- `lib/core/economy/**` — achievements, daily calendar, rewards, unlock tree, XP curve
- `lib/core/model/**` — player_profile, stats, currency, booster, daily_reward, achievement, game_result
- Most of `lib/core/services/**` — achievement, currency, reward, stats, game_events, player_repository, monetization (analytics/ads/iap)
- Deps: `flame`, `flame_audio`, `flame_test` (dev). `flutter_animate` kept for chrome animations.
- l10n content rewritten for chess (keep the gen_l10n pipeline).

## What survives (adapted)

- `lib/core/save/**` — atomic JSON + corruption protection, reused for settings + chess stats
- `settings_service`, `audio_service`, `haptics_service`
- Cosmic Toybox chrome (`lib/ui/theme/**`)
- CI (`.github/workflows/build.yml`) — stays green across all platforms

The hub becomes a **lean launcher**: one Chess card + empty "coming soon" slots,
the seam for future games (user will dictate games later; every future game gets
its own RL-trained AI via the same trainer→app contract).

## App architecture (post-strip)

```
lib/
  main.dart
  app/                      # starcade_app (renamed), bootstrap, providers
  core/
    save/                   # keep (save_controller, save_repository, checksum, envelope, migration)
    services/               # keep settings/audio/haptics
    chess/
      protocol/             # GameProtocol (transport-agnostic JSON) + TCP framer
      ai/                   # ChessAI interface, RLNetChessAI, MCTS engine, model manifest gate
      game_state.dart       # dartchess wrapper: repetition/50-75 draw detection, PGN, result resolution
  ui/
    launcher/               # lean hub: chess card + coming-soon slots
    chess/                  # chess_screen, board chrome, player bars, clock, move list, controls, result dialog
      themes/               # board_theme.dart: Nebula (default) + wood + blue
    theme/                  # cosmic_toybox chrome (keep)
```

## Chess game layer (native)

- **Rules:** `dartchess`0.13.1 pinned. **Board:** `chessground`10.1.1 pinned.
- **`GameState`** wraps dartchess and adds what it does NOT auto-detect: 3/5-fold
  repetition + 50/75-move auto-draw (silent-correctness trap), FEN/PGN move list,
  result resolution (checkmate / stalemate / resignation / draw agreement /
  timer / repetition / 50-move).
- **Board themes:** Nebula default (light `#2E2454`, dark `#191238`, cyan
  last-move, gold selected, coral check) + classic wood (`#f0d9b6`/`#b58863`) +
  blue (`#dee3e6`/`#8ca2ad`). Piece sets: cburnett default, merida + letter.
- **Screen:** Lichess-mobile layout — top player bar (name/clock/captured
  material) → 1:1 board with coordinates → bottom player bar → move-list pane +
  controls (undo/hint/draw/resign). Result dialog with the `GameStatus` reason +
  Rematch/New Game (~1s button-activation delay). Chess clock = `dart:async`
  timers, no package. Board wrapped in a **Semantics live region** announcing SAN
  moves (chessground has no built-in accessibility).

## AI — RL-only

- **`ChessAI` interface:** `Future<ChessMove?> chooseMove(Position, {int simBudget})`.
  Impls: `RLNetChessAI` (shipped) + a legal-random **placeholder** so vs-AI stays
  usable in dev until the model asset lands.
- **`RLNetChessAI`:** `flutter_onnxruntime` (masicai fork)1.8.3 pinned, loads the
  int8/fp16 `.onnx` from assets; MCTS in a dedicated Dart isolate, batched
  forwards (32-64), transposition table + NN cache; sim budget = difficulty slider
  (~100-400 sims/move → 0.5-2s responses).
- **Model gating:** compiled-in `expectedNetworkFormatVersion` vs the manifest's —
  refuse-to-run or update-banner on mismatch.

## Multiplayer — WiFi first, online locked

- **v1 transport:** LAN TCP (`dart:io` ServerSocket). Host binds an ephemeral
  port; guest joins via QR (`network_info_plus` + `qr_flutter` + `mobile_scanner`)
  or manual IP. bonsoir mDNS "nearby games" list = optional convenience, never the
  only path.
- **`GameProtocol`:** pure-Dart JSON messages, **no dart:io imports** —
  `hello`/`protocol-version`, `join`, `match_start`, `move` (UCI), `draw`,
  `resign`, `rematch`, `state_sync`, `ping`/`bye`.4-byte length-prefix framing on
  TCP; the **identical JSON over WebSocket later** — a future relay forwards
  messages verbatim and only adds `hello`/auth. Both peers run the same rules
  engine and validate every incoming move; divergence → reject-and-resync via
  `state_sync` (session id + FEN + PGN + clocks). Host is the tiebreaker for
  draw/rematch/clock.
- **Online:** locked "coming soon" button; seam already in place. Future online
  handshake must carry `network_format_version` + `model_sha256` so both peers
  validate the same net encoding.

Play modes in v1: vs AI · local multiplayer (WiFi) · **hotseat** (two players on
one device — free with the board + GameState, no AI/network involved) · online
locked.

## Model contract (trainer → app)

- **Network format v1 = `az119`:** 119-plane input (arXiv:1712.01815),8-step
  history, side-to-move flip for Black; policy head 8×8×73 = 4672 (56 queen + 8
  knight + 9 underpromotions), illegal moves masked at MCTS time; value scalar
  tanh[-1,1]. *Not* LC0's 112-plane format (GPLv3 contamination).
- **Artifact:** `chess_net.onnx` (fp32, opset 17, IR 8, plain
  Conv/BN/ReLU/Add/MatMul/Softmax ops — safe for the app's bundled ONNX Runtime)
  + sidecar `manifest.json` with `schema_version`, `network_format_version`,
  `input_shape [1,119,8,8]`, `policy_shape [1,8,8,73]`, `value_shape [1,1]`,
  `history`, `opset`, `onnx_version`, `torch_version`, `trainer_git_sha`,
  `model_sha256`. Versioning lives in the manifest — flutter_onnxruntime cannot
  read ONNX metadata on iOS/web.
- **Delivery:** trainer tags a `net-v*` GitHub Release (onnx + manifest); game
  repo pins URL + sha256, fetches into gitignored `assets/ai/` via a CI step +
  `dart run tool/fetch_net.dart`.
- **Anti-drift:** trainer emits golden fixtures (FEN → expected 119-plane tensor +
  legal moves + policy index map), committed to the game repo; Dart tests assert
  byte-identical tensors + one run-the-real-net test asserting the argmax is a
  legal move.

## RL_game_train (sibling project)

```
RL_game_train/
  AGENTS.md                     # sibling-project linkage
  README.md
  docs/CHESS_AI_CONTRACT.md     # source of truth for the az119 contract
  src/
    net/       # residual CNN, az119 encoder, policy head
    selfplay/  # MCTS/PUCT, worker processes, game generation
    train/     # supervised warm-start + async self-play fine-tuning, eval gate, ring-of-nets, KLD
    export/    # export_onnx.py, manifest.py, quantize.py (int8 QDQ/S8S8)
    data/      # PGN loaders, golden-fixture emitter
    eval/      # strength eval vs fixed opponents / Stockfish (python-chess)
  pyproject.toml / requirements.txt   # torch==2.13.0+cu126, python-chess
  tests/
  config/                            # yaml experiment configs
```

- **Training schedule:** (1) supervised warm-start on public PGNs → mobile CNN
  (8-20 residual blocks × 128-256 filters, ~2-15M params) → ~1800-2400 in
  days-weeks on the 1080 Ti; (2) async self-play fine-tuning with eval gate +
  promotion, ring-of-recent-nets + KLD regularization → solid club ~1800-2200.
- Skip MuZero (known rules make a learned dynamics head pointless), skip
  transformer/big-net (can't run MCTS on a phone; distill a small CNN now).

## Delivery phases

- **A — now:** strip → lean launcher; init RL_game_train + AGENTS.md + contract;
  chess shell (board, GameState, clock, screen, a11y); placeholder AI; TCP+QR
  multiplayer + protocol.
- **B — parallel trainer:** supervised pipeline → first net → ONNX + int8
  quantization → real `RLNetChessAI` + MCTS isolate; golden fixtures + anti-drift
  tests.
- **C:** async self-play fine-tuning on the 1080 Ti (weeks), eval gate, ship the
  tested model to the app release.
- **D:** on-device profiling (nps, NNAPI/CoreML/XNNPACK), difficulty knob, store
  prep (Android 16KB pages, iOS local-network prompt).

## Testing

Our layers only (dartchess rules correctness is its own project's job):
GameState draw-detection (repetition + 50/75-move), protocol roundtrip + framing,
MCTS legality + determinism, encoder golden fixtures, AI-contract test with the
stub, host/guest integration over an in-memory transport, clock. Existing
`flutter analyze` / `flutter test` / CI stay.

## Non-goals (YAGNI)

No Bluetooth transport in v1 · no web board · no Stockfish tier · no relay server
yet · no in-app training · no MuZero / transformer big-net · no cloud GPU
orchestration.
