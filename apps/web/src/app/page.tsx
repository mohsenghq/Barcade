"use client";

import { useEffect, useState } from "react";
import {
  SaveController,
  LocalStorageSave,
  SettingsService,
  type ChessProfile,
  defaultChessProfile,
} from "@starcade/core";
import { ChessScreen } from "@/components/chess/chess-screen";
import { PlayModeSheet } from "@/components/chess/play-mode-sheet";

export default function Home() {
  const [save] = useState(() => new SaveController(new LocalStorageSave()));
  const [settings] = useState(() => {
    const s = new SettingsService();
    if (typeof window !== "undefined") s.load();
    return s;
  });
  const [profile, setProfile] = useState<ChessProfile>(defaultChessProfile());
  const [view, setView] = useState<"launcher" | "mode" | "chess">("launcher");
  const [playMode, setPlayMode] = useState<"ai" | "hotseat" | null>(null);

  useEffect(() => {
    save.load().then((result) => {
      setProfile(result.profile);
    });
    return save.onChange(setProfile);
  }, [save]);

  const handleOpenChess = () => setView("mode");

  const handleModeSelected = (mode: "ai" | "hotseat") => {
    setPlayMode(mode);
    setView("chess");
  };

  const handleNewGame = () => setView("mode");

  const handleBack = () => setView("launcher");

  if (view === "chess" && playMode) {
    return (
      <ChessScreen
        mode={playMode}
        save={save}
        settings={settings}
        onNewGame={handleNewGame}
        onBack={handleBack}
      />
    );
  }

  return (
    <div className="min-h-screen flex flex-col p-5 md:p-8">
      <h1 className="font-display font-extrabold text-3xl md:text-4xl animate-fade-slide-in">
        Starcade
      </h1>

      <div className="mt-8 md:mt-10 animate-pop-in">
        <button
          onClick={handleOpenChess}
          className="btn-ghost w-full min-h-[104px] flex items-center justify-center gap-4"
        >
          <div className="w-12 h-12 rounded-cosmic-sm bg-mint/18 flex items-center justify-center flex-shrink-0">
            <span className="text-mint text-2xl">♜</span>
          </div>
          <div className="text-left">
            <div className="font-display font-bold text-lg">Chess</div>
            <div className="font-body text-xs text-cosmic/55">
              Wins: {profile.wins}
            </div>
          </div>
        </button>
      </div>

      <p className="mt-5 text-center text-sm text-cosmic/55 animate-fade-slide-in font-body">
        More games coming soon
      </p>

      {view === "mode" && (
        <PlayModeSheet
          onSelect={handleModeSelected}
          onClose={() => setView("launcher")}
        />
      )}
    </div>
  );
}
