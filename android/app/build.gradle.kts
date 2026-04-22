import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "delivero.com"
    compileSdk = flutter.compileSdkVersion
    // Work around broken/partial NDK install on this machine.
    // Use an NDK version that exists under `$ANDROID_SDK_ROOT/ndk/`.
    ndkVersion = "30.0.14904198"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "delivero.com"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val hasKeystoreProperties = keystorePropertiesFile.exists()
    val isReleaseTask = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }

    val releaseSigningConfig = run {
        val cfg = signingConfigs.findByName("release") ?: signingConfigs.create("release")

        if (hasKeystoreProperties) {
            val keystoreProperties = Properties().apply {
                load(keystorePropertiesFile.inputStream())
            }

            val storeFilePath = keystoreProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }
            val storePassword = keystoreProperties.getProperty("storePassword")?.takeIf { it.isNotBlank() }
            val keyAlias = keystoreProperties.getProperty("keyAlias")?.takeIf { it.isNotBlank() }
            val keyPassword = keystoreProperties.getProperty("keyPassword")?.takeIf { it.isNotBlank() }

            if (storeFilePath == null || storePassword == null || keyAlias == null || keyPassword == null) {
                throw GradleException(
                    "android/key.properties is missing required fields (storeFile, storePassword, keyAlias, keyPassword). " +
                        "Copy android/key.properties.example to android/key.properties and fill it in."
                )
            }

            cfg.storeFile = rootProject.file(storeFilePath)
            cfg.storePassword = storePassword
            cfg.keyAlias = keyAlias
            cfg.keyPassword = keyPassword
        } else {
            // Keep the release signing config deterministic for local dev tooling (e.g. `signingReport`)
            // when no real upload keystore is configured.
            cfg.storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
            cfg.storePassword = "android"
            cfg.keyAlias = "AndroidDebugKey"
            cfg.keyPassword = "android"
        }
        cfg
    }

    buildTypes {
        release {
            if (!hasKeystoreProperties && isReleaseTask) {
                throw GradleException(
                    "android/key.properties was not found, so a release build would be signed with the debug key. " +
                        "Create android/key.properties (copy from android/key.properties.example) and point it to your upload keystore."
                )
            }
            signingConfig = releaseSigningConfig
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
