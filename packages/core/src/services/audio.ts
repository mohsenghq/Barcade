import type { SettingsService } from "./settings";

/** Shared SFX pool matching the Flutter asset list. */
export const SFX_ASSETS = [
  "ui_click",
  "ui_confirm",
  "ui_back",
  "ui_error",
  "ui_open",
  "reward_coin",
  "reward_gems",
  "reward_levelup",
  "reward_achievement",
  "feedback_success",
  "feedback_fail",
  "feedback_perfect",
  "feedback_good",
  "feedback_miss",
  "game_pop",
  "game_drop",
  "game_combo",
] as const;

export type SfxKey = (typeof SFX_ASSETS)[number];

export class AudioService {
  private settings: SettingsService;
  private audioCache = new Map<string, HTMLAudioElement>();
  private bgm: HTMLAudioElement | null = null;

  constructor(settings: SettingsService) {
    this.settings = settings;
  }

  /** Preload SFX pool. Call at boot. */
  async init(): Promise<void> {
    const promises = SFX_ASSETS.map(async (key) => {
      const audio = new Audio(`/audio/${key}.wav`);
      audio.preload = "auto";
      this.audioCache.set(key, audio);
    });
    await Promise.allSettled(promises);
  }

  playSfx(key: SfxKey): void {
    if (!this.settings.state.soundEnabled) return;
    const audio = this.audioCache.get(key);
    if (audio) {
      audio.currentTime = 0;
      audio.play().catch(() => {});
    }
  }

  playMusic(key: string, loop = true): void {
    if (!this.settings.state.musicEnabled) return;
    this.stopMusic();
    this.bgm = new Audio(`/audio/${key}.wav`);
    this.bgm.loop = loop;
    this.bgm.volume = 0.35;
    this.bgm.play().catch(() => {});
  }

  stopMusic(): void {
    if (this.bgm) {
      this.bgm.pause();
      this.bgm = null;
    }
  }
}
