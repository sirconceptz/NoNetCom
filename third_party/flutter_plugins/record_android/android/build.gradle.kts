group = "com.llfbandit.record"
version = "1.0"

/*
 * Flutter 3.44 scans plugin Gradle files for KGP markers and otherwise applies
 * kotlin-android programmatically. Keep this marker until Flutter stops doing
 * that; the plugin itself uses AGP 9 Built-in Kotlin.
plugins {
    id("kotlin-android")
}
 */

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.2.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.llfbandit.record"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 23
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
