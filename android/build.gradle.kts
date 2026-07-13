import org.gradle.api.tasks.compile.JavaCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// geocoding_android still declares compileSdk 33, but its AndroidX
// dependencies (fragment 1.7.1, window 1.2.0, activity 1.8.1) require 34+,
// which fails checkDebugAarMetadata. Pin plugin modules to the SDK the app
// itself compiles against until the plugin catches up.
//
// This must run in afterEvaluate — the plugin's own `android { compileSdk 33 }`
// block is evaluated after its plugin is applied, so configuring at apply-time
// gets overwritten. It must also come before the evaluationDependsOn(":app")
// block below and skip :app, since that call evaluates :app eagerly and
// registering afterEvaluate on an already-evaluated project throws.
subprojects {
    if (name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.let { ext ->
                (ext as com.android.build.gradle.BaseExtension)
                    .compileSdkVersion(36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
