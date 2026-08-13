"""Training: supervised warm-start, then async self-play fine-tuning.

The 1080 Ti does the real work; this module stays single-process and simple:
supervised warm-start on a PGN corpus (streamed, no materialization), then
alternating game generation and gradient steps (replay buffer).
"""

import random
import time

import chess
import chess.pgn
import torch
import torch.nn.functional as F

from src.net.network import ChessNet
from src.selfplay.games import generate_game


def _iter_examples(path: str, sample: float, rng: random.Random):
    """Stream (tensor, [(index, prob)], value) triples from a PGN file."""
    with open(path) as f:
        while True:
            game = chess.pgn.read_game(f)
            if game is None:
                return
            from src.data.pgn_loader import game_examples
            yield from game_examples(game, rng=rng, sample=sample)


def train_supervised(net: ChessNet, pgn_path: str, *, epochs: int = 1,
                     batch_size: int = 256, lr: float = 1e-3, device="cpu",
                     sample: float = 1.0) -> None:
    """Warm-start: policy CE + value MSE against played moves / game results."""
    opt = torch.optim.Adam(net.parameters(), lr=lr)
    net.train()
    for epoch in range(epochs):
        rng = random.Random(42 + epoch)
        xs, targets, zs = [], [], []
        steps = 0
        t0 = time.time()
        for x, pi, v in _iter_examples(pgn_path, sample, rng):
            xs.append(torch.from_numpy(x))
            targets.append(pi[0][0])  # supervised targets are 1-hot
            zs.append(v)
            if len(xs) == batch_size:
                batch = torch.stack(xs).to(device)
                indices = torch.tensor(targets, device=device)
                z = torch.tensor(zs, device=device)
                logits = net.flat_logits(batch)
                _, value = net(batch)
                loss = (F.cross_entropy(logits, indices)
                        + F.mse_loss(value.squeeze(1), z))
                opt.zero_grad()
                loss.backward()
                opt.step()
                xs, targets, zs = [], [], []
                steps += 1
                if steps % 250 == 0:
                    print(f"  epoch {epoch}: {steps * batch_size} positions, "
                          f"loss {loss.item():.3f}, {time.time() - t0:.0f}s",
                          flush=True)
        if xs:
            batch = torch.stack(xs).to(device)
            indices = torch.tensor(targets, device=device)
            z = torch.tensor(zs, device=device)
            logits = net.flat_logits(batch)
            _, value = net(batch)
            loss = (F.cross_entropy(logits, indices)
                    + F.mse_loss(value.squeeze(1), z))
            opt.zero_grad()
            loss.backward()
            opt.step()
            steps += 1


def train_selfplay(net: ChessNet, *, steps: int = 100, games_per_step: int = 8,
                   sims: int = 200, batch_size: int = 256, lr: float = 1e-4,
                   buffer_size: int = 32768, device="cpu") -> None:
    """RL: generate games with the current net, learn from (state, pi, z)."""
    opt = torch.optim.Adam(net.parameters(), lr=lr)
    buffer: list[tuple] = []
    for step in range(steps):
        t0 = time.time()
        new = [ex for _ in range(games_per_step) for ex in generate_game(net, sims)]
        buffer.extend(new)
        if len(buffer) > buffer_size:
            buffer = buffer[-buffer_size:]
        rng = random.Random(step)
        rng.shuffle(buffer)
        net.train()
        for start in range(0, len(buffer) // 2, batch_size):
            batch = buffer[start:start + batch_size]
            xs = torch.stack([torch.from_numpy(x) for x, _, _ in batch]).to(device)
            pi = torch.zeros(len(batch), 4672, device=device)
            z = torch.tensor([v for _, _, v in batch], device=device)
            for i, (_, moves, _) in enumerate(batch):
                for idx, prob in moves:
                    pi[i, idx] = prob
            logits = net.flat_logits(xs)
            _, value = net(xs)
            loss = F.cross_entropy(logits, pi) + F.mse_loss(value.squeeze(1), z)
            opt.zero_grad()
            loss.backward()
            opt.step()
        won = sum(1 for ex in new if ex[2] > 0.5)
        drawn = sum(1 for ex in new if abs(ex[2]) < 0.5)
        print(f"step {step}: {len(new)} new positions, "
              f"{won} win-view, {drawn} draw-view, {time.time() - t0:.1f}s", flush=True)
