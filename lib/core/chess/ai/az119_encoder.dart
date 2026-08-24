import 'dart:typed_data';

/// az119 input encoder (AlphaZero chess, arXiv:1712.01815 Table S1).
///
/// Mirrors RL_game_train `src/net/encoder.py` exactly — the golden fixtures
/// in `test/fixtures/az119/` pin byte-identical tensors. If this file and
/// the trainer disagree, the fixtures catch it; regenerate from the trainer,
/// never edit by hand.
///
/// Input: the position plus its game history (last element = current FEN).
/// Canonicalized to the side to move: its pieces are always "own" (planes
/// 0-5) and the board is rotated 180° when it is Black.
/// Planes: 8 history steps x (6 own + 6 opponent + 2 repetition), then
/// 112-115 castling, 116 en passant exists, 117 halfmove < 50, 118 white.

const kStartFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const kHistoryLen = 8;

const _piecePlane = {'p': 0, 'n': 1, 'b': 2, 'r': 3, 'q': 4, 'k': 5};

/// Encode a single FEN with no history (the golden-fixture path).
Float32List encodeFen(String fen) => encodeHistory([fen]);

/// Encode a game history (oldest first; last = current) into 119x8x8 NCHW.
Float32List encodeHistory(List<String> fullHistory) {
  final full = fullHistory;
  final window = full.length > kHistoryLen
      ? full.sublist(full.length - kHistoryLen)
      : full;
  final pad = kHistoryLen - window.length;
  final planes = Float32List(119 * 64);
  final ownIsWhite = full.last.split(' ')[1] == 'w';

  for (var i = 0; i < kHistoryLen; i++) {
    final fen = i < pad ? kStartFen : window[i - pad];
    _encodeStep(planes, i * 14, fen, ownIsWhite, full, i - pad);
  }

  final parts = full.last.split(' ');
  final castling = parts[2];
  if (castling.contains('K')) _fill(planes, 112);
  if (castling.contains('Q')) _fill(planes, 113);
  if (castling.contains('k')) _fill(planes, 114);
  if (castling.contains('q')) _fill(planes, 115);
  if (parts[3] != '-') _fill(planes, 116);
  if (int.parse(parts[4]) < 50) _fill(planes, 117);
  if (ownIsWhite) _fill(planes, 118);
  return planes;
}

void _fill(Float32List planes, int plane) {
  for (var i = plane * 64; i < plane * 64 + 64; i++) {
    planes[i] = 1;
  }
}

/// One 14-plane history step. `fullIndex` is the step's index in the full
/// history (negative = padding, which never counts as a repetition).
void _encodeStep(Float32List planes, int base, String fen, bool ownIsWhite,
    List<String> full, int fullIndex) {
  final parts = fen.split(' ');
  final rows = parts[0].split('/');
  for (var r = 0; r < 8; r++) {
    var file = 0;
    for (final ch in rows[r].split('')) {
      final digit = int.tryParse(ch);
      if (digit != null) {
        file += digit;
        continue;
      }
      final isWhite = ch.toUpperCase() == ch;
      final plane = _piecePlane[ch.toLowerCase()]! + (isWhite == ownIsWhite ? 0 : 6);
      final pos = ownIsWhite
          ? (base + plane) * 64 + r * 8 + file
          : (base + plane) * 64 + (7 - r) * 8 + (7 - file);
      planes[pos] = 1;
      file++;
    }
  }
  // Repetition planes (12, 13): occurrences *before* this one in full
  // history. 1 = exactly once before, 2+ = twice or more before.
  if (fullIndex >= 0) {
    var earlier = 0;
    for (var j = 0; j < fullIndex; j++) {
      if (full[j] == fen) earlier++;
    }
    if (earlier >= 2) {
      for (var i = (base + 13) * 64; i < (base + 14) * 64; i++) {
        planes[i] = 1;
      }
    } else if (earlier == 1) {
      for (var i = (base + 12) * 64; i < (base + 13) * 64; i++) {
        planes[i] = 1;
      }
    }
  }
}
