plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cheemeow.pos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
    applicationId = "com.cheemeow.pos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Optional: use a shared debug keystore checked into the repo to keep the
    // same signature across machines (mac/win). Place the file at
    // android/keystore/debug.keystore with default android debug creds.
    val sharedDebugKeystore = file("keystore/debug.keystore")

    signingConfigs {
        if (sharedDebugKeystore.exists()) {
            create("sharedDebug") {
                storeFile = sharedDebugKeystore
                storePassword = "android"
                keyAlias = "AndroidDebugKey"
                keyPassword = "android"
            }
        }
    }

    buildTypes {
        debug {
            // Prefer shared debug keystore if present; fallback to default debug
            if (sharedDebugKeystore.exists()) {
                signingConfig = signingConfigs.getByName("sharedDebug")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
        release {
            // For CI/local quick runs we sign release with debug config unless
            // a proper release signing is configured via key.properties.
            if (sharedDebugKeystore.exists()) {
                signingConfig = signingConfigs.getByName("sharedDebug")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
