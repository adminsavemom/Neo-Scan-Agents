# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate

# Keep Flutter and its plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keep class shared_preferences_android.** { *; }

# MediaPipe / Gemma rules
-keep class com.google.mediapipe.** { *; }
-keep class com.google.tensorflow.** { *; }
-keep class com.google.flatbuffers.** { *; }
-keep class io.github.v7lin.flutter_gemma.** { *; }

# Suppress warnings
-dontwarn io.flutter.embedding.**
-dontwarn com.google.mediapipe.**
-dontwarn com.google.flatbuffers.**