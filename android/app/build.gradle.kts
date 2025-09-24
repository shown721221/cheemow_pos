import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.tasks.Copy

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

    // 讀取 key.properties (若建立了正式簽署憑證則啟用 release 簽署)
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProps = Properties()
    if (keystorePropertiesFile.exists()) {
        try {
            FileInputStream(keystorePropertiesFile).use { fis ->
                keystoreProps.load(fis)
            }
        } catch (_: Exception) {}
    }

    signingConfigs {
        if (sharedDebugKeystore.exists()) {
            create("sharedDebug") {
                storeFile = sharedDebugKeystore
                storePassword = "android"
                keyAlias = "AndroidDebugKey"
                keyPassword = "android"
            }
        }
        if (keystorePropertiesFile.exists() &&
            keystoreProps["storeFile"] != null &&
            keystoreProps["storePassword"] != null &&
            keystoreProps["keyAlias"] != null &&
            keystoreProps["keyPassword"] != null) {
            create("releaseSigning") {
                val storePath = keystoreProps["storeFile"].toString()
                storeFile = if (storePath.startsWith("/")) file(storePath) else file(storePath)
                storePassword = keystoreProps["storePassword"].toString()
                keyAlias = keystoreProps["keyAlias"].toString()
                keyPassword = keystoreProps["keyPassword"].toString()
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
            // 若存在 releaseSigning 則使用，否則 fallback 到 sharedDebug / debug
            signingConfig = when {
                signingConfigs.findByName("releaseSigning") != null -> signingConfigs.getByName("releaseSigning")
                sharedDebugKeystore.exists() -> signingConfigs.getByName("sharedDebug")
                else -> signingConfigs.getByName("debug")
            }
            // 依需求可開啟：minifyEnabled / shrinkResources
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// (Removed rename hook to keep Flutter build stable)

flutter {
    source = "../.."
}
