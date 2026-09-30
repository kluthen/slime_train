extends GutTest
## The v1 build guarantees, read straight from the files that make the build:
## the Android export presets ask for no permission, the SlimePlatform plugin
## asks only for USE_BIOMETRIC (the parent gate's device-credential prompt),
## no billing library is linked, and no gameplay script (src/) uses one of
## Godot's network classes. So the app never connects to a network and offers
## no purchase inside it.

# @test-link [[rule_no_network_connection]]
# @test-link [[rule_no_in_app_purchases]]

const EXPORT_PRESETS := "res://export_presets.cfg"
const PLUGIN_MANIFEST := "native/android_plugin/plugin/src/main/AndroidManifest.xml"
const PLUGIN_GRADLE := "native/android_plugin/plugin/build.gradle.kts"
const SRC_ROOT := "res://src/"
const ALLOWED_PERMISSIONS := ["android.permission.USE_BIOMETRIC"]
const NETWORK_CLASS_PATTERN := \
		"\\b(HTTPRequest|HTTPClient|StreamPeerTCP|PacketPeerUDP|WebSocketPeer|TCPServer|UDPServer|ENet\\w*)\\b"
const USES_PERMISSION_PATTERN := \
		"<uses-permission(?:-sdk-23)?\\b[^>]*\\bandroid:name\\s*=\\s*\"([^\"]+)\""
const XML_COMMENT_PATTERN := "(?s)<!--.*?-->"


## Every Android preset leaves each permissions/* switch off and lists no
## custom permission; at least one Android preset must exist.
# @test-link [[rule_no_network_connection]]
# @test-link [[rule_no_in_app_purchases]]
func test_android_presets_request_no_permission() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load(EXPORT_PRESETS), OK, "cannot read " + EXPORT_PRESETS)
	var preset_section := RegEx.create_from_string("^preset\\.\\d+$")
	var android_presets := 0
	var offenders := PackedStringArray()
	for section in presets.get_sections():
		if preset_section.search(section) == null:
			continue
		if presets.get_value(section, "platform", "") != "Android":
			continue
		android_presets += 1
		var options := section + ".options"
		assert_true(presets.has_section_key(options, "permissions/custom_permissions"),
				"%s has no permissions/custom_permissions" % options)
		for key in presets.get_section_keys(options):
			if not key.begins_with("permissions/"):
				continue
			var value: Variant = presets.get_value(options, key)
			if key == "permissions/custom_permissions":
				if typeof(value) != TYPE_PACKED_STRING_ARRAY or not value.is_empty():
					offenders.append("%s %s=%s" % [options, key, value])
			elif typeof(value) == TYPE_BOOL and value:
				offenders.append("%s %s=true" % [options, key])
	assert_gt(android_presets, 0, "no Android preset found in " + EXPORT_PRESETS)
	assert_eq(offenders, PackedStringArray(), "Android presets must request no permission")


## The plugin's manifest requests USE_BIOMETRIC and nothing else (commented-out
## tags are not requests).
# @test-link [[rule_no_network_connection]]
# @test-link [[rule_no_in_app_purchases]]
func test_plugin_manifest_requests_only_use_biometric() -> void:
	var manifest := _read_outside_import(PLUGIN_MANIFEST)
	assert_ne(manifest, "", "cannot read " + PLUGIN_MANIFEST)
	assert_eq(_requested_permissions(manifest), ALLOWED_PERMISSIONS)


## The plugin links no billing library (Play Billing or any other).
# @test-link [[rule_no_in_app_purchases]]
func test_plugin_links_no_billing_library() -> void:
	var gradle := _read_outside_import(PLUGIN_GRADLE)
	assert_ne(gradle, "", "cannot read " + PLUGIN_GRADLE)
	assert_false(gradle.to_lower().contains("billing"), PLUGIN_GRADLE + " mentions billing")


## No script under src/ names a Godot network class, comments included.
# @test-link [[rule_no_network_connection]]
func test_no_network_class_in_src() -> void:
	var network_class := RegEx.create_from_string(NETWORK_CLASS_PATTERN)
	var files := _gd_files(SRC_ROOT)
	assert_gt(files.size(), 10, "the scan of %s found too few scripts" % SRC_ROOT)
	var offenders := PackedStringArray()
	for path in files:
		for found in network_class.search_all(FileAccess.get_file_as_string(path)):
			offenders.append("%s:%s" % [path, found.get_string(1)])
	assert_eq(offenders, PackedStringArray(), "src/ must use no network class")


## Guards the patterns above against silently matching nothing (or too much).
func test_the_checks_catch_offenders() -> void:
	var network_class := RegEx.create_from_string(NETWORK_CLASS_PATTERN)
	for bad in ["var r := HTTPRequest.new()", "ENetMultiplayerPeer.new()", "var s: StreamPeerTCP",
			"WebSocketPeer.new()", "ENetConnection", "var u := UDPServer.new()"]:
		assert_not_null(network_class.search(bad), bad)
	for good in ["var http_request_count := 0", "MyHTTPClientish", "var enet := 1", "TCPServers"]:
		assert_null(network_class.search(good), good)
	var manifest := "<!-- <uses-permission android:name=\"android.permission.INTERNET\" /> -->\n" \
			+ "<uses-permission android:name=\"android.permission.USE_BIOMETRIC\" />\n" \
			+ "<uses-permission-sdk-23\n    android:name=\"android.permission.ACCESS_NETWORK_STATE\"/>"
	assert_eq(_requested_permissions(manifest),
			["android.permission.USE_BIOMETRIC", "android.permission.ACCESS_NETWORK_STATE"])


## The permission names a manifest's uses-permission tags request, in order,
## XML comments removed first.
func _requested_permissions(manifest: String) -> Array:
	var comment := RegEx.create_from_string(XML_COMMENT_PATTERN)
	var uses_permission := RegEx.create_from_string(USES_PERMISSION_PATTERN)
	var names := []
	for found in uses_permission.search_all(comment.sub(manifest, "", true)):
		names.append(found.get_string(1))
	return names


## A repository file outside Godot's import scope, read from its absolute path
## ("" when it cannot be read).
func _read_outside_import(relative_path: String) -> String:
	return FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://") + relative_path)


## Every .gd file under dir_path, recursively.
func _gd_files(dir_path: String) -> PackedStringArray:
	var files := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir_path):
		files.append_array(_gd_files(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			files.append(dir_path.path_join(file))
	return files
