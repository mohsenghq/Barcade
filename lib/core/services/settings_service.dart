/// User preferences, persisted in shared_preferences (not the save envelope —
/// they're device-local, small, and don't need schema versioning).
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  const SettingsState({
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
    this.reduceMotion = false,
  });

  final bool soundEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;
  final bool reduceMotion;
}

class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _sound = 'settings.sound';
  static const _music = 'settings.music';
  static const _haptics = 'settings.haptics';
  static const _motion = 'settings.reduce_motion';

  SettingsState _state = const SettingsState();
  SettingsState get state => _state;

  void load() {
    _state = SettingsState(
      soundEnabled: _prefs.getBool(_sound) ?? true,
      musicEnabled: _prefs.getBool(_music) ?? true,
      hapticsEnabled: _prefs.getBool(_haptics) ?? true,
      reduceMotion: _prefs.getBool(_motion) ?? false,
    );
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool v) async {
    _state = SettingsState(
      soundEnabled: v,
      musicEnabled: _state.musicEnabled,
      hapticsEnabled: _state.hapticsEnabled,
      reduceMotion: _state.reduceMotion,
    );
    await _prefs.setBool(_sound, v);
    notifyListeners();
  }

  Future<void> setMusicEnabled(bool v) async {
    _state = SettingsState(
      soundEnabled: _state.soundEnabled,
      musicEnabled: v,
      hapticsEnabled: _state.hapticsEnabled,
      reduceMotion: _state.reduceMotion,
    );
    await _prefs.setBool(_music, v);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool v) async {
    _state = SettingsState(
      soundEnabled: _state.soundEnabled,
      musicEnabled: _state.musicEnabled,
      hapticsEnabled: v,
      reduceMotion: _state.reduceMotion,
    );
    await _prefs.setBool(_haptics, v);
    notifyListeners();
  }

  Future<void> setReduceMotion(bool v) async {
    _state = SettingsState(
      soundEnabled: _state.soundEnabled,
      musicEnabled: _state.musicEnabled,
      hapticsEnabled: _state.hapticsEnabled,
      reduceMotion: v,
    );
    await _prefs.setBool(_motion, v);
    notifyListeners();
  }
}
