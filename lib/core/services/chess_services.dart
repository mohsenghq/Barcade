import 'audio_service.dart';
import 'haptics_service.dart';
import 'save_controller.dart';
import 'settings_service.dart';

/// Lean composition root (replaces MiniGameServices): constructor-injected
/// into the launcher and chess screens.
class ChessServices {
  ChessServices({
    required this.save,
    required this.settings,
    required this.audio,
    required this.haptics,
  });

  final SaveController save;
  final SettingsService settings;
  final AudioService audio;
  final HapticsService haptics;
}
