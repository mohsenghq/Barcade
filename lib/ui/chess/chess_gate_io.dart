import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/chess/ai/rl_net_chess_ai.dart';
import '../../l10n/app_localizations.dart';
import 'chess_ai.dart';
import 'chess_screen.dart';
import 'play_mode_sheet.dart';

/// IO gate: real chess. Opens the play-mode sheet, then pushes the screen with
/// the services from the composition root. When the screen pops with `true`
/// (New game), the gate re-presents the mode sheet so the player can pick a
/// fresh mode; popping with `null` (back button) stops the loop.
void openChess(BuildContext context) {
  Future<void> pick() async {
    final mode = await showModalBottomSheet<PlayMode>(
      context: context,
      builder: (_) => const PlayModeSheet(),
    );
    if (mode == null || !context.mounted) return;
    ChessAI? ai;
    if (mode == PlayMode.ai) {
      // No fallback: refuse vs-AI play unless the trained model actually loads.
      final rl = RLNetChessAI();
      if (!await rl.ready) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).chessAiModelMissing),
          ));
        }
        return;
      }
      ai = rl;
    }
    if (!context.mounted) return;
    final again = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => Consumer(
          builder: (_, ref, _) => ChessScreen(
            services: ref.read(servicesProvider),
            mode: mode,
            ai: ai,
          ),
        ),
      ),
    );
    if (again == true && context.mounted) pick();
  }

  pick();
}
