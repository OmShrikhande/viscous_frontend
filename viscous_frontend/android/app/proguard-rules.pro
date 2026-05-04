# Optional Play Core / deferred components (referenced by embedding; not used by typical apps)
-dontwarn com.google.android.play.core.**

# Flutter / engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Gson / reflective models (common in plugins)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
