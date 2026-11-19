import org.gradle.api.tasks.Copy

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.ashur.app"
    // Required by flutter_local_notifications and permission_handler Android plugins.
    compileSdk = 37
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 10
        versionName = "1.0.9"
        multiDexEnabled = true

        // Network configuration
        manifestPlaceholders["networkSecurityConfig"] = "@xml/network_security_config"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            isMinifyEnabled = true
            isShrinkResources = true

            // Performance optimizations
            ndk {
                debugSymbolLevel = "FULL"
            }
        }

        debug {
            // Enable debugging and disable minification
            isMinifyEnabled = false
            isShrinkResources = false

            // Performance profiling
            isDebuggable = true
        }
    }

    // Fix for mobile_scanner
    packaging {
        jniLibs {
            pickFirsts.add("**/libc++_shared.so")
            pickFirsts.add("**/libjsc.so")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.0.0"))
    implementation("androidx.multidex:multidex:2.0.1")

    implementation("com.google.android.gms:play-services-base:18.2.0")
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    implementation("com.google.android.gms:play-services-location:21.0.1")

    // استخدام app-update بدلاً من core القديم
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:app-update-ktx:2.1.0")

    // Core library desugaring - required for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Flutter 3.50+ CLI expects the release APK at:
//   <project>/build/app/outputs/flutter-apk/app-release.apk
// (see flutter_tools getApkDirectory). The Flutter Gradle Plugin copies APKs into:
//   <project>/android/app/build/outputs/flutter-apk/
// Mirror them so `flutter build apk` discovers the artifact.
val flutterApkSource = File("${project.buildDir}/outputs/flutter-apk")
val flutterApkDestination = File("${rootProject.projectDir.parentFile}/build/app/outputs/flutter-apk")
tasks.register<Copy>("syncFlutterApks") {
    from(flutterApkSource)
    into(flutterApkDestination)
    onlyIf { flutterApkSource.exists() && flutterApkSource.listFiles()?.isNotEmpty() == true }
}
gradle.projectsEvaluated {
    tasks.named("assembleRelease") {
        finalizedBy(tasks.named("syncFlutterApks"))
    }
}
