import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

val releaseStoreFile = (keystoreProperties["storeFile"] as String?)
    ?.takeIf { it.isNotBlank() }
    ?.let { path ->
        val normalizedPath = path.removePrefix("android/").removePrefix("/android/")
        val candidate = rootProject.file(path)
        val alternate = rootProject.file(normalizedPath)
        if (candidate.exists()) candidate else if (alternate.exists()) alternate else null
    }
    ?.takeIf { it.exists() }

if (releaseStoreFile == null) {
    throw GradleException(
        "Release signing config is invalid: create android/key.properties and ensure storeFile points to an existing keystore."
    )
}

android {
    namespace = "com.windowsdemeter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.windowsdemeter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            debugSymbolLevel 'SYMBOL_TABLE'
        }
    }

    signingConfigs {
        create("release") {
            storeFile = releaseStoreFile
            storePassword = keystoreProperties["storePassword"] as String?
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            uploadSymbols = true
        }
    }
}

flutter {
    source = "../.."
}
