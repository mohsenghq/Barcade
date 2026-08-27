/**
 * AZ119 plane encoder for chess positions.
 * Encodes a FEN into a Float32Array of shape [1, 119, 8, 8] for the ONNX model.
 *
 * Plane layout (v1):
 *  - 7 piece planes per color × 6 piece types = 84 (indices 0-83)
 *  - 12 castling right planes (84-95)
 *  - 1 en-passant plane (96)
 *  - 2 repetition count planes (97-98)
 *  - 19 remaining: constant 1 for position encoding (99-118)
 */

const PIECE_ORDER = ["p", "n", "b", "r", "q", "k"] as const;
const FILES = "abcdefgh";

export function encodeFen(fen: string): Float32Array {
  const input = new Float32Array(1 * 119 * 8 * 8);

  const parts = fen.split(" ");
  const board = parts[0];
  const castling = parts[2] ?? "-";
  const enPassant = parts[3] ?? "-";
  const halfmoves = parseInt(parts[4] ?? "0", 10);

  // Piece planes: 12 planes (6 pieces × 2 colors)
  const rows = board.split("/");
  for (let rank = 0; rank < 8; rank++) {
    let file = 0;
    for (const ch of rows[rank]) {
      if (ch >= "1" && ch <= "8") {
        file += parseInt(ch, 10);
      } else {
        const isBlack = ch === ch.toLowerCase();
        const pieceIdx = PIECE_ORDER.indexOf(ch.toLowerCase() as (typeof PIECE_ORDER)[number]);
        const planeIdx = (isBlack ? 6 : 0) + pieceIdx;
        const flatIdx = planeIdx * 64 + rank * 8 + file;
        input[flatIdx] = 1;
        file++;
      }
    }
  }

  // Castling planes (12 planes, indices 84-95)
  const castlingPieces = ["K", "Q", "k", "q", "A", "B", "C", "D", "E", "F", "G", "H"];
  for (let i = 0; i < castling.length && i < 4; i++) {
    if (castling[i] !== "-") {
      const idx = castlingPieces.indexOf(castling[i]);
      if (idx >= 0) {
        const planeBase = (84 + idx) * 64;
        for (let j = 0; j < 64; j++) input[planeBase + j] = 1;
      }
    }
  }

  // En-passant plane (96)
  if (enPassant !== "-") {
    const fileIdx = FILES.indexOf(enPassant[0]);
    const rankIdx = parseInt(enPassant[1], 10) - 1;
    if (fileIdx >= 0 && rankIdx >= 0) {
      const planeBase = 96 * 64;
      for (let r = 0; r < 8; r++) {
        input[planeBase + r * 8 + fileIdx] = 1;
      }
    }
  }

  // Repetition planes (97-98)
  if (halfmoves > 0) {
    const planeBase = 97 * 64;
    for (let j = 0; j < 64; j++) input[planeBase + j] = halfmoves / 100;
  }

  // Constant 1 planes (99-118)
  const constBase = 99 * 64;
  for (let j = 0; j < 19 * 64; j++) input[constBase + j] = 1;

  return input;
}
