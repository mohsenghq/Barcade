import 'package:chessground/chessground.dart' as cg;
import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/material.dart';

import 'themes/board_theme.dart';

/// 1:1 chess board backed by chessground, themed (Nebula default), with keyed
/// squares for tests and a Semantics live region for screen readers.
///
/// chessground 10.1.1 has no built-in a11y — the live region is where move
/// announcements land — and no per-square builder, so the keyed squares are an
/// overlay of hit-test-transparent [Positioned] widgets computed from the
/// board's 1:1 geometry.
class ChessBoard extends StatelessWidget {
  const ChessBoard({
    super.key,
    required this.controller,
    required this.sideToMove,
    required this.onUserMove,
    required this.isAiTurn,
    this.theme,
    this.orientation,
    this.semanticsLabel,
  });

  final cg.ChessboardController controller;
  final String sideToMove;
  final void Function(String uci) onUserMove;
  final bool isAiTurn;

  /// Board palette; defaults to the first entry of [kBoardThemes] (Nebula).
  final BoardTheme? theme;

  /// Which side sits at the bottom; defaults to White.
  final dc.Side? orientation;

  /// Optional override for the live-region label (e.g. to announce the last
  /// move and the result). Defaults to 'Chess board. $sideToMove to move.'.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? kBoardThemes.first;
    final effectiveOrientation = orientation ?? dc.Side.white;
    return Semantics(
      liveRegion: true,
      label: semanticsLabel ?? 'Chess board. $sideToMove to move.',
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest.shortestSide;
            final squareSize = size / 8;
            final blackAtBottom = effectiveOrientation == dc.Side.black;
            return Stack(
              children: [
                cg.Chessboard(
                  size: size,
                  controller: controller,
                  orientation: effectiveOrientation,
                  settings: cg.ChessboardSettings(
                    colorScheme: effectiveTheme.colorScheme,
                  ),
                  onMove: (move, {viaDragAndDrop}) => onUserMove(move.uci),
                ),
                IgnorePointer(
                  child: SizedBox.square(
                    dimension: size,
                    child: Stack(
                      children: [
                        for (final square in dc.Square.values)
                          Positioned(
                            key: ValueKey('sq-${square.name}'),
                            left: (blackAtBottom
                                    ? 7 - square.file
                                    : square.file)
                                .toDouble() *
                                squareSize,
                            top: (blackAtBottom
                                    ? square.rank
                                    : 7 - square.rank)
                                .toDouble() *
                                squareSize,
                            width: squareSize,
                            height: squareSize,
                            child: const SizedBox.expand(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
