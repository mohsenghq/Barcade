import { checksumOf, checksumMatches } from "./checksum.js";

export const CURRENT_SCHEMA_VERSION = 2;

export interface SaveEnvelope {
  schemaVersion: number;
  savedAt: string; // ISO 8601
  checksum: string;
  payload: Record<string, unknown>;
}

/** Build a current-version envelope, computing the checksum. */
export async function signEnvelope(
  payload: Record<string, unknown>,
  savedAt?: Date,
): Promise<SaveEnvelope> {
  return {
    schemaVersion: CURRENT_SCHEMA_VERSION,
    savedAt: (savedAt ?? new Date()).toISOString(),
    checksum: await checksumOf(payload),
    payload,
  };
}

export function encodeEnvelope(env: SaveEnvelope): string {
  return JSON.stringify(env);
}

export function tryDecodeEnvelope(raw: string): SaveEnvelope | null {
  try {
    const map = JSON.parse(raw);
    if (typeof map !== "object" || map === null) return null;
    if (typeof map.schemaVersion !== "number") return null;
    if (typeof map.savedAt !== "string") return null;
    if (typeof map.checksum !== "string") return null;
    if (typeof map.payload !== "object" || map.payload === null) return null;
    if (isNaN(Date.parse(map.savedAt))) return null;
    return {
      schemaVersion: map.schemaVersion,
      savedAt: map.savedAt,
      checksum: map.checksum,
      payload: map.payload as Record<string, unknown>,
    };
  } catch {
    return null;
  }
}

export async function verifyEnvelope(raw: string): Promise<{
  envelope: SaveEnvelope;
  valid: boolean;
} | null> {
  const env = tryDecodeEnvelope(raw);
  if (!env) return null;
  const valid = await checksumMatches(env.payload, env.checksum);
  return { envelope: env, valid };
}
