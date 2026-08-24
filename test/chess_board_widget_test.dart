import 'package:starcade/ui/chess/chess_board.dart';
import 'package:chessground/chessground.dart' as cg;
import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('board renders 64 keyed squares and a live Semantics region',
      (tester) async {
    final ctrl = cg.ChessboardController(
      game: cg.GameData(
        fen: dc.Setup.standard.fen,
        playerSide: cg.PlayerSide.both,
        sideToMove: dc.Side.white,
        validMoves: const {},
      ),
    );
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ChessBoard(controller: ctrl, sideToMove: 'w',
          onUserMove: (_) {}, isAiTurn: false),
    ));
    expect(find.byKey(const ValueKey('sq-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('sq-e4')), findsOneWidget);
    expect(find.byKey(const ValueKey('sq-h8')), findsOneWidget);
    final regionFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.liveRegion == true,
    );
    expect(regionFinder, findsOneWidget);
    final region = tester.widget<Semantics>(regionFinder);
    expect(region.properties.liveRegion, isTrue);
  });
}
