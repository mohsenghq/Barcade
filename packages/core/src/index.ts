// Models
export {
  type ChessProfile,
  defaultChessProfile,
  chessProfileFromJson,
  chessProfileToJson,
} from "./model/chess-profile";

// Save system
export { CURRENT_SCHEMA_VERSION, type SaveEnvelope, encodeEnvelope, tryDecodeEnvelope, signEnvelope } from "./save/envelope";
export { checksumOf, checksumMatches } from "./save/checksum";
export { migratePayload } from "./save/migration";
export { type SaveStorage, LocalStorageSave } from "./save/storage";
export { SaveController, LoadSource, type LoadResult } from "./save/save-controller";

// Chess
export { GameState, GameStatus } from "./chess/game-state";
export type { ChessAI } from "./chess/chess-ai";
export { encodeFen } from "./chess/az119-encoder";
export { decodePolicy, moveToIndex, squareToIndex, indexToSquare } from "./chess/az119-policy";
export { WebChessAI, webChessAI } from "./chess/web-chess-ai";

// Services
export {
  SettingsService,
  type SettingsState,
  AudioService,
  type SfxKey,
  SFX_ASSETS,
  HapticsService,
  HapticType,
} from "./services/index";
