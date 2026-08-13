"""MCTS/PUCT self-play (AlphaZero). Used for game generation in training and
by the eval gate. The app re-implements MCTS on-device; this one exists to
produce training games and to rank nets — correctness of the policy/value
heads is what matters, not this tree's performance.
"""

import math
import random

import chess
import torch

from src.net.encoder import encode_history
from src.net.policy import move_to_index

C_PUCT = 1.4
DIRICHLET_ALPHA = 0.3
DIRICHLET_EPS = 0.25


class _Node:
    __slots__ = ("prior", "visit", "value", "children")

    def __init__(self, prior: float):
        self.prior = prior
        self.visit = 0
        self.value = 0.0  # running mean of backpropagated values
        self.children: dict[chess.Move, _Node] = {}


class MCTS:
    def __init__(self, net, board: chess.Board, *, noise: bool = True,
                 cpuct: float = C_PUCT):
        self.net = net
        self.board = board
        self.noise = noise
        self.cpuct = cpuct
        self.root = _Node(0.0)

    @torch.no_grad()
    def _policy_probs(self, board: chess.Board) -> dict[chess.Move, float]:
        x = torch.from_numpy(encode_history([board.fen()], board.turn))
        logits = self.net.flat_logits(x.unsqueeze(0))[0]
        probs = {}
        for move in board.legal_moves:
            probs[move] = max(logits[move_to_index(board, move)].item(), 0.0)
        total = sum(probs.values())
        return {m: p / max(total, 1e-9) for m, p in probs.items()}

    def _select(self) -> tuple[list[_Node], list[chess.Move], chess.Board, _Node]:
        board = self.board.copy()
        path, moves = [], []
        node = self.root
        while node.children:
            best, best_q = None, -math.inf
            for move, child in node.children.items():
                q = child.value if child.visit else 0.0
                u = self.cpuct * child.prior * math.sqrt(node.visit) / (1 + child.visit)
                score = q + u
                if score > best_q:
                    best_q, best = score, (move, child)
            move, child = best
            path.append(node)
            moves.append(move)
            node = child
            board.push(move)
        return path, moves, board, node

    @torch.no_grad()
    def run(self, sims: int) -> None:
        if self.board.is_game_over() or not self.board.legal_moves:
            self.root.value = -1.0 if self.board.is_checkmate() else 0.0
            return
        if self.noise and not self.root.children:
            probs = self._policy_probs(self.board)
            noise = torch.distributions.Dirichlet(
                torch.full((len(probs),), DIRICHLET_ALPHA)).sample().tolist()
            for (m, p), eps in zip(probs.items(), noise):
                probs[m] = (1 - DIRICHLET_EPS) * p + DIRICHLET_EPS * eps
            self.root.children = {m: _Node(p) for m, p in probs.items()}
        for _ in range(sims):
            path, moves, board, leaf = self._select()
            if board.is_game_over() or not board.legal_moves:
                value = -1.0 if board.is_checkmate() else 0.0  # mover's view
            else:
                probs = self._policy_probs(board)
                leaf.children = {m: _Node(p) for m, p in probs.items()}
                x = torch.from_numpy(encode_history([board.fen()], board.turn))
                _, v = self.net(x.unsqueeze(0))
                value = v.item()
            v = value  # leaf value from the leaf mover's view
            for node in reversed(path):
                node.visit += 1
                node.value += (v - node.value) / node.visit
                v = -v

    def play(self, sims: int, temperature: float = 1.0) -> chess.Move | None:
        """Run sims, then pick a move from the root visit distribution."""
        self.run(sims)
        counts = {m: child.visit for m, child in self.root.children.items()}
        if not counts:
            return None  # terminal root: no legal moves
        if temperature == 0:
            return max(counts, key=counts.get)
        r = random.random() * sum(counts.values())
        acc = 0.0
        for move, c in sorted(counts.items(), key=lambda kv: -kv[1]):
            acc += c
            if r < acc:
                return move
        return max(counts, key=counts.get)
