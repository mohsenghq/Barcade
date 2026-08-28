#!/usr/bin/env node
/**
 * Copies the trained chess AI model into apps/web/public/ so the React
 * web app can load it at runtime via fetch().
 *
 * Usage: node tool/fetch_web_model.mjs
 *
 * Prerequisites: assets/ai/chess_net.onnx must exist (run dart run tool/fetch_net.dart first).
 */

import { existsSync, mkdirSync, copyFileSync, statSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..");
const FLUTTER_MODEL = join(ROOT, "assets", "ai", "chess_net.onnx");
const WEB_PUBLIC = join(ROOT, "apps", "web", "public", "chess_net.onnx");

if (!existsSync(FLUTTER_MODEL)) {
  console.error(
    "❌ Model not found at assets/ai/chess_net.onnx\n" +
      "   Run: dart run tool/fetch_net.dart\n" +
      "   Or place chess_net.onnx manually in assets/ai/"
  );
  process.exit(1);
}

mkdirSync(dirname(WEB_PUBLIC), { recursive: true });
copyFileSync(FLUTTER_MODEL, WEB_PUBLIC);

const sizeMB = (statSync(WEB_PUBLIC).size / (1024 * 1024)).toFixed(1);
console.log(`✅ Copied chess_net.onnx (${sizeMB} MB) → apps/web/public/`);
