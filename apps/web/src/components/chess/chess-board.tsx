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
  humanColor?: "white" | "black";
}

const BOARD_THEMES: Record<string, { light: string; dark: string }> = {
  nebula: { light: "#2E2454", dark: "#191238" },
  wood: { light: "#F0D9B6", dark: "#B58863" },
  blue: { light: "#DEE3E6", dark: "#8CA2AD" },
};

function buildDests(fen: string) {
  const chess = new Chess(fen);
  const moves = chess.moves({ verbose: true });
  const dests = new Map<Key, Key[]>();
  for (const move of moves) {
    const from = move.from as Key;
    const to = move.to as Key;
    if (!dests.has(from)) dests.set(from, []);
    dests.get(from)!.push(to);
  }
  return { dests, moves, turn: chess.turn() as "w" | "b" };
}

export function ChessBoard({
  gameState,
  onMove,
  flipped,
  humanColor = "white",
}: ChessBoardProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const apiRef = useRef<Api | null>(null);
  const onMoveRef = useRef(onMove);
  onMoveRef.current = onMove;
  const flippedRef = useRef(flipped);
  flippedRef.current = flipped;
  const humanColorRef = useRef(humanColor);
  humanColorRef.current = humanColor;

  // Init chessground ONCE on mount
  useEffect(() => {
    if (!containerRef.current) return;

    const { dests, turn } = buildDests(gameState.fen);
    const orientation: Color = flipped ? "black" : "white";

    apiRef.current = Chessground(containerRef.current, {
      fen: gameState.fen,
      orientation,
      turnColor: turn as Color,
      coordinates: true,
      highlight: {
        lastMove: true,
        check: true,
      },
      animation: {
        duration: 200,
      },
      movable: {
        color: humanColor,
        free: false,
        dests,
        showDests: true,
        events: {
          after: (orig, dest) => {
            const chess = new Chess(gameState.fen);
            const moves = chess.moves({ verbose: true });
            const move = moves.find(
              (m) => m.from === orig && m.to === dest,
            );
            if (move?.promotion) {
              onMoveRef.current(`${orig}${dest}${move.promotion}`);
            } else {
              onMoveRef.current(`${orig}${dest}`);
            }
          },
        },
      },
      draggable: {
        showGhost: true,
      },
    });

    return () => {
      apiRef.current?.destroy();
      apiRef.current = null;
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Update position when fen changes (after a move)
  useEffect(() => {
    if (!apiRef.current) return;
    const { dests, turn } = buildDests(gameState.fen);
    const movableColor = humanColorRef.current;
    apiRef.current.set({
      fen: gameState.fen,
      turnColor: turn as Color,
      movable: {
        color: movableColor,
        dests,
        events: {
          after: (orig, dest) => {
            const chess = new Chess(gameState.fen);
            const moves = chess.moves({ verbose: true });
            const move = moves.find(
              (m) => m.from === orig && m.to === dest,
            );
            if (move?.promotion) {
              onMoveRef.current(`${orig}${dest}${move.promotion}`);
            } else {
              onMoveRef.current(`${orig}${dest}`);
            }
          },
        },
      },
    });
  }, [gameState.fen]);

  return (
    <div className="chessboard-wrapper">
      <div
        ref={containerRef}
        className="w-full h-full"
        style=
          {
            {
              "--cg-light": BOARD_THEMES.nebula.light,
              "--cg-dark": BOARD_THEMES.nebula.dark,
            } as React.CSSProperties
          }
      />
    </div>
  );
}
