import type { GameState } from "./game-state";

/**
 * AI seam. The trained RL model (RL_game_train) plugs in behind this
 * interface. There is deliberately no random/placeholder fallback: when the
 * model can't be used the AI returns null and the caller surfaces a
 * "model missing" state instead of pretending to play.
 */
export interface ChessAI {
  chooseMove(game: GameState, simBudget?: number): Promise<string | null>;
  readonly ready: Promise<boolean>;
}
