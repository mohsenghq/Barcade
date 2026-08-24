import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Web gate: chess needs dartchess, which has no web support, so web builds
/// show a coming-soon snackbar instead of opening anything.
void openChess(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(AppLocalizations.of(context).chessComingSoon),
  ));
}
