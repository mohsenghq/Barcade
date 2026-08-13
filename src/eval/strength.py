"""Strength eval gate: candidate vs champion, plus a fixed material baseline.

A net is promoted (tagged net-v*) only when it beats the champion AND the
baseline within the configured margin. The baseline is a greedy
material-counting bot built on python-chess — the floor any shipped net
must clear, and the app's own "basic opponent" floor.
"""

import chess

PIECE_VALUES = {chess.PAWN: 1, chess.KNIGHT: 3, chess.BISHOP: 3,
                chess.ROOK: 5, chess.QUEEN: 9, chess.KING: 0}


def material_balance(board: chess.Board) -> float:
    total = 0.0
    for sq, piece in board.piece_map().items():
        v = PIECE_VALUES[piece.piece_type]
        total += v if piece.color == chess.WHITE else -v
    return total


def greedy_material_move(board: chess.Board) -> chess.Move:
    """Baseline bot: maximize own material + smallest loss, quiet-ish moves."""
    best, best_score = None, -1e9
    for move in board.legal_moves:
        score = material_balance(board)
        board.push(move)
        if board.is_checkmate():
            board.pop()
            return move
        board.pop()
        # prefer captures, avoid hanging pieces (crude, deterministic)
        if board.is_capture(move):
            score += PIECE_VALUES.get(board.piece_type_at(move.to_square), 0) * 10
        if move.promotion:
            score += 8
        if score > best_score:
            best_score, best = score, move
    return best


def play_game(net_a, net_b, *, sims: int = 100, opening: chess.Board | None = None):
    """Candidate A (white) vs B (black) with MCTS; returns +1/0/-1 for A."""
    from src.selfplay.mcts import MCTS

    board = opening.copy() if opening else chess.Board()
    while not board.is_game_over() and len(board.move_stack) < 120:
        net = net_a if board.turn == chess.WHITE else net_b
        mcts = MCTS(net, board, noise=False)
        move = mcts.play(sims, temperature=0)
        board.push(move)
    if board.is_checkmate():
        return 1.0 if board.turn == chess.BLACK else -1.0
    return 0.0


def gate(net_a, net_b, *, games: int = 40, sims: int = 100,
         baseline: bool = True) -> dict:
    """Return {score, win_rate, beats_champion, beats_baseline}."""
    wins = draws = losses = 0
    for g in range(games):
        result = play_game(net_a, net_b, sims=sims)
        wins += result > 0
        draws += result == 0
        losses += result < 0
    beats_champion = wins >= games * 0.55
    beats_baseline = None
    if baseline:
        from src.selfplay.games import generate_game
        b_wins = sum(
            1 for _ in range(20)
            if _vs_greedy(net_a, sims=sims) == 1)
        beats_baseline = b_wins >= 14
    return {"score": wins - losses, "win_rate": wins / games,
            "beats_champion": beats_champion, "beats_baseline": beats_baseline}


def _vs_greedy(net, *, sims: int = 100) -> float:
    """One game: net (white) vs the greedy material bot (black)."""
    from src.selfplay.mcts import MCTS

    board = chess.Board()
    while not board.is_game_over() and len(board.move_stack) < 120:
        if board.turn == chess.WHITE:
            mcts = MCTS(net, board, noise=False)
            board.push(mcts.play(sims, temperature=0))
        else:
            board.push(greedy_material_move(board))
    if board.is_checkmate():
        return 1.0 if board.turn == chess.BLACK else -1.0
    return 0.0
