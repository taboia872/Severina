plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    id("com.facebook.react")
}

extensions.configure<com.facebook.react.ReactExtension>("react") {
    autolinkLibrariesWithApp()
}

android {
    ndkVersion = rootProject.extra["ndkVersion"] as String
    buildToolsVersion = rootProject.extra["buildToolsVersion"] as String
    compileSdk = rootProject.extra["compileSdkVersion"] as Int

    namespace = "com.severina"

    defaultConfig {
        applicationId = "com.severina"
        minSdk = rootProject.extra["minSdkVersion"] as Int
        targetSdk = rootProject.extra["targetSdkVersion"] as Int
        versionCode = 1
        versionName = "1.0.0"
    }

    signingConfigs {
        create("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    implementation("com.facebook.react:react-android")
    implementation("com.facebook.react:hermes-android")
}
