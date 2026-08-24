import 'package:flutter_test/flutter_test.dart';
import 'package:starcade/core/chess/game_state.dart';

void main() {
  test('threefold repetition is detected and ends the game as a draw', () {
    final s = GameState();
    // The classic repetition line: Nf3 Nf6 Ng1 Ng8 Nf3 Nf6 Ng1 Ng8
    // (each pair returns to the start position 3 times).
    const moves = [
      'g1f3',
      'g8f6',
      'f3g1',
      'f6g8',
      'g1f3',
      'g8f6',
      'f3g1',
      'f6g8',
    ];
    for (final m in moves) {
      expect(s.makeMove(m), isTrue, reason: 'illegal move in the line: $m');
    }
    expect(s.isThreefoldRepetition, isTrue);
    expect(s.isGameOver, isTrue);
    expect(s.drawReason, contains('repetition'));
  });

  test('50-move rule ends the game as a draw', () {
    // Start with the halfmove clock already at 99 (FEN 5th field), then one
    // quiet knight move pushes it to 100 — FIDE's fifty-move threshold.
    // A single move cannot create a repetition, so this isolates the rule.
    final s = GameState.fromFen(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 99 1',
    );
    expect(s.isFiftyMoveRule, isFalse, reason: 'clock at 99 is not yet 100');
    expect(s.makeMove('g1f3'), isTrue, reason: 'knight move must be legal');
    expect(s.isFiftyMoveRule, isTrue);
    expect(s.isGameOver, isTrue);
  });

  test('checkmate resolves a winner', () {
    final s = GameState();
    // Fool's mate: f3 e5 g4 Qh4#
    for (final m in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      expect(s.makeMove(m), isTrue);
    }
    expect(s.status, GameStatus.checkmate);
    expect(s.isGameOver, isTrue);
  });

  test('stalemate is detected', () {
    final s = GameState.fromFen('k7/8/1Q6/8/8/8/8/7K b - - 0 1');
    expect(s.isGameOver, isTrue);
    expect(s.status, GameStatus.stalemate);
  });

  test('undo restores the previous position', () {
    final s = GameState();
    expect(s.makeMove('e2e4'), isTrue);
    expect(s.pgnMoves.length, 1);
    s.undoLast();
    expect(s.pgnMoves, isEmpty);
    expect(s.makeMove('g1f3'), isTrue, reason: 'e4 was undone');
  });

  test('illegal moves are rejected and state is untouched', () {
    final s = GameState();
    expect(
      s.makeMove('e2e5'),
      isFalse,
      reason: 'pawn cannot jump two-from-first',
    );
    expect(s.pgnMoves, isEmpty);
  });

  test('a bare pawn push to the promotion rank is rejected; promotion required',
      () {
    // White pawn on a7, white to move — dartchess accepts the bare 'a7a8',
    // which would strand an illegal pawn on the 8th rank.
    final s = GameState.fromFen('8/P7/8/8/8/8/8/4K2k w - - 0 1');
    expect(
      s.makeMove('a7a8'),
      isFalse,
      reason: 'a pawn must promote on reaching the last rank',
    );
    expect(
      s.makeMove('h2h1'),
      isFalse,
      reason: 'a bare push to the mover\'s own back rank is never legal',
    );
    expect(s.makeMove('a7a8q'), isTrue, reason: 'promotion is accepted');
    expect(s.pgnMoves, ['a7a8q']);
  });
}
