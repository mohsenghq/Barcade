/**
 * Web chess AI: runs the trained RL model via ONNX Runtime Web.
 *
 * Uses a single-pass policy evaluation (no MCTS) for browser speed.
 * The model picks the legal move with the highest policy logit score.
 *
 * Setup:
 * 1. Place chess_net.onnx in apps/web/public/
 * 2. The model is fetched on first use and cached.
 */

import { Chess } from "chess.js";
import { encodeFen } from "./az119-encoder";
import { decodePolicy } from "./az119-policy";
import type { GameState } from "./game-state";

// Lazy-loaded ORT session
let _sessionPromise: Promise<any> | null = null;
let _sessionReady = false;

async function loadSession(): Promise<any> {
  if (_sessionPromise) return _sessionPromise;

  _sessionPromise = (async () => {
    try {
      // Dynamic import so the chunk is only loaded when AI is used
      const ort = await import("onnxruntime-web");

      // Use WASM backend (most compatible)
      ort.env.wasm.numThreads = navigator.hardwareConcurrency ?? 2;

      const response = await fetch("/chess_net.onnx");
      if (!response.ok) {
        throw new Error(
          `Failed to fetch model: ${response.status} ${response.statusText}`,
        );
      }
      const modelBytes = await response.arrayBuffer();
      const session = await ort.InferenceSession.create(modelBytes, {
        executionProviders: ["wasm"],
      });
      _sessionReady = true;
      return session;
    } catch (err) {
      console.error("[WebChessAI] Failed to load ONNX model:", err);
      _sessionPromise = null; // allow retry
      throw err;
    }
  })();

  return _sessionPromise;
}

/**
 * Evaluate a position using the ONNX model.
 * Returns { policy: scored moves, value }.
 */
async function evaluate(fen: string): Promise<{
  scoredMoves: { from: string; to: string; promotion?: string; score: number }[];
  value: number;
}> {
  const session = await loadSession();
  const chess = new Chess(fen);

  // Encode position → [1, 119, 8, 8]
  const inputTensor = encodeFen(fen);

  // Run inference
  const inputName = session.inputNames[0];
  const outputNames = session.outputNames;

  const feeds: Record<string, any> = {};
  // onnxruntime-web wants Float32Array with explicit dims
  feeds[inputName] = new Float32Array(inputTensor);

  const results = await session.run(feeds);

  // Extract policy logits (4672 values)
  const policyOutput = results["policy_logits"] ?? results[outputNames[0]];
  const policyData = policyOutput?.data;
  if (!policyData) {
    throw new Error("No policy output from model");
  }

  // Extract value
  const valueOutput = results["value"] ?? results[outputNames[1]];
  const valueData = valueOutput?.data;
  const value = valueData ? valueData[0] : 0;

  // Get legal moves and decode policy
  const moves = chess.moves({ verbose: true });
  const scoredMoves = decodePolicy(policyData as Float32Array, moves);

  return { scoredMoves, value };
}

/**
 * ChessAI implementation for the web.
 * Loads the trained ONNX model and picks moves via single-pass policy evaluation.
 */
export class WebChessAI {
  private _ready: Promise<boolean>;

  constructor() {
    this._ready = loadSession()
      .then(() => true)
      .catch(() => false);
  }

  get ready(): Promise<boolean> {
    return this._ready;
  }

  get isReadySync(): boolean {
    return _sessionReady;
  }

  /**
   * Choose a move for the current position.
   * Returns the UCI string (e.g. "e2e4") or null if the model isn't available.
   */
  async chooseMove(game: GameState): Promise<string | null> {
    try {
      const { scoredMoves } = await evaluate(game.fen);
      if (scoredMoves.length === 0) return null;

      // Pick the move with highest policy score
      const best = scoredMoves[0];
      const promo = best.promotion ? best.promotion : "";
      return `${best.from}${best.to}${promo}`;
    } catch (err) {
      console.error("[WebChessAI] chooseMove failed:", err);
      return null;
    }
  }
}

export const webChessAI = new WebChessAI();
