#!/usr/bin/env bash
# Headless-Chrome screenshot of the built web app, for visual QA.
# Usage:
#   tool/screenshot.sh [route] [out.png] [width] [height]
#     route    fragment path, e.g. 'hub' or 'game/gravity_bloom'  (default: hub)
#     out.png  output file path                                    (default: /tmp/shot.png)
#     width    viewport width in px                                (default: 1080)
#     height   viewport height in px                               (default: 1920)
set -euo pipefail
cd "$(dirname "$0")/.."
ROUTE="${1:-hub}"
OUT="${2:-/tmp/shot.png}"
W="${3:-1080}"
H="${4:-1920}"

if [ ! -d build/web ]; then
  echo "build/web missing — run: flutter build web"
  exit 1
fi

# Serve quietly in the background and screenshot after the app boots.
python3 -m http.server 8099 --directory build/web >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT

# Give the app time to boot and paint.
sleep 2
google-chrome --headless=new --disable-gpu --no-sandbox \
  --window-size="${W},${H}" \
  --virtual-time-budget=6000 \
  --screenshot="$OUT" \
  "http://localhost:8099/#$ROUTE" >/dev/null 2>&1 || true

if [ -f "$OUT" ]; then
  echo "screenshot -> $OUT ($(stat -c%s "$OUT") bytes)"
else
  echo "screenshot failed"
  exit 1
fi
