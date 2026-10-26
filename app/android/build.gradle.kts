allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Vài plugin (permission_handler_android 14.1.0, receive_sharing_intent 1.9.0) đặt compileSdk = 37, nhưng AGP 9.1
// tìm "android-37" trong khi SDK Android 17 cài với tên "android-37.0" → build lỗi
// "Failed to find target with hash string 'android-37'". Ép các plugin đó biên dịch với SDK 36 (đã cài).
// Bỏ đoạn này khi nâng AGP hỗ trợ API 37.
subprojects {
    if (project.name != "app") {
        project.afterEvaluate {
            project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let { android ->
                if (android.compileSdkVersion == "android-37") {
                    android.compileSdk = 36
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
