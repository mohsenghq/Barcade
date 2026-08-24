/// Settings-gated haptics. Games call `haptics.trigger(HapticType.light)`; the
/// service consults settings + platform support so games can't bypass either.
library;

import 'package:flutter/services.dart';

import 'settings_service.dart';

enum HapticType { light, medium, heavy, success, warning }

class HapticsService {
  HapticsService(this._settings);

  final SettingsService _settings;

  void trigger(HapticType type) {
    if (!_settings.state.hapticsEnabled) return;
    // HapticFeedback calls are silent no-ops on platforms without the hardware.
    switch (type) {
      case HapticType.light:
        HapticFeedback.lightImpact();
      case HapticType.medium:
        HapticFeedback.mediumImpact();
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
      case HapticType.success:
        HapticFeedback.selectionClick();
      case HapticType.warning:
        HapticFeedback.vibrate();
    }
  }
}
