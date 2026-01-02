plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Namespace must be declared here (NOT in AndroidManifest.xml)
    namespace = "com.nicaraguaninaverde.theapp"

    // Use Flutterâ€™s provided SDK/NDK values
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
        // Application ID (separate from namespace)
        applicationId = "com.nicaraguaninaverde.theapp"

        // SDK levels and versioning passed through from Flutter
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // Debug builds should NOT shrink or obfuscate
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // You can replace this with a proper release signing config later
            signingConfig = signingConfigs.getByName("debug")

            // Enable code + resource shrinking for optimized release builds
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}


