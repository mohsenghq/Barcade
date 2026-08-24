import 'package:dartchess/dartchess.dart' as dc;

/// Policy index map: 64 squares x 73 moves = 4672 logits.
///
/// Mirrors RL_game_train `src/net/policy.py` exactly (locked by the golden
/// fixtures): within a square, 0-55 queen-like (8 directions x 7 distances),
/// 56-63 knight moves, 64-72 underpromotions ((N,B,R) x (left, straight,
/// right)). Deltas are in encoder orientation (row 0 = rank 8; "up" the
/// board is a negative row delta).

const kPolicyLen = 4672;

const _queenDirs = [
  (0, 1),
  (1, 1),
  (1, 0),
  (1, -1),
  (0, -1),
  (-1, -1),
  (-1, 0),
  (-1, 1),
];

const _knightOffsets = [
  (-1, -2),
  (-2, -1),
  (-2, 1),
  (-1, 2),
  (1, 2),
  (2, 1),
  (2, -1),
  (1, -2),
];

int moveToIndex(int fromSq, int toSq, dc.Role? promotion) {
  final base = fromSq * 73;
  final fr = 7 - fromSq ~/ 8;
  final fc = fromSq % 8;
  final tr = 7 - toSq ~/ 8;
  final tc = toSq % 8;
  final dr = tr - fr;
  final dc2 = tc - fc;

  if (promotion != null && promotion != dc.Role.queen) {
    final piece = switch (promotion) {
      dc.Role.knight => 0,
      dc.Role.bishop => 1,
      _ => 2,
    };
    return base + 64 + piece * 3 + (dc2 + 1);
  }
  if ((dr.abs() == 1 && dc2.abs() == 2) || (dr.abs() == 2 && dc2.abs() == 1)) {
    return base + 56 + _knightOffsets.indexWhere((o) => o.$1 == dr && o.$2 == dc2);
  }
  final d = dr.abs() > dc2.abs() ? dr.abs() : dc2.abs();
  final qd = (dr ~/ d, dc2 ~/ d);
  return base + _queenDirs.indexWhere((q) => q.$1 == qd.$1 && q.$2 == qd.$2) * 7 + (d - 1);
}

/// Policy index of a dartchess move. Castling is normalized: dartchess moves
/// the king onto the rook's square (e.g. e8h8/e8a8), while the trainer's
/// python-chess mapping uses the king's actual destination (e8g8/e8c8) — the
/// two must land on the same slot (locked by the fixtures).
int moveToIndexMove(dc.NormalMove move) {
  var to = move.to.value;
  final from = move.from.value;
  final diff = (to - from).abs();
  final toFile = move.to.file;
  final kingHome = from == 4 || from == 60; // e1 / e8
  if (kingHome &&
      (diff == 3 || diff == 4) &&
      (toFile == dc.File.a || toFile == dc.File.h)) {
    to = toFile == dc.File.a ? to + 2 : to - 1;
  }
  return moveToIndex(from, to, move.promotion);
}

/// Policy slots of every legal move, sorted (fixture contract).
List<int> legalMoveIndices(dc.Position position) {
  final result = <int>[];
  for (final entry in position.legalMoves.entries) {
    final from = entry.key;
    final piece = position.board.pieceAt(from);
    for (final to in entry.value.squares) {
      final promotes =
          piece != null &&
          piece.role == dc.Role.pawn &&
          to.rank ==
              (piece.color == dc.Side.white ? dc.Rank.eighth : dc.Rank.first);
      if (promotes) {
        for (final role in const [
          dc.Role.queen,
          dc.Role.rook,
          dc.Role.bishop,
          dc.Role.knight,
        ]) {
          result.add(moveToIndexMove(dc.NormalMove(from: from, to: to, promotion: role)));
        }
      } else {
        result.add(moveToIndexMove(dc.NormalMove(from: from, to: to)));
      }
    }
  }
  result.sort();
  return result;
}
