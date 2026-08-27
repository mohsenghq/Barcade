export interface SaveStorage {
  read(): Promise<string | null>;
  write(data: string): Promise<void>;
  readBackup(): Promise<string | null>;
  writeBackup(data: string): Promise<void>;
  preserveCorrupt(data: string): Promise<void>;
  clear(): Promise<void>;
}

/** Web: localStorage implementation. */
export class LocalStorageSave implements SaveStorage {
  private key: string;
  private backupKey: string;

  constructor(key = "starcade.save") {
    this.key = key;
    this.backupKey = `${key}.bak`;
  }

  async read(): Promise<string | null> {
    return localStorage.getItem(this.key);
  }

  async write(data: string): Promise<void> {
    const prev = localStorage.getItem(this.key);
    if (prev) localStorage.setItem(this.backupKey, prev);
    localStorage.setItem(this.key, data);
  }

  async readBackup(): Promise<string | null> {
    return localStorage.getItem(this.backupKey);
  }

  async writeBackup(data: string): Promise<void> {
    localStorage.setItem(this.backupKey, data);
  }

  async preserveCorrupt(data: string): Promise<void> {
    const ts = Date.now();
    localStorage.setItem(`${this.key}.corrupt.${ts}`, data);
  }

  async clear(): Promise<void> {
    localStorage.removeItem(this.key);
    localStorage.removeItem(this.backupKey);
  }
}
