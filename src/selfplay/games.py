"""Self-play game generation: full games with MCTS, storing (state, pi, z).

pi is the root visit distribution (policy target), z the game outcome from
the side-to-move's view. These tuples are the RL training data.
"""

import chess

from src.net.encoder import encode_history
from src.net.policy import move_to_index
from src.selfplay.mcts import MCTS

TEMP_HORIZON = 30  # temperature-1 sampling for the first 30 plies, greedy after


def generate_game(net, sims: int = 200, temp_horizon: int = TEMP_HORIZON,
                  max_plies: int = 120) -> list[tuple]:
    """One self-play game. Returns [(tensor, pi_indices, z)]."""
    board = chess.Board()
    history: list[str] = []
    examples = []
    ply = 0
    while not board.is_game_over() and ply < max_plies:
        mcts = MCTS(net, board)
        temperature = 1.0 if ply < temp_horizon else 0.0
        move = mcts.play(sims, temperature)
        total = sum(c.visit for c in mcts.root.children.values()) or 1
        pi = [(move_to_index(board, m), c.visit / total)
              for m, c in mcts.root.children.items() if c.visit > 0]
        examples.append((board.fen(), pi, None, history.copy()))  # z filled at the end
        history.append(board.fen())
        board.push(move)
        ply += 1

    if board.is_checkmate():
        z = -1.0  # side to move (mated) loses
    else:
        z = 0.0  # stalemate / insufficient material / repetition / 50-move
    out = []
    for i, (fen, pi, _, hist) in enumerate(examples):
        board = chess.Board(fen)
        value = z if (ply - i) % 2 == 0 else -z
        x = encode_history(hist + [fen], board.turn)
        out.append((x, pi, value))
    return out
