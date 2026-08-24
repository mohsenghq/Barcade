import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter_test/flutter_test.dart';
import 'package:starcade/core/chess/ai/az119_encoder.dart';
import 'package:starcade/core/chess/ai/az119_policy.dart';

/// Anti-drift contract: the Dart encoder must reproduce the trainer's
/// tensors and policy indices byte-identically (RL_game_train
/// src/data/fixtures.py). If this fails, fix the trainer first, regenerate
/// the fixtures, then re-run — never edit the fixtures by hand.
void main() {
  final dir = Directory('test/fixtures/az119');
  final manifest =
      jsonDecode(File('${dir.path}/az119_fixtures.json').readAsStringSync())
          as List;

  test('encoder reproduces the trainer tensor byte-for-byte', () {
    for (final f in manifest) {
      final fen = f['fen'] as String;
      final raw = File('${dir.path}/${f['tensor_file']}').readAsBytesSync();
      final expected =
          ByteData.sublistView(Uint8List.fromList(raw)).buffer.asFloat32List();
      final actual = encodeFen(fen);
      expect(actual.length, 119 * 64, reason: 'shape for $fen');
      for (var i = 0; i < actual.length; i++) {
        expect(actual[i], expected[i],
            reason: 'plane byte $i differs for $fen');
      }
    }
  });

  test('policy indices match the trainer mapping', () {
    for (final f in manifest) {
      final fen = f['fen'] as String;
      final expected = (f['policy_indices'] as List).cast<int>();
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      // The trainer sorts legal moves by UCI string, then maps to indices.
      final moves = <dc.NormalMove>[];
      for (final entry in position.legalMoves.entries) {
        final piece = position.board.pieceAt(entry.key);
        for (final to in entry.value.squares) {
          final promotes =
              piece != null &&
              piece.role == dc.Role.pawn &&
              to.rank ==
                  (piece.color == dc.Side.white
                      ? dc.Rank.eighth
                      : dc.Rank.first);
          if (promotes) {
            for (final role in const [
              dc.Role.queen,
              dc.Role.rook,
              dc.Role.bishop,
              dc.Role.knight,
            ]) {
              moves.add(dc.NormalMove(from: entry.key, to: to, promotion: role));
            }
          } else {
            moves.add(dc.NormalMove(from: entry.key, to: to));
          }
        }
      }
      // The trainer sorts legal moves by python-chess UCI (castling is
      // king->c/g file), then maps to indices. Mirror that order exactly.
      String pythonUci(dc.NormalMove m) {
        // Castling: dartchess puts the king on the rook's square (e1h1 /
        // e8a8); python-chess uses the real king square (e1g1 / e8c8).
        final from = m.from.value;
        final diff = (m.to.value - from).abs();
        final kingHome = from == 4 || from == 60;
        if (kingHome &&
            (diff == 3 || diff == 4) &&
            (m.to.file == dc.File.a || m.to.file == dc.File.h)) {
          final to = dc.Square(
              m.to.file == dc.File.a ? m.to.value + 2 : m.to.value - 1);
          return m.from.name +
              to.name +
              (m.promotion != null ? m.promotion!.letter : '');
        }
        return m.from.name +
            m.to.name +
            (m.promotion != null ? m.promotion!.letter : '');
      }

      moves.sort((a, b) => pythonUci(a).compareTo(pythonUci(b)));
      final actual =
          moves.map(moveToIndexMove).toList();
      expect(actual, expected, reason: 'policy mapping for $fen');
    }
  });

  test('pinned anchor slots stay stable', () {
    final e4 = dc.NormalMove(
        from: dc.Square(12), to: dc.Square(28)); // e2e4
    expect(moveToIndex(e4.from.value, e4.to.value, null), 919);
    final nf3 =
        dc.NormalMove(from: dc.Square(6), to: dc.Square(21)); // g1f3
    expect(moveToIndex(nf3.from.value, nf3.to.value, null), 495);
    // a7a8n underpromotion
    expect(moveToIndex(48, 56, dc.Role.knight), 3569);
  });
}
