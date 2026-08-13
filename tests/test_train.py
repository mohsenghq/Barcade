"""Smoke training tests: tiny warm-start + self-play step on CPU only."""

from pathlib import Path

import torch

from src.net.network import ChessNet
from src.train.train import train_selfplay, train_supervised

PGN = """[Event "Smoke"]
[Result "1-0"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 O-O 1-0

[Event "Smoke"]
[Result "0-1"]

1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7 5. e3 O-O 0-1
"""


def test_supervised_warmstart_smoke(tmp_path: Path):
    p = tmp_path / "smoke.pgn"
    p.write_text(PGN)
    net = ChessNet(blocks=1, channels=8)
    train_supervised(net, str(p), epochs=1, batch_size=8, lr=1e-2,
                     device="cpu", sample=1.0)
    assert all(p.isnan().sum() == 0 for p in net.parameters())


def test_selfplay_smoke():
    net = ChessNet(blocks=1, channels=8)
    before = {k: v.clone() for k, v in net.named_parameters()}
    train_selfplay(net, steps=1, games_per_step=1, sims=8, batch_size=4,
                   buffer_size=256, device="cpu")
    moved = any(not torch.equal(before[k], v) for k, v in net.named_parameters())
    assert moved
