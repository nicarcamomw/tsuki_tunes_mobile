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

# Spotify App Remote SDK (spotify_sdk): its protocol messages are (de)serialized
# by reflection, so R8 must not strip or rename them.
-keep class com.spotify.** { *; }
-keep interface com.spotify.** { *; }
-dontwarn com.spotify.**
-keep class de.minimalme.spotify_sdk.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod
