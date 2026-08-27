import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Starcade",
  description: "A cosmic hub of offline mini-games, starting with chess.",
  icons: { icon: "/icon.png" },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <div className="cosmic-bg min-h-screen">
          <Motes />
          <main className="relative z-10">{children}</main>
        </div>
      </body>
    </html>
  );
}

/** Floating cyan motes behind every screen. */
function Motes() {
  const motes = Array.from({ length: 24 }, (_, i) => ({
    id: i,
    x: ((i * 7919) % 100),
    y: ((i * 104729) % 100),
    size: 1.5 + ((i * 31) % 25) / 10,
    opacity: 0.25 + ((i * 17) % 55) / 100,
    delay: ((i * 13) % 22),
  }));

  return (
    <div className="motes">
      {motes.map((m) => (
        <div
          key={m.id}
          className="mote"
          style={{
            left: `${m.x}%`,
            top: `${m.y}%`,
            width: m.size * 3,
            height: m.size * 3,
            opacity: m.opacity,
            animationDelay: `${m.delay}s`,
          }}
        />
      ))}
    </div>
  );
}
