extends GutTest
## The parent store's damage paths (src/save/parent_store.gd, D130, proposed)
## through the real game scene, with real touch events and stepped ticks: a
## game sets its code, then parent.json is damaged (garbage, or cut short as
## by a kill mid-write) and a new game boots on the same files. With the
## backup (parent.json.bak) readable, the code, the wrong tries and the wait's
## end come from it: setup is not shown again (DoD 23), the gate asks for the
## code, the old code opens it, a wrong code counts, a running wait still
## runs. With both files damaged the store is locked: setup is still not
## shown, the prompt refuses every code (the old one too) and the files stay
## byte for byte as they were.
##
## Every game here gets its own ParentStore on a scratch directory; a "new
## game" (a kill, then a launch) reads the files as they are.

# @test-link [[req_parent_gate_and_access]]

const MAIN_SCENE := "res://src/main.tscn"
const DIR := "user://test-parent-store-e2e/"
const STORE_PATH := DIR + "parent.json"
const BACKUP_PATH := STORE_PATH + ParentStore.BACKUP_SUFFIX
const SEED := 20260930
const CODE := "135790"
const WRONG := "975310"
## A point in the parent zone, well left of the parent buttons.
const ZONE_POINT := Vector2(300, 20)

## Counts the calls to the game's quit_app.
var quits := 0


func before_each() -> void:
	quits = 0
	_clear(DIR)


func after_all() -> void:
	_clear(DIR)


## Removes `path` and everything under it.
func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A game (a launch) on the store at STORE_PATH as its files are, in test
## mode with sessions, real input let through, its quit counted.
func _game() -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.parent_store = ParentStore.new(STORE_PATH)
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0, "sessions": true, "block_real_input": false}
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	game.quit_app = func() -> void: quits += 1
	return game


func _touch(game: Node, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = at
	game._unhandled_input(event)


## A press and its release at `at` (no step).
func _press(game: Node, at: Vector2) -> void:
	_touch(game, at, true)
	_touch(game, at, false)


func _steps(game: Node, count: int) -> void:
	for i in count:
		game.step_simulation()


func _state(game: Node) -> ParentGate.State:
	return game.parent_gate.state


func _setup(game: Node) -> ParentSetup:
	return game.parent_gate.surfaces[ParentGate.State.SETUP]


func _prompt(game: Node) -> ParentCodePrompt:
	return game.parent_gate.surfaces[ParentGate.State.PROMPT]


## Walks setup's four steps, choosing CODE: the code is saved.
func _walk_setup(game: Node) -> void:
	assert_eq(_state(game), ParentGate.State.SETUP, "first launch: setup")
	var setup := _setup(game)
	_press(game, setup.next_rect().get_center())
	for entry in 2:
		for digit in CODE:
			_press(game, setup.code_entry.pad.key_rect(digit).get_center())
	_press(game, setup.next_rect().get_center())
	_press(game, setup.next_rect().get_center())
	assert_eq(_state(game), ParentGate.State.HIDDEN, "setup closed")
	assert_true(game.parent_store.has_code(), "the code is saved")


## Reveals the parent buttons and presses `action`'s: the code prompt opens.
func _open(game: Node, action: String) -> ParentCodePrompt:
	_press(game, ZONE_POINT)
	game.step_simulation()
	_press(game, game.parent_gate.button_rect(action).get_center())
	assert_eq(_state(game), ParentGate.State.PROMPT, "%s asks for the code" % action)
	return _prompt(game)


## Types `code` on the prompt's pad (its 6th digit submits it).
func _enter(game: Node, code: String) -> void:
	for digit in code:
		_press(game, _prompt(game).pad.key_rect(digit).get_center())


## Overwrites the file at `path` with `bytes`, as damage would.
func _damage(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "can write %s" % path)
	file.store_buffer(bytes)
	file.close()


## The file at `path` cut to half its length, as a kill mid-write leaves it.
func _cut_short(path: String) -> PackedByteArray:
	var bytes := FileAccess.get_file_as_bytes(path)
	return bytes.slice(0, bytes.size() / 2)


## Bytes that are no JSON at all.
func _garbage() -> PackedByteArray:
	return PackedByteArray([0x00, 0xff, 0x7b, 0x13, 0x88, 0x22, 0x00, 0x5d])


# --- The backup keeps the code ---------------------------------------------------------------

# @test-link [[req_parent_gate_and_access]]
func test_a_damaged_parent_file_keeps_the_code_from_its_backup() -> void:
	var game := _game()
	_walk_setup(game)
	assert_true(FileAccess.file_exists(BACKUP_PATH), "setup wrote the backup")
	_damage(STORE_PATH, _cut_short(STORE_PATH))
	var again := _game()
	assert_push_error("backup")
	assert_eq(_state(again), ParentGate.State.HIDDEN, "setup is not shown again (DoD 23)")
	assert_false(_setup(again).visible)
	assert_true(again.parent_store.has_code())
	assert_false(again.parent_store.is_locked())
	var prompt := _open(again, ParentGate.LEAVE)
	_enter(again, WRONG)
	assert_eq(again.parent_store.wrong_tries(), 1, "a wrong code counts")
	assert_eq(prompt.entry, "", "and clears the entry")
	assert_eq(_state(again), ParentGate.State.PROMPT, "the gate stays shut")
	assert_eq(quits, 0)
	assert_eq(ParentStore.new(STORE_PATH).wrong_tries(), 1, "the count is on disk: the file is mended")
	assert_eq(FileAccess.get_file_as_bytes(STORE_PATH), FileAccess.get_file_as_bytes(BACKUP_PATH),
			"the file and its backup agree again")
	_enter(again, CODE)
	assert_eq(quits, 1, "the old code opens the gate")
	assert_eq(again.parent_store.wrong_tries(), 0, "and resets the count")


# @test-link [[req_parent_gate_and_access]]
func test_a_wait_running_before_the_damage_still_runs_after_a_new_launch() -> void:
	var game := _game()
	_walk_setup(game)
	_open(game, ParentGate.SETTINGS)
	for i in ParentStore.WRONG_TRIES_BEFORE_WAIT:
		_enter(game, WRONG)
	assert_true(_prompt(game).waiting(), "5 wrong tries: the wait")
	_damage(STORE_PATH, _garbage())
	var again := _game()
	assert_push_error("backup")
	assert_eq(_state(again), ParentGate.State.HIDDEN, "setup is not shown again (DoD 23)")
	assert_eq(again.parent_store.wrong_tries(), ParentStore.WRONG_TRIES_BEFORE_WAIT, "the count from the backup")
	var prompt := _open(again, ParentGate.SETTINGS)
	assert_true(prompt.waiting(), "the wait still runs")
	_enter(again, CODE)
	assert_eq(_state(again), ParentGate.State.PROMPT, "even the right code is refused")
	_steps(again, ParentStore.WAIT_MS * 60 / 1000)
	prompt = _open(again, ParentGate.SETTINGS)
	assert_false(prompt.waiting(), "30 s later: the wait is over")
	_enter(again, CODE)
	assert_eq(_state(again), ParentGate.State.SETTINGS, "the old code opens settings")


# --- Both damaged: locked ----------------------------------------------------------------------

# @test-link [[req_parent_gate_and_access]]
# @test-link [[req_denial_and_stepup_behavior]]
func test_both_files_damaged_lock_the_gate_without_setup_and_leave_the_files_as_they_are() -> void:
	var game := _game()
	_walk_setup(game)
	_damage(STORE_PATH, _cut_short(STORE_PATH))
	_damage(BACKUP_PATH, _garbage())
	var main_bytes := FileAccess.get_file_as_bytes(STORE_PATH)
	var backup_bytes := FileAccess.get_file_as_bytes(BACKUP_PATH)
	var again := _game()
	assert_push_error("locked")
	assert_eq(_state(again), ParentGate.State.HIDDEN, "setup is not shown again (DoD 23)")
	assert_false(_setup(again).visible)
	assert_true(again.parent_store.is_locked())
	var prompt := _open(again, ParentGate.LEAVE)
	_enter(again, CODE)
	assert_eq(quits, 0, "the old code is refused")
	assert_eq(_state(again), ParentGate.State.PROMPT, "the gate stays shut")
	assert_eq(again.parent_store.wrong_tries(), 1, "it counts as a wrong try")
	for i in ParentStore.WRONG_TRIES_BEFORE_WAIT - 1:
		_enter(again, WRONG)
	assert_true(prompt.waiting(), "5 wrong: the wait applies as usual")
	assert_eq(FileAccess.get_file_as_bytes(STORE_PATH), main_bytes, "parent.json left byte for byte")
	assert_eq(FileAccess.get_file_as_bytes(BACKUP_PATH), backup_bytes, "parent.json.bak left byte for byte")
	for side in [STORE_PATH + ParentStore.SIDE_SUFFIX, BACKUP_PATH + ParentStore.SIDE_SUFFIX]:
		assert_false(FileAccess.file_exists(side), "no side file %s" % side)
	var third := _game()
	assert_push_error("locked")
	assert_eq(_state(third), ParentGate.State.HIDDEN, "still no setup at the next launch")
