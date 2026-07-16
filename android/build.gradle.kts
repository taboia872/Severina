buildscript {
    extra["buildToolsVersion"] = "36.0.0"
    extra["minSdkVersion"] = 24
    extra["compileSdkVersion"] = 36
    extra["targetSdkVersion"] = 36
    extra["ndkVersion"] = "27.1.12297006"
    extra["kotlinVersion"] = "2.1.20"
    
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.facebook.react:react-native-gradle-plugin")
    }
}

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("$rootDir/../node_modules/react-native/android") }
    }
}

apply(plugin = "com.facebook.react.rootproject")
