import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Keep release signing compatible with the Flutter app. The same keystore,
// alias and credentials are used so an eventual Native release can update the
// installed application without changing package identity or signing lineage.
val releaseSigningProperties = Properties()
val flutterAndroidRoot = rootProject.projectDir.parentFile.resolve("android")
val flutterAndroidApp = flutterAndroidRoot.resolve("app")
val releaseSigningPropertiesFile = flutterAndroidRoot.resolve("key.properties")
if (releaseSigningPropertiesFile.isFile) {
    releaseSigningPropertiesFile.inputStream().use(releaseSigningProperties::load)
}

fun releaseSigningValue(environmentName: String, propertiesName: String): String? =
    System.getenv(environmentName)?.takeIf { it.isNotBlank() }
        ?: releaseSigningProperties.getProperty(propertiesName)?.takeIf { it.isNotBlank() }

val releaseStorePath = releaseSigningValue("KEYSTORE_PATH", "storeFile")
val releaseStorePassword = releaseSigningValue("KEYSTORE_PASSWORD", "storePassword")
val releaseKeyPassword = releaseSigningValue("KEY_PASSWORD", "keyPassword")
val releaseKeyAlias = releaseSigningValue("KEY_ALIAS", "keyAlias")
val releaseSigningConfigured = listOf(
    releaseStorePath,
    releaseStorePassword,
    releaseKeyPassword,
    releaseKeyAlias
).all { !it.isNullOrBlank() }

val resolvedReleaseStoreFile = releaseStorePath?.let { configuredPath ->
    val file = File(configuredPath)
    if (file.isAbsolute) file else File(flutterAndroidApp, configuredPath)
}

val validateReleaseSigning = tasks.register("validateReleaseSigning") {
    doLast {
        if (!releaseSigningConfigured) {
            throw GradleException(
                "Release signing is not configured. Set KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_PASSWORD, and KEY_ALIAS, or configure android/key.properties."
            )
        }
        val store = requireNotNull(resolvedReleaseStoreFile)
        if (!store.isFile) {
            throw GradleException(
                "Release keystore file does not exist at the configured KEYSTORE_PATH/storeFile."
            )
        }
    }
}

tasks.configureEach {
    if (name == "assembleRelease" || name == "bundleRelease") {
        dependsOn(validateReleaseSigning)
    }
}

android {
    namespace = "com.byepro.bye_pro_finance"
    compileSdk = 36

    defaultConfig {
        // Must remain identical to the installed Flutter application's ID.
        applicationId = "com.byepro.bye_pro_finance"
        minSdk = 30
        targetSdk = 36
        versionCode = 156
        versionName = "1.1.55"
        testInstrumentationRunner = "android.test.InstrumentationTestRunner"
    }

    if (releaseSigningConfigured) {
        signingConfigs {
            create("release") {
                storeFile = requireNotNull(resolvedReleaseStoreFile)
                storePassword = requireNotNull(releaseStorePassword)
                keyPassword = requireNotNull(releaseKeyPassword)
                keyAlias = requireNotNull(releaseKeyAlias)
            }
        }
    }

    buildTypes {
        debug {
            // Preview cannot replace the production app or access its sandbox.
            applicationIdSuffix = ".nativepreview"
            versionNameSuffix = "-native-preview"
        }
        release {
            isMinifyEnabled = false
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
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
