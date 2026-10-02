allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Force 16KB-page-size-compatible versions of WorkManager, Room, & SQLite
    // across ALL subprojects (including transitive plugin dependencies).
    configurations.all {
        resolutionStrategy {
            force("androidx.work:work-runtime:2.10.1")
            force("androidx.room:room-runtime:2.7.1")
            force("androidx.room:room-common:2.7.1")
            force("androidx.sqlite:sqlite-framework:2.5.1")
            force("androidx.sqlite:sqlite:2.5.1")
        }
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

subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}

subprojects {
    plugins.withId("com.android.library") {
        (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.apply {
            ndkVersion = "28.2.13676358"
            defaultConfig {
                externalNativeBuild {
                    cmake {
                        arguments("-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=16384")
                    }
                    ndkBuild {
                        arguments("APP_LDFLAGS=-Wl,-z,max-page-size=16384")
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
