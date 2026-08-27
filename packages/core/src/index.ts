// Models
export {
  type ChessProfile,
  defaultChessProfile,
  chessProfileFromJson,
  chessProfileToJson,
} from "./model/chess-profile.js";

// Save system
export { CURRENT_SCHEMA_VERSION, type SaveEnvelope, encodeEnvelope, tryDecodeEnvelope, signEnvelope } from "./save/envelope.js";
export { checksumOf, checksumMatches } from "./save/checksum.js";
export { migratePayload } from "./save/migration.js";
export { type SaveStorage, LocalStorageSave } from "./save/storage.js";
export { SaveController, LoadSource, type LoadResult } from "./save/save-controller.js";

// Chess
export { GameState, GameStatus } from "./chess/game-state.js";
export type { ChessAI } from "./chess/chess-ai.js";
export { encodeFen } from "./chess/az119-encoder.js";

// Services
export {
  SettingsService,
  type SettingsState,
  AudioService,
  type SfxKey,
  SFX_ASSETS,
  HapticsService,
  HapticType,
} from "./services/index.js";
