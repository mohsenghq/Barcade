"""Encoder tests: plane layout per docs/CHESS_AI_CONTRACT.md (normative)."""

import numpy as np
import pytest

import chess

from src.net.encoder import encode_fen, encode_history


def test_start_position_planes():
    x = encode_fen(chess.STARTING_FEN)
    assert x.shape == (119, 8, 8)
    assert x.dtype == np.float32
    # own pawns on rank 2 (row 6), opponent pawns on rank 7 (row 1)
    assert x[0, 6].all() and x[0].sum() == 8
    assert x[6, 1].all() and x[6].sum() == 8
    # all four castling rights, rule-50 on, white to move, no en passant
    assert x[112].all() and x[113].all() and x[114].all() and x[115].all()
    assert x[116].sum() == 0
    assert x[117].all()
    assert x[118].all()


def test_black_to_move_rotates():
    # Black king a8, white queen b6, white king h1. Black to move: the whole
    # input rotates 180 deg so black attacks "up"; black's king is "own".
    x = encode_fen("k7/8/1Q6/8/8/8/8/7K b - - 0 1")
    assert x[118].sum() == 0
    assert x[103, 7, 7] == 1.0   # own (black) king a8 -> h1 (last history step)
    assert x[108, 5, 6] == 1.0   # opponent (white) queen b6 -> g3


def test_en_passant_plane():
    x = encode_fen("rnbqkbnr/ppppp1pp/8/5p2/4P3/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3")
    assert x[116].all()


def test_rule50_plane_boundary():
    x = encode_fen("8/8/8/8/8/8/8/8 w - - 49 100")
    assert x[117].all()
    y = encode_fen("8/8/8/8/8/8/8/8 w - - 50 100")
    assert y[117].sum() == 0


def test_repetition_planes():
    fen = "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3"
    # Current position = last history step -> its rep planes are 110/111.
    x = encode_history([fen, fen], chess.WHITE)
    assert x[110].sum() == 64  # current position occurred exactly once before
    y = encode_history([fen, fen, fen], chess.WHITE)
    assert y[110].sum() == 0
    assert y[111].sum() == 64  # twice or more before


def test_history_padding():
    x = encode_history(["4k3/8/8/8/8/8/8/4K3 w - - 0 1"], chess.WHITE)
    assert x.shape == (119, 8, 8)
    # padded steps are the starting position: white pawns at row 6
    assert x[0, 6].sum() == 8
    # the real position (last step): own king e1 -> row 7, col 4
    assert x[5, 7, 4] == 1.0
    assert x[5, 0, 4] == 0.0  # black king is the opponent's piece, not own
