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

    buildTypes {
        release {
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = Properties()
                keystoreProperties.load(keystorePropertiesFile.inputStream())

                val storeFilePath =
                    keystoreProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }
                val storePassword =
                    keystoreProperties.getProperty("storePassword")?.takeIf { it.isNotBlank() }
                val keyAlias = keystoreProperties.getProperty("keyAlias")?.takeIf { it.isNotBlank() }
                val keyPassword =
                    keystoreProperties.getProperty("keyPassword")?.takeIf { it.isNotBlank() }

                if (storeFilePath == null ||
                    storePassword == null ||
                    keyAlias == null ||
                    keyPassword == null
                ) {
                    throw GradleException("android/key.properties is missing required fields (storeFile, storePassword, keyAlias, keyPassword).")
                }

                val releaseSigningConfig =
                    signingConfigs.findByName("release") ?: signingConfigs.create("release")
                releaseSigningConfig.storeFile = file(storeFilePath)
                releaseSigningConfig.storePassword = storePassword
                releaseSigningConfig.keyAlias = keyAlias
                releaseSigningConfig.keyPassword = keyPassword

                signingConfig = releaseSigningConfig
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
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
