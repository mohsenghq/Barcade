"""Policy index map tests. The pinned values below are contract anchors;
the app must produce the same numbers from the fixtures."""

import chess

from src.net.policy import index_to_move, legal_move_indices, move_to_index


def test_known_slots():
    board = chess.Board()
    # e2e4: e2 = sq 12, up the board (-1,0) = block 6, distance 2.
    #   12*73 + 6*7 + (2-1) = 919
    assert move_to_index(board, chess.Move.from_uci("e2e4")) == 919
    # g1f3: knight offset (-2,-1) = block 1 -> 6*73 + 56 + 1 = 495
    assert move_to_index(board, chess.Move.from_uci("g1f3")) == 495


def test_roundtrip_random_positions():
    rng = __import__("random").Random(7)
    for _ in range(50):
        board = chess.Board()
        for _ in range(rng.randint(0, 30)):
            moves = list(board.legal_moves)
            if not moves:
                break
            board.push(rng.choice(moves))
        for move in board.legal_moves:
            idx = move_to_index(board, move)
            back = index_to_move(board, idx)
            assert back.from_square == move.from_square
            assert back.to_square == move.to_square
            # Queen promotions share the queen-like slots: the plain move is
            # recovered, the promotion flag is lost by design.
            if move.promotion and move.promotion != chess.QUEEN:
                assert back.promotion == move.promotion
            elif move.promotion == chess.QUEEN:
                assert back.promotion is None
            else:
                assert back.promotion is None


def test_index_to_move_on_board_edge():
    board = chess.Board()
    # a1 -> a8: up direction (-1,0) block 6, distance 7
    idx = 0 * 73 + 6 * 7 + 6
    assert index_to_move(board, idx) == chess.Move.from_uci("a1a8")


def test_underpromotion_slot():
    # e7e8q is NOT in the underpromotion block; e7e8n is.
    board = chess.Board("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
    assert move_to_index(board, chess.Move.from_uci("a7a8n")) == \
        48 * 73 + 64 + 0 * 3 + 1
    assert move_to_index(board, chess.Move.from_uci("a7a8q")) < 48 * 73 + 56
    assert index_to_move(board, 48 * 73 + 64 + 2 * 3 + 2) == \
        chess.Move.from_uci("a7b8r")  # rook, right (file +1)


def test_legal_indices_unique_and_in_range():
    board = chess.Board("r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3")
    idxs = legal_move_indices(board)
    assert len(idxs) == len(set(idxs))
    assert all(0 <= i < 4672 for i in idxs)
    assert len(idxs) == len(list(board.legal_moves))
