import {
  type ChessProfile,
  chessProfileFromJson,
  chessProfileToJson,
  defaultChessProfile,
} from "../model/chess-profile.js";
import {
  CURRENT_SCHEMA_VERSION,
  type SaveEnvelope,
  encodeEnvelope,
  signEnvelope,
  tryDecodeEnvelope,
} from "./envelope.js";
import { checksumMatches } from "./checksum.js";
import { migratePayload } from "./migration.js";
import type { SaveStorage } from "./storage.js";

export enum LoadSource {
  Loaded = "loaded",
  RecoveredFromBackup = "recoveredFromBackup",
  SeededDefaults = "seededDefaults",
}

export interface LoadResult {
  profile: ChessProfile;
  source: LoadSource;
}

type Listener = (profile: ChessProfile) => void;

export class SaveController {
  private storage: SaveStorage;
  private _profile: ChessProfile = defaultChessProfile();
  private _loaded = false;
  private _writing = false;
  private _listeners: Set<Listener> = new Set();

  constructor(storage: SaveStorage) {
    this.storage = storage;
  }

  get profile(): ChessProfile {
    return this._profile;
  }

  get isLoaded(): boolean {
    return this._loaded;
  }

  onChange(listener: Listener): () => void {
    this._listeners.add(listener);
    return () => this._listeners.delete(listener);
  }

  private notify() {
    for (const listener of this._listeners) {
      listener(this._profile);
    }
  }

  async load(): Promise<LoadResult> {
    // 1. Read canonical save
    try {
      const raw = await this.storage.read();
      if (raw) {
        const result = await this.verifyAndLoad(raw);
        if (result) {
          await this.writeBackup(result.profile);
          this.notify();
          return { profile: result.profile, source: LoadSource.Loaded };
        }
        // Corrupt: preserve for support
        await this.storage.preserveCorrupt(raw);
      }
    } catch {
      // Read failure — fall through to backup
    }

    // 2. Try backup
    try {
      const backup = await this.storage.readBackup();
      if (backup) {
        const result = await this.verifyAndLoad(backup);
        if (result) {
          await this.writeCanonical(result.profile);
          this.notify();
          return {
            profile: result.profile,
            source: LoadSource.RecoveredFromBackup,
          };
        }
      }
    } catch {
      // Fall through to defaults
    }

    // 3. Seed defaults
    const fresh = defaultChessProfile();
    this._profile = fresh;
    this._loaded = true;
    await this.writeCanonical(fresh);
    await this.writeBackup(fresh);
    this.notify();
    return { profile: fresh, source: LoadSource.SeededDefaults };
  }

  private async verifyAndLoad(
    raw: string,
  ): Promise<{ profile: ChessProfile } | null> {
    const env = tryDecodeEnvelope(raw);
    if (!env) return null;
    const valid = await checksumMatches(env.payload, env.checksum);
    if (!valid) return null;
    try {
      const migrated = migratePayload(env.payload, env.schemaVersion);
      const profile = chessProfileFromJson(
        migrated as Record<string, unknown>,
      );
      this._profile = profile;
      this._loaded = true;
      return { profile };
    } catch {
      return null;
    }
  }

  async saveNow(): Promise<void> {
    if (!this._loaded || this._writing) return;
    this._writing = true;
    try {
      await this.writeCanonical(this._profile);
      await this.writeBackup(this._profile);
    } finally {
      this._writing = false;
    }
    this.notify();
  }

  async replaceProfile(value: ChessProfile): Promise<void> {
    this._profile = value;
    this._loaded = true;
    await this.saveNow();
  }

  private async writeCanonical(value: ChessProfile): Promise<void> {
    const envelope = await signEnvelope(chessProfileToJson(value));
    await this.storage.write(encodeEnvelope(envelope));
  }

  private async writeBackup(value: ChessProfile): Promise<void> {
    const envelope = await signEnvelope(chessProfileToJson(value));
    await this.storage.writeBackup(encodeEnvelope(envelope));
  }
}
