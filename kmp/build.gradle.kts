plugins {
    alias(libs.plugins.kotlinMultiplatform)
    `maven-publish`
}

repositories {
    mavenCentral()
}

group = "tech.xpoint"
version = "0.24.1"

val kmpLibsDir = rootProject.layout.projectDirectory.dir("../build/kmp-libs")
val headersDir = rootProject.layout.projectDirectory.dir("../include/rtc")

fun cinteropLibdatachannel(target: org.jetbrains.kotlin.gradle.plugin.mpp.KotlinNativeTarget) {
    target.compilations.getByName("main") {
        cinterops.create("libdatachannel") {
            defFile("src/nativeInterop/cinterop/libdatachannel.def")
            compilerOpts("-I${headersDir.asFile.absolutePath}")
            extraOpts("-libraryPath", kmpLibsDir.dir(target.name).asFile.absolutePath)
        }
    }
}

kotlin {
    val iosArm64 = iosArm64()
    val iosSimArm64 = iosSimulatorArm64()
    val iosX64 = iosX64()
    val macosArm64 = macosArm64()
    val macosX64 = macosX64()

    listOf(iosArm64, iosSimArm64, iosX64, macosArm64, macosX64).forEach {
        cinteropLibdatachannel(it)
    }

    sourceSets {
        all {
            languageSettings {
                optIn("kotlinx.cinterop.ExperimentalForeignApi")
                optIn("kotlinx.coroutines.ExperimentalCoroutinesApi")
            }
        }
        commonMain.dependencies {
            implementation(libs.coroutines.core)
        }
    }
}

publishing {
    repositories {
        maven("s3://downloads.xpoint.tech/nexus/") {
            credentials(AwsCredentials::class) {
                accessKey = findProperty("xpoint.aws.accessKey")?.toString()
                    ?: System.getenv("AWS_ACCESS_KEY_ID")
                secretKey = findProperty("xpoint.aws.secretKey")?.toString()
                    ?: System.getenv("AWS_SECRET_ACCESS_KEY")
            }
        }
    }
}

