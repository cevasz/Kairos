import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kairos.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kairos.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // La firma de las versiones. Una actualización solo se instala encima de
    // la app si va firmada con la misma clave; si no, Android obliga a
    // desinstalar y eso borra los datos. Por eso las compilaciones de GitHub
    // (android/key.properties, que escribe el workflow desde sus secretos)
    // usan la misma clave con la que se firmó la app que ya está en el
    // teléfono. Sin ese archivo, en local, se firma como siempre.
    val keyProperties = Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }
    signingConfigs {
        if (keyProperties.getProperty("storeFile") != null) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    // Dos canales de la misma app, instalables uno junto al otro (§51):
    //   prod  «Kairós»      la estable: la que se comparte y se publica en
    //                        GitHub, firmada con la clave de release.
    //   dev   «Kairós Dev»  la de trabajo: otro id, otro nombre, ícono en
    //                        terracota y la firma de este equipo.
    // Cada una tiene sus propios datos; se pasan con la copia de seguridad.
    // `resValue` fija el nombre de cada canal; AGP lo trae apagado.
    buildFeatures {
        resValues = true
    }

    flavorDimensions += "canal"
    productFlavors {
        create("prod") {
            dimension = "canal"
            resValue("string", "app_name", "Kairós")
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
        create("dev") {
            dimension = "canal"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Kairós Dev")
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    buildTypes {
        release {
            // La firma la decide el canal (arriba), no el tipo de compilación.
            signingConfig = null
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
