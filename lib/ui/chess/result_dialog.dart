import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/cosmic_toybox.dart';

/// End-of-game dialog. The screen composes the localized [title]/[subtitle]
/// (Checkmate / Stalemate / Draw by reason / winner phrase) and the move
/// count; this presents them with Rematch + New game, which arm after a
/// ~1s delay so a mash-tap can't instantly restart a game.
class ResultDialog extends StatefulWidget {
  const ResultDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.moveCount,
    required this.onRematch,
    required this.onNewGame,
  });

  final String title;
  final String? subtitle;
  final int moveCount;
  final VoidCallback onRematch;
  final VoidCallback onNewGame;

  @override
  State<ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<ResultDialog> {
  Timer? _armTimer;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _armTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _enabled = true);
    });
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: Ct.indigoLight,
      title: Text(widget.title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Ct.gold,
                  ),
            ),
          const SizedBox(height: 8),
          Text(
            l.chessMoveCount(widget.moveCount),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _enabled ? widget.onNewGame : null,
          child: Text(l.chessNewGame),
        ),
        FilledButton(
          onPressed: _enabled ? widget.onRematch : null,
          child: Text(l.chessRematch),
        ),
      ],
    );
  }
}
