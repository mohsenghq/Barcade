"use client";

import { useEffect, useState } from "react";

interface ResultDialogProps {
  title: string;
  subtitle?: string;
  moveCount: number;
  onRematch: () => void;
  onNewGame: () => void;
}

export function ResultDialog({
  title,
  subtitle,
  moveCount,
  onRematch,
  onNewGame,
}: ResultDialogProps) {
  const [enabled, setEnabled] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => setEnabled(true), 1000);
    return () => clearTimeout(timer);
  }, []);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-indigo-light rounded-cosmic p-6 max-w-sm w-full mx-4 animate-pop-in">
        <h2 className="font-display font-bold text-xl text-center">{title}</h2>
        {subtitle && (
          <p className="font-display font-bold text-center text-gold mt-2">
            {subtitle}
          </p>
        )}
        <p className="font-body text-xs text-cosmic/70 text-center mt-2">
          {moveCount === 1 ? "1 move" : `${moveCount} moves`}
        </p>
        <div className="flex gap-3 justify-end mt-6">
          <button
            onClick={onNewGame}
            disabled={!enabled}
            className="btn-ghost text-sm px-5 py-2 disabled:opacity-40"
          >
            New game
          </button>
          <button
            onClick={onRematch}
            disabled={!enabled}
            className="btn-primary text-sm px-5 py-2 disabled:opacity-40"
          >
            Rematch
          </button>
        </div>
      </div>
    </div>
  );
}
