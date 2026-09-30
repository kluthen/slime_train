extends Node2D
## The game root (the main scene). It owns the simulation and drives it at a
## fixed step: every frame, FixedStep turns the frame time into whole ticks
## and each tick runs one Simulation.step(), so the game runs the same at any
## frame rate. Real touches go to the simulation as input events, after the
## parent layer (ParentGate, src/parent/) and the debug overlay take theirs.
##
## Test mode (see TestModeGuard) is reached only through enable_test_mode()
## or the "--test-mode" command-line flag, and only in a debug build. This
## script names test-mode code by path only, never by class, so a release
## export can leave src/test_mode/ out.
##
## In a debug build it loads the test level (levels/test/), adds a Camera2D
## and hands the level's plain data to the simulation. The test level is
## named by path too (LevelCatalog: res://levels/<id>/level.tscn), never by a
## class: it never ships (D91). A release build has no level yet (the real
## first level comes later).
##
## Choosing a level (chunk LD1) is for test mode only, so debug builds only:
## a run's "level" (--level=<id>) replaces the loaded level before anything
## reads it, and the game started with --test-mode --level=<id> loads that
## level from the start. The player never chooses a level (v1 ships one).
##
## The level's collision terrain is baked once into TerrainSegments and
## shared by every simulation started on it; a SlimeRenderer draws the
## current simulation's slimes and a TapFeedback their ripples and eyes.
## The camera is the simulation's (Camera: rails, edge buttons, call drag,
## framing zones, idle camera). Normal play has sessions (Session, chunk 17):
## it opens in screensaver mode (the idle camera), or where its session or
## bedtime was; before every tick the game hands the session the real clocks
## (SessionClock), saves when bedtime begins, and SessionScreen shows the
## dusk and keeps the screen on during a session. Test mode plays untimed,
## as in a session, unless its run turns sessions on; its clocks are test
## mode's. sync_view() makes the simulation's view and the scene's Camera2D show it,
## before and after every tick. EdgeButtons draws the edge buttons on a HUD
## layer.
##
## Saves (chunk 8). In normal play the game starts from the level's save when
## there is one (SaveStore, user://saves/<level id>.json; SaveData has the
## format), else fresh with the first slime woken. It autosaves (Autosave)
## every 15 s of wall time, when the app goes to the background, and when it
## quits. A save it can't use (unreadable, another level version) is left
## untouched: the game starts fresh, says why, and writes nothing over it.
## Only the main scene gets the default store: a game a test adds gets the
## store the test gives it, or none, and then never writes. Test mode starts
## from its fixture or "load" save, and autosaves only when its run asks.
##
## A build exported with the "spike_soft_slimes" feature tag (the "Android
## spike: soft slimes" preset) runs spike 1's phone benchmark instead of the
## game, since the official Android templates ignore a scene given on the
## command line (see docs/dev/README.md "Android export (debug)"). The spike
## is named by path only, like the test level.
##
## The phone (chunk 20): `platform` (PhonePlatform) reaches the Android
## plugin; ScreenPinning asks for screen pinning at launch and handles Back
## and the back gesture's excluded edge strips; the parent's leave stops the
## pinning (ParentGate.act). In normal play, `tilt_feed` (TiltFeed) hands the
## simulation the phone's tilt sensor before every tick.
# @spec-link [[req_test_level_and_test_mode]]

const TEST_MODE_SCRIPT := "res://src/test_mode/test_mode.gd"
const TEST_MODE_REFUSED := "Test mode is not available in this build (release builds never run it)."
## The most ticks one frame runs at normal speed (proposed, chunk 22): 2
## ticks, a 33 ms frame (30 fps) still plays at full speed. Beyond that the
## game plays in slow motion rather than catching up: a tick costing more
## than a frame's time no longer multiplies the next frame (it was 8, and on
## the reference phone an overloaded frame then ran 8 ticks, 4-5 fps). A
## faster debug speed scales it (FixedStep.max_ticks_for).
const MAX_TICKS_PER_FRAME := 2
## The export feature tag that swaps the game for spike 1's benchmark.
const SPIKE_SOFT_SLIMES_FEATURE := "spike_soft_slimes"
const SPIKE_SOFT_SLIMES_SCENE := "res://spikes/soft-slimes/spike.tscn"
## The debug overlay (speed, reset, labels, kill, counter). Debug builds only,
## named by path like test mode (see add_debug_overlay()).
const DEBUG_OVERLAY_SCRIPT := "res://src/debug/debug_overlay.gd"
## The perf log (a PERF line every few seconds, for measuring on a phone).
## Debug builds only, named by path like the overlay (see add_perf_log()).
const PERF_LOG_SCRIPT := "res://src/debug/perf_log.gd"
## The user argument that asks for it: --perf-log[=SECONDS].
const PERF_LOG_FLAG := "--perf-log"
## The measurement's other user argument, --max-ticks-per-frame=N: the cap
## at 1x for this run (max_ticks_per_frame), read with the perf log's.
const MAX_TICKS_FLAG := "--max-ticks-per-frame"
const PERF_LOG_REFUSED := ("The perf log and its measurement flags are not available in this build"
		+ " (release builds never run them).")

var simulation: Simulation
## The loaded level, or null (a release build has none yet).
var level: Level = null
## Shows what the simulation's camera shows (sync_view()); it has no logic of
## its own. Null without a level.
var camera: Camera2D = null
## Draws the current simulation's slimes (DIRECT when headless).
var slime_renderer: SlimeRenderer = null
## Draws the tap ripples and the slimes' facing, above the slimes.
var tap_feedback: TapFeedback = null
## Draws the frontier sets' state and the celebration (chunk 14).
# @spec-link [[req_switch_basket_gate_set]]
var frontier_view: FrontierView = null
## Draws the edge buttons, in screen pixels on the HUD layer.
var edge_buttons: EdgeButtons = null
## Tints the world toward dusk and keeps the screen on during a session.
var session_screen: SessionScreen = null
## The real clocks the session counts on in normal play. Loosely typed so
## tests can hand it anything with a now() (see SessionClock).
# @spec-link [[req_session_lifecycle]]
var session_clock: RefCounted = SessionClock.new()
## The running TestMode, or null. Loosely typed on purpose (see above).
var test_mode: RefCounted = null
## Replaced by tests to check the release path.
var test_mode_guard := TestModeGuard.for_this_build()
## Where the levels' saves go, or null: the game never saves. The main scene
## gets the default (user://saves/) in _ready; tests set their own first.
# @spec-link [[req_persistence_and_saves]]
var save_store: SaveStore = null
## When the game saves on its own. Enabled in normal play with a store, and
## in test mode only when the run asks.
# @spec-link [[req_persistence_and_saves]]
var autosave := Autosave.new()
## The app's parent store (the parent code), or null: no parent layer at
## all. Like save_store, the main scene gets the default (user://parent.json)
## in _ready; a game a test adds gets the store the test gives it, or none.
# @spec-link [[req_parent_gate_and_access]]
var parent_store: ParentStore = null
## The parent layer (parent buttons and surfaces), or null without a store.
var parent_gate: ParentGate = null
## Closes the app: the parent's leave (ParentGate.act). The tree's quit unless
## a test put its own first.
var quit_app := Callable()
## The phone's services (screen pinning, the back gesture, the lock screen):
## the Android plugin's in an Android build, else the desktop stub, whose
## calls do nothing. Tests put a fake first, before the game enters the tree.
# @spec-link [[req_screen_pinning]]
var platform: PhonePlatform = PhonePlatform.for_this_build()
## Screen pinning at launch and the back gesture, through `platform`.
var screen_pinning: ScreenPinning = null
## The display's safe area through `platform`, handed to the view (sync_view()).
# @spec-link [[req_parent_gate_and_access]]
var safe_area: SafeArea = null
## The phone's tilt sensor, fed to the simulation in normal play only (test
## mode's script is its only tilt). Tests replace its `sensor`.
# @spec-link [[req_tilt_input]]
var tilt_feed := TiltFeed.new()
## The debug overlay, or null (a release build, or a game a test adds).
## Loosely typed: src/debug/ is named by path only.
var debug_overlay: Node = null
## The perf log, or null (not asked for, a release build, or a game a test
## adds). Loosely typed: src/debug/ is named by path only.
var perf_log: Node = null
## The most ticks a frame runs at 1x (FixedStep.max_ticks_for scales it with
## the speed): MAX_TICKS_PER_FRAME, unless a debug measurement set another
## (--max-ticks-per-frame, read by add_perf_log()).
var max_ticks_per_frame := MAX_TICKS_PER_FRAME
## The ticks the last frame ran, and the real time they took (microseconds,
## around the step_simulation() calls): the perf log reads them.
var frame_ticks := 0
var frame_tick_usec := 0

var _clock := FixedStep.new()
## The level's collision terrain for the slimes, or null without a level.
var _terrain: TerrainSegments = null


func _ready() -> void:
	autosave.enabled = false
	if OS.has_feature(SPIKE_SOFT_SLIMES_FEATURE):
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().change_scene_to_file.call_deferred(SPIKE_SOFT_SLIMES_SCENE)
		return
	print("Slime Train booted (Godot %s)." % Engine.get_version_info().string)
	if get_tree().current_scene == self:
		save_store = save_store if save_store != null else SaveStore.new()
		parent_store = parent_store if parent_store != null else ParentStore.new()
	var user_args := OS.get_cmdline_user_args()
	if test_mode_guard.allows():
		var level_errors := _load_level(_first_level_id(user_args))
		for error in level_errors:
			printerr(error)
	slime_renderer = SlimeRenderer.new()
	slime_renderer.name = "Slimes"
	slime_renderer.draw_mode = SlimeRenderer.default_mode()
	add_child(slime_renderer)
	frontier_view = FrontierView.new()
	frontier_view.name = "Frontier"
	add_child(frontier_view)
	tap_feedback = TapFeedback.new()
	tap_feedback.name = "TapFeedback"
	add_child(tap_feedback)
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	add_child(hud)
	edge_buttons = EdgeButtons.new()
	edge_buttons.name = "EdgeButtons"
	hud.add_child(edge_buttons)
	session_screen = SessionScreen.new()
	session_screen.name = "SessionScreen"
	add_child(session_screen)
	if parent_store != null:
		parent_gate = ParentGate.new(parent_store, self)
		add_child(parent_gate)
	if not quit_app.is_valid():
		quit_app = func() -> void: get_tree().quit()
	# Pinning is asked at launch, before the world takes a tap (after setup on
	# first launch); test mode's runs too, through the same platform.
	screen_pinning = ScreenPinning.new(platform)
	add_child(screen_pinning)
	screen_pinning.launch(parent_gate)
	safe_area = SafeArea.new(platform)
	add_child(safe_area)
	if get_tree().current_scene == self:
		add_debug_overlay()
	_use_simulation(_new_simulation(Rng.random_seed()))
	if get_tree().current_scene == self:
		var perf_errors := add_perf_log(user_args)
		for error in perf_errors:
			printerr("Perf log: ", error)
		# A measurement asked for with a bad flag must not run as if unmeasured,
		# but in a release build the flag is simply ignored.
		if not perf_errors.is_empty() and test_mode_guard.allows():
			get_tree().quit(1)
			return
	if TestModeGuard.requested(user_args):
		var errors := start_test_mode_from_args(user_args)
		for error in errors:
			printerr("Test mode: ", error)
		# A scripted run that can't start must not carry on as normal play,
		# but in a release build the flag is simply ignored.
		if not errors.is_empty() and test_mode_guard.allows():
			get_tree().quit(1)
			return
	if test_mode == null:
		_resume_play()
		simulation.session.open(simulation)


## Runs the ticks this frame's time is worth at the current speed (FixedStep,
## at most FixedStep.max_ticks_for per frame), recording how many and how
## long they took (frame_ticks, frame_tick_usec), then autosaves when due.
func _process(delta: float) -> void:
	var scale: float = test_mode.time_scale if test_mode != null else 1.0
	if debug_overlay != null:
		scale *= debug_overlay.speed
	var ticks := _clock.advance(delta * scale, FixedStep.max_ticks_for(scale, max_ticks_per_frame))
	var start_usec := Time.get_ticks_usec()
	for i in ticks:
		step_simulation()
	frame_ticks = ticks
	frame_tick_usec = Time.get_ticks_usec() - start_usec
	if autosave.due(_now()):
		var error := save_now()
		if error != "":
			printerr("Autosave: ", error)


## Going to the background (Autosave.is_background) saves at once.
func _notification(what: int) -> void:
	# Back from the background: a running session takes the tilt's neutral again (D95).
	if what == NOTIFICATION_APPLICATION_RESUMED and simulation != null:
		simulation.session.reopened()
	if autosave.enabled and Autosave.is_background(what):
		var error := save_now()
		if error != "":
			printerr("Autosave: ", error)


## Quitting (or the game root leaving the tree) saves too.
func _exit_tree() -> void:
	if autosave.enabled:
		var error := save_now()
		if error != "":
			printerr("Autosave: ", error)
		autosave.enabled = false


func _unhandled_input(event: InputEvent) -> void:
	# Test mode's block keeps real input off the parent layer as off the world;
	# the debug overlay still gets it.
	var blocked: bool = test_mode != null and test_mode.block_real_input
	if parent_gate != null and not blocked and parent_gate.intercept(event):
		return
	if debug_overlay != null and debug_overlay.intercept(event):
		return
	if blocked:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			simulation.push_input(Simulation.touch_down(event.index, event.position))
		else:
			simulation.push_input(Simulation.touch_up(event.index, event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# On a phone, Godot also turns each touch into a mouse event; those
		# are already handled above.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.pressed:
			simulation.push_input(Simulation.touch_down(0, event.position))
		else:
			simulation.push_input(Simulation.touch_up(0, event.position))


## Runs one simulation tick, first giving it the view, the clocks (test
## mode's, else the real ones) and the input test mode scripted for that
## tick (in normal play, the tilt sensor's reading instead). When bedtime begins the game saves (if it autosaves). Then the
## parent layer's timers count the step (in normal play and test mode alike).
# @spec-link [[req_session_lifecycle]]
func step_simulation() -> void:
	sync_view()
	if test_mode != null:
		simulation.session.read_clock(test_mode.clock_at(simulation.tick))
		for event in test_mode.inputs_for_tick(simulation.tick):
			simulation.push_input(event)
	else:
		simulation.session.read_clock(session_clock.now())
		tilt_feed.feed(simulation)
	simulation.step()
	if simulation.session.save_due:
		simulation.session.save_due = false
		if autosave.enabled:
			var error := save_now()
			if error != "":
				printerr("Bedtime save: ", error)
	sync_view()
	if parent_gate != null:
		parent_gate.advance()


## Makes the simulation's view show what its camera shows (taps are
## dispatched through the view), and the scene's Camera2D show the view. The
## screen's size is test mode's "screen_size" in test mode (a headless window
## reports a wrong size), else the viewport's; its density is
## screen_px_per_mm(); its safe area, `safe_area`'s insets.
# @spec-link [[req_controls_tap_zones]]
# @spec-link [[req_camera_rails_and_framing]]
func sync_view() -> void:
	var size: Vector2 = test_mode.screen_size if test_mode != null else get_viewport_rect().size
	simulation.camera.apply_to(simulation.view, size)
	simulation.view.px_per_mm = screen_px_per_mm()
	if safe_area != null:
		safe_area.apply_to(simulation.view)
	if camera != null:
		camera.position = simulation.view.centre
		camera.zoom = Vector2(simulation.view.zoom, simulation.view.zoom)


## Viewport px per millimetre on this screen, for the sizes measured on the
## screen (the parent zone's 7 mm). On a phone: the display's density
## (platform.screen_dpi(): the panel's physical one when plausible, else
## DisplayServer's logical one) over the stretch's physical px per viewport
## px. In test mode and on the desktop: the reference phone's, so
## runs are the same everywhere and the desktop shows the phone's layout. A
## phone reading of 0 or less is reported and the reference phone's used.
# @spec-link [[req_controls_tap_zones]]
func screen_px_per_mm() -> float:
	if test_mode != null or not OS.has_feature("mobile"):
		return ScreenView.REFERENCE_PX_PER_MM
	var dpi := platform.screen_dpi()
	var shown := get_viewport_rect().size.x
	var physical := float(DisplayServer.window_get_size().x)
	if dpi <= 0.0 or shown <= 0.0 or physical <= 0.0:
		push_error("Screen density unreadable (dpi %s, %s physical px for %s viewport px): using the reference phone's"
				% [dpi, physical, shown])
		return ScreenView.REFERENCE_PX_PER_MM
	return ScreenView.px_per_mm_for(dpi, physical / shown)


## Saves the running simulation to its level's file now. Returns "" or why
## nothing was written (no store, no level, or SaveStore refused: the old
## file is kept). Autosave calls it; test mode may too.
# @spec-link [[req_persistence_and_saves]]
func save_now() -> String:
	autosave.saved(_now())
	if save_store == null:
		return "this game has no save store"
	if level == null or simulation == null or simulation.level == null:
		return "no level to save"
	return save_store.write(simulation.to_save())


## Turns test mode on with a run configuration (see src/test_mode/test_mode.gd)
## and starts a simulation from its seed on the run's level (loaded first
## when it isn't the loaded one): fresh, or from the fixture's or the "load"
## file's save (a save's own seed wins), the camera where "at" or else the
## fixture puts it. A run that blocks real input closes any open parent
## surface. Returns the errors; empty means test mode is on, and on an error
## the running game is left as it was. Refused in a release build.
# @spec-link [[req_test_level_and_test_mode]]
func enable_test_mode(config: Dictionary) -> PackedStringArray:
	if not test_mode_guard.allows():
		return PackedStringArray([TEST_MODE_REFUSED])
	var candidate: RefCounted = load(TEST_MODE_SCRIPT).from_config(config)
	if not candidate.errors.is_empty():
		return candidate.errors
	if candidate.autosave and save_store == null:
		return PackedStringArray(["'autosave' needs a save store, and this game has none"])
	var run_level := level
	if level == null or level.level_id != candidate.level_id:
		var opened := _open_level(candidate.level_id)
		if not opened["errors"].is_empty():
			return opened["errors"]
		run_level = opened["level"]
	var start := _run_start(candidate, run_level)
	if not start["errors"].is_empty():
		if run_level != level:
			run_level.free()
		return start["errors"]
	if run_level != level:
		_use_level(run_level)
	var fresh: Simulation
	if candidate.save_data.is_empty():
		fresh = _new_simulation(candidate.seed_value)
	else:
		fresh = Simulation.from_save(candidate.save_data, level.data, _terrain, candidate.seed_value)
	if start["camera"] != null and level.data.loop != null:
		fresh.camera.start(level.data.loop, fresh.train.open_gates if fresh.train != null else [], start["camera"])
	if candidate.sessions:
		fresh.session.open(fresh)
	if test_mode != null:
		test_mode.detach()
	test_mode = candidate
	_use_simulation(fresh)
	_clock.reset()
	autosave.enabled = candidate.autosave
	autosave.start(_now())
	# Real input blocked, no one could answer a parent surface (first launch's
	# setup, proposed): it closes. Setup saved no code, so the next launch
	# shows it again.
	if parent_gate != null and test_mode.block_real_input:
		parent_gate.close()
	test_mode.attach(self)
	return PackedStringArray()


## Starts test mode from the command-line flags (see TestMode.config_from_args).
## With --run-ticks=N it runs N ticks at once, prints
## "STATE tick=<N> hash=<sha256>", saves to --save's file if given, and
## quits. Returns the errors.
func start_test_mode_from_args(user_args: PackedStringArray) -> PackedStringArray:
	if not test_mode_guard.allows():
		return PackedStringArray([TEST_MODE_REFUSED])
	var parsed: Dictionary = load(TEST_MODE_SCRIPT).config_from_args(user_args)
	if not parsed["errors"].is_empty():
		return parsed["errors"]
	var errors := enable_test_mode(parsed["config"])
	if not errors.is_empty():
		return errors
	if parsed["run_ticks"] >= 0:
		test_mode.run_ticks(parsed["run_ticks"])
		print("STATE tick=%d hash=%s" % [simulation.tick, simulation.state_hash()])
		if parsed["print_state"]:
			print("STATE_JSON ", StateHash.canonical_json(simulation.dump()))
		if parsed["save_path"] != "":
			var error := SaveStore.write_file(parsed["save_path"], simulation.to_save())
			if error != "":
				return PackedStringArray([error])
			print("SAVED ", parsed["save_path"])
		get_tree().quit()
	return PackedStringArray()


## What a test-mode run starts from on `run_level` (not yet the loaded level
## when the run switches levels): its save checked against the level, and
## where the camera starts ("at" over the fixture's camera; either may be a
## stable ID, found in the level: Level.point_of). Returns {"errors",
## "camera" (a level point or null)}.
# @spec-link [[req_test_level_and_test_mode]]
func _run_start(candidate: RefCounted, run_level: Level) -> Dictionary:
	if not candidate.save_data.is_empty():
		var problems := SaveData.problems(candidate.save_data, run_level.data)
		if not problems.is_empty():
			return {"errors": problems, "camera": null}
	var at: Variant = candidate.at if candidate.at != null else candidate.camera
	if at is String:
		var setting := "'at'" if candidate.at != null else "fixture '%s''s 'camera'" % candidate.fixture_name
		var point: Variant = run_level.point_of(at)
		if point == null:
			return {"errors": PackedStringArray(["%s: no '%s' in level '%s'" % [setting, at, run_level.level_id]]),
					"camera": null}
		at = point
	return {"errors": PackedStringArray(), "camera": at}


## The level the game loads at start: the test level, or in a debug build
## started with --test-mode, the run's "level" when it is one (a bad one is
## reported when test mode starts), so that the game doesn't load the test
## level only to replace it.
# @spec-link [[req_test_level_and_test_mode]]
func _first_level_id(user_args: PackedStringArray) -> String:
	if not TestModeGuard.requested(user_args):
		return LevelCatalog.DEFAULT_ID
	var parsed: Dictionary = load(TEST_MODE_SCRIPT).config_from_args(user_args)
	var id: Variant = parsed["config"].get("level", LevelCatalog.DEFAULT_ID)
	if typeof(id) == TYPE_STRING and LevelCatalog.exists(id):
		return id
	return LevelCatalog.DEFAULT_ID


## Loads level `id` (LevelCatalog) in place of the loaded one. Returns the
## errors; on an error the loaded level stays.
# @spec-link [[req_loop_and_world]]
func _load_level(id: String) -> PackedStringArray:
	var opened := _open_level(id)
	if opened["errors"].is_empty():
		_use_level(opened["level"])
	return opened["errors"]


## Opens level `id`'s scene without adding it: instantiated and built
## (Level.build doesn't need the tree), so that it can be checked before it
## replaces anything. A level with problems (Level.load_errors) is refused,
## as is a scene that isn't a Level or whose level_id isn't `id`. Returns
## {"level" (null on an error), "errors"}.
# @spec-link [[req_test_level_and_test_mode]]
func _open_level(id: String) -> Dictionary:
	var problem := LevelCatalog.problem(id)
	if problem != "":
		return {"level": null, "errors": PackedStringArray([problem])}
	var path := LevelCatalog.scene_path(id)
	var scene := load(path) as PackedScene
	var node: Node = scene.instantiate() if scene != null else null
	if not (node is Level):
		if node != null:
			node.free()
		return {"level": null, "errors": PackedStringArray(["level %s: %s is not a level scene (its root must be a Level)"
				% [id, path]])}
	var errors := PackedStringArray()
	for error in node.build():
		errors.append("level %s: %s" % [id, error])
	if node.level_id != id:
		errors.append("level %s: its level_id is '%s' (it must be its folder's name)" % [id, node.level_id])
	if not errors.is_empty():
		node.free()
		return {"level": null, "errors": errors}
	return {"level": node, "errors": errors}


## Makes `opened` (from _open_level) the loaded level: frees the old one,
## adds it under everything the game draws, bakes its collision terrain, and
## adds the Camera2D that shows the simulation's camera if there is none
## yet. The caller then starts a simulation on it.
# @spec-link [[req_test_level_and_test_mode]]
func _use_level(opened: Level) -> void:
	if level != null:
		# Freed now: nothing but the game holds a level node (the simulation
		# and the views hold its plain data).
		remove_child(level)
		level.free()
	level = opened
	add_child(level)
	move_child(level, 0)
	_terrain = SlimeWorld.terrain_from(level)
	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera"
		add_child(camera)
		camera.make_current()


## Normal play: starts from the level's save if there is a usable one (else
## the fresh simulation stays), then turns autosave on. The store falls back
## on the backup and sets unreadable files aside (SaveStore.read), which is
## said on the error output. A save that can't be used is kept as it is and
## blocked from being written over. A save of an older level version is
## migrated as it loads, its file kept first (_keep_pre_migration).
# @spec-link [[req_persistence_and_saves]]
# @spec-link [[rule_saves_never_wiped]]
func _resume_play() -> void:
	if save_store == null or level == null:
		return
	var level_id := level.data.level_id
	var result := save_store.read(level_id)
	if result["status"] == SaveStore.UNREADABLE:
		printerr("Save: ", result["error"], " Starting fresh; it won't be written over.")
	elif result["status"] == SaveStore.FRESH and not result["set_aside"].is_empty():
		printerr("Save: ", result["error"], " Nothing could be read: starting fresh.")
	elif result["status"] == SaveStore.OK and result["error"] != "":
		printerr("Save: ", result["error"])
	if result["status"] == SaveStore.OK:
		var problems := SaveData.problems(result["save"], level.data)
		if problems.is_empty():
			if SaveMigration.is_older(result["save"], level.data):
				_keep_pre_migration(result)
			_use_simulation(Simulation.from_save(result["save"], level.data, _terrain, simulation.rng.seed_value))
		else:
			var reason := "; ".join(problems)
			var used := save_store.path_for(level_id)
			if result["source"] == SaveStore.SOURCE_BACKUP:
				used += SaveStore.BACKUP_SUFFIX
			save_store.block(level_id, reason)
			printerr("Save: %s can't be used (%s). Starting fresh; it won't be written over."
					% [used, reason])
	autosave.enabled = true
	autosave.start(_now())


## Before a save of an older level version is loaded (and so migrated,
## SaveMigration) and later written at the level's version: keeps the file
## it was read from as it is (SaveStore.keep_version_copy), and says so on
## the error output. A copy that fails blocks the level's writes (the
## store does), so the old save is never written over.
# @spec-link [[rule_released_level_stable_with_migration]]
# @spec-link [[rule_saves_never_wiped]]
func _keep_pre_migration(result: Dictionary) -> void:
	var level_id := level.data.level_id
	var old_version := int(result["save"]["level"]["version"])
	var kept := save_store.keep_version_copy(level_id, old_version, result["source"])
	var migrating := "Save: level '%s' was saved by its version %d and is at version %d: migrating it." % [
			level_id, old_version, level.data.level_version]
	if kept["error"] != "":
		printerr(migrating, " ", kept["error"])
	else:
		printerr(migrating, " The file as it was is kept as ", kept["path"], ".")


## Adds the debug overlay (src/debug/debug_overlay.gd) on its own layer, if
## this build is a debug build (TestModeGuard) and it has none yet. The main
## scene does in _ready; tests may.
func add_debug_overlay() -> void:
	if debug_overlay != null or not test_mode_guard.allows():
		return
	debug_overlay = load(DEBUG_OVERLAY_SCRIPT).new()
	add_child(debug_overlay)


## Adds the perf log (src/debug/perf_log.gd) when `user_args` hold
## --perf-log[=SECONDS] and this build is a debug build (TestModeGuard), in
## normal play or test mode alike, and it has none yet; with
## --max-ticks-per-frame=N (a measurement, with or without the log) sets
## max_ticks_per_frame to N. Returns the errors: the refusal in a release
## build, or a malformed flag (nothing added or set). The main scene calls it
## in _ready; tests may.
func add_perf_log(user_args: PackedStringArray) -> PackedStringArray:
	var asked := false
	for arg in user_args:
		asked = asked or arg.get_slice("=", 0) in [PERF_LOG_FLAG, MAX_TICKS_FLAG]
	if not asked or perf_log != null:
		return PackedStringArray()
	if not test_mode_guard.allows():
		return PackedStringArray([PERF_LOG_REFUSED])
	var script: GDScript = load(PERF_LOG_SCRIPT)
	var parsed: Dictionary = script.parse_args(user_args)
	if not parsed["errors"].is_empty():
		return parsed["errors"]
	if parsed["max_ticks"] > 0:
		max_ticks_per_frame = parsed["max_ticks"]
	if parsed["requested"]:
		perf_log = script.new(parsed["seconds"])
		add_child(perf_log)
	return PackedStringArray()


## Starts the level over as on a first launch: a fresh simulation (a new
## random seed; test mode's run seed in test mode), sessions open in normal
## play (in test mode when the run has them), the frame clock and autosave
## counting from now. With `keep_session` the running session goes on in the
## fresh simulation instead (Simulation.carry_session: phase, timer, clocks),
## for the parent's delete. Writes no save (the debug overlay's reset and
## delete_level_save() save after it). Returns the new simulation.
func restart_fresh(keep_session := false) -> Simulation:
	var old := simulation
	_use_simulation(_new_simulation(test_mode.seed_value if test_mode != null else Rng.random_seed()))
	_clock.reset()
	if keep_session:
		# Test mode's clocks are a function of the tick: they go on from the
		# old tick, not from the fresh one (the real clocks simply go on).
		if test_mode != null:
			test_mode.carry_clock(old.tick, simulation.tick)
		simulation.carry_session(old)
	elif test_mode == null or test_mode.sessions:
		simulation.session.open(simulation)
	autosave.start(_now())
	return simulation


## The parent's delete of the running level's save (settings, D43, D104; DoD
## 29): the store deletes it, then the level reloads fresh at once (the hint
## due again, the celebration able to play again, all progress gone) while
## the running session goes on untouched, so it ends when it would have; the
## fresh save is written at once, so a kill right after resumes the same
## session. Without a store (tests) it only reloads. Returns "" or why not:
## a save the store can't delete leaves the game as it was; a fresh save the
## store refuses is reported after the reload (the old file is gone anyway).
# @spec-link [[req_persistence_and_saves]]
# @spec-link [[req_session_lifecycle]]
func delete_level_save() -> String:
	if save_store != null and level != null:
		var error := save_store.delete(level.data.level_id)
		if error != "":
			return error
	restart_fresh(true)
	if save_store == null or level == null:
		return ""
	return save_now()


## The parent's wake early (D57): queued for the next simulation step, where
## bedtime ends in sunrise and screensaver mode (Simulation.wake_early; it
## does nothing outside bedtime).
# @spec-link [[req_session_lifecycle]]
func wake_early() -> void:
	simulation.push_input(Simulation.wake_early())


## The wall clock the session reads, Unix ms: test mode's clock at the
## current tick, else session_clock (the parent's wrong-code wait counts on it).
func now_wall_ms() -> int:
	var reading: Dictionary = test_mode.clock_at(simulation.tick) if test_mode != null else session_clock.now()
	return reading["wall_ms"]


## Wall-clock seconds, for autosave.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## A fresh simulation from `seed_value`, holding the level's plain data and
## its collision terrain.
func _new_simulation(seed_value: int) -> Simulation:
	var fresh := Simulation.new(seed_value)
	fresh.slimes.terrain = _terrain
	if level != null:
		fresh.load_level(level.data)
	return fresh


## Makes `fresh` the running simulation, and the one drawn.
func _use_simulation(fresh: Simulation) -> void:
	simulation = fresh
	# The game simulates only near the screen (chunk 15).
	fresh.offscreen.enabled = true
	# The world shows: a due first-play hint counts its 10 s from here.
	fresh.hint.world_shown(fresh.tick)
	if slime_renderer != null:
		slime_renderer.bodies = fresh.slimes
	if tap_feedback != null:
		tap_feedback.simulation = fresh
	if frontier_view != null:
		frontier_view.simulation = fresh
	if edge_buttons != null:
		edge_buttons.simulation = fresh
	if session_screen != null:
		session_screen.simulation = fresh
	if parent_gate != null:
		parent_gate.simulation = fresh
	sync_view()
