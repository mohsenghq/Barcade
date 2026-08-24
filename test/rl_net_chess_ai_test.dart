import 'package:starcade/core/chess/ai/model_contract.dart';
import 'package:starcade/core/chess/ai/rl_net_chess_ai.dart';
import 'package:starcade/core/chess/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Headless contract tests for the RL AI. The native ONNX runtime cannot load
/// under `flutter test` (no engine), so these assert the no-fallback contract;
/// on-device behavior of the real model is covered by
/// integration_test/ai_model_test.dart (`flutter test integration_test -d linux`).
void main() {
  final hasModel = ModelContract.isAvailable();
  setUpAll(() {
    if (hasModel) {
      final error = ModelContract.verifyManifest();
      expect(error, isNull, reason: 'manifest must match the contract');
    }
  });

  test('no fallback: chooseMove is null when the session cannot load',
      () async {
    // Under `flutter test` the session never loads, so chooseMove must return
    // null — never a legal-random move. There is deliberately no placeholder.
    final ai = RLNetChessAI();
    final move = await ai.chooseMove(GameState());
    expect(move, isNull, reason: 'no placeholder fallback may exist');
  });
}
