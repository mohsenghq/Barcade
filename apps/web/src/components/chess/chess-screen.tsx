"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  GameState,
  GameStatus,
  SaveController,
  SettingsService,
  type ChessProfile,
} from "@starcade/core";
import { ChessBoard } from "./chess-board";
import { ChessClock } from "./chess-clock";
import { MoveList } from "./move-list";
import { ResultDialog } from "./result-dialog";

interface ChessScreenProps {
  mode: "ai" | "hotseat";
  save: SaveController;
  settings: SettingsService;
  onNewGame: () => void;
  onBack: () => void;
}

export function ChessScreen({
  mode,
  save,
  settings,
  onNewGame,
  onBack,
}: ChessScreenProps) {
  const [gameState, setGameState] = useState(() => new GameState());
  const [ended, setEnded] = useState(false);
  const [isAiTurn, setIsAiTurn] = useState(false);
  const [whiteElapsed, setWhiteElapsed] = useState(0);
  const [blackElapsed, setBlackElapsed] = useState(0);
  const [clockHistory, setClockHistory] = useState<[number, number][]>([]);
  const [result, setResult] = useState<{
    title: string;
    subtitle?: string;
    moveCount: number;
  } | null>(null);
  const [showConfirm, setShowConfirm] = useState<
    { title: string; onConfirm: () => void } | null
  >(null);

  const gameStateRef = useRef(gameState);
  gameStateRef.current = gameState;

  // Clock ticker
  useEffect(() => {
    if (ended) return;
    const interval = setInterval(() => {
      if (gameStateRef.current.sideToMove === "white") {
        setWhiteElapsed((s) => s + 1);
      } else {
        setBlackElapsed((s) => s + 1);
      }
    }, 1000);
    return () => clearInterval(interval);
  }, [ended]);

  const checkGameEnd = useCallback(
    (gs: GameState) => {
      switch (gs.status) {
        case GameStatus.Checkmate: {
          const winner =
            gs.sideToMove === "white" ? "black" : "white";
          const subtitle =
            mode === "ai"
              ? winner === "white"
                ? "You won"
                : "AI won"
              : `${winner === "white" ? "White" : "Black"} wins`;
          setResult({
            title: "Checkmate",
            subtitle,
            moveCount: Math.ceil(gs.pgnMoves.length / 2),
          });
          setEnded(true);
          recordResult(gs, winner, false);
          break;
        }
        case GameStatus.Stalemate:
          setResult({
            title: "Stalemate",
            moveCount: Math.ceil(gs.pgnMoves.length / 2),
          });
          setEnded(true);
          recordResult(gs, null, true);
          break;
        case GameStatus.Draw:
          setResult({
            title: gs.drawReason
              ? `Draw by ${gs.drawReason}`
              : "Draw",
            moveCount: Math.ceil(gs.pgnMoves.length / 2),
          });
          setEnded(true);
          recordResult(gs, null, true);
          break;
        default:
          break;
      }
    },
    [mode],
  );

  const recordResult = useCallback(
    (gs: GameState, winner: string | null, isDraw: boolean) => {
      if (mode === "hotseat") return;
      const p = save.profile;
      const humanWin = !isDraw && winner === "white" ? 1 : 0;
      const humanLoss = !isDraw && winner === "black" ? 1 : 0;
      const draw = isDraw ? 1 : 0;
      save.replaceProfile({
        ...p,
        wins: p.wins + humanWin,
        losses: p.losses + humanLoss,
        draws: p.draws + draw,
        aiWins: p.aiWins + humanLoss,
        aiLosses: p.aiLosses + humanWin,
        aiDraws: p.aiDraws + draw,
      });
    },
    [mode, save],
  );

  const handleUserMove = useCallback(
    (uci: string) => {
      if (isAiTurn || ended) return;
      const gs = gameStateRef.current;
      if (!gs.makeMove(uci)) return;
      setClockHistory((h) => [...h, [whiteElapsed, blackElapsed]]);
      setGameState(new GameState(gs.fen)); // trigger re-render
      checkGameEnd(gs);
    },
    [isAiTurn, ended, whiteElapsed, blackElapsed, checkGameEnd],
  );

  const handleRematch = useCallback(() => {
    setResult(null);
    setGameState(new GameState());
    setEnded(false);
    setIsAiTurn(false);
    setWhiteElapsed(0);
    setBlackElapsed(0);
    setClockHistory([]);
  }, []);

  const handleConfirm = useCallback(
    (title: string, onConfirm: () => void) => {
      setShowConfirm({ title, onConfirm });
    },
    [],
  );

  const playerBar = (
    name: string,
    side: "white" | "black",
    active: boolean,
  ) => (
    <div className="flex items-center gap-3">
      <span className="font-display font-bold text-sm flex-1 truncate">
        {name}
      </span>
      <ChessClock
        elapsed={side === "white" ? whiteElapsed : blackElapsed}
        active={active}
      />
    </div>
  );

  const bottomName = mode === "ai" ? "You" : "White";
  const topName = mode === "ai" ? "AI" : "Black";
  const whiteActive = !ended && gameState.sideToMove === "white";
  const blackActive = !ended && gameState.sideToMove === "black";

  return (
    <div className="min-h-screen flex flex-col p-4 md:p-6">
      <div className="flex flex-col gap-3 max-w-lg mx-auto w-full flex-1">
        {/* Top player bar */}
        {playerBar(topName, "black", blackActive)}

        {/* Board */}
        <div className="flex-1 flex items-center justify-center">
          <ChessBoard
            gameState={gameState}
            onMove={handleUserMove}
            flipped={false}
            humanColor={mode === "ai" ? "white" : gameState.sideToMove}
          />
        </div>

        {/* Bottom player bar */}
        {playerBar(bottomName, "white", whiteActive)}

        {/* Move list */}
        <MoveList moves={gameState.pgnMoves} />

        {/* Controls */}
        <div className="flex justify-around py-2">
          <button
            onClick={() => {
              if (mode !== "hotseat" || ended) return;
              if (clockHistory.length > 0) {
                const [w, b] = clockHistory[clockHistory.length - 1];
                setWhiteElapsed(w);
                setBlackElapsed(b);
                setClockHistory((h) => h.slice(0, -1));
              }
              gameState.undoLast();
              setGameState(new GameState(gameState.fen));
            }}
            disabled={mode !== "hotseat" || ended}
            className="text-sm font-display text-cosmic/70 disabled:text-cosmic/30 hover:text-cosmic transition-colors"
          >
            Undo
          </button>
          <button
            onClick={() => {
              const legal = gameState.legalMoves;
              if (legal.length > 0) {
                alert(`Hint: ${legal[0].from}${legal[0].to}${legal[0].promotion ?? ""}`);
              }
            }}
            disabled={isAiTurn}
            className="text-sm font-display text-cosmic/70 disabled:text-cosmic/30 hover:text-cosmic transition-colors"
          >
            Hint
          </button>
          <button
            onClick={() =>
              handleConfirm("Agree to a draw?", () => {
                setShowConfirm(null);
                setResult({
                  title: "Draw",
                  moveCount: Math.ceil(gameState.pgnMoves.length / 2),
                });
                setEnded(true);
                recordResult(gameStateRef.current, null, true);
              })
            }
            disabled={ended}
            className="text-sm font-display text-cosmic/70 disabled:text-cosmic/30 hover:text-cosmic transition-colors"
          >
            Draw
          </button>
          <button
            onClick={() =>
              handleConfirm("Resign the game?", () => {
                setShowConfirm(null);
                const winner =
                  mode === "ai" || gameStateRef.current.sideToMove === "white"
                    ? "black"
                    : "white";
                const subtitle =
                  mode === "ai"
                    ? winner === "black"
                      ? "AI won"
                      : "You won"
                    : `${winner === "white" ? "White" : "Black"} wins`;
                setResult({
                  title: subtitle,
                  moveCount: Math.ceil(
                    gameStateRef.current.pgnMoves.length / 2,
                  ),
                });
                setEnded(true);
                recordResult(gameStateRef.current, winner, false);
              })
            }
            disabled={ended}
            className="text-sm font-display text-cosmic/70 disabled:text-cosmic/30 hover:text-cosmic transition-colors"
          >
            Resign
          </button>
        </div>
      </div>

      {/* Result dialog */}
      {result && (
        <ResultDialog
          title={result.title}
          subtitle={result.subtitle}
          moveCount={result.moveCount}
          onRematch={handleRematch}
          onNewGame={onNewGame}
        />
      )}

      {/* Confirm dialog */}
      {showConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-indigo-light rounded-cosmic p-6 max-w-sm w-full mx-4 animate-pop-in">
            <h3 className="font-display font-bold text-lg text-center mb-6">
              {showConfirm.title}
            </h3>
            <div className="flex gap-3 justify-end">
              <button
                onClick={() => setShowConfirm(null)}
                className="btn-ghost text-sm px-5 py-2"
              >
                Cancel
              </button>
              <button
                onClick={showConfirm.onConfirm}
                className="btn-primary text-sm px-5 py-2"
              >
                Confirm
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
