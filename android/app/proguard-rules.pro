# ── Flutter / Dart ──────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**   { *; }
-keep class io.flutter.view.**   { *; }
-keep class io.flutter.**        { *; }
-keep class io.flutter.plugins.** { *; }

# ── ONNX Runtime ────────────────────────────────────────────────────
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# ── Flame ───────────────────────────────────────────────────────────
-keep class com.flame.** { *; }

# ── Keep the chess AI classes (reflection via method channel) ──────
-keep class com.arcadestarcade.starcade.** { *; }
