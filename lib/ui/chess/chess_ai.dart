import '../../core/chess/game_state.dart';

/// AI seam. The trained RL model (RL_game_train) plugs in behind this
/// interface. There is deliberately no random/placeholder fallback: when the
/// model can't be used the AI returns `null` and the caller surfaces a
/// "model missing" state instead of pretending to play.
abstract class ChessAI {
  Future<String?> chooseMove(GameState game, {int simBudget = 200});
}
