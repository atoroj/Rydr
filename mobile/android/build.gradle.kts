allprojects {
    repositories {
        google()
        mavenCentral()

        // Repo privado de Mapbox: necesario para resolver las dependencias
        // nativas de mapbox_maps_flutter. El token se lee de gradle.properties
        // (MAPBOX_DOWNLOADS_TOKEN), que vive en ~/.gradle/gradle.properties
        // y NO se commitea al repo.
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                password = providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").getOrElse(
                    System.getenv("MAPBOX_DOWNLOADS_TOKEN") ?: ""
                )
            }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}