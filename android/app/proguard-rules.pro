# Flutter embedding rules to prevent JNI call optimization errors
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native Drift/SQLite components
-keep class net.sqlcipher.** { *; }
-keep class org.sqlite.** { *; }

# Biometric / local_auth plugin rules
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.FragmentActivity { *; }

# Keep timezone package classes
-keep class com.jakewharton.threetenabp.** { *; }

# Ignore missing Play Core split-install classes referenced by Flutter's deferred components feature
-dontwarn com.google.android.play.core.**
