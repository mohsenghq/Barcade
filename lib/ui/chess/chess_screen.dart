import 'dart:async';

import 'package:chessground/chessground.dart' as cg;
import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chess/game_state.dart';
import '../../core/services/chess_services.dart';
import '../../l10n/app_localizations.dart';
import '../theme/cosmic_toybox.dart';
import '../theme/widgets.dart';
import 'chess_ai.dart';
import 'chess_board.dart';
import 'chess_clock.dart';
import 'move_list.dart';
import 'play_mode_sheet.dart';
import 'result_dialog.dart';
import 'themes/board_theme.dart';

/// The playable chess screen (Lichess-mobile layout): top player bar → 1:1
/// board → bottom player bar → move list → controls. Hotseat plays two humans
/// on the board; AI mode casts the human as White against the injected
/// [ChessAI] seam (the trained RL model). No placeholder fallback exists.
class ChessScreen extends ConsumerStatefulWidget {
  const ChessScreen({
    super.key,
    required this.services,
    required this.mode,
    this.ai,
  });

  final ChessServices services;
  final PlayMode mode;

  /// AI seam override (the gate supplies the RL model; tests substitute a
  /// fake). Null in hotseat, or in vs-AI when the model is unusable.
  final ChessAI? ai;

  @override
  ConsumerState<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends ConsumerState<ChessScreen> {
  late GameState _gameState = GameState();
  late final cg.ChessboardController _controller =
      cg.ChessboardController(game: _buildGameData());

  bool _ended = false;
  bool _isAiTurn = false;

  Timer? _ticker;
  Timer? _aiTimer;
  Duration _whiteElapsed = Duration.zero;
  Duration _blackElapsed = Duration.zero;

  /// Per-ply clock snapshot (white, black) taken when a move is applied, so
  /// undo can rewind the count-up clocks to the pre-move state.
  final List<(Duration, Duration)> _clockHistory = <(Duration, Duration)>[];

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _aiTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  late final ChessAI? _ai = widget.ai;

  AppLocalizations _l10n() => AppLocalizations.of(context);

  // ------------------------------------------------------------------ board

  cg.GameData _buildGameData() {
    final validMoves = <dc.Square, Set<dc.Square>>{};
    for (final m in _gameState.legalMoves) {
      if (m is dc.NormalMove) {
        validMoves.putIfAbsent(m.from, () => <dc.Square>{}).add(m.to);
      }
    }
    final side = _gameState.sideToMove == 'black' ? dc.Side.black : dc.Side.white;
    final lastMove = _gameState.pgnMoves.isEmpty
        ? null
        : dc.Move.parse(_gameState.pgnMoves.last);
    return cg.GameData(
      fen: _gameState.fen,
      playerSide: _playerSide(side),
      sideToMove: side,
      validMoves: validMoves,
      lastMove: lastMove,
    );
  }

  cg.PlayerSide _playerSide(dc.Side side) {
    if (_ended || _gameState.isGameOver || _isAiTurn) {
      return cg.PlayerSide.none;
    }
    if (widget.mode == PlayMode.hotseat) return cg.PlayerSide.both;
    // AI mode: the human plays White; the AI's turn is frozen out.
    return side == dc.Side.white ? cg.PlayerSide.white : cg.PlayerSide.none;
  }

  void _syncBoard() {
    _controller.updatePosition(_buildGameData(), resetPremove: true);
  }

  dc.Side _orientation() {
    if (widget.mode == PlayMode.ai) return dc.Side.white;
    final profile = widget.services.save.profile;
    if (!profile.flipBoard) return dc.Side.white;
    return _gameState.sideToMove == 'black' ? dc.Side.black : dc.Side.white;
  }

  BoardTheme _themeForProfile() {
    final themeId = widget.services.save.profile.themeId;
    return kBoardThemes.firstWhere(
      (t) => t.id == themeId,
      orElse: () => kBoardThemes.first,
    );
  }

  // ------------------------------------------------------------------ moves

  void _onUserMove(String uci) {
    if (_isAiTurn || _ended) return;
    if (!_gameState.makeMove(uci)) return;
    _afterMove();
  }

  void _afterMove() {
    _clockHistory.add((_whiteElapsed, _blackElapsed));
    setState(() {});
    _syncBoard();
    if (_gameState.isGameOver) {
      _finishAutoResult();
      return;
    }
    if (widget.mode == PlayMode.ai && _gameState.sideToMove == 'black') {
      _scheduleAiTurn();
    }
  }

  void _applyMove(String uci) {
    if (!_gameState.makeMove(uci)) return;
    setState(() => _isAiTurn = false);
    _afterMove();
  }

  void _scheduleAiTurn() {
    setState(() => _isAiTurn = true);
    _syncBoard(); // freeze the board for the AI window
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted || _ended) return;
      final ai = _ai;
      final move = ai == null ? null : await ai.chooseMove(_gameState);
      if (!mounted || _ended) return;
      if (move == null) {
        // No fallback: the model is missing/unusable — don't leave a frozen
        // board pretending the AI will move.
        setState(() => _isAiTurn = false);
        _aiTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_l10n().chessAiModelMissing),
        ));
        return;
      }
      _applyMove(move);
    });
  }

  void _undo() {
    if (widget.mode != PlayMode.hotseat || _ended) return;
    if (_clockHistory.isNotEmpty) {
      final (white, black) = _clockHistory.removeLast();
      _whiteElapsed = white;
      _blackElapsed = black;
    }
    _gameState.undoLast();
    setState(() {});
    _syncBoard();
  }

  void _hint() {
    if (_isAiTurn) return; // never hint the AI's own move
    final l = _l10n();
    final legal = _gameState.legalMoves;
    if (legal.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.chessHintMove(legal.first.uci))),
    );
  }

  // ------------------------------------------------------------------ clocks

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _ended) return;
      setState(() {
        if (_gameState.sideToMove == 'white') {
          _whiteElapsed += const Duration(seconds: 1);
        } else {
          _blackElapsed += const Duration(seconds: 1);
        }
      });
    });
  }

  // ---------------------------------------------------------------- result

  void _finishAutoResult() {
    final l = _l10n();
    switch (_gameState.status) {
      case GameStatus.checkmate:
        // sideToMove is the side that got mated; the winner is the other one.
        final winner = _gameState.sideToMove == 'white' ? 'black' : 'white';
        _endGame(
          title: l.chessResultMate,
          subtitle: _winnerPhrase(winner),
          isDraw: false,
          winner: winner,
        );
      case GameStatus.stalemate:
        _endGame(title: l.chessResultStalemate, isDraw: true, winner: null);
      case GameStatus.draw:
        final reason = _gameState.drawReason;
        _endGame(
          title: reason == null
              ? l.chessResultDraw
              : '${l.chessResultDraw} ${l.chessDrawReason(reason)}',
          isDraw: true,
          winner: null,
        );
      case GameStatus.playing:
        break; // draw agreed / resignation handled by the confirm dialogs
    }
  }

  /// Winner display for a decisive game won by [winner] ('white'/'black').
  String _winnerPhrase(String winner) {
    final l = _l10n();
    if (widget.mode == PlayMode.ai) {
      return winner == 'white' ? l.chessResultYouWon : l.chessResultAiWon;
    }
    return '${winner == 'white' ? l.chessWhite : l.chessBlack} ${l.chessWins}';
  }

  void _endGame({
    required String title,
    String? subtitle,
    required bool isDraw,
    String? winner,
  }) {
    if (_ended) return; // the result is recorded exactly once per game
    setState(() {
      _ended = true;
      _isAiTurn = false;
    });
    _recordResult(isDraw: isDraw, winner: winner);
    _aiTimer?.cancel();
    _syncBoard();
    _ticker?.cancel();
    _showResultDialog(title: title, subtitle: subtitle);
  }

  /// Persists the outcome into [ChessProfile] so the launcher counter updates.
  /// AI mode credits the human (White): a human win raises `wins` and the AI's
  /// `aiLosses`, a human loss raises `losses` and the AI's `aiWins`, a draw
  /// raises both `draws`. Hotseat records nothing — both sides are human, so
  /// there is no owner to credit. [replaceProfile] updates memory + persists.
  Future<void> _recordResult({required bool isDraw, String? winner}) async {
    if (widget.mode == PlayMode.hotseat) return; // no owner to credit
    final p = widget.services.save.profile;
    final humanWin = !isDraw && winner == 'white' ? 1 : 0;
    final humanLoss = !isDraw && winner == 'black' ? 1 : 0;
    final draw = isDraw ? 1 : 0;
    await widget.services.save.replaceProfile(
      p.copyWith(
        wins: p.wins + humanWin,
        losses: p.losses + humanLoss,
        draws: p.draws + draw,
        aiWins: p.aiWins + humanLoss,
        aiLosses: p.aiLosses + humanWin,
        aiDraws: p.aiDraws + draw,
      ),
    );
  }

  void _showResultDialog({required String title, String? subtitle}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResultDialog(
        title: title,
        subtitle: subtitle,
        moveCount: _gameState.pgnMoves.length ~/ 2,
        onRematch: _rematch,
        onNewGame: _newGame,
      ),
    );
  }

  Future<void> _confirmDraw() async {
    final l = _l10n();
    final ok = await _confirm(l.chessConfirmDraw);
    if (ok != true || !mounted) return;
    _endGame(title: l.chessResultDraw, isDraw: true, winner: null);
  }

  Future<void> _confirmResign() async {
    final l = _l10n();
    final ok = await _confirm(l.chessConfirmResign);
    if (ok != true || !mounted) return;
    // In AI mode the human is the only player who can press Resign, so the
    // resigner is always White; in hotseat it is the side on the move.
    final resignerIsWhite =
        widget.mode == PlayMode.ai || _gameState.sideToMove == 'white';
    final winner = resignerIsWhite ? 'black' : 'white';
    _endGame(title: _winnerPhrase(winner), isDraw: false, winner: winner);
  }

  Future<bool?> _confirm(String message) {
    final l = _l10n();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.chessCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.chessConfirm),
          ),
        ],
      ),
    );
  }

  void _rematch() {
    Navigator.of(context).pop(); // close the result dialog
    setState(() {
      _gameState = GameState();
      _clockHistory.clear();
      _ended = false;
      _isAiTurn = false;
      _whiteElapsed = Duration.zero;
      _blackElapsed = Duration.zero;
      _controller.updatePosition(
        _buildGameData(),
        animate: false,
        resetPremove: true,
      );
    });
    _startTicker();
  }

  void _newGame() {
    Navigator.of(context).pop(); // close the result dialog
    // Pop the screen with a sentinel so the gate re-presents the mode sheet
    // (the sheet was already popped when the mode was chosen).
    Navigator.of(context).pop(true);
  }

  // --------------------------------------------------------------- captured

  /// Pieces of [side]'s colour that [side] has captured, replaying the move
  /// history from the start position (handles ordinary and en-passant takes).
  List<dc.Piece> _capturedBy(dc.Side side) {
    final captured = <dc.Piece>[];
    dc.Position pos = dc.Chess.fromSetup(dc.Setup.standard);
    for (final uci in _gameState.pgnMoves) {
      final m = dc.Move.parse(uci);
      if (m is! dc.NormalMove) continue;
      dc.Piece? taken = pos.board.pieceAt(m.to);
      if (taken == null) {
        final mover = pos.board.pieceAt(m.from);
        final enPassantTarget = dc.Square.fromCoords(m.to.file, m.from.rank);
        if (mover?.role == dc.Role.pawn && m.to.file != m.from.file) {
          taken = pos.board.pieceAt(enPassantTarget);
        }
      }
      if (taken != null) captured.add(taken);
      pos = pos.play(m);
    }
    return captured.where((p) => p.color == side.opposite).toList();
  }

  static String _glyph(dc.Piece p) => switch (p.role) {
        dc.Role.pawn => '♟',
        dc.Role.knight => '♞',
        dc.Role.bishop => '♝',
        dc.Role.rook => '♜',
        dc.Role.queen => '♛',
        dc.Role.king => '♚',
      };

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final l = _l10n();
    final whiteActive = !_ended && _gameState.sideToMove == 'white';
    final blackActive = !_ended && _gameState.sideToMove == 'black';
    final bottomName = widget.mode == PlayMode.ai ? l.chessYou : l.chessWhite;
    final topName = widget.mode == PlayMode.ai ? l.chessAi : l.chessBlack;

    // The board live region announces moves and results, not just the turn.
    final boardLabel =
        StringBuffer('Chess board. ${_gameState.sideToMove} to move.');
    if (_gameState.pgnMoves.isNotEmpty) {
      boardLabel.write(' Last move: ${_gameState.pgnMoves.last}.');
    }
    switch (_gameState.status) {
      case GameStatus.checkmate:
        boardLabel.write(' Checkmate.');
      case GameStatus.stalemate:
        boardLabel.write(' Stalemate.');
      case GameStatus.draw:
        boardLabel.write(' Draw.');
      case GameStatus.playing:
        break; // resignation / agreed draws are not GameState statuses
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _playerBar(
                  name: topName,
                  side: dc.Side.black,
                  active: blackActive,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: ChessBoard(
                      controller: _controller,
                      sideToMove: _gameState.sideToMove,
                      onUserMove: _onUserMove,
                      isAiTurn: _isAiTurn,
                      theme: _themeForProfile(),
                      orientation: _orientation(),
                      semanticsLabel: boardLabel.toString(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _playerBar(
                  name: bottomName,
                  side: dc.Side.white,
                  active: whiteActive,
                ),
                const SizedBox(height: 8),
                MoveList(moves: _gameState.pgnMoves),
                const SizedBox(height: 8),
                _controls(l),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playerBar({
    required String name,
    required dc.Side side,
    required bool active,
  }) {
    final captured = _capturedBy(side);
    return Row(
      children: [
        Expanded(
          child: Text(name, style: Theme.of(context).textTheme.titleSmall),
        ),
        Flexible(
          child: Text(
            captured.map(_glyph).join(' '),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: Ct.white.withValues(alpha: 0.55)),
          ),
        ),
        const SizedBox(width: 12),
        ChessClock(
          side: name,
          active: active,
          elapsed: side == dc.Side.white ? _whiteElapsed : _blackElapsed,
        ),
      ],
    );
  }

  Widget _controls(AppLocalizations l) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed:
              widget.mode == PlayMode.hotseat && !_ended ? _undo : null,
          child: Text(l.chessUndo),
        ),
        TextButton(
          onPressed: (_ended || _isAiTurn) ? null : _hint,
          child: Text(l.chessHint),
        ),
        TextButton(
          onPressed: _ended ? null : _confirmDraw,
          child: Text(l.chessDraw),
        ),
        TextButton(
          onPressed: _ended ? null : _confirmResign,
          child: Text(l.chessResign),
        ),
      ],
    );
  }
}
