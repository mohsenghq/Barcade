/**
 * AZ119 policy decoder.
 * Maps (from-sq, to-sq, promotion?) → index in the 4672-logit policy vector.
 *
 * Policy layout: 64 squares × 73 move-slots = 4672.
 *   0–55  queen-like (8 dirs × 7 distances)
 *  56–63  knight moves
 *  64–72  under-promotions ((N,B,R) × (left, straight, right))
 *
 * Deltas are in encoder orientation: row 0 = rank 8, "up" = negative row delta.
 * Ported from lib/core/chess/ai/az119_policy.dart
 */

const POLICY_LEN = 4672;

const QUEEN_DIRS: readonly [number, number][] = [
  [0, 1], [1, 1], [1, 0], [1, -1],
  [0, -1], [-1, -1], [-1, 0], [-1, 1],
];

const KNIGHT_OFFSETS: readonly [number, number][] = [
  [-1, -2], [-2, -1], [-2, 1], [-1, 2],
  [1, 2], [2, 1], [2, -1], [1, -2],
];

/**
 * Convert a chess square like "e2" to a 0–63 index (a1=0, h8=63).
 */
export function squareToIndex(sq: string): number {
  const file = sq.charCodeAt(0) - 97; // a=0
  const rank = parseInt(sq[1], 10) - 1; // 1=0
  return rank * 8 + file;
}

/**
 * Convert a 0–63 index back to a square string like "e2".
 */
export function indexToSquare(idx: number): string {
  const file = idx % 8;
  const rank = (idx - file) / 8;
  return String.fromCharCode(97 + file) + (rank + 1);
}

/**
 * Compute the policy index for a move given as (fromIdx, toIdx, promotion?).
 * Matches the Dart `moveToIndex` exactly.
 */
export function moveToIndex(
  fromSq: string,
  toSq: string,
  promotion?: string,
): number {
  const from = squareToIndex(fromSq);
  const to = squareToIndex(toSq);
  const base = from * 73;

  // Encoder orientation: row 0 = rank 8
  const fr = 7 - Math.floor(from / 8);
  const fc = from % 8;
  const tr = 7 - Math.floor(to / 8);
  const tc = to % 8;
  const dr = tr - fr;
  const dc2 = tc - fc;

  // Under-promotions (non-queen): piece × 3 + (dc + 1)
  if (promotion && promotion !== "q") {
    const piece =
      promotion === "n" ? 0 : promotion === "b" ? 1 : 2; // N=0, B=1, R=2
    return base + 64 + piece * 3 + (dc2 + 1);
  }

  // Knight moves
  if (
    (Math.abs(dr) === 1 && Math.abs(dc2) === 2) ||
    (Math.abs(dr) === 2 && Math.abs(dc2) === 1)
  ) {
    const ki = KNIGHT_OFFSETS.findIndex(
      (o) => o[0] === dr && o[1] === dc2,
    );
    return base + 56 + ki;
  }

  // Queen-like moves: find direction + distance
  const d = Math.max(Math.abs(dr), Math.abs(dc2));
  const qd: [number, number] = [dr / d, dc2 / d];
  const qDirIdx = QUEEN_DIRS.findIndex(
    (q) => q[0] === qd[0] && q[1] === qd[1],
  );
  return base + qDirIdx * 7 + (d - 1);
}

/**
 * Decode a raw 4672-element policy logit array into per-legal-move scores.
 * Returns an array of { from, to, promotion?, score } sorted by score descending.
 */
export function decodePolicy(
  logits: Float32Array | number[],
  legalMoves: { from: string; to: string; promotion?: string }[],
): { from: string; to: string; promotion?: string; score: number }[] {
  const scored = legalMoves.map((m) => ({
    ...m,
    score: logits[moveToIndex(m.from, m.to, m.promotion)] ?? -Infinity,
  }));
  scored.sort((a, b) => b.score - a.score);
  return scored;
}

export { POLICY_LEN };
