plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tsuki.tsuki_tunes_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.15729638"

    compileOptions {
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tsuki.tsuki_tunes_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Runs integration_test/ on a phone (Firebase Test Lab): see
        // src/androidTest/.../MainActivityTest.java.
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // Two environments of the same app, side by side on a phone:
    // - dev: its own id, name and Firebase project (tsuki-tunes-dev,
    //   src/dev/google-services.json), and its own link schemes, so
    //   nothing it does reaches real users' data.
    // - prod: what users install (same id as always), Firebase project
    //   tsuki-tunes-web (google-services.json beside this file).
    // flutter run/build pick dev unless told --flavor prod (pubspec.yaml).
    buildFeatures {
        resValues = true // the flavors' app_name
    }
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Tsuki DEV")
            manifestPlaceholders["deepLinkScheme"] = "tsukitunes-dev"
            manifestPlaceholders["spotifyAuthScheme"] = "com.tsuki.tsukitunesmobile.dev"
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Tsuki Tunes")
            manifestPlaceholders["deepLinkScheme"] = "tsukitunes"
            manifestPlaceholders["spotifyAuthScheme"] = "com.tsuki.tsukitunesmobile"
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled = true
                nativeSymbolUploadEnabled = true
            }
            // Release key when android/key.properties exists (see README);
            // debug key otherwise so local release builds keep working.
            // Remember to add the release key's SHA-1/SHA-256 in Firebase,
            // or Google Sign-In fails with the release build.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // The versions the integration_test plugin already brings to debug
    // builds: Gradle requires the test APK to use the very same ones.
    androidTestImplementation("androidx.test:runner:1.3.0")
    androidTestImplementation("androidx.test:rules:1.2.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.3.0")
}
