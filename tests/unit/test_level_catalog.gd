extends GutTest
## Chunk LD1: levels are found by ID, by convention (LevelCatalog): the scene
## res://levels/<id>/level.tscn, its fixtures in res://levels/<id>/fixtures/.

# @test-link [[req_test_level_and_test_mode]]


func test_the_paths_follow_the_convention() -> void:
	assert_eq(LevelCatalog.scene_path("test"), "res://levels/test/level.tscn")
	assert_eq(LevelCatalog.fixtures_dir("test"), "res://levels/test/fixtures/")
	assert_eq(LevelCatalog.dir_of("01"), "res://levels/01/")


func test_the_test_level_is_found_and_is_the_default() -> void:
	assert_eq(LevelCatalog.DEFAULT_ID, "test")
	assert_true(LevelCatalog.exists("test"))
	assert_true("test" in LevelCatalog.ids())
	assert_eq(LevelCatalog.problem("test"), "")


func test_every_listed_level_has_its_scene() -> void:
	for id in LevelCatalog.ids():
		assert_true(ResourceLoader.exists(LevelCatalog.scene_path(id)), id)


func test_ids_are_checked() -> void:
	for id in ["test", "01", "my-level"]:
		assert_true(LevelCatalog.is_valid_id(id), id)
	for id in ["", "Test", "a b", "../test", "a/b", "-a", "a-"]:
		assert_false(LevelCatalog.is_valid_id(id), id)
		assert_false(LevelCatalog.exists(id), id)


func test_a_missing_level_says_what_is_missing() -> void:
	assert_false(LevelCatalog.exists("no-such-level"))
	var problem := LevelCatalog.problem("no-such-level")
	assert_string_contains(problem, "res://levels/no-such-level/level.tscn")
	assert_string_contains(problem, "test")
	assert_string_contains(LevelCatalog.problem("Bad Id"), "invalid level id")
