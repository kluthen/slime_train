// Slime Train Android plugin (SlimePlatform): a Godot v2 Android plugin.
// Built by tools/android/build_plugin.sh (JDK 21); see that script's header.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "SlimePlatform"
include(":plugin")
