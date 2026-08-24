/// App boot: build the lean service set once, load the save (recovery ladder),
/// preload audio, and hand the composition root to main(). Everything here is
/// offline-safe.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/audio_service.dart';
import '../core/services/chess_services.dart';
import '../core/services/haptics_service.dart';
import '../core/services/save_controller.dart';
import '../core/services/save_repository.dart';
import '../core/services/settings_service.dart';

Future<ChessServices> bootstrap() async {
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsService(prefs)..load();
  final save = SaveController(repository: await createSaveRepository());
  await save.load(); // recovery ladder: canonical → .bak → defaults
  final services = ChessServices(
    save: save,
    settings: settings,
    audio: AudioService(settings),
    haptics: HapticsService(settings),
  );
  await services.audio.init();
  return services;
}
