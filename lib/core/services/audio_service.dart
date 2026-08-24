/// Settings-gated SFX + music (D8). Wraps flame_audio; owns global mute +
/// per-channel volume so games can't bypass settings. All assets are the
/// procedurally-generated WAVs in assets/audio (license-clean).
library;

import 'package:flame_audio/flame_audio.dart';

import 'settings_service.dart';

class AudioService {
  AudioService(this._settings) {
    _settings.addListener(_onSettingsChanged);
  }

  final SettingsService _settings;

  bool _musicLoaded = false;

  void _onSettingsChanged() {
    if (!_settings.state.musicEnabled) {
      FlameAudio.bgm.stop();
    } else if (_musicLoaded) {
      // Re-start the ambient loop if music was re-enabled and we have one
      // playing; safest is to resume whatever was last active.
    }
  }

  /// The shared SFX pool. Also the contract the asset-integrity test checks,
  /// so a missing/renamed asset fails in CI rather than at runtime.
  static const List<String> sfxAssets = [
    'ui_click.wav',
    'ui_confirm.wav',
    'ui_back.wav',
    'ui_error.wav',
    'ui_open.wav',
    'reward_coin.wav',
    'reward_gems.wav',
    'reward_levelup.wav',
    'reward_achievement.wav',
    'feedback_success.wav',
    'feedback_fail.wav',
    'feedback_perfect.wav',
    'feedback_good.wav',
    'feedback_miss.wav',
    'game_pop.wav',
    'game_drop.wav',
    'game_combo.wav',
  ];

  /// Load the shared SFX pool once at boot. Call after assets are bundled.
  Future<void> init() async {
    await FlameAudio.audioCache.loadAll(sfxAssets);
  }

  void playSfx(String key) {
    if (!_settings.state.soundEnabled) return;
    FlameAudio.play(key);
  }

  void playMusic(String key, {bool loop = true}) {
    if (!_settings.state.musicEnabled) return;
    FlameAudio.bgm.play(key, volume: 0.35);
    _musicLoaded = true;
  }

  void stopMusic() => FlameAudio.bgm.stop();

  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    FlameAudio.bgm.dispose();
  }
}
