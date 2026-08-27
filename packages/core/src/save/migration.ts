import { CURRENT_SCHEMA_VERSION } from "./envelope";

/** Migrate a raw payload map from fromVersion to currentVersion. */
export function migratePayload(
  payload: Record<string, unknown>,
  fromVersion: number,
): Record<string, unknown> {
  if (fromVersion > CURRENT_SCHEMA_VERSION) {
    throw new Error(
      `save is from a newer schema (${fromVersion} > ${CURRENT_SCHEMA_VERSION})`,
    );
  }

  let out = payload;
  let v = fromVersion < 1 ? 1 : fromVersion;

  // v1 (arcade profile) → v2 (chess profile): reset to defaults
  if (v < 2) out = {};
  v = 2;

  return out;
}
