## Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

## Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

## Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

## Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

## Google Play Core (deferred components)
-dontwarn com.google.android.play.core.**

## OkHttp / networking
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

## Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

## Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

## Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# audio_service (media session / playback notification)
-keep class com.ryanheise.audioservice.** { *; }

# flutter_local_notifications (Gson-serialized notification details)
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

# workmanager (background release radar)
-keep class dev.fluttercommunity.workmanager.** { *; }
