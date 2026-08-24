/// The launcher: a lean, chess-first picker. Title row, one Chess card (mint
/// accent) gated behind the platform chess-gate seam, and a muted "more soon"
/// slot. The only Riverpod consumer — everything else is constructor-injected.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/model/chess_profile.dart';
import '../../core/save/defaults.dart';
import '../../l10n/app_localizations.dart';
import '../chess/chess_gate.dart';
import '../theme/cosmic_toybox.dart';
import '../theme/widgets.dart';

class LauncherScreen extends ConsumerStatefulWidget {
  const LauncherScreen({super.key});

  @override
  ConsumerState<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends ConsumerState<LauncherScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(chessProfileProvider).value ?? newChessProfile();
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(
                  child: Text(
                    l.launcherTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 28),
                PopIn(
                  child: GlowButton(
                    onPressed: () => openChess(context),
                    filled: false,
                    minSize: const Size(0, 104),
                    child: _ChessCardBody(profile: profile, l: l),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: FadeSlideIn(
                    child: Text(
                      l.launcherMoreSoon,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(color: Ct.white.withValues(alpha: 0.55)),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChessCardBody extends StatelessWidget {
  const _ChessCardBody({required this.profile, required this.l});

  final ChessProfile profile;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Ct.mint.withValues(alpha: 0.18),
            borderRadius: Ct.radiusSmall,
          ),
          child: const Icon(Icons.castle, color: Ct.mint, size: 28),
        ),
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.launcherChess, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(l.launcherWins(profile.wins),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
