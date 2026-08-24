/// Conditional-import seam: chess is native-only (dartchess has no web
/// support). Web builds resolve the web stub; io builds resolve the real gate.
library;

import 'package:flutter/widgets.dart';

import 'chess_gate_web.dart'
    if (dart.library.io) 'chess_gate_io.dart' as impl;

/// Opens the chess entry point for the current platform.
void openChess(BuildContext context) => impl.openChess(context);
