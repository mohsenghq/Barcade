"use client";

import { useEffect, useRef } from "react";
import type { GameState } from "@starcade/core";
import { Chessground } from "chessground";
import type { Api } from "chessground/api";
import type { Color, Key } from "chessground/types";
import { Chess } from "chess.js";
import "chessground/assets/chessground.base.css";
import "chessground/assets/chessground.brown.css";
import "chessground/assets/chessground.cburnett.css";

interface ChessBoardProps {
  gameState: GameState;
  onMove: (uci: string) => void;
  flipped?: boolean;
}

const BOARD_THEMES: Record<string, { light: string; dark: string }> = {
  nebula: { light: "#2E2454", dark: "#191238" },
  wood: { light: "#F0D9B6", dark: "#B58863" },
  blue: { light: "#DEE3E6", dark: "#8CA2AD" },
};

export function ChessBoard({
  gameState,
  onMove,
  flipped,
}: ChessBoardProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const apiRef = useRef<Api | null>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    const chess = new Chess(gameState.fen);
    const orientation: Color = flipped ? "black" : "white";
    const turn: Color = chess.turn() === "w" ? "white" : "black";

    // Build legal moves map
    const moves = chess.moves({ verbose: true });
    const dests = new Map<Key, Key[]>();
    for (const move of moves) {
      const from = move.from as Key;
      const to = move.to as Key;
      if (!dests.has(from)) dests.set(from, []);
      dests.get(from)!.push(to);
    }

    const theme = BOARD_THEMES.nebula;

    if (apiRef.current) {
      apiRef.current.set({
        fen: gameState.fen,
        orientation,
        turnColor: turn,
        movable: {
          color: flipped ? "black" : "white",
          dests,
          events: {
            after: (orig, dest, capturedPiece) => {
              // Handle promotion
              const move = moves.find(
                (m) => m.from === orig && m.to === dest,
              );
              if (move?.promotion) {
                onMove(`${orig}${dest}${move.promotion}`);
              } else {
                onMove(`${orig}${dest}`);
              }
            },
          },
        },
        highlight: {
          lastMove: true,
          check: true,
        },
        animation: {
          duration: 200,
        },
      });
    } else {
      apiRef.current = Chessground(containerRef.current, {
        fen: gameState.fen,
        orientation,
        turnColor: turn,
        coordinates: true,
        highlight: {
          lastMove: true,
          check: true,
        },
        animation: {
          duration: 200,
        },
        movable: {
          color: flipped ? "black" : "white",
          free: false,
          dests,
          showDests: true,
          events: {
            after: (orig, dest) => {
              const move = moves.find(
                (m) => m.from === orig && m.to === dest,
              );
              if (move?.promotion) {
                onMove(`${orig}${dest}${move.promotion}`);
              } else {
                onMove(`${orig}${dest}`);
              }
            },
          },
        },
        draggable: {
          showGhost: true,
        },
      });
    }

    return () => {
      apiRef.current?.destroy();
      apiRef.current = null;
    };
  }, [gameState.fen, flipped, onMove, gameState]);

  return (
    <div className="chessboard-wrapper">
      <div
        ref={containerRef}
        className="w-full h-full"
        style={
          {
            "--cg-light": BOARD_THEMES.nebula.light,
            "--cg-dark": BOARD_THEMES.nebula.dark,
          } as React.CSSProperties
        }
      />
    </div>
  );
}
