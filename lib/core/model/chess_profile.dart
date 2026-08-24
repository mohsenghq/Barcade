/// Player-facing chess state persisted atomically (theme, piece set, board
/// orientation, and match counters). v2 of the save schema (the v1 arcade
/// profile is discarded on migration).
class ChessProfile {
  const ChessProfile({
    this.themeId = 'nebula',
    this.pieceSetId = 'letter',
    this.flipBoard = false,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.aiWins = 0,
    this.aiLosses = 0,
    this.aiDraws = 0,
  });

  final String themeId;
  final String pieceSetId;
  final bool flipBoard;
  final int wins;
  final int losses;
  final int draws;
  final int aiWins;
  final int aiLosses;
  final int aiDraws;

  ChessProfile copyWith({String? themeId, String? pieceSetId, bool? flipBoard,
      int? wins, int? losses, int? draws, int? aiWins, int? aiLosses, int? aiDraws}) =>
      ChessProfile(
        themeId: themeId ?? this.themeId,
        pieceSetId: pieceSetId ?? this.pieceSetId,
        flipBoard: flipBoard ?? this.flipBoard,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
        draws: draws ?? this.draws,
        aiWins: aiWins ?? this.aiWins,
        aiLosses: aiLosses ?? this.aiLosses,
        aiDraws: aiDraws ?? this.aiDraws,
      );

  factory ChessProfile.fromJson(Map<String, Object?> json) => ChessProfile(
        themeId: json['themeId'] as String? ?? 'nebula',
        pieceSetId: json['pieceSetId'] as String? ?? 'letter',
        flipBoard: json['flipBoard'] as bool? ?? false,
        wins: json['wins'] as int? ?? 0,
        losses: json['losses'] as int? ?? 0,
        draws: json['draws'] as int? ?? 0,
        aiWins: json['aiWins'] as int? ?? 0,
        aiLosses: json['aiLosses'] as int? ?? 0,
        aiDraws: json['aiDraws'] as int? ?? 0,
      );

  Map<String, Object?> toJson() => {
        'themeId': themeId,
        'pieceSetId': pieceSetId,
        'flipBoard': flipBoard,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'aiWins': aiWins,
        'aiLosses': aiLosses,
        'aiDraws': aiDraws,
      };
}
