extends GutTest
## The fixture coverage rule (build chunk 21): every fixture of the test level
## (a `*.fixture.json` sidecar in levels/test/fixtures/) is loaded by at least
## one scripted end-to-end test. A fixture counts as covered when its quoted
## name, "<name>", appears in a .gd file under tests/e2e/ or in a .json run
## file under tests/e2e/scripts/ as a value: comment lines, dictionary keys
## ("lost": ...) and subscripts (run["lost"]) don't count.

# @test-link [[req_test_level_and_test_mode]]

const E2E_ROOT := "res://tests/e2e/"
const RUN_FILES_DIR := "res://tests/e2e/scripts/"


# @test-link [[req_test_level_and_test_mode]]
func test_every_test_level_fixture_is_loaded_by_an_e2e_test() -> void:
	var names := _fixture_names(LevelCatalog.fixtures_dir(LevelCatalog.DEFAULT_ID))
	assert_gt(names.size(), 0, "no fixture sidecar found in the test level")
	var texts := PackedStringArray()
	for path in _files_with_extension(E2E_ROOT, ".gd"):
		texts.append(_code_only(FileAccess.get_file_as_string(path)))
	for path in _files_with_extension(RUN_FILES_DIR, ".json"):
		texts.append(FileAccess.get_file_as_string(path))
	var uncovered := _uncovered(names, texts)
	assert_eq(uncovered, PackedStringArray(),
			"fixtures no e2e test loads: %s; add an e2e test in tests/e2e/ that loads it, see tests/e2e/README.md"
			% ", ".join(uncovered))


func test_the_matcher_needs_the_exact_quoted_name() -> void:
	# Guards the matcher against passing vacuously or on a longer name.
	var names := PackedStringArray(["sunrise", "gate1-open", "lost"])
	var texts := PackedStringArray([
		"TestMode.load_fixture(\"sunrise\")",
		"{\"fixture\": \"gate1-open-x\"}",
		"var lost_count := 0",
		_code_only("return {\"lost\": 0}\nassert_eq(run[\"lost\"], 0)\n## \"lost\" in a comment"),
	])
	assert_eq(_uncovered(names, texts), PackedStringArray(["gate1-open", "lost"]))
	texts.append("_load(\"gate1-open\")")
	assert_eq(_uncovered(names, texts), PackedStringArray(["lost"]))
	texts.append("for name in [\"bump\", \"lost\"]:")
	assert_eq(_uncovered(names, texts), PackedStringArray())
	assert_eq(_uncovered(names, PackedStringArray()), names)


## `text` (GDScript) without its comment lines and without its string
## subscripts (`run["lost"]` becomes `run[]`), so that a fixture name used as
## a dictionary key or in prose doesn't count as a fixture load.
func _code_only(text: String) -> String:
	var kept := PackedStringArray()
	for line in text.split("\n"):
		if not line.strip_edges().begins_with("#"):
			kept.append(line)
	var subscript := RegEx.create_from_string("(?<=[\\w\\)\\]])\\[\\s*\"[^\"]*\"\\s*\\]")
	return subscript.sub("\n".join(kept), "[]", true)


## The names in `names` quoted as a value (not followed by `:`, so not a
## dictionary key) in none of `texts`.
func _uncovered(names: PackedStringArray, texts: PackedStringArray) -> PackedStringArray:
	var missing := PackedStringArray()
	for fixture_name in names:
		var quoted := RegEx.create_from_string("\"%s\"(?!\\s*:)" % fixture_name)
		var found := false
		for text in texts:
			if quoted.search(text) != null:
				found = true
				break
		if not found:
			missing.append(fixture_name)
	return missing


## The fixture names in `dir_path`: each sidecar's file name without its
## extension, sorted.
func _fixture_names(dir_path: String) -> PackedStringArray:
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(TestMode.SIDECAR_EXTENSION):
			names.append(file.trim_suffix(TestMode.SIDECAR_EXTENSION))
	names.sort()
	return names


## Every file under `dir_path` (recursively) whose name ends with `extension`.
func _files_with_extension(dir_path: String, extension: String) -> PackedStringArray:
	var files := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir_path):
		files.append_array(_files_with_extension(dir_path.path_join(sub), extension))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(extension):
			files.append(dir_path.path_join(file))
	return files
