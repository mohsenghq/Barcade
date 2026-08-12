# AGENTS.md — RL_game_train (the trainer)

This file tells agentic tools (Claude Code, etc.) what this repo is and how it
relates to its sibling. Read it before doing work here.

## What this repo is

The **chess AI trainer** for the Arcade Vault app. It trains a chess neural net
(supervised warm-start + async self-play RL) on the developer's local GPU and
exports a versioned ONNX model. Nothing here ships to users; the model artifact
is the only output.

## The sibling project (important)

- **mini_games** at `/home/mohsenghq/Documents/mini_games` (Flutter) is the game
  app. It runs the trained model on-device with MCTS.
- The app is **human vs trained AI** — it has no classical engine fallback and
  does no training. AI strength work lives HERE.
- The two repos couple ONLY through the model artifact.

## The model contract (load-bearing)

- **`docs/CHESS_AI_CONTRACT.md` is the source of truth** for the network format
  (az119/v1: plane order, policy index mapping, manifest schema). The app mirrors
  it at `mini_games/docs/CHESS_AI_CONTRACT.md`. Keep them in sync.
- **The contract must be written and reviewed before any encoder or training
  code** — both sides implement against it.
- **Golden fixtures:** this repo emits FEN → expected 119-plane tensor + legal
  moves + policy index map fixtures, committed into the app's `test/`. Regenerate
  them whenever the encoder changes. If the app's tests fail on fixtures, fix the
  encoder/trainer here first — the app is the consumer, not the source.
- **Versioning:** manifest.json fields `network_format_version` (bumps only when
  the encoder changes) and `model_sha256` (every retrain). Never version via ONNX
  metadata_props — the app's runtime can't read them on iOS/web.
- **Anti-contamination:** do NOT adopt LC0's 112-plane encoding (GPLv3). We use
  the AlphaZero 119-plane layout (arXiv:1712.01815).

## Conventions

- Pin `torch==2.13.0+cu126` (Pascal sm_61 GPU). Verify
  `torch.cuda.get_arch_list()` includes `sm_61` before trusting GPU availability.
- Determinism: seed RNGs, keep experiments reproducible; track runs under
  `runs/` (TensorBoard).
- A net is promoted only through the **eval gate** (candidate vs champion, plus a
  fixed baseline via python-chess). Never tag a `net-v*` release without passing.
- Export: fp32 ONNX (opset 17, IR 8, plain Conv/BN/ReLU/Add/MatMul/Softmax ops),
  then int8 QDQ/S8S8 static quantization; re-verify strength after quantization.
- Tests: `pytest` under `tests/`; CI runs lint + type-check + a tiny smoke train
  only — real training happens on the dev GPU, never in CI.

## Strength reality

On the 1080 Ti, expect ~1800-2200 (solid club) after supervised warm-start +
light self-play. Difficulty in the app is an MCTS sim budget, not net size — every
trained model ships unchanged regardless of strength.
