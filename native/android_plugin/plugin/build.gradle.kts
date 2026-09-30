// SlimePlatform: the Godot v2 Android plugin of Slime Train.
// Output: build/outputs/aar/SlimePlatform-{debug,release}.aar, copied into
// addons/slime_platform/bin/ by tools/android/build_plugin.sh.
plugins {
    id("com.android.library")
}

val pluginName = "SlimePlatform"
val pluginPackageName = "com.slimetrain.platform"

android {
    namespace = pluginPackageName
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = pluginName
        manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

base {
    archivesName.set(pluginName)
}

dependencies {
    // Provided at run time by the Godot app; never bundled into the AAR.
    compileOnly("org.godotengine:godot:4.7.2.stable")
}
