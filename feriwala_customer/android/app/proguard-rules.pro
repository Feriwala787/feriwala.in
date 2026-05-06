# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Keep model classes
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# OkHttp / HTTP
-dontwarn okhttp3.**
-dontwarn okio.**

# Socket.IO
-keep class io.socket.** { *; }
-dontwarn io.socket.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Permission handler
-keep class com.baseflow.permissionhandler.** { *; }

# Keep enums
-keepclassmembers enum * { *; }
