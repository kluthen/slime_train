@tool
extends EditorPlugin
## Editor side of the SlimePlatform Android plugin: registers the export
## plugin that adds the plugin's AAR to Android exports (Gradle builds only,
## the v2 plugin format). The Java source is in native/android_plugin/; the
## AARs in bin/ are built by tools/android/build_plugin.sh (not tracked).
## The engine singleton "SlimePlatform" it provides is wrapped by
## src/platform/phone_platform.gd.

var _export_plugin: SlimePlatformExportPlugin


## Registers the export plugin when the editor plugin is enabled.
func _enter_tree() -> void:
	_export_plugin = SlimePlatformExportPlugin.new()
	add_export_plugin(_export_plugin)


## Unregisters the export plugin when the editor plugin is disabled.
func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


## Adds the SlimePlatform AAR to Android exports.
class SlimePlatformExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "SlimePlatform"

	## Only Android exports take the AAR.
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	## The AAR for the build type; paths are relative to res://addons/.
	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var build := "debug" if debug else "release"
		return PackedStringArray(
			["slime_platform/bin/%s/%s-%s.aar" % [build, PLUGIN_NAME, build]]
		)

	## The export plugin's name, shown in export errors.
	func _get_name() -> String:
		return PLUGIN_NAME
