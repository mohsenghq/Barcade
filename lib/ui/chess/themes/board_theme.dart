import 'package:chessground/chessground.dart' as cg;
import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/material.dart';

/// A named board palette. `colorScheme` is the chessground theme; the light/
/// dark square colors are derived from it for the test contract.
class BoardTheme {
  const BoardTheme({required this.id, required this.displayName,
      required this.colorScheme});
  final String id;
  final String displayName;
  final cg.ChessboardColorScheme colorScheme;
  Color get lightSquare => colorScheme.lightSquare;
  Color get darkSquare => colorScheme.darkSquare;
}

/// Default = Nebula (bespoke dark). Order matters: index 0 is the default.
/// Wood and blue reuse chessground's canonical accent colors (via copyWith);
/// Nebula needs a full custom scheme since its palette is bespoke.
final List<BoardTheme> kBoardThemes = [
  BoardTheme(id: 'nebula', displayName: 'Nebula', colorScheme: _nebula()),
  BoardTheme(id: 'wood', displayName: 'Classic Wood', colorScheme: _wood()),
  BoardTheme(id: 'blue', displayName: 'Ice Blue', colorScheme: _blue()),
];

cg.ChessboardColorScheme _nebula() => const cg.ChessboardColorScheme(
      lightSquare: Color(0xFF2E2454),
      darkSquare: Color(0xFF191238),
      background: cg.SolidColorChessboardBackground(
        lightSquare: Color(0xFF2E2454),
        darkSquare: Color(0xFF191238),
      ),
      whiteCoordBackground: cg.SolidColorChessboardBackground(
        lightSquare: Color(0xFF2E2454),
        darkSquare: Color(0xFF191238),
        coordinates: true,
      ),
      blackCoordBackground: cg.SolidColorChessboardBackground(
        lightSquare: Color(0xFF2E2454),
        darkSquare: Color(0xFF191238),
        coordinates: true,
        orientation: dc.Side.black,
      ),
      lastMove: cg.HighlightDetails(solidColor: Color(0xFF22D3EE)),
      selected: cg.HighlightDetails(solidColor: Color(0xFFF2C14E)),
      validMoves: Color(0x3322D3EE),
      validPremoves: Color(0x3345C4FF),
    );

cg.ChessboardColorScheme _wood() => cg.ChessboardColorScheme.brown.copyWith(
      lightSquare: const Color(0xFFF0D9B6),
      darkSquare: const Color(0xFFB58863),
    );

cg.ChessboardColorScheme _blue() => cg.ChessboardColorScheme.blue.copyWith(
      lightSquare: const Color(0xFFDEE3E6),
      darkSquare: const Color(0xFF8CA2AD),
    );
