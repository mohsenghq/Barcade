#!/usr/bin/env bash
# Source this file before any `flutter` / `dart pub` command.
#
# Google-fronted hosts (pub.dev, storage.googleapis.com, dl.google.com) are
# geo-blocked from this build location. The official China mirrors and the
# Iranian national mirror (archive.ito.gov.ir) are reachable instead.
# See docs/research/00-environment.md for the probe results.
#
# Usage:  source tool/env.sh

export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PATH="$HOME/flutter/bin:$PATH"

echo "[env] PUB_HOSTED_URL=$PUB_HOSTED_URL"
echo "[env] FLUTTER_STORAGE_BASE_URL=$FLUTTER_STORAGE_BASE_URL"
