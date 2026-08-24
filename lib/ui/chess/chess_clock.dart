import 'package:flutter/material.dart';

import '../theme/cosmic_toybox.dart';

/// Per-side count-up clock (Lichess-style). Pure display widget: the owning
/// screen runs the `dart:async Timer` that advances [elapsed] and toggles
/// [active]; this renders `mm:ss` and marks which side is on the move.
class ChessClock extends StatelessWidget {
  const ChessClock({
    super.key,
    required this.side,
    required this.active,
    required this.elapsed,
  });

  final String side;
  final bool active;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final mm = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Semantics(
      label: '$side clock $mm:$ss, ${active ? 'running' : 'paused'}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.schedule : Icons.schedule_outlined,
            size: 16,
            color: active ? Ct.cyan : Ct.white.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 4),
          Text(
            '$mm:$ss',
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: active ? Ct.white : Ct.white.withValues(alpha: 0.55),
                ),
          ),
        ],
      ),
    );
  }
}
