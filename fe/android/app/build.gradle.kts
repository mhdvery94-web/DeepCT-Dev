plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.go.brin.neutronct"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Reverse-DNS of the institution that owns the app. Changing this
        // after a release installs a second copy alongside the first rather
        // than updating it, so it had to be settled before distribution.
        applicationId = "id.go.brin.neutronct"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// The release APK leaves this machine under the product's name, not Gradle's.
//
// It cannot be done with `outputFileName`. Flutter's own Gradle plugin copies
// the APK into `build/app/outputs/flutter-apk/` and renames it to
// `app-<build-mode>.apk` on the way — that name is built from the variant, not
// read from the output, so setting `outputFileName` only renames the earlier
// copy under `outputs/apk/release/`.
//
// Renaming the file instead of copying it is not an option either: after Gradle
// returns, `flutter build apk` looks for `app-release.apk` by that exact name
// and exits with "Gradle build failed to produce an .apk file" if it is gone.
// So the copy stays and the named one sits beside it.
//
// `finalizedBy` rather than `doLast`: the plugin adds its copy as a `doLast` on
// assembleRelease during `afterEvaluate`, and an action registered here could
// land ahead of it and run before the file exists.
val renameReleaseApk by tasks.registering {
    description = "Copies the release APK to app-deepCT-ai.apk."
    doLast {
        val outputs = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
        val built = File(outputs, "app-release.apk")
        if (built.exists()) {
            built.copyTo(File(outputs, "app-deepCT-ai.apk"), overwrite = true)
        } else {
            logger.warn("No app-release.apk in $outputs — nothing renamed.")
        }
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy(renameReleaseApk)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
