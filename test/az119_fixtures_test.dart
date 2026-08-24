import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Golden fixtures emitted by the trainer (RL_game_train, src/data/fixtures.py).
/// Regenerate them there whenever the encoder or policy map changes — never
/// edit by hand. The app's encoder + policy tests will compare byte-identical
/// tensors and index maps against these files (anti-drift contract).
void main() {
  final dir = Directory('test/fixtures/az119');
  final manifest = File('${dir.path}/az119_fixtures.json');
  final json = jsonDecode(manifest.readAsStringSync()) as List;

  test('fixture manifest is well-formed and tensors are fp32 119x8x8', () {
    expect(json.length, 5, reason: 'trainer emits a fixed set of 5 FENs');
    for (final f in json) {
      final fen = f['fen'] as String;
      final shape = (f['tensor_shape'] as List).cast<int>();
      final moves = (f['legal_moves'] as List).cast<String>();
      final indices = (f['policy_indices'] as List).cast<int>();
      expect(shape, [119, 8, 8]);
      expect(moves.length, indices.length);
      expect(indices.every((i) => i >= 0 && i < 4672), isTrue);
      final raw = File('${dir.path}/${f['tensor_file']}').readAsBytesSync();
      expect(raw.length, 119 * 8 * 8 * 4,
          reason: 'fp32 NCHW tensor bytes for $fen');
      expect(raw.any((b) => b != 0), isTrue, reason: '$fen not all zeros');
    }
  });

  test('start position fixture: castling set, e2e4 present', () {
    final start = json.first;
    expect(start['fen'], 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    expect((start['legal_moves'] as List).cast<String>(), contains('e2e4'));
  });
}
