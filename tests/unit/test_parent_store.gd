extends GutTest
## The parent store (src/save/parent_store.gd): the app's one parent code
## (salted and hashed, never in plain text) and the wrong-try state (the count
## and the end of the 30 s wait), in one file apart from the level saves, so
## both survive the code prompt closing and the app being killed.

# @test-link [[rule_parent_code_not_stored_plaintext]]
# @test-link [[req_denial_and_stepup_behavior]]
# @test-link [[req_parent_gate_and_access]]

const DIR := "user://test-parent-store/"
const PATH := DIR + "parent.json"
## The mirror backup, written after the file with the same content.
const BAK := PATH + ".bak"
## Unreadable parent files: not JSON, not an object, another format, a bad
## code, a bad count.
const DAMAGED := ["not json", "[1, 2]", '{"format": 99, "code": null, "wrong_tries": 0, "wait_until_ms": 0}',
		'{"format": 1, "code": {"salt": "zz"}, "wrong_tries": 0, "wait_until_ms": 0}',
		'{"format": 1, "code": null, "wrong_tries": -1, "wait_until_ms": 0}']
const CODE := "482913"
const OTHER := "105277"
## A wall-clock time, in ms, for the tries.
const NOW := 1_800_000_000_000


func before_each() -> void:
	_clear(DIR)


func after_all() -> void:
	_clear(DIR)


## Tests may delete their own scratch files; the game's code may not.
func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A store on the test path with CODE set.
func _store_with_code() -> ParentStore:
	var store := ParentStore.new(PATH)
	store.set_code(CODE)
	return store


## Tries `code` `times` times at `now`, asserting each answer is `want`.
func _try(store: ParentStore, code: String, times: int, now: int, want: ParentStore.Result) -> void:
	for i in times:
		assert_eq(store.try_code(code, now), want, "try %d of %s" % [i + 1, code])


## The file's raw bytes, as text.
func _raw() -> String:
	return FileAccess.get_file_as_bytes(PATH).get_string_from_ascii()


## Writes `bytes` over the file at `file_path` (a damaged or stray file).
func _put(file_path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## Garbage bytes, as a kill or a bad disk might leave them.
func _garbage() -> PackedByteArray:
	return PackedByteArray([0x7b, 0x00, 0xff, 0x22, 0x9c, 0x0a, 0x13, 0xfe])


## Asserts the file holds `code` nowhere in plain text, deterministically: the
## salt and hash are lowercase hex of their lengths (16 and 32 bytes) and
## neither is the code, no other value is, and the file's text with the salt
## and hash taken out doesn't hold it (a 6-digit run can occur by chance
## inside random hex).
func _assert_not_in_file(code: String, why: String) -> void:
	var raw := _raw()
	var data := JSON.parse_string(raw) as Dictionary
	var salt: String = data["code"]["salt"]
	var digest: String = data["code"]["hash"]
	var hex := RegEx.create_from_string("^[0-9a-f]+$")
	assert_eq(salt.length(), ParentStore.SALT_BYTES * 2, "%s: the salt is %d bytes" % [why, ParentStore.SALT_BYTES])
	assert_eq(digest.length(), 64, "%s: the hash is a SHA-256" % why)
	for value in [salt, digest]:
		assert_not_null(hex.search(value), "%s: '%s' is lowercase hex" % [why, value])
	for key in data:
		assert_ne(str(data[key]), code, "%s: '%s' isn't the code" % [why, key])
	var rest := raw.replace(salt, "").replace(digest, "")
	assert_false(rest.contains(code), "%s: %s" % [why, rest])


func test_the_tuning_values() -> void:
	assert_eq(ParentStore.DEFAULT_PATH, "user://parent.json")
	assert_eq(ParentStore.WRONG_TRIES_BEFORE_WAIT, 5)
	assert_eq(ParentStore.WAIT_MS, 30000)


func test_no_code_at_first() -> void:
	var store := ParentStore.new(PATH)
	assert_false(store.has_code())
	assert_eq(store.wrong_tries(), 0)
	assert_eq(store.wait_left_ms(NOW), 0)
	assert_false(FileAccess.file_exists(PATH), "nothing written before a code is set")


func test_set_code_then_has_code() -> void:
	var store := _store_with_code()
	assert_true(store.has_code())
	assert_true(FileAccess.file_exists(PATH))
	assert_false(FileAccess.file_exists(PATH + ParentStore.SIDE_SUFFIX), "no side file left")


func test_a_new_store_on_the_same_path_sees_the_code_and_the_count() -> void:
	var store := _store_with_code()
	_try(store, OTHER, 2, NOW, ParentStore.Result.WRONG)
	var reopened := ParentStore.new(PATH)
	assert_true(reopened.has_code(), "the code survives an app kill")
	assert_eq(reopened.wrong_tries(), 2, "the count survives an app kill")
	assert_eq(reopened.try_code(CODE, NOW), ParentStore.Result.OK)


func test_the_right_code_is_ok_a_wrong_one_counts() -> void:
	var store := _store_with_code()
	assert_eq(store.try_code(CODE, NOW), ParentStore.Result.OK)
	assert_eq(store.wrong_tries(), 0)
	assert_eq(store.try_code(OTHER, NOW), ParentStore.Result.WRONG)
	assert_eq(store.wrong_tries(), 1)
	assert_eq(store.try_code("", NOW), ParentStore.Result.WRONG, "an empty entry is just wrong")
	assert_eq(store.try_code("48291", NOW), ParentStore.Result.WRONG, "a short entry is just wrong")
	assert_eq(store.wrong_tries(), 3)


func test_five_wrong_in_a_row_bring_the_wait_even_for_the_right_code() -> void:
	var store := _store_with_code()
	_try(store, OTHER, 4, NOW, ParentStore.Result.WRONG)
	assert_eq(store.wait_left_ms(NOW), 0, "4 wrong: no wait yet")
	assert_eq(store.try_code(OTHER, NOW), ParentStore.Result.WRONG, "the 5th is still answered WRONG")
	assert_eq(store.wait_left_ms(NOW), 30000)
	assert_eq(store.try_code(CODE, NOW + 1000), ParentStore.Result.WAITING, "the right code waits too")
	assert_eq(store.wrong_tries(), 5, "nothing counts during the wait")
	assert_eq(store.wait_left_ms(NOW + 1000), 29000)
	assert_eq(store.wait_left_ms(NOW + 29999), 1)
	assert_eq(store.wait_left_ms(NOW + 30000), 0)
	assert_eq(store.wait_left_ms(NOW + 90000), 0)


func test_a_new_store_during_the_wait_still_waits() -> void:
	var store := _store_with_code()
	_try(store, OTHER, 5, NOW, ParentStore.Result.WRONG)
	var reopened := ParentStore.new(PATH)
	assert_eq(reopened.wait_left_ms(NOW + 10000), 20000, "the wait survives an app kill")
	assert_eq(reopened.try_code(CODE, NOW + 10000), ParentStore.Result.WAITING)


func test_after_the_wait_the_count_starts_again_from_0() -> void:
	var store := _store_with_code()
	_try(store, OTHER, 5, NOW, ParentStore.Result.WRONG)
	var after := NOW + ParentStore.WAIT_MS
	_try(store, OTHER, 4, after, ParentStore.Result.WRONG)
	assert_eq(store.wrong_tries(), 4)
	assert_eq(store.wait_left_ms(after), 0, "4 wrong after a wait: no new wait")
	assert_eq(store.try_code(CODE, after), ParentStore.Result.OK)


func test_a_right_code_resets_the_count() -> void:
	var store := _store_with_code()
	_try(store, OTHER, 4, NOW, ParentStore.Result.WRONG)
	assert_eq(store.try_code(CODE, NOW), ParentStore.Result.OK)
	assert_eq(store.wrong_tries(), 0)
	assert_eq(ParentStore.new(PATH).wrong_tries(), 0, "the reset is on disk")
	_try(store, OTHER, 4, NOW, ParentStore.Result.WRONG)
	assert_eq(store.wait_left_ms(NOW), 0, "not 5 in a row: no wait")


func test_set_code_resets_the_count_and_the_wait() -> void:
	var store := _store_with_code()
	_try(store, OTHER, 5, NOW, ParentStore.Result.WRONG)
	store.set_code(OTHER)
	assert_eq(store.wrong_tries(), 0)
	assert_eq(store.wait_left_ms(NOW), 0)
	assert_eq(store.try_code(OTHER, NOW), ParentStore.Result.OK)
	var reopened := ParentStore.new(PATH)
	assert_eq(reopened.wait_left_ms(NOW), 0, "the reset is on disk")


func test_the_file_never_holds_the_code_in_plain_text() -> void:
	var store := _store_with_code()
	_assert_not_in_file(CODE, "after setup")
	store.set_code(OTHER)
	_assert_not_in_file(OTHER, "after a change")
	_assert_not_in_file(CODE, "the old code isn't there either")


func test_a_fresh_salt_at_every_set_code() -> void:
	var store := _store_with_code()
	var first := JSON.parse_string(_raw()) as Dictionary
	store.set_code(CODE)
	var second := JSON.parse_string(_raw()) as Dictionary
	assert_ne(first["code"]["salt"], second["code"]["salt"])
	assert_ne(first["code"]["hash"], second["code"]["hash"], "same code, another hash")


func test_the_old_code_stops_working_at_once() -> void:
	var store := _store_with_code()
	store.set_code(OTHER)
	assert_eq(store.try_code(CODE, NOW), ParentStore.Result.WRONG)
	assert_eq(ParentStore.new(PATH).try_code(CODE, NOW), ParentStore.Result.WRONG, "on disk too")


func test_a_clock_moved_back_never_makes_the_wait_longer_than_30_s() -> void:
	var store := _store_with_code()
	_try(store, OTHER, 5, NOW, ParentStore.Result.WRONG)
	var back := NOW - 3_600_000
	assert_eq(store.wait_left_ms(back), 30000, "clamped to 30 s")
	assert_eq(store.wait_left_ms(back + 10000), 20000, "then it runs down from there")
	assert_eq(store.wait_left_ms(back + 30000), 0, "over 30 s after the clock moved back")
	assert_eq(store.try_code(CODE, back + 30000), ParentStore.Result.OK)


func test_set_code_refuses_anything_but_6_digits() -> void:
	var store := ParentStore.new(PATH)
	for bad in ["12345", "1234567", "12a456", "", " 12345", "１２３４５６"]:
		store.set_code(bad)
		assert_push_error("6 digits")
		assert_false(store.has_code(), "'%s' refused" % bad)
	assert_false(FileAccess.file_exists(PATH), "nothing written")


func test_try_code_without_a_code_is_refused_loudly() -> void:
	var store := ParentStore.new(PATH)
	assert_eq(store.try_code(CODE, NOW), ParentStore.Result.WRONG)
	assert_push_error("no parent code")
	assert_eq(store.wrong_tries(), 0, "nothing counts")
	assert_false(FileAccess.file_exists(PATH), "nothing written")


# @test-link [[req_denial_and_stepup_behavior]]
func test_an_unreadable_file_without_a_backup_locks_the_store_and_is_left_untouched() -> void:
	# Chunk 18 read such a file as "no code" (setup again); D130/chunk 19
	# decision B: it locks instead, so setup never comes back.
	for text in DAMAGED:
		_put(PATH, text.to_utf8_buffer())
		var store := ParentStore.new(PATH)
		assert_push_error("locked")
		assert_true(store.has_code(), "'%s': a code exists, so no setup" % text)
		assert_true(store.is_locked(), "'%s': locked" % text)
		assert_eq(store.try_code(CODE, NOW), ParentStore.Result.WRONG, "'%s': no code matches" % text)
		assert_eq(FileAccess.get_file_as_string(PATH), text, "'%s' left as it was" % text)
		assert_false(FileAccess.file_exists(BAK), "'%s': no backup made" % text)


# @test-link [[req_parent_gate_and_access]]
# @test-link [[rule_parent_code_not_stored_plaintext]]
func test_set_code_writes_the_file_and_its_backup_the_same() -> void:
	var store := _store_with_code()
	assert_true(FileAccess.file_exists(BAK), "the backup is written")
	assert_eq(FileAccess.get_file_as_bytes(BAK), FileAccess.get_file_as_bytes(PATH), "same content")
	_assert_not_in_file(CODE, "the file")
	assert_false(FileAccess.get_file_as_string(BAK).replace(_salt(), "").replace(_digest(), "").contains(CODE),
			"the backup holds no code in plain text")
	_try(store, OTHER, 2, NOW, ParentStore.Result.WRONG)
	assert_eq(FileAccess.get_file_as_bytes(BAK), FileAccess.get_file_as_bytes(PATH), "a try updates both")
	for side in [PATH + ParentStore.SIDE_SUFFIX, BAK + ParentStore.SIDE_SUFFIX]:
		assert_false(FileAccess.file_exists(side), "no side file %s left" % side)


# @test-link [[req_parent_gate_and_access]]
# @test-link [[req_denial_and_stepup_behavior]]
func test_a_damaged_file_falls_back_to_the_backup_with_the_tries_and_the_wait() -> void:
	var store := _store_with_code()
	_try(store, OTHER, 5, NOW, ParentStore.Result.WRONG)
	_put(PATH, _garbage())
	var reopened := ParentStore.new(PATH)
	assert_push_error("backup")
	assert_false(reopened.is_locked())
	assert_true(reopened.has_code())
	assert_eq(reopened.wrong_tries(), 5, "the count from the backup")
	assert_eq(reopened.wait_left_ms(NOW + 10000), 20000, "the wait's end from the backup")
	assert_eq(reopened.try_code(CODE, NOW + 10000), ParentStore.Result.WAITING)
	var after := NOW + ParentStore.WAIT_MS
	assert_eq(reopened.try_code(CODE, after), ParentStore.Result.OK, "the code from the backup")
	assert_eq(FileAccess.get_file_as_bytes(PATH), FileAccess.get_file_as_bytes(BAK), "the next write mends the file")
	assert_eq(ParentStore.new(PATH).try_code(OTHER, after), ParentStore.Result.WRONG, "the file reads again")


# @test-link [[req_parent_gate_and_access]]
func test_a_missing_file_falls_back_to_the_backup() -> void:
	var store := _store_with_code()
	_try(store, OTHER, 2, NOW, ParentStore.Result.WRONG)
	var backup := FileAccess.get_file_as_bytes(BAK)
	_clear(DIR)
	_put(BAK, backup)
	var reopened := ParentStore.new(PATH)
	assert_push_error("backup")
	assert_true(reopened.has_code())
	assert_eq(reopened.wrong_tries(), 2)
	assert_eq(reopened.try_code(CODE, NOW), ParentStore.Result.OK)
	assert_true(FileAccess.file_exists(PATH), "written again")


# @test-link [[req_denial_and_stepup_behavior]]
# @test-link [[req_parent_gate_and_access]]
func test_both_damaged_lock_the_store_until_a_new_code() -> void:
	_store_with_code()
	_put(PATH, _garbage())
	_put(BAK, "not json".to_utf8_buffer())
	var store := ParentStore.new(PATH)
	assert_push_error("locked")
	assert_true(store.is_locked())
	assert_true(store.has_code(), "a code exists: setup is never shown again")
	_try(store, CODE, 4, NOW, ParentStore.Result.WRONG)
	assert_eq(store.wait_left_ms(NOW), 0)
	assert_eq(store.try_code(CODE, NOW), ParentStore.Result.WRONG, "the right old code is refused")
	assert_eq(store.wait_left_ms(NOW), ParentStore.WAIT_MS, "the 5th wrong try in a row brings the wait")
	assert_eq(store.try_code(CODE, NOW + 1000), ParentStore.Result.WAITING)
	store.wait_left_ms(NOW - 3_600_000)
	assert_eq(FileAccess.get_file_as_bytes(PATH), _garbage(), "the file is left byte-identical")
	assert_eq(FileAccess.get_file_as_string(BAK), "not json", "the backup is left byte-identical")
	store.set_code(OTHER)
	assert_false(store.is_locked(), "a new code unlocks it")
	assert_eq(store.wait_left_ms(NOW), 0)
	assert_eq(store.try_code(OTHER, NOW), ParentStore.Result.OK)
	assert_eq(FileAccess.get_file_as_bytes(BAK), FileAccess.get_file_as_bytes(PATH), "both written anew")
	var reopened := ParentStore.new(PATH)
	assert_false(reopened.is_locked())
	assert_eq(reopened.try_code(OTHER, NOW), ParentStore.Result.OK, "the new code on disk")


# @test-link [[req_denial_and_stepup_behavior]]
func test_a_damaged_backup_without_the_file_locks_the_store() -> void:
	_put(BAK, _garbage())
	var store := ParentStore.new(PATH)
	assert_push_error("locked")
	assert_true(store.is_locked())
	assert_true(store.has_code())
	assert_false(FileAccess.file_exists(PATH), "nothing written")


# @test-link [[req_parent_gate_and_access]]
func test_a_side_file_left_by_a_kill_is_ignored_and_the_next_write_works() -> void:
	var store := _store_with_code()
	_try(store, OTHER, 1, NOW, ParentStore.Result.WRONG)
	_put(PATH + ParentStore.SIDE_SUFFIX, _garbage())
	_put(BAK + ParentStore.SIDE_SUFFIX, _garbage())
	var reopened := ParentStore.new(PATH)
	assert_false(reopened.is_locked())
	assert_eq(reopened.wrong_tries(), 1, "loaded normally")
	assert_eq(reopened.try_code(CODE, NOW), ParentStore.Result.OK)
	assert_eq(ParentStore.new(PATH).wrong_tries(), 0, "the next write is on disk")
	assert_eq(FileAccess.get_file_as_bytes(BAK), FileAccess.get_file_as_bytes(PATH))
	for side in [PATH + ParentStore.SIDE_SUFFIX, BAK + ParentStore.SIDE_SUFFIX]:
		assert_false(FileAccess.file_exists(side), "the side file %s was used and moved in" % side)


## The salt in the file.
func _salt() -> String:
	return (JSON.parse_string(_raw()) as Dictionary)["code"]["salt"]


## The hash in the file.
func _digest() -> String:
	return (JSON.parse_string(_raw()) as Dictionary)["code"]["hash"]
