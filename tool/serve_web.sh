#!/usr/bin/env bash
# Serve the built web app locally for manual / headless testing.
# Usage:  tool/serve_web.sh [port]     (default 8080)
set -euo pipefail
cd "$(dirname "$0")/.."
PORT="${1:-8080}"
if [ ! -d build/web ]; then
  echo "build/web missing — run: flutter build web"
  exit 1
fi
echo "Serving build/web on http://localhost:$PORT"
exec python3 -m http.server "$PORT" --directory build/web
