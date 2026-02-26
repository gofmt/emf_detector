// Kotlin DSL 格式的 buildscript 配置（核心：AGP 依赖放在这里）
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Kotlin DSL 必须用括号：classpath("xxx")，而非 Groovy 的 classpath 'xxx'
        classpath("com.android.tools.build:gradle:8.2.0")
        // 如果你项目用了 Kotlin，保留这行（版本号根据你项目实际情况调整）
        // classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.6.21")
    }
}

// 你原来的 allprojects 配置
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 你原来的构建目录配置
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
