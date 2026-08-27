import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Cosmic Toybox palette
        indigo: {
          DEFAULT: "#1B1533",
          deep: "#130E24",
          light: "#241A45",
        },
        coral: {
          DEFAULT: "#FF5A5F",
          hot: "#FF7A72",
        },
        cyan: "#29E0E0",
        gold: "#FFC53D",
        mint: "#3DDC97",
        ember: "#FF4D6D",
        ink: "#0B0817",
        cosmic: "#F6F3FF",
        surface: "rgba(255,255,255,0.08)",
        "surface-strong": "rgba(255,255,255,0.14)",
        "surface-stroke": "rgba(255,255,255,0.18)",
      },
      fontFamily: {
        display: ["Nunito", "system-ui", "sans-serif"],
        body: ["Inter", "system-ui", "sans-serif"],
      },
      borderRadius: {
        cosmic: "20px",
        "cosmic-sm": "12px",
      },
      boxShadow: {
        glow: "0 6px 24px rgba(255,90,95,0.4)",
      },
      animation: {
        "pop-in": "popIn 520ms cubic-bezier(0.34,1.56,0.64,1) both",
        "fade-slide-in": "fadeSlideIn 260ms ease-out both",
        "mote-drift": "moteDrift 22s linear infinite",
      },
      keyframes: {
        popIn: {
          "0%": { transform: "scale(0.6)", opacity: "0" },
          "100%": { transform: "scale(1)", opacity: "1" },
        },
        fadeSlideIn: {
          "0%": { transform: "translateY(12px)", opacity: "0" },
          "100%": { transform: "translateY(0)", opacity: "1" },
        },
        moteDrift: {
          "0%": { transform: "translateY(0)" },
          "100%": { transform: "translateY(-100%)" },
        },
      },
    },
  },
  plugins: [],
};

export default config;
