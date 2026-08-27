/**
 * SHA-256 checksum over the save payload.
 * Uses the Web Crypto API (available in all modern runtimes).
 */

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = new Uint8Array(hashBuffer);
  return Array.from(hashArray)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Hex sha256 of the canonical JSON encoding of payload. */
export async function checksumOf(
  payload: Record<string, unknown>,
): Promise<string> {
  // Stable JSON encoding: sort keys for reproducibility
  const json = JSON.stringify(payload, Object.keys(payload).sort());
  return sha256Hex(json);
}

/** Check if checksum matches. */
export async function checksumMatches(
  payload: Record<string, unknown>,
  expected: string,
): Promise<boolean> {
  const actual = await checksumOf(payload);
  return actual === expected;
}
