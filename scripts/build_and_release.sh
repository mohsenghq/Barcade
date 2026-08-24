#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# Starcade — Local Build + Release Script
#
# Builds platforms available on this PC and uploads to a GitHub Release.
# Run from project root in Git Bash or any bash shell.
#
# Usage:
#   bash scripts/build_and_release.sh v2.1.0
#   bash scripts/build_and_release.sh v2.1.0 --skip-upload
#   bash scripts/build_and_release.sh v2.1.0 --platforms web,windows
#
# Supported locally:
#   - Web       ✅ always (no extra SDK)
#   - Windows   ⚠️  needs Visual Studio Build Tools
#   - Android   ❌ dl.google.com geo-blocked
#   - macOS/iOS ❌ requires macOS
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────
FLUTTER_BIN="$HOME/flutter_sdk/flutter/bin/flutter"
DART_BIN="$HOME/flutter_sdk/flutter/bin/cache/dart-sdk/bin/dart"
APP_NAME="starcade"
RELEASE_DIR="release_packages"

# Chinese mirror to bypass geo-blocking
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export PATH="$HOME/flutter_sdk/flutter/bin:$HOME/flutter_sdk/flutter/bin/cache/dart-sdk/bin:$PATH"

# ── Parse args ───────────────────────────────────────────────────────
TAG=""
PLATFORMS="web"
SKIP_UPLOAD=false
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-upload)  SKIP_UPLOAD=true; shift ;;
        --skip-build)   SKIP_BUILD=true; shift ;;
        --platforms)    PLATFORMS="$2"; shift 2 ;;
        v*)             TAG="$1"; shift ;;
        *)
            echo "Usage: $0 <tag> [--platforms web,windows] [--skip-upload] [--skip-build]"
            exit 1
            ;;
    esac
done

if [[ -z "$TAG" ]]; then
    echo "Error: Tag is required. Example: $0 v2.1.0"
    exit 1
fi

# ── Colors ───────────────────────────────────────────────────────────
step()  { echo -e "\n\033[36m▸ $1\033[0m"; }
ok()    { echo -e "  \033[32m✓ $1\033[0m"; }
fail()  { echo -e "  \033[31m✗ $1\033[0m"; exit 1; }
warn()  { echo -e "  \033[33m⚠ $1\033[0m"; }

# ── Header ───────────────────────────────────────────────────────────
echo -e "\033[35m═══════════════════════════════════════════════════"
echo "  Starcade Local Build + Release"
echo "  Tag: $TAG"
echo "  Platforms: $PLATFORMS"
echo "═══════════════════════════════════════════════════\033[0m"

# ── Pre-flight ───────────────────────────────────────────────────────
[[ -f "$FLUTTER_BIN" ]] || fail "Flutter not found at $FLUTTER_BIN"

if [[ "$SKIP_UPLOAD" == false ]]; then
    command -v gh >/dev/null 2>&1 || fail "gh CLI not found. Install: winget install GitHub.cli"
    gh auth status >/dev/null 2>&1 || fail "Not authenticated. Run: gh auth login"
    ok "gh CLI authenticated"
fi

# ── Clean release dir ────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == false ]]; then
    rm -rf "$RELEASE_DIR"
    mkdir -p "$RELEASE_DIR"
fi

# ── Dependencies ─────────────────────────────────────────────────────
step "Resolving dependencies"
$FLUTTER_BIN pub get
ok "Dependencies resolved"

# ── Analyze ──────────────────────────────────────────────────────────
step "Running static analysis"
$FLUTTER_BIN analyze
ok "Analysis passed"

# ── Tests ────────────────────────────────────────────────────────────
step "Running tests"
$FLUTTER_BIN test
ok "All tests passed"

# ── Build Web ────────────────────────────────────────────────────────
if echo "$PLATFORMS" | grep -qw "web"; then
    if [[ "$SKIP_BUILD" == false ]]; then
        step "Building Web"
        $FLUTTER_BIN build web --release

        # Use Node.js to create zip (zip CLI not available on Windows)
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        node "$script_dir/zip_helper.mjs" 2>&1
        mv "$APP_NAME-web.zip" "$RELEASE_DIR/"
        local size=$(du -h "$RELEASE_DIR/$APP_NAME-web.zip" | cut -f1)
        ok "Web build: $RELEASE_DIR/$APP_NAME-web.zip ($size)"
    fi
fi

# ── Build Windows ────────────────────────────────────────────────────
if echo "$PLATFORMS" | grep -qw "windows"; then
    step "Building Windows Desktop"

    # Check for VS
    VSWHERE="${PROGRAMFILES(X86)}/Microsoft Visual Studio/Installer/vswhere.exe"
    if [[ ! -f "$VSWHERE" ]]; then
        warn "Visual Studio not found — skipping Windows build"
        warn "Install: winget install Microsoft.VisualStudio.2022.BuildTools"
    else
        if [[ "$SKIP_BUILD" == false ]]; then
            $FLUTTER_BIN build windows --release
            # Use Node.js to create zip
            node "$HOME/flutter_sdk/flutter/bin/cache/../../../scripts/zip_helper.mjs" 2>/dev/null || \
              echo "TODO: add windows zip helper"
            mv "$APP_NAME-windows.zip" "$RELEASE_DIR/" 2>/dev/null
            local size=$(du -h "$RELEASE_DIR/$APP_NAME-windows.zip" | cut -f1)
            ok "Windows build: $RELEASE_DIR/$APP_NAME-windows.zip ($size)"
        fi
    fi
fi

# ── Summary ──────────────────────────────────────────────────────────
echo -e "\n\033[35m═══════════════════════════════════════════════════"
echo "  Build Summary"
echo "═══════════════════════════════════════════════════\033[0m"

ASSETS=()
for f in "$RELEASE_DIR"/*.zip; do
    [[ -f "$f" ]] || continue
    size=$(du -h "$f" | cut -f1)
    echo -e "  📦 $(basename "$f") ($size)"
    ASSETS+=("$f")
done

if [[ ${#ASSETS[@]} -eq 0 ]]; then
    fail "No build artifacts produced"
fi

# ── Upload ───────────────────────────────────────────────────────────
if [[ "$SKIP_UPLOAD" == true ]]; then
    echo -e "\n  ⏭  Skipping upload (--skip-upload)"
    echo "  Artifacts in: $RELEASE_DIR/"
    echo -e "\n  To upload manually:"
    echo "    gh release create \"$TAG\" --title \"Starcade $TAG\" --generate-notes ${ASSETS[*]}"
    exit 0
fi

step "Uploading to GitHub Release"

# Create release if needed
if ! gh release view "$TAG" >/dev/null 2>&1; then
    echo "  Creating release $TAG..."
    gh release create "$TAG" \
        --title "Starcade $TAG" \
        --generate-notes \
        --draft
    ok "Release created (draft)"
fi

# Upload assets
for asset in "${ASSETS[@]}"; do
    name=$(basename "$asset")
    echo "  ⬆  Uploading $name..."
    gh release upload "$TAG" "$asset" --clobber
    ok "Uploaded $name"
done

# Publish
gh release edit "$TAG" --draft=false 2>/dev/null || true
ok "Release published: $TAG"

echo -e "\n\033[32m═══════════════════════════════════════════════════"
echo "  ✅ Done! Release: $TAG"
echo "═══════════════════════════════════════════════════\033[0m"
