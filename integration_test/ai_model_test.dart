import 'package:starcade/core/chess/ai/az119_encoder.dart';
import 'package:starcade/core/chess/ai/model_contract.dart';
import 'package:starcade/core/chess/ai/rl_net_chess_ai.dart';
import 'package:starcade/core/chess/game_state.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// On-device test of the trained model: the ONNX session is only reachable in
/// a running app (native plugin), so this runs on a real target
/// (`flutter test integration_test -d linux`), not in the headless VM.
/// Skips when the artifact is absent (fetch with `dart run tool/fetch_net.dart`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('trained model loads and drives legal RL moves on-device',
      (tester) async {
    if (!ModelContract.isAvailable()) {
      markTestSkipped('model artifact absent; run tool/fetch_net.dart');
      return;
    }
    expect(ModelContract.verifyManifest(), isNull,
        reason: 'manifest must match the az119/v1 contract');

    // The bundled ONNX actually executes: one forward pass, correct shapes.
    final options = ort.OrtSessionOptions(
      intraOpNumThreads: 2,
      providers: const [ort.OrtProvider.CPU],
    );
    final session = await ort.OnnxRuntime()
        .createSessionFromAsset(ModelContract.assetKey, options: options);
    final input = encodeFen(kStartFen);
    final outputs = await session.run({
      'input': await ort.OrtValue.fromList(input, const [1, 119, 8, 8]),
    });
    final policy =
        (await outputs['policy_logits']!.asFlattenedList())
            .cast<num>()
            .map((e) => e.toDouble())
            .toList();
    final value =
        (await outputs['value']!.asFlattenedList())
            .cast<num>()
            .map((e) => e.toDouble())
            .toList();
    expect(policy.length, 8 * 8 * 73, reason: 'policy_logits shape');
    expect(value.length, 1, reason: 'value shape');
    expect(value.first.abs(), lessThan(1.5),
        reason: 'value is a win-probability score, not a logit');

    // The full RL AI (MCTS + net, no fallback) proposes only legal moves.
    final ai = RLNetChessAI();
    expect(ai.isModelAvailable, isTrue);
    final game = GameState();
    for (var ply = 0; ply < 30; ply++) {
      final uci = await ai.chooseMove(game, simBudget: 100);
      expect(uci, isNotNull, reason: 'a legal move must exist at ply $ply');
      expect(game.makeMove(uci!), isTrue,
          reason: 'AI proposed an illegal move at ply $ply');
    }
  });
}
