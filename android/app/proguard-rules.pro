# Add project-specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in the Android SDK tools.

# Preserve app-specific classes
-keep class com.naren.NESmartConnect.** { *; }
-keep class com.naren.NESmartConnect.MainActivity { *; }

# Preserve Flutter and AndroidX
-keep class io.flutter.** { *; }
-keep class androidx.** { *; }

# Preserve HTTP and OkHttp (used by http package)
-dontwarn okio.**
-dontwarn okhttp3.**
-keep class okio.** { *; }
-keep class okhttp3.** { *; }

# Preserve SharedPreferences
-keep class com.google.android.shared.** { *; }

# Preserve PermissionHandler
-keep class com.baseflow.permissionhandler.** { *; }

# Preserve Google Play Core classes for Flutter embedding
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**