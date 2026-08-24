/// Riverpod providers for the app. Composition happens once in `bootstrap()`;
/// main() overrides [servicesProvider] with the built instance. Screens never
/// construct services — they get them by constructor injection or here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/model/chess_profile.dart';
import '../core/services/chess_services.dart';

final servicesProvider = Provider<ChessServices>(
  (ref) => throw UnimplementedError('servicesProvider must be overridden at boot'),
);

/// Live chess profile. Emits the current profile immediately, then every change.
final chessProfileProvider = StreamProvider<ChessProfile>(
  (ref) => ref.watch(servicesProvider).save.changes,
);
