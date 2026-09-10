// allprojects {
//     repositories {
//         google()
//         mavenCentral()
//     }
// }

allprojects {
        repositories {
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/public")
        maven("https://maven.aliyun.com/repository/gradle-plugin")
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// 修复 isar_flutter_libs 3.1.0+1 缺少 namespace 导致 AGP 8.x 构建失败的问题
subprojects {
    plugins.withId("com.android.library") {
        if (name == "isar_flutter_libs") {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                namespace = "dev.isar.isar_flutter_libs"
            }
        }
    }
}

// 修复 isar_flutter_libs 3.1.0+1 自身 compileSdk=30 过低，其依赖 androidx.startup 引用
// android:attr/lStar (API 31+)，AAPT 资源编译报 "resource android:attr/lStar not found"
subprojects {
    if (name == "isar_flutter_libs") {
        if (state.executed) {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileSdk = 34
            }
        } else {
            afterEvaluate {
                extensions.configure<com.android.build.gradle.LibraryExtension> {
                    compileSdk = 34
                }
            }
        }
    }
}
