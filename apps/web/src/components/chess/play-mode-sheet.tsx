"use client";

interface PlayModeSheetProps {
  onSelect: (mode: "ai" | "hotseat") => void;
  onClose: () => void;
}

interface ModeEntry {
  id: string;
  icon: string;
  title: string;
  subtitle?: string;
  enabled: boolean;
}

const modes: ModeEntry[] = [
  { id: "hotseat", icon: "👥", title: "Hotseat", enabled: true },
  { id: "ai", icon: "🤖", title: "vs AI", subtitle: "Training model — basic opponent", enabled: true },
  { id: "local", icon: "👨‍👩‍👧‍👦", title: "Local multiplayer", subtitle: "Next update", enabled: false },
  { id: "online", icon: "🔒", title: "Online — locked", enabled: false },
];

export function PlayModeSheet({ onSelect, onClose }: PlayModeSheetProps) {
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/50" onClick={onClose} />

      {/* Sheet */}
      <div className="relative w-full max-w-lg bg-indigo-light rounded-t-[20px] p-5 pb-8 animate-fade-slide-in">
        <div className="flex flex-col gap-1">
          {modes.map((mode) => (
            <button
              key={mode.id}
              disabled={!mode.enabled}
              onClick={() => mode.enabled && onSelect(mode.id as "ai" | "hotseat")}
              className={`flex items-center gap-4 p-4 rounded-cosmic-sm text-left transition-colors ${
                mode.enabled
                  ? "hover:bg-surface-strong cursor-pointer"
                  : "opacity-40 cursor-not-allowed"
              }`}
            >
              <span className="text-xl">{mode.icon}</span>
              <div className="flex-1">
                <div className="font-display font-bold">{mode.title}</div>
                {mode.subtitle && (
                  <div className="text-sm text-cosmic/55 font-body">
                    {mode.subtitle}
                  </div>
                )}
              </div>
              {mode.enabled && (
                <span className="text-cosmic/55 text-lg">›</span>
              )}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
