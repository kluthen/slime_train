extends GutTest
## The randomness rule: gameplay code (everything under src/) draws random
## numbers only from the one seeded generator, Rng (src/sim/rng.gd). Godot's
## global random functions and the Array helpers that use them are refused,
## because they would make runs impossible to repeat.

const SRC_ROOT := "res://src/"
const RNG_SCRIPT := "res://src/sim/rng.gd"


func test_no_global_random_calls_in_src() -> void:
	var global_call := RegEx.create_from_string(
			"(?<![\\w.])(randi|randf|randi_range|randf_range|randfn|randomize|seed|rand_from_seed)\\s*\\(")
	var array_helper := RegEx.create_from_string("\\.(shuffle|pick_random)\\s*\\(")
	var own_generator := RegEx.create_from_string("\\bRandomNumberGenerator\\b")
	var method_definition := RegEx.create_from_string("^\\s*(static\\s+)?func\\s")
	var offenders := PackedStringArray()
	for path in _gd_files(SRC_ROOT):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].split("#")[0]
			if method_definition.search(code) != null:
				continue  # Rng's own methods share the global functions' names.
			var bad := global_call.search(code) != null or array_helper.search(code) != null
			if path != RNG_SCRIPT and own_generator.search(code) != null:
				bad = true
			if bad:
				offenders.append("%s:%d: %s" % [path, i + 1, lines[i].strip_edges()])
	assert_eq(offenders, PackedStringArray(), "use Rng (src/sim/rng.gd) instead")


func test_the_check_catches_offenders() -> void:
	# Guards the regular expressions above against silently matching nothing.
	var global_call := RegEx.create_from_string(
			"(?<![\\w.])(randi|randf|randi_range|randf_range|randfn|randomize|seed|rand_from_seed)\\s*\\(")
	var array_helper := RegEx.create_from_string("\\.(shuffle|pick_random)\\s*\\(")
	for bad in ["var x = randi()", "x = randf_range(0, 1)", "randomize()", "items.shuffle()", "a.pick_random()"]:
		assert_true(global_call.search(bad) != null or array_helper.search(bad) != null, bad)
	for good in ["rng.randi()", "rng.randf_range(0, 1)", "Rng.derive_seed(1, \"a\")", "var seed_value := 1"]:
		assert_true(global_call.search(good) == null and array_helper.search(good) == null, good)


func _gd_files(dir_path: String) -> PackedStringArray:
	var files := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir_path):
		files.append_array(_gd_files(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			files.append(dir_path.path_join(file))
	return files
