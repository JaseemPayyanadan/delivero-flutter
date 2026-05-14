import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.nio.charset.StandardCharsets
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
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
        // Required by flutter_local_notifications (and other plugins) for
        // java.time APIs on older Android versions.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "delivero.com"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            isDefault = true
        }
        create("prod") {
            dimension = "env"
            applicationId = "webnhue.delivero"
        }
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val hasKeystoreProperties = keystorePropertiesFile.exists()
    val isReleaseTask = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }

    val releaseSigningConfig = run {
        val cfg = signingConfigs.findByName("release") ?: signingConfigs.create("release")

        if (hasKeystoreProperties) {
            val keystoreProperties = Properties().apply {
                keystorePropertiesFile.reader(StandardCharsets.UTF_8).use { load(it) }
            }

            val storeFilePath =
                keystoreProperties.getProperty("storeFile")?.trim()?.takeIf { it.isNotBlank() }
            val storePassword =
                keystoreProperties.getProperty("storePassword")?.trim()?.takeIf { it.isNotBlank() }
                    ?: System.getenv("DELIVERO_STORE_PASSWORD")?.trim()?.takeIf { it.isNotEmpty() }
            val keyAlias =
                keystoreProperties.getProperty("keyAlias")?.trim()?.takeIf { it.isNotBlank() }
            val keyPasswordExplicit =
                keystoreProperties.getProperty("keyPassword")?.trim()?.takeIf { it.isNotBlank() }
                    ?: System.getenv("DELIVERO_KEY_PASSWORD")?.trim()?.takeIf { it.isNotEmpty() }

            if (storeFilePath == null || storePassword == null || keyAlias == null) {
                throw GradleException(
                    "android/key.properties: set storeFile, keyAlias, and storePassword " +
                        "(or export DELIVERO_STORE_PASSWORD). " +
                        "Verify: keytool -list -v -keystore android/app/<storeFile> -alias <keyAlias>"
                )
            }

            val keyPassword = keyPasswordExplicit ?: storePassword

            cfg.storeFile = rootProject.file(storeFilePath)
            val storeType =
                keystoreProperties.getProperty("storeType")?.trim()?.takeIf { it.isNotBlank() } ?: "pkcs12"
            cfg.storeType = storeType
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
