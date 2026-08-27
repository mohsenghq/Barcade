export interface SettingsState {
  soundEnabled: boolean;
  musicEnabled: boolean;
  hapticsEnabled: boolean;
  reduceMotion: boolean;
}

const DEFAULTS: SettingsState = {
  soundEnabled: true,
  musicEnabled: true,
  hapticsEnabled: true,
  reduceMotion: false,
};

type SettingsListener = (state: SettingsState) => void;

export class SettingsService {
  private _state: SettingsState = { ...DEFAULTS };
  private _listeners: Set<SettingsListener> = new Set();

  get state(): SettingsState {
    return this._state;
  }

  load(): void {
    try {
      this._state = {
        soundEnabled: this.get("settings.sound", true),
        musicEnabled: this.get("settings.music", true),
        hapticsEnabled: this.get("settings.haptics", true),
        reduceMotion: this.get("settings.reduce_motion", false),
      };
    } catch {
      // SSR or no localStorage — use defaults
    }
    this.notify();
  }

  onChange(listener: SettingsListener): () => void {
    this._listeners.add(listener);
    return () => this._listeners.delete(listener);
  }

  private notify() {
    for (const l of this._listeners) l(this._state);
  }

  async setSoundEnabled(v: boolean): Promise<void> {
    this._state = { ...this._state, soundEnabled: v };
    this.set("settings.sound", v);
    this.notify();
  }

  async setMusicEnabled(v: boolean): Promise<void> {
    this._state = { ...this._state, musicEnabled: v };
    this.set("settings.music", v);
    this.notify();
  }

  async setHapticsEnabled(v: boolean): Promise<void> {
    this._state = { ...this._state, hapticsEnabled: v };
    this.set("settings.haptics", v);
    this.notify();
  }

  async setReduceMotion(v: boolean): Promise<void> {
    this._state = { ...this._state, reduceMotion: v };
    this.set("settings.reduce_motion", v);
    this.notify();
  }

  private get(key: string, fallback: boolean): boolean {
    const raw = localStorage.getItem(key);
    if (raw === null) return fallback;
    return raw === "true";
  }

  private set(key: string, value: boolean): void {
    localStorage.setItem(key, String(value));
  }
}
