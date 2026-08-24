import 'package:dartchess/dartchess.dart' as dc;

enum GameStatus { playing, checkmate, stalemate, draw }

/// Stateful game wrapper around dartchess. dartchess validates moves and
/// reports check/mate, but does NOT auto-detect repetition or the 50/75-move
/// rules — that is this layer's job (silent-correctness trap).
class GameState {
  GameState() : this.fromFen(dc.Setup.standard.fen);

  GameState.fromFen(String fen)
    : _position = dc.Chess.fromSetup(dc.Setup.parseFen(fen)) {
    _fenHistory.add(_repetitionKey);
  }

  dc.Position _position;
  final List<String> _fenHistory = <String>[];
  final List<dc.Move> _moves = <dc.Move>[];

  dc.Position get position => _position;
  String get fen => _position.fen;
  String get sideToMove => _position.turn.name;
  bool get isGameOver => status != GameStatus.playing;
  List<String> get pgnMoves => _moves.map((m) => m.uci).toList();

  /// Every position reached in this game (oldest first, the current position
  /// last). Feeds the az119 encoder for the RL AI.
  List<String> get fenHistory => List.unmodifiable(_fenHistory);

  List<dc.Move> get legalMoves {
    final result = <dc.Move>[];
    for (final entry in _position.legalMoves.entries) {
      final from = entry.key;
      final piece = _position.board.pieceAt(from);
      for (final to in entry.value.squares) {
        final promotes =
            piece != null &&
            piece.role == dc.Role.pawn &&
            to.rank ==
                (piece.color == dc.Side.white ? dc.Rank.eighth : dc.Rank.first);
        if (promotes) {
          for (final role in _promotionRoles) {
            result.add(dc.NormalMove(from: from, to: to, promotion: role));
          }
        } else {
          result.add(dc.NormalMove(from: from, to: to));
        }
      }
    }
    return result;
  }

  static const _promotionRoles = <dc.Role>[
    dc.Role.queen,
    dc.Role.rook,
    dc.Role.bishop,
    dc.Role.knight,
  ];

  GameStatus get status {
    if (_position.isCheckmate) return GameStatus.checkmate;
    if (_position.isStalemate) return GameStatus.stalemate;
    if (isThreefoldRepetition || isFiftyMoveRule) return GameStatus.draw;
    return GameStatus.playing;
  }

  bool get isThreefoldRepetition {
    // _fenHistory holds every position reached (including the current one and
    // the start position); >= 3 occurrences of the current position is a draw.
    final counts = <String, int>{};
    for (final f in _fenHistory) {
      counts[f] = (counts[f] ?? 0) + 1;
    }
    return (counts[_repetitionKey] ?? 0) >= 3;
  }

  /// Position identity for the repetition rule: FEN without the halfmove
  /// clock and fullmove counter — those change on every ply, so the same
  /// board position reached twice would otherwise look like two positions.
  String get _repetitionKey => _position.fen.split(' ').take(4).join(' ');

  /// FIDE fifty-move rule: a draw is claimable after 100 plies (half-moves)
  /// without a capture or pawn move. dartchess tracks the clock as `halfmoves`.
  bool get isFiftyMoveRule => _position.halfmoves >= 100;

  /// Why the game is drawn, or `null` if no draw condition is currently met.
  /// Computed so it can never go stale after undo.
  String? get drawReason {
    if (isThreefoldRepetition) return 'repetition';
    if (isFiftyMoveRule) return '50-move rule';
    return null;
  }

  bool makeMove(String uci) {
    final m = uci.length < 4 ? null : dc.Move.parse(uci);
    if (m == null || !_position.isLegal(m)) return false;
    // Reject a bare pawn push to the promotion rank: dartchess accepts it, but
    // play() then leaves an illegal pawn on the last rank. GameState is the
    // trusted rules layer (future multiplayer), so enforcement lives here.
    if (m is dc.NormalMove && m.promotion == null) {
      final piece = _position.board.pieceAt(m.from);
      final promotes =
          piece != null &&
          piece.role == dc.Role.pawn &&
          m.to.rank ==
              (piece.color == dc.Side.white ? dc.Rank.eighth : dc.Rank.first);
      if (promotes) return false;
    }
    _position = _position.play(m);
    _moves.add(m);
    _fenHistory.add(_repetitionKey);
    return true;
  }

  void undoLast() {
    if (_moves.isEmpty) return;
    _moves.removeLast();
    _fenHistory.removeLast();
    _position = _replay(_fenHistory.first, _moves);
  }

  static dc.Position _replay(String startFen, List<dc.Move> moves) {
    dc.Position pos = dc.Chess.fromSetup(dc.Setup.parseFen(startFen));
    for (final m in moves) {
      pos = pos.play(m);
    }
    return pos;
  }
}
