# RL_game_train

Trainer for the Arcade Vault chess AI. Trains a chess neural net with
supervised warm-start + async self-play reinforcement learning on a local GPU,
exports a versioned ONNX artifact, and tests it against fixed opponents before it
is shipped into the Flutter app.

**This project does not ship anything to users on its own.** Its only output is
the trained model artifact consumed by the sibling project:

> **App:** `/home/mohsenghq/Documents/mini_games` (Flutter) — see `AGENTS.md`.

Read `docs/CHESS_AI_CONTRACT.md` **before writing any code** — it defines the
network format both sides must agree on.

## Hardware / environment

- Training GPU: **NVIDIA GTX 1080 Ti** (Pascal, compute capability **sm_61**).
- **PyTorch pin:** `torch==2.13.0+cu126` — PyTorch dropped Pascal from newer
  CUDA lines, and the default pip install is CPU-only.
- Verify after install: `python -c "import torch; print(torch.cuda.get_arch_list())"`
  must include `sm_61`, and `torch.cuda.is_available()` must be `True`.

## Quick start

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python -c "import torch; assert torch.cuda.is_available(), 'CUDA not available'"
```

## Pipeline

One command per stage (`python -m src.cli <cmd>`):

| Stage | Command | Notes |
|---|---|---|
| Fetch corpus | `python -m src.data.fetch_corpus 2024-01 --count 200000` | streams the Lichess monthly dump, keeps the first N finished games |
| Supervised warm-start | `python -m src.cli warmstart data/warmstart.pgn` | policy CE + outcome value MSE |
| RL fine-tune | `python -m src.cli selfplay` | MCTS/PUCT self-play against itself, replay buffer |
| Eval gate | `python -m src.cli eval runs/candidate.pt runs/champion.pt` | candidate must beat champion + the greedy-material baseline |
| Golden fixtures | `python -m src.cli fixtures ../mini_games/test/fixtures/az119` | FEN → 119-plane tensor + policy indices, committed into the app |
| Export | `python -m src.cli export runs/chess_net.pt runs/export` | fp32 + int8 QDQ ONNX + manifest.json |

The app is gated on `expectedNetworkFormatVersion` == `az119/v1`; a net ships
only via a `net-v*` release that passed the eval gate.

## Layout

```
src/
  net/       residual CNN, az119 encoder, policy head
  selfplay/  MCTS/PUCT, worker processes, game generation
  train/     supervised warm-start + async self-play fine-tuning, eval gate, ring-of-nets, KLD
  export/    export_onnx.py, manifest.py, quantize.py (int8 QDQ/S8S8)
  data/      PGN loaders, golden-fixture emitter
  eval/      strength eval vs fixed opponents / Stockfish (python-chess)
tests/
config/      yaml experiment configs
docs/        CHESS_AI_CONTRACT.md (the load-bearing spec)
```

## The model contract (trainer → app)

- Network format v1 = **`az119`** (see `docs/CHESS_AI_CONTRACT.md`).
- Trainer exports `chess_net.onnx` (fp32, opset 17, IR 8) + `manifest.json`
  (versioning in the manifest, never ONNX metadata — the app's runtime cannot
  read ONNX metadata on iOS/web).
- Trainer emits **golden fixtures** (FEN → expected 119-plane tensor + legal
  moves + policy index map) that are committed into the app's test suite.
- When a net is good enough, tag a `net-v*` GitHub Release with (onnx + manifest);
  the app pins the URL + `model_sha256` and fetches it.
