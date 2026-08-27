# ── Flutter / Dart ──────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**   { *; }
-keep class io.flutter.view.**   { *; }
-keep class io.flutter.**        { *; }
-keep class io.flutter.plugins.** { *; }

# ── Play Core (referenced by Flutter but not bundled in the app) ─────
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ── ONNX Runtime ────────────────────────────────────────────────────
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# ── Flame ───────────────────────────────────────────────────────────
-keep class com.flame.** { *; }

# ── Keep the chess AI classes (reflection via method channel) ──────
-keep class com.arcadestarcade.starcade.** { *; }
