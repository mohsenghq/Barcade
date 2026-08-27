import { Chess, type Move } from "chess.js";

export enum GameStatus {
  Playing = "playing",
  Checkmate = "checkmate",
  Stalemate = "stalemate",
  Draw = "draw",
}

/**
 * Stateful game wrapper around chess.js.
 * Mirrors the Dart GameState: tracks position, move history, FEN history
 * for repetition detection, and enforces promotion rules.
 */
export class GameState {
  private _chess: Chess;
  private _fenHistory: string[] = [];
  private _moves: Move[] = [];

  constructor(fen?: string) {
    this._chess = new Chess(fen);
    this._fenHistory.push(this.repetitionKey);
  }

  private get repetitionKey(): string {
    return this._chess.fen().split(" ").slice(0, 4).join(" ");
  }

  get fen(): string {
    return this._chess.fen();
  }

  get sideToMove(): "white" | "black" {
    return this._chess.turn() === "w" ? "white" : "black";
  }

  get isGameOver(): boolean {
    return this.status !== GameStatus.Playing;
  }

  get pgnMoves(): string[] {
    return this._moves.map((m) => m.from + m.to + (m.promotion ?? ""));
  }

  get fenHistory(): string[] {
    return [...this._fenHistory];
  }

  get legalMoves(): Move[] {
    return this._chess.moves({ verbose: true });
  }

  get status(): GameStatus {
    if (this._chess.isCheckmate()) return GameStatus.Checkmate;
    if (this._chess.isStalemate()) return GameStatus.Stalemate;
    if (this.isThreefoldRepetition || this.isFiftyMoveRule)
      return GameStatus.Draw;
    return GameStatus.Playing;
  }

  get isThreefoldRepetition(): boolean {
    const counts = new Map<string, number>();
    for (const f of this._fenHistory) {
      counts.set(f, (counts.get(f) ?? 0) + 1);
    }
    return (counts.get(this.repetitionKey) ?? 0) >= 3;
  }

  get isFiftyMoveRule(): boolean {
    const history = this._chess.history({ verbose: true });
    if (history.length === 0) return false;
    const last = history[history.length - 1];
    // chess.js tracks halfmoves internally; we check via FEN
    const halfmoves = parseInt(this.fen.split(" ")[4], 10);
    return halfmoves >= 100;
  }

  get drawReason(): string | null {
    if (this.isThreefoldRepetition) return "repetition";
    if (this.isFiftyMoveRule) return "50-move rule";
    return null;
  }

  makeMove(uci: string): boolean {
    if (uci.length < 4) return false;
    const from = uci.slice(0, 2);
    const to = uci.slice(2, 4);
    const promotion = uci.length === 5 ? uci[4] : undefined;

    // Reject bare pawn push to promotion rank without promotion piece
    const piece = this._chess.get(from as Square);
    if (
      piece?.type === "p" &&
      !promotion &&
      ((piece.color === "w" && to[1] === "8") ||
        (piece.color === "b" && to[1] === "1"))
    ) {
      return false;
    }

    try {
      const move = this._chess.move({ from, to, promotion });
      if (!move) return false;
      this._moves.push(move);
      this._fenHistory.push(this.repetitionKey);
      return true;
    } catch {
      return false;
    }
  }

  undoLast(): void {
    if (this._moves.length === 0) return;
    this._moves.pop();
    this._fenHistory.pop();
    // Replay from scratch
    const startFen = this._fenHistory[0];
    this._chess = new Chess(startFen);
    for (const m of this._moves) {
      this._chess.move(m);
    }
  }

  clone(): GameState {
    const gs = new GameState(this.fen);
    return gs;
  }
}

type Square =
  | "a1" | "a2" | "a3" | "a4" | "a5" | "a6" | "a7" | "a8"
  | "b1" | "b2" | "b3" | "b4" | "b5" | "b6" | "b7" | "b8"
  | "c1" | "c2" | "c3" | "c4" | "c5" | "c6" | "c7" | "c8"
  | "d1" | "d2" | "d3" | "d4" | "d5" | "d6" | "d7" | "d8"
  | "e1" | "e2" | "e3" | "e4" | "e5" | "e6" | "e7" | "e8"
  | "f1" | "f2" | "f3" | "f4" | "f5" | "f6" | "f7" | "f8"
  | "g1" | "g2" | "g3" | "g4" | "g5" | "g6" | "g7" | "g8"
  | "h1" | "h2" | "h3" | "h4" | "h5" | "h6" | "h7" | "h8";
