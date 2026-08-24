import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/cosmic_toybox.dart';

/// The two ways to play a local game.
enum PlayMode { ai, hotseat }

/// Bottom-sheet mode select. Hotseat and vs-AI are live; local multiplayer is
/// next-up and online is locked behind the future networking seam.
class PlayModeSheet extends StatelessWidget {
  const PlayModeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: Ct.indigoLight,
      borderRadius: BorderRadius.vertical(top: const Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeTile(
                icon: Icons.people_alt_outlined,
                title: l.chessModeHotseat,
                onTap: () => Navigator.pop(context, PlayMode.hotseat),
              ),
              _ModeTile(
                icon: Icons.smart_toy_outlined,
                title: l.chessModeVsAi,
                subtitle: l.chessModeVsAiNote,
                onTap: () => Navigator.pop(context, PlayMode.ai),
              ),
              _ModeTile(
                icon: Icons.groups_outlined,
                title: l.chessModeLocal,
                subtitle: l.chessModeLocalSoon,
                enabled: false,
              ),
              _ModeTile(
                icon: Icons.lock_outline,
                title: l.chessModeOnlineLocked,
                enabled: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: enabled ? const Icon(Icons.chevron_right) : null,
      onTap: enabled ? onTap : null,
      shape: RoundedRectangleBorder(borderRadius: Ct.radiusSmall),
    );
  }
}
