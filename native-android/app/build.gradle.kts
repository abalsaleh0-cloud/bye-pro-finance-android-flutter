plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.byepro.bye_pro_finance"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.byepro.bye_pro_finance"
        minSdk = 30
        targetSdk = 36
        versionCode = 155
        versionName = "1.1.54"
        testInstrumentationRunner = "android.test.InstrumentationTestRunner"
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".nativepreview"
            versionNameSuffix = "-native-preview"
        }
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}


dependencies {
    testImplementation("junit:junit:4.13.2")
}
