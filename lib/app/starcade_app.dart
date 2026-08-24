/// Root widget: MaterialApp with the Cosmic Toybox theme + gen_l10n delegates.
/// The ProviderScope lives in main() so services can be overridden in tests.
library;

import 'package:flutter/material.dart';
import 'package:starcade/l10n/app_localizations.dart';

import '../ui/launcher/launcher_screen.dart';
import '../ui/theme/cosmic_toybox.dart';

class StarcadeApp extends StatelessWidget {
  const StarcadeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Starcade',
      debugShowCheckedModeBanner: false,
      theme: cosmicTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      home: const LauncherScreen(),
    );
  }
}
