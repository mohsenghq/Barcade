import type { SettingsService } from "./settings.js";

export enum HapticType {
  Light = "light",
  Medium = "medium",
  Heavy = "heavy",
  Success = "success",
  Warning = "warning",
}

export class HapticsService {
  private settings: SettingsService;

  constructor(settings: SettingsService) {
    this.settings = settings;
  }

  trigger(type: HapticType): void {
    if (!this.settings.state.hapticsEnabled) return;
    if (typeof navigator === "undefined" || !navigator.vibrate) return;

    switch (type) {
      case HapticType.Light:
        navigator.vibrate(10);
        break;
      case HapticType.Medium:
        navigator.vibrate(20);
        break;
      case HapticType.Heavy:
        navigator.vibrate(40);
        break;
      case HapticType.Success:
        navigator.vibrate([10, 50, 20]);
        break;
      case HapticType.Warning:
        navigator.vibrate([40, 30, 40]);
        break;
    }
  }
}
