"""az119 input encoder (AlphaZero chess, arXiv:1712.01815 Table S1).

Encodes a chess position plus its history into the 119 binary planes both
repos agree on (docs/CHESS_AI_CONTRACT.md). From the side-to-move's
perspective: Black positions are rotated 180 degrees. The exact plane
ordering here is normative — locked by golden fixtures in the app.

Planes:
  0-5    own pieces (P N B R Q K)
  6-11   opponent pieces (P N B R Q K)
  12     repetition: 1 if this position occurred exactly once before
  13     repetition: 1 if this position occurred twice or more before
  ...    (8 history steps x 14 = 112)
  112-115  castling rights: wk, wq, bk, bq
  116     en passant square exists
  117     halfmove clock < 50
  118     white to move
"""

import functools

import numpy as np

import chess

PIECE_TO_PLANE = {
    chess.PAWN: 0,
    chess.KNIGHT: 1,
    chess.BISHOP: 2,
    chess.ROOK: 3,
    chess.QUEEN: 4,
    chess.KING: 5,
}

HISTORY = 8

# FEN strings repeat heavily across a corpus (openings); parsing them is the
# warm-start bottleneck. Boards are only ever read, never mutated.
@functools.lru_cache(maxsize=262144)
def _parse_board(fen: str) -> chess.Board:
    return chess.Board(fen)

# Board orientation: row 0 = rank 8, col 0 = file a. The whole input is
# canonicalized to the CURRENT side to move: its pieces are always "own"
# (planes 0-5) and the board is rotated 180 degrees when it is Black.
def _board_to_array(board: chess.Board, own_color: chess.Color) -> np.ndarray:
    """12 binary planes (own, opponent) x 6 piece types for the given board."""
    planes = np.zeros((12, 8, 8), dtype=np.float32)
    for sq, piece in board.piece_map().items():
        rank, file = divmod(sq, 8)
        if piece.color == own_color:
            planes[PIECE_TO_PLANE[piece.piece_type]][7 - rank][file] = 1.0
        else:
            planes[6 + PIECE_TO_PLANE[piece.piece_type]][7 - rank][file] = 1.0
    if own_color == chess.BLACK:
        planes = np.rot90(planes, 2, axes=(1, 2))
    return planes


def _repetition_planes(full_history: list[str], index: int) -> np.ndarray:
    """Two planes for one history position: occurrences *before* this one,
    counted over the full game history. Negative index = padding position,
    which never counts as a repetition."""
    planes = np.zeros((2, 8, 8), dtype=np.float32)
    if index < 0:
        return planes
    fen = full_history[index]
    earlier = sum(1 for f in full_history[:index] if f == fen)
    if earlier >= 2:
        planes[1] = 1.0
    elif earlier == 1:
        planes[0] = 1.0
    return planes


def encode_fen(fen: str) -> np.ndarray:
    """Encode a single FEN with no game history (fixtures, one-off calls).

    The original FEN string is passed through untouched — re-serializing via
    Board.fen() would drop en-passant squares with no legal capture."""
    return encode_history([fen], _parse_board(fen).turn)


def encode_history(positions: list[str], turn: chess.Color) -> np.ndarray:
    """Encode a position plus its history (oldest first; the last element is
    the current position). The last 8 positions supply the piece planes
    (padded at the front with the starting position); repetition planes are
    counted over the FULL history, per the AlphaZero spec — a 3-fold repeat
    is a 3-fold repeat even if the repeats are 15 plies apart."""
    full = list(positions)
    window = full[-HISTORY:]
    while len(window) < HISTORY:
        window.insert(0, chess.STARTING_FEN)

    planes = np.zeros((119, 8, 8), dtype=np.float32)
    pad = HISTORY - len(full)
    for i, fen in enumerate(window):
        board = _parse_board(fen)
        step = _board_to_array(board, turn)
        full_index = i - pad  # negative = padding, never a repetition
        rep = _repetition_planes(full, full_index)
        planes[i * 14:i * 14 + 12] = step
        planes[i * 14 + 12:i * 14 + 14] = rep

    board = _parse_board(full[-1])
    if board.has_kingside_castling_rights(chess.WHITE):
        planes[112] = 1.0
    if board.has_queenside_castling_rights(chess.WHITE):
        planes[113] = 1.0
    if board.has_kingside_castling_rights(chess.BLACK):
        planes[114] = 1.0
    if board.has_queenside_castling_rights(chess.BLACK):
        planes[115] = 1.0
    if board.ep_square is not None:
        planes[116] = 1.0
    if board.halfmove_clock < 50:
        planes[117] = 1.0
    if turn == chess.WHITE:
        planes[118] = 1.0
    return planes
