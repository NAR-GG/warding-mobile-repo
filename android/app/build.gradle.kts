import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        load(FileInputStream(file))
    }
}

android {
    namespace = "com.warding.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 가 요구하는 Java 8+ API 디슈가링.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.warding.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties["storeFile"] as String?
            if (storeFilePath != null) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    testOptions {
        unitTests {
            // android.jar 스텁의 org.json 은 모든 메서드가 예외를 던진다.
            // 테스트 의존성으로 넣은 실제 구현이 스텁보다 먼저 잡히도록
            // 클래스패스 앞으로 당긴다 (returnDefaultValues 로 덮으면 파싱이
            // 조용히 null 을 돌려줘 테스트가 의미를 잃는다).
            all {
                it.classpath = it.classpath.filter { f -> !f.name.equals("android.jar") } +
                    it.classpath.filter { f -> f.name.equals("android.jar") }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.isNotEmpty()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // 디슈가링으로 R8 가 도는데, okhttp 의 선택적 TLS 클래스 누락 경고로
            // 빌드가 실패하므로 proguard 규칙으로 억제한다.
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // flutter_local_notifications 디슈가링 런타임 라이브러리.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // 위젯 데이터 파싱 유닛 테스트용. org.json 은 안드로이드 SDK 스텁이라
    // JVM 테스트에서 메서드가 전부 예외를 던지므로, 실제 구현을 따로 넣는다.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
