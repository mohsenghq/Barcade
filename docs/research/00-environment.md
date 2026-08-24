# Environment & Build-Feasibility Findings (researched 2026-08-11)

This document records the actual build environment, the network constraints that shaped
the technical decisions, and the exact mirror configuration required to reproduce the
build. It is **primary-source research**, verified by live probes, not assumption.

## Machine

| Item | Value |
|------|-------|
| OS | Ubuntu 24.04 (kernel 6.8.0-136-generic), x86_64 |
| CPU / RAM | 8 cores / 19 GiB (≈8.7 GiB available at build time) |
| Disk | 377 GiB free |
| Display | X server on `:1` (no Wayland); Chrome installed → headless screenshots possible |
| KVM | present → an Android emulator would be possible, but no emulator images are available |
| sudo | **password-required** → no system package installs (no `apt install`) |
| Java | OpenJDK 21.0.11 (sufficient for AGP/Flutter Android tooling) |
| Node / npm | v22.23.1 / npm (registry.npmjs.org reachable) |
| Python | 3.10 (venv) |

## Network constraints (the decisive factor)

Google-fronted hosts are **geo-blocked from this location**. Live probes returned:

| Endpoint | Result |
|----------|--------|
| `pub.dev` | 403 for **all** paths (homepage included) |
| `dl.google.com/android/repository/*` | 404 for every SDK artifact (cmdline-tools, platform-tools, platforms, build-tools) |
| `dl.google.com/dl/android/maven2/*` | 404 |
| `maven.google.com/*` | unreachable |
| `storage.googleapis.com/flutter_infra_release/*` | HTTP 200 status but body `AccessDenied … not available in your location` (geo-ACL) |
| `storage.flutter-io.cn/*` (official China mirror) | **200 — works** |
| `pub.flutter-io.cn/*` (official China pub mirror) | **200 — works** |
| `github.com`, `api.github.com`, release assets | **200 — works** |
| `services.gradle.org` | 307 → GitHub release assets → 200 — **works** |
| `repo1.maven.org` (Maven Central) | **200 — works** |
| `archive.ito.gov.ir` (Iranian national mirror) | **200 — works**; mirrors Google Maven, Maven Central, Gradle dists, Flutter pub packages, Ubuntu/Debian, etc. |
| `maven.aliyun.com/repository/google` and `/central` | **200 — works** (used as fallback) |

Chinese university mirrors (Tsinghua, USTC, SJTU, NJU) are reachable but now **geo-deny
non-China IPs** for the Android SDK paths (403), so they were not usable.

## What this means for builds

| Build target | Feasible in THIS environment | How |
|---|---|---|
| Flutter **web** (playable artifact) | ✅ verified | `flutter build web` succeeded; serves CanvasKit |
| **Widget / golden / integration tests** | ✅ verified | `flutter test` runs headless |
| **Visual QA screenshots** | ✅ verified | headless Chrome `--screenshot` on the web build |
| Android **APK / AAB** | ❌ not locally (SDK unobtainable) | dl.google.com geo-blocked → cannot fetch Android SDK (`platforms`, `build-tools`, `licenses`). **Produced via GitHub Actions CI** (runners are not geo-blocked). Exact workflow + manual procedure documented. |
| Windows / macOS / iOS | ❌ not locally | need those OSes (cross-compile not supported by Flutter); produced via CI matrix on native runners |
| Linux desktop | ❌ not locally | needs `libgtk-3-dev`, `clang`, `ninja` (sudo blocked); produced via CI on an ubuntu runner |

> Honest reporting: **no APK/desktop/iOS binary was produced in this session**. The web
> build, the full test suite, and screenshot-verified UI are the locally produced,
> tested artifacts. CI workflows are written to produce the native builds on push.

## Toolchain install (for reproducibility)

```bash
# 1. Flutter SDK 3.44.9 (Dart 3.12.2), installed at ~/flutter
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
curl -L -o /tmp/flutter.tar.xz \
  "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.9-stable.tar.xz"
tar xf /tmp/flutter.tar.xz -C ~
export PATH="$HOME/flutter/bin:$PATH"

# 2. Permanent mirror config (must be set BEFORE any `flutter`/`dart pub` command)
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

Both variables are set automatically by `tool/env.sh` in this repo.

## Gradle / Maven config for Android builds (used by CI and documented in BUILD_GUIDE.md)

For a future build where the Android SDK exists, point Gradle at reachable mirrors:

```kotlin
// android/build.gradle.kts or settings.gradle.kts — mirror block
repositories {
  maven { url = uri("https://archive.ito.gov.ir/maven/google") }        // Google Maven
  maven { url = uri("https://archive.ito.gov.ir/maven/central") }       // Maven Central
  maven { url = uri("https://maven.aliyun.com/repository/google") }     // fallbacks
  maven { url = uri("https://maven.aliyun.com/repository/central") }
}
```

Gradle distributions resolve via `services.gradle.org` (works). AGP + Kotlin + AndroidX
artifacts resolve via the Google Maven mirror. This is exercised only by CI or on a
machine with an SDK, since this machine cannot obtain the SDK itself.
