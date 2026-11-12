import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningPropertiesFile = rootProject.file("key.properties")
if (releaseSigningPropertiesFile.exists()) {
    releaseSigningPropertiesFile.inputStream().use(releaseSigningProperties::load)
}

fun releaseSigningValue(environmentName: String, propertiesName: String): String? =
    System.getenv(environmentName)?.takeIf { it.isNotBlank() }
        ?: releaseSigningProperties.getProperty(propertiesName)?.takeIf { it.isNotBlank() }

val releaseStoreFile = releaseSigningValue("KEYSTORE_PATH", "storeFile")
val releaseStorePassword = releaseSigningValue("KEYSTORE_PASSWORD", "storePassword")
val releaseKeyPassword = releaseSigningValue("KEY_PASSWORD", "keyPassword")
val releaseKeyAlias = releaseSigningValue("KEY_ALIAS", "keyAlias")
val releaseSigningConfigured = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyPassword,
    releaseKeyAlias,
).all { !it.isNullOrBlank() }

val validateReleaseSigning = tasks.register("validateReleaseSigning") {
    doLast {
        if (!releaseSigningConfigured) {
            throw GradleException(
                "Release signing is not configured. Set KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_PASSWORD, and KEY_ALIAS environment variables, or configure android/key.properties."
            )
        }
        val storePath = requireNotNull(releaseStoreFile)
        if (!file(storePath).isFile) {
            throw GradleException("Release keystore file does not exist at the configured KEYSTORE_PATH/storeFile.")
        }
    }
}

tasks.configureEach {
    if (name == "assembleRelease" || name == "bundleRelease") {
        dependsOn(validateReleaseSigning)
    }
}

android {
    namespace = "com.example.expense_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.byepro.bye_pro_finance"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (releaseSigningConfigured) {
        signingConfigs {
            create("release") {
                storeFile = file(requireNotNull(releaseStoreFile))
                storePassword = requireNotNull(releaseStorePassword)
                keyPassword = requireNotNull(releaseKeyPassword)
                keyAlias = requireNotNull(releaseKeyAlias)
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
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
