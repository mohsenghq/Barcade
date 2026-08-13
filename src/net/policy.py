"""Policy index map: 64 squares x 73 moves = 4672 logits.

Contract (docs/CHESS_AI_CONTRACT.md): within a square,
  0-55   queen-like: 8 compass directions x 7 distances
  56-63  knight moves: 8 L-shapes, up-left .. clockwise
  64-72  underpromotions: (N, B, R) x (left, straight, right)

The exact ordering here is normative — locked by golden fixtures in the app.
"""

import chess

# Queen-like directions (row, col deltas) in the contract's block order:
# right, down-right, down, down-left, left, up-left, up, up-right.
QUEEN_DIRS = [
    (0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1), (-1, 0), (-1, 1),
]

# Knight offsets: up-left, up-up-left, up-up-right, up-right, down-right,
# down-down-right, down-down-left, down-left.
KNIGHT_OFFSETS = [
    (-1, -2), (-2, -1), (-2, 1), (-1, 2), (1, 2), (2, 1), (2, -1), (1, -2),
]

UNDERPROMO_PIECES = [chess.KNIGHT, chess.BISHOP, chess.ROOK]

# UCI-style (row, col) delta from source to destination square, in the same
# array orientation as the encoder (row 0 = rank 8): "up" the board (toward
# the opponent) is a negative row delta. Matches the contract's direction
# table exactly.
def _arr(sq: int) -> tuple[int, int]:
    return (7 - sq // 8, sq % 8)


def _delta(from_sq: int, to_sq: int) -> tuple[int, int]:
    fr, fc = _arr(from_sq)
    tr, tc = _arr(to_sq)
    return (tr - fr, tc - fc)


def move_to_index(board: chess.Board, move: chess.Move) -> int:
    """Map a move on `board` to its 0-4671 policy slot.

    Only meaningful for legal moves; the caller masks illegal ones.
    """
    from_sq = move.from_square
    base = from_sq * 73
    dr, dc = _delta(from_sq, move.to_square)

    if move.promotion is not None and move.promotion != chess.QUEEN:
        # Underpromotion: 3 pieces x 3 destinations (left, straight, right).
        piece = UNDERPROMO_PIECES.index(chess.Piece(move.promotion, chess.WHITE).piece_type)
        dest = dc + 1
        return base + 64 + piece * 3 + dest

    if (abs(dr), abs(dc)) in ((1, 2), (2, 1)):
        return base + 56 + KNIGHT_OFFSETS.index((dr, dc))

    d = max(abs(dr), abs(dc))
    return base + QUEEN_DIRS.index((dr // d, dc // d)) * 7 + (d - 1)


def index_to_move(board: chess.Board, index: int) -> chess.Move:
    """Inverse of move_to_index for a legal index on `board`."""
    from_sq, local = divmod(index, 73)
    if local >= 64:
        local -= 64
        piece, dest = divmod(local, 3)
        piece_type = UNDERPROMO_PIECES[piece]
        pawn = chess.Piece(chess.PAWN, board.turn)
        target_rank = 7 if board.turn == chess.WHITE else 0
        if board.piece_at(from_sq) != pawn:
            raise ValueError(f"index {index} implies an underpromotion from {from_sq}")
        rank, file = divmod(from_sq, 8)
        dest_file = file + dest - 1
        if not 0 <= dest_file <= 7:
            raise ValueError(f"index {index} promotes off the board")
        to_sq = target_rank * 8 + dest_file
        return chess.Move(from_sq, to_sq, promotion=piece_type)

    if local >= 56:
        dr, dc = KNIGHT_OFFSETS[local - 56]
    else:
        dr, dc = QUEEN_DIRS[local // 7]
        dist = local % 7 + 1
        dr, dc = dr * dist, dc * dist
    row, col = _arr(from_sq)
    to_sq = (7 - (row + dr)) * 8 + (col + dc)
    if not 0 <= to_sq < 64:
        raise ValueError(f"index {index} moves off the board")
    return chess.Move(from_sq, to_sq)


def legal_move_indices(board: chess.Board) -> list[int]:
    """Policy slots of every legal move on `board`."""
    return sorted(move_to_index(board, m) for m in board.legal_moves)
