"""MCTS and game-generation smoke tests (tiny net, CPU)."""

import chess

from src.net.network import ChessNet
from src.selfplay.games import generate_game
from src.selfplay.mcts import MCTS


def _tiny_net():
    return ChessNet(blocks=1, channels=8).eval()


def test_mcts_returns_legal_move():
    board = chess.Board()
    mcts = MCTS(_tiny_net(), board, noise=False)
    move = mcts.play(8, temperature=0)
    assert move in board.legal_moves


def test_mcts_with_noise_visits_root():
    board = chess.Board()
    mcts = MCTS(_tiny_net(), board, noise=True)
    assert mcts.play(8, temperature=1.0) in board.legal_moves
    assert mcts.root.visit == 8  # every sim backprops through the root


def test_generate_game_shapes():
    examples = generate_game(_tiny_net(), sims=8, max_plies=10)
    assert len(examples) >= 1
    for x, pi, z in examples:
        assert x.shape == (119, 8, 8)
        assert all(0 <= i < 4672 for i, _ in pi)
        assert abs(sum(p for _, p in pi) - 1.0) < 1e-3
        assert z in (-1.0, 0.0, 1.0)


def test_mate_value_sign():
    from src.selfplay.mcts import MCTS

    # Fool's mate final position: white is checkmated, root value must be -1.
    board = chess.Board("rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3")
    assert board.is_checkmate()
    mcts = MCTS(_tiny_net(), board, noise=False)
    mcts.run(4)
    assert mcts.root.value == -1.0
    assert mcts.play(4) is None  # terminal root: no moves to choose
