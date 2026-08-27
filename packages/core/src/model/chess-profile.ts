export interface ChessProfile {
  themeId: string;
  pieceSetId: string;
  flipBoard: boolean;
  wins: number;
  losses: number;
  draws: number;
  aiWins: number;
  aiLosses: number;
  aiDraws: number;
}

export function defaultChessProfile(): ChessProfile {
  return {
    themeId: "nebula",
    pieceSetId: "letter",
    flipBoard: false,
    wins: 0,
    losses: 0,
    draws: 0,
    aiWins: 0,
    aiLosses: 0,
    aiDraws: 0,
  };
}

export function chessProfileFromJson(
  json: Record<string, unknown>,
): ChessProfile {
  return {
    themeId: (json.themeId as string) ?? "nebula",
    pieceSetId: (json.pieceSetId as string) ?? "letter",
    flipBoard: (json.flipBoard as boolean) ?? false,
    wins: (json.wins as number) ?? 0,
    losses: (json.losses as number) ?? 0,
    draws: (json.draws as number) ?? 0,
    aiWins: (json.aiWins as number) ?? 0,
    aiLosses: (json.aiLosses as number) ?? 0,
    aiDraws: (json.aiDraws as number) ?? 0,
  };
}

export function chessProfileToJson(profile: ChessProfile): Record<string, unknown> {
  return { ...profile };
}
