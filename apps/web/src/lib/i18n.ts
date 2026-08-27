/**
 * Internationalization — ported from Flutter's gen_l10n (app_en.arb).
 * Lightweight key-value lookup; no heavy i18next dependency needed.
 */

const en = {
  appTitle: "Starcade",
  launcherTitle: "Starcade",
  launcherChess: "Chess",
  launcherMoreSoon: "More games coming soon",
  launcherWins: (count: number) => `Wins: ${count}`,
  chessComingSoon: "Chess is coming soon on web.",
  chessAiModelMissing:
    "The chess AI model could not be loaded. Please try restarting the app.",
  chessModeHotseat: "Hotseat",
  chessModeVsAi: "vs AI",
  chessModeVsAiNote: "Training model — basic opponent",
  chessModeLocal: "Local multiplayer",
  chessModeLocalSoon: "Next update",
  chessModeOnlineLocked: "Online — locked",
  chessNewGame: "New game",
  chessRematch: "Rematch",
  chessUndo: "Undo",
  chessHint: "Hint",
  chessDraw: "Draw",
  chessResign: "Resign",
  chessWhite: "White",
  chessBlack: "Black",
  chessYou: "You",
  chessAi: "AI",
  chessWins: "wins",
  chessResultMate: "Checkmate",
  chessResultStalemate: "Stalemate",
  chessResultDraw: "Draw",
  chessResultYouWon: "You won",
  chessResultAiWon: "AI won",
  chessDrawReason: (reason: string) => `by ${reason}`,
  chessHintMove: (move: string) => `Hint: ${move}`,
  chessMoveCount: (count: number) =>
    count === 1 ? "1 move" : `${count} moves`,
  chessConfirmDraw: "Agree to a draw?",
  chessConfirmResign: "Resign the game?",
  chessCancel: "Cancel",
  chessConfirm: "Confirm",
} as const;

export type LocaleMessages = typeof en;

export function t(key: keyof LocaleMessages, ...args: unknown[]): string {
  const val = en[key];
  if (typeof val === "function") {
    return (val as (...a: unknown[]) => string)(...args);
  }
  return val;
}

export default en;
