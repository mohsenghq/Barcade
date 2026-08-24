import 'package:flutter/material.dart';

import '../theme/cosmic_toybox.dart';

/// Scrollable pane of played moves rendered in pairs (`1. e2e4 e7e5 …`),
/// matching the UCI contract of `GameState.pgnMoves` (there is no SAN
/// generator on this branch). Auto-scrolls to the newest move whenever the
/// list grows.
class MoveList extends StatefulWidget {
  const MoveList({super.key, required this.moves});

  final List<String> moves;

  @override
  State<MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<MoveList> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant MoveList old) {
    super.didUpdateWidget(old);
    if (old.moves.length != widget.moves.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pairs = <String>[];
    for (var i = 0; i < widget.moves.length; i += 2) {
      final number = (i ~/ 2) + 1;
      final white = widget.moves[i];
      final black = i + 1 < widget.moves.length ? widget.moves[i + 1] : '';
      pairs.add('$number. $white $black'.trimRight());
    }
    return Container(
      height: 104,
      decoration: BoxDecoration(
        color: Ct.surface,
        borderRadius: Ct.radiusSmall,
        border: Border.all(color: Ct.surfaceStroke),
      ),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(10),
        itemCount: pairs.length,
        itemBuilder: (context, i) => Text(
          pairs[i],
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ),
    );
  }
}
