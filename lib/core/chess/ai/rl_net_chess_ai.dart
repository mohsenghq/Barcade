import 'dart:math';
import 'dart:typed_data';

import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;

import '../../../ui/chess/chess_ai.dart';
import '../game_state.dart';
import 'az119_encoder.dart';
import 'az119_policy.dart';
import 'model_contract.dart';

/// The trained RL model behind the [ChessAI] seam: az119 encoder + ONNX
/// session + PUCT MCTS. There is no fallback: when the model asset is absent
/// or the session can't load, [ready] is false and [chooseMove] returns
/// `null` so the caller can surface a "model missing" state.
class RLNetChessAI implements ChessAI {
  RLNetChessAI({this._assetsDir});

  final String? _assetsDir;
  ort.OrtSession? _session;

  bool get isModelAvailable {
    final base = _assetsDir ?? 'assets/ai';
    return ModelContract.isAvailable(assetsDir: base) &&
        ModelContract.verifyManifest(assetsDir: base) == null;
  }

  /// True when the ONNX session can actually be created. Used by the gate to
  /// refuse vs-AI play instead of silently playing a placeholder.
  Future<bool> get ready async => (await _sessionOrNull()) != null;

  Future<ort.OrtSession?> _sessionOrNull() async {
    if (_session != null) return _session;
    final base = _assetsDir ?? 'assets/ai';
    if (!ModelContract.isAvailable(assetsDir: base)) return null;
    if (ModelContract.verifyManifest(assetsDir: base) != null) return null;
    try {
      final options = ort.OrtSessionOptions(        intraOpNumThreads: 2,
        providers: const [ort.OrtProvider.CPU],
      );
      if (_assetsDir != null) {
        _session = await ort.OnnxRuntime()
            .createSession('$base/chess_net.onnx', options: options);
      } else {
        _session = await ort.OnnxRuntime()
            .createSessionFromAsset(ModelContract.assetKey, options: options);
      }
    } catch (_) {
      _session = null; // e.g. running under `flutter test` without a device
    }
    return _session;
  }

  @override
  Future<String?> chooseMove(GameState game, {int simBudget = 200}) async {
    final session = await _sessionOrNull();
    if (session == null) return null; // no fallback: caller shows the state
    final mcts = _Mcts(session, game.position);
    final move = await mcts.play(simBudget);
    return move?.uci;
  }
}

class _Node {
  _Node(this.prior);
  double prior;
  int visits = 0;
  double value = 0; // running mean from the mover's view
  final Map<dc.Move, _Node> children = {};
}

/// PUCT MCTS over dartchess positions, batched loosely for UI liveness.
/// Mirrors the trainer's `src/selfplay/mcts.py` tree semantics.
class _Mcts {
  _Mcts(this._session, this._rootBoard);

  final ort.OrtSession _session;
  final dc.Position _rootBoard;
  static const _cpuct = 1.4;

  Future<dc.Move?> play(int sims) async {
    var root = _Node(0);
    for (var i = 0; i < sims; i++) {
      if (i % 32 == 0) await Future<void>.delayed(Duration.zero);
      await _simulate(root, _rootBoard, i == 0);
    }
    if (root.children.isEmpty) return null;
    dc.Move? best;
    var bestVisits = -1;
    root.children.forEach((move, node) {
      if (node.visits > bestVisits) {
        bestVisits = node.visits;
        best = move;
      }
    });
    return best;
  }

  Future<void> _simulate(_Node node, dc.Position board, bool isRoot) async {
    final path = <_Node>[];
    var current = node;
    var b = board;
    while (current.children.isNotEmpty) {
      dc.Move? chosen;
      var bestQ = -double.infinity;
      current.children.forEach((move, child) {
        final q = child.visits == 0 ? 0.0 : child.value;
        final u = _cpuct *
            child.prior *
            sqrt(current.visits) /
            (1 + child.visits);
        final score = q + u;
        if (score > bestQ) {
          bestQ = score;
          chosen = move;
        }
      });
      path.add(current);
      current = current.children[chosen]!;
      b = b.play(chosen!);
    }
    double value;
    final legal = _legalMoves(b);
    if (b.isCheckmate) {
      value = -1; // side to move is mated
    } else if (b.isStalemate || b.isInsufficientMaterial || legal.isEmpty) {
      value = 0;
    } else {
      final (logits, v) = await _evaluate(b);
      final probs = <dc.NormalMove, double>{};
      for (final move in legal) {
        probs[move] =
            max(logits[moveToIndexMove(move)], 0.0);
      }
      final total = probs.values.fold(0.0, (a, p) => a + p);
      final children = <dc.Move, _Node>{};
      for (final e in probs.entries) {
        children[e.key] = _Node(e.value / max(total, 1e-9));
      }
      if (isRoot && current == node) {
        // Dirichlet noise at the root (same shape as the trainer).
        final noise = _dirichlet(children.length);
        var i = 0;
        children.forEach((_, child) {
          child.prior = 0.75 * child.prior + 0.25 * noise[i++];
        });
      }
      current.children.addAll(children);
      value = v;
    }
    // Backprop: flip sign per ply; the root stores its mover's view.
    for (final ancestor in path.reversed) {
      ancestor.visits += 1;
      ancestor.value += (value - ancestor.value) / ancestor.visits;
      value = -value;
    }
  }

  List<dc.NormalMove> _legalMoves(dc.Position board) {
    final result = <dc.NormalMove>[];
    for (final entry in board.legalMoves.entries) {
      final piece = board.board.pieceAt(entry.key);
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
            result.add(dc.NormalMove(from: entry.key, to: to, promotion: role));
          }
        } else {
          result.add(dc.NormalMove(from: entry.key, to: to));
        }
      }
    }
    return result;
  }

  /// One batched evaluation: 119-plane tensor in, (flat policy, value) out.
  Future<(Float32List, double)> _evaluate(dc.Position board) async {
    final input = encodeFen(board.fen);
    final inputs = {
      'input': await ort.OrtValue.fromList(input, const [1, 119, 8, 8]),
    };
    final outputs = await _session.run(inputs);
    // asFlattenedList returns the raw 1D data (asList would re-nest it into
    // the [1,8,8,73]/[1,1] shapes), which is what the policy/value readers want.
    final policy = (await outputs['policy_logits']!.asFlattenedList())
        .cast<num>()
        .map((e) => e.toDouble())
        .toList();
    final value = (await outputs['value']!.asFlattenedList())
        .cast<num>()
        .map((e) => e.toDouble())
        .toList();
    return (Float32List.fromList(policy), value.first);
  }

  List<double> _dirichlet(int n) {
    final rng = Random();
    final draws = List<double>.generate(n, (_) => -log(1 - rng.nextDouble()));
    final total = draws.fold(0.0, (a, d) => a + d);
    return draws.map((d) => d / total).toList();
  }
}
