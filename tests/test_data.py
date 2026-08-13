"""PGN loader + fixtures emitter tests."""

import json
import struct
from pathlib import Path

import chess
import chess.pgn

from src.data.fixtures import emit_fixtures
from src.data.pgn_loader import game_examples, read_games

PGN = """[Event "Test"]
[Result "1-0"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0
"""


def test_read_games(tmp_path: Path):
    p = tmp_path / "t.pgn"
    p.write_text(PGN)
    games = read_games(str(p))
    assert len(games) == 1
    assert games[0].headers["Result"] == "1-0"


def test_game_examples(tmp_path: Path):
    p = tmp_path / "t.pgn"
    p.write_text(PGN)
    game = read_games(str(p))[0]
    exs = list(game_examples(game))
    assert len(exs) == 2  # 6 plies, 4 skipped
    for x, pi, v in exs:
        assert x.shape == (119, 8, 8)
        assert pi[0][1] == 1.0
    # white to move positions label +1 (white won), black positions -1
    vals = [v for _, _, v in exs]
    assert 1.0 in vals and -1.0 in vals


def test_emit_fixtures(tmp_path: Path):
    fixtures = emit_fixtures(tmp_path)
    assert len(fixtures) == 5
    manifest = json.loads((tmp_path / "az119_fixtures.json").read_text())
    assert len(manifest) == 5
    for f in manifest:
        assert f["fen"]
        assert len(f["legal_moves"]) == len(f["policy_indices"])
        assert all(0 <= i < 4672 for i in f["policy_indices"])
        raw = (tmp_path / f["tensor_file"]).read_bytes()
        assert len(raw) == 119 * 8 * 8 * 4  # fp32
        tensor = struct.unpack(f"{119 * 64}f", raw)
        assert any(tensor)  # not all zeros
    # start position: first fixture, castling rights all set
    assert fixtures[0]["fen"] == chess.STARTING_FEN
    assert "e2e4" in fixtures[0]["legal_moves"]
