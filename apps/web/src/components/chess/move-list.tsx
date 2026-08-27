"use client";

import { useEffect, useRef } from "react";

interface MoveListProps {
  moves: string[];
}

export function MoveList({ moves }: MoveListProps) {
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [moves.length]);

  const pairs: string[] = [];
  for (let i = 0; i < moves.length; i += 2) {
    const num = Math.floor(i / 2) + 1;
    const white = moves[i];
    const black = i + 1 < moves.length ? moves[i + 1] : "";
    pairs.push(`${num}. ${white} ${black}`.trimEnd());
  }

  return (
    <div
      ref={scrollRef}
      className="h-[104px] rounded-cosmic-sm border border-surface-stroke bg-surface overflow-y-auto p-2.5"
    >
      {pairs.map((pair, i) => (
        <div key={i} className="font-body text-sm tabular-nums">
          {pair}
        </div>
      ))}
    </div>
  );
}
