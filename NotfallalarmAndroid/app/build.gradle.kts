import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.google.services)
}

// The real google-services.json belongs to the school's own Firebase project and is
// therefore not in Git. Without any file at all the Google Services plugin aborts the
// build, which would make the project impossible to open for anyone who just cloned it.
// So we fall back to the checked-in template and warn loudly; the app itself shows a
// red banner at runtime when it detects the placeholder project id.
val googleServicesFile = file("google-services.json")
if (!googleServicesFile.exists()) {
    val template = file("google-services.json.template")
    template.copyTo(googleServicesFile)
    logger.warn(
        "\n*** app/google-services.json was missing - the placeholder template was copied in.\n" +
            "*** Replace it with the file from your own Firebase project before building a release.\n"
    )
}

// Release signing is configured through keystore.properties, which is never committed.
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "de.dbo.alarm"
    compileSdk = 37

    defaultConfig {
        applicationId = "de.dbo.alarm"
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "1.0.0"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // No applicationIdSuffix on purpose: google-services.json is issued for exactly
            // one package name, and a ".debug" suffix would make every fresh clone fail with
            // "No matching client found" before anyone has written a line of code.
            versionNameSuffix = "-debug"
            isMinifyEnabled = false
        }
        release {
            // R8 is off on purpose: the whole delivery path lives in a foreground service
            // that is started from a push message, and a stripped stack trace in the
            // local error log would cost us the one clue we get when a phone stays silent.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    androidResources {
        // The interface is German only. Without this, every AndroidX and Compose
        // translation ends up in the APK for languages this app never speaks.
        localeFilters += listOf("de")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.splashscreen)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.process)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.datastore.preferences)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    debugImplementation(libs.androidx.compose.ui.tooling)

    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.auth)
    implementation(libs.firebase.firestore)
    implementation(libs.firebase.functions)
    implementation(libs.firebase.messaging)

    implementation(libs.kotlinx.coroutines.play.services)

    testImplementation(libs.junit)
}
