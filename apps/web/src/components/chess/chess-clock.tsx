"use client";

interface ChessClockProps {
  elapsed: number; // seconds
  active: boolean;
}

export function ChessClock({ elapsed, active }: ChessClockProps) {
  const mm = String(Math.floor(elapsed / 60) % 60).padStart(2, "0");
  const ss = String(elapsed % 60).padStart(2, "0");

  return (
    <span
      className={`font-body text-sm tabular-nums ${
        active ? "text-cosmic" : "text-cosmic/55"
      }`}
    >
      <span className="mr-1">{active ? "⏱" : "◷"}</span>
      {mm}:{ss}
    </span>
  );
}
