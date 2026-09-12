import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material lives in android/key.properties, which is git-ignored — see
// key.properties.example. When it is absent (a fresh clone, CI without secrets) the
// release build falls back to the debug keys so `flutter run --release` still works, and
// says so, rather than failing the build.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val releaseKeystore = keystoreProperties.getProperty("storeFile")?.let(rootProject::file)
val hasReleaseKeystore = releaseKeystore?.exists() == true

android {
    namespace = "com.devaccess.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.devaccess.app"
        // A1 — minimum supported Android 7.0 (API 24), target the latest stable API.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // A2 / C6 — two distribution flavors.
    //   play : Play-policy compliant. No QUERY_ALL_PACKAGES, no free-form intent tester.
    //   foss : sideload / internal builds. Full package visibility + advanced tools.
    flavorDimensions += "distribution"
    productFlavors {
        create("play") {
            dimension = "distribution"
            buildConfigField("boolean", "FULL_ACCESS", "false")
            buildConfigField("String", "DISTRIBUTION", "\"play\"")
        }
        create("foss") {
            dimension = "distribution"
            applicationIdSuffix = ".foss"
            buildConfigField("boolean", "FULL_ACCESS", "true")
            buildConfigField("String", "DISTRIBUTION", "\"foss\"")
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "DevAccess: android/key.properties not found — signing the release " +
                        "build with the debug keys. This APK/AAB cannot be distributed.",
                )
                signingConfigs.getByName("debug")
            }
        }
    }

    packaging {
        resources.excludes += setOf("META-INF/*.kotlin_module")
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
