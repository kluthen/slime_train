extends GutTest
## Saves cross the ticks (chunk 5N U6; build plan 5N "Done when": a save
## written under either tick loads under the other). Fixtures of the test
## level, loaded as tools/bench_level.gd loads them, run LEAD_IN ticks on one
## tick (SlimeBodies.use_native) and saved through the save's text; each save
## is loaded under the other tick and runs TICKS more: no NaN, the same slimes
## at the load (ids, species, sizes, states), the population kept to the end
## (the slimes of each species, counted by size: fusion and splits keep it),
## every centre within the terrain's grid. And a save loaded twice under the
## same tick runs to the same hash (each tick is repeatable from a save).
## Nothing in a save says which tick wrote it (docs/dev/native.md, "Saves").
## And a reload carries on as the run that never stopped (docs/dev/README.md,
## "Saves and fixtures"): on `stress-dense`, saved just after a train slime
## took off (the train's relay, chunk 24g), with no slime in the air, the
## reload's state equals the uninterrupted run's at the load, one tick and
## TICKS ticks later.
## Pending when the run asked for the GDScript tick without the extension
## (SLIME_TICK=gdscript); failing otherwise.
# @test-link [[req_persistence_and_saves]]

const SEED := 909
## Ticks a fixture runs before it is saved.
const LEAD_IN := 120
## Ticks a loaded save runs.
const TICKS := 600
## A resting pile in a basket with the train moving past it; shut doors.
const FIXTURES: PackedStringArray = ["s3-basket-59of60", "gate2-open"]
## The crowded bowl, where the relay acts on most ticks.
const RELAY_FIXTURE := "stress-dense"
## The last tick the relay check looks for its save tick at.
const RELAY_SEARCH_UNTIL := 300
const NATIVE := true
const GDSCRIPT := false
## How far outside the terrain's grid a centre may be (a hop above the top).
const MARGIN := 400.0

var _level: Level = null
var _terrain: TerrainSegments = null


## The test level, built once, and its terrain.
func before_all() -> void:
	_level = load(LevelCatalog.scene_path(LevelCatalog.DEFAULT_ID)).instantiate()
	assert_eq(_level.build(), PackedStringArray(), "the test level builds")
	_terrain = SlimeWorld.terrain_from(_level)


## Frees the test level (never in the tree).
func after_all() -> void:
	_level.free()


## Whether the native tick can run; marks the test pending (SLIME_TICK=gdscript
## without the extension) or failed (the extension didn't load) when not.
func _native_available() -> bool:
	if ClassDB.class_exists(TickChoice.SOLVER_CLASS):
		return true
	if OS.get_environment(TickChoice.ENV) == TickChoice.GDSCRIPT:
		pending("SLIME_TICK=gdscript and the slime_native extension isn't loaded")
	else:
		fail_test("SlimeSolver is not registered: the slime_native extension didn't load")
	return false


## `sim` on the tick asked for (`native`), set up as the game sets up a
## simulation it loads (main._use_simulation: off-screen simulation on, the
## hint's world shown).
func _ready_on(sim: Simulation, native: bool) -> Simulation:
	assert_true(sim.slimes.use_native(native), "the tick asked for")
	assert_eq(sim.slimes.uses_native(), native)
	sim.offscreen.enabled = true
	sim.hint.world_shown(sim.tick)
	return sim


## Fixture `fixture_name` as the bench loads it (the camera where the
## fixture puts it), on the tick asked for.
func _from_fixture(fixture_name: String, native: bool) -> Simulation:
	var loaded := TestMode.load_fixture(fixture_name)
	assert_true(loaded["ok"], str(loaded["error"]))
	var sim := Simulation.from_save(loaded["save"], _level.data, _terrain, SEED)
	assert_not_null(sim, fixture_name + " loads on the test level")
	var camera: Variant = loaded["camera"]
	if camera is String:
		camera = _level.point_of(camera)
	if camera != null:
		sim.camera.start(_level.data.loop, sim.train.open_gates, camera)
	return _ready_on(sim, native)


## `sim` saved as the game writes it: the save's text, parsed back.
func _save_text(sim: Simulation) -> Dictionary:
	var json := JSON.new()
	assert_eq(json.parse(SaveData.to_text(sim.to_save())), OK)
	return json.data


## The save `save` loaded on the tick asked for, or null after failing.
func _load(save: Dictionary, native: bool, label: String) -> Simulation:
	var sim := Simulation.from_save(save, _level.data, _terrain, SEED)
	assert_not_null(sim, label + ": the save loads")
	return _ready_on(sim, native) if sim != null else null


## `ticks` ticks as the bench runs them: the view follows the camera first.
func _run(sim: Simulation, ticks: int) -> void:
	for t in ticks:
		sim.camera.apply_to(sim.view, ScreenView.DEFAULT_SIZE)
		sim.step()


## Each slime's id, species, size and state, by id.
func _slimes(sim: Simulation) -> Dictionary:
	var out := {}
	for slime_id in sim.slimes.ids():
		out[slime_id] = [sim.slimes.species_of(slime_id), sim.slimes.size_of(slime_id), sim.slimes.state_of(slime_id)]
	return out


## The population: per species, the slimes counted by size.
func _population(sim: Simulation) -> Dictionary:
	var out := {}
	for slime_id in sim.slimes.ids():
		var species := sim.slimes.species_of(slime_id)
		out[species] = out.get(species, 0) + sim.slimes.size_of(slime_id)
	return out


## Whether `sim` has a slime in the air, as MidairLanding finds them (not
## supported, not parked, neither a sleeper nor in a basket): a load would
## move it.
func _any_in_the_air(sim: Simulation) -> bool:
	var bodies := sim.slimes
	for slime_id in bodies.ids():
		var state := bodies.state_of(slime_id)
		if bodies.is_parked(slime_id) or state == SlimeBodies.SLEEPER or state == SlimeBodies.IN_BASKET:
			continue
		if not bodies.body_of(slime_id)["supported"]:
			return true
	return false


## The entries of `a`'s and `b`'s dumps that differ, by name; the hint is
## left out (each load shows the hint's world again, Simulation.hint).
func _dump_differences(a: Simulation, b: Simulation) -> PackedStringArray:
	var da := a.dump()
	var db := b.dump()
	var out := PackedStringArray()
	for key: String in da:
		if key != "hint" and da[key] != db.get(key):
			out.append(key)
	return out


## No NaN or infinity in the points, and every centre within the terrain's
## grid (grown by MARGIN).
func _assert_sound(sim: Simulation, label: String) -> void:
	var bodies := sim.slimes
	var bad := 0
	for i in bodies.pos.size():
		if not (bodies.pos[i].is_finite() and bodies.prev[i].is_finite()):
			bad += 1
	assert_eq(bad, 0, label + ": every point finite")
	var grid := Rect2(_terrain.origin, Vector2(_terrain.grid_w, _terrain.grid_h) / _terrain.inv_cell).grow(MARGIN)
	var out := PackedStringArray()
	for slime_id in bodies.ids():
		var c := bodies.centre_of(slime_id)
		if not (c.is_finite() and grid.has_point(c)):
			out.append("%d at %s" % [slime_id, c])
	assert_eq(out, PackedStringArray(), "%s: every centre within %s" % [label, grid])


## A save written on one tick, loaded on the other: the same slimes at the
## load, then TICKS ticks sound, the population kept.
func _assert_crosses(save: Dictionary, source: Simulation, native: bool, label: String) -> void:
	var sim := _load(save, native, label)
	if sim == null:
		return
	assert_eq(sim.tick, source.tick, label + ": the save's tick")
	assert_eq(_slimes(sim), _slimes(source), label + ": the same slimes (ids, species, sizes, states)")
	var population := _population(source)
	_run(sim, TICKS)
	assert_eq(sim.tick, source.tick + TICKS, label)
	assert_eq(_population(sim), population, label + ": the population kept")
	_assert_sound(sim, label)


## Each fixture run on each tick and saved; each save loaded under the
## other tick (_assert_crosses).
func test_a_save_from_each_tick_loads_and_runs_under_the_other() -> void:
	if not _native_available():
		return
	for fixture_name in FIXTURES:
		var on_gdscript := _from_fixture(fixture_name, GDSCRIPT)
		var on_native := _from_fixture(fixture_name, NATIVE)
		_run(on_gdscript, LEAD_IN)
		_run(on_native, LEAD_IN)
		_assert_crosses(_save_text(on_gdscript), on_gdscript, NATIVE, fixture_name + ", GDScript save on native")
		_assert_crosses(_save_text(on_native), on_native, GDSCRIPT, fixture_name + ", native save on GDScript")


## Each fixture's save, on each tick, loaded twice under the tick that wrote
## it: the same hash at the load and TICKS ticks later.
func test_a_save_reloaded_on_the_same_tick_runs_to_the_same_hash() -> void:
	if not _native_available():
		return
	for fixture_name in FIXTURES:
		for native in [NATIVE, GDSCRIPT]:
			var label := "%s, %s" % [fixture_name, "native" if native else "GDScript"]
			var source := _from_fixture(fixture_name, native)
			_run(source, LEAD_IN)
			var save := _save_text(source)
			var first := _load(save, native, label + ", first load")
			var second := _load(save, native, label + ", second load")
			if first == null or second == null:
				return
			assert_eq(first.state_hash(), second.state_hash(), label + ": the loads agree")
			_run(first, TICKS)
			_run(second, TICKS)
			assert_eq(first.state_hash(), second.state_hash(), label + ": the same hash after %d ticks" % TICKS)
			_assert_sound(first, label)


## RELAY_FIXTURE on the native tick, saved at the first tick from LEAD_IN on
## that a train slime took off with no slime in the air (SlimeBodies
## .train_hopped, which is not saved), reloaded: the reload's state equals
## the run that never stopped at the load, one tick and TICKS ticks later.
func test_a_reload_after_a_take_off_carries_on_as_the_run_that_never_stopped() -> void:
	if not _native_available():
		return
	var source := _from_fixture(RELAY_FIXTURE, NATIVE)
	_run(source, LEAD_IN)
	while source.tick < RELAY_SEARCH_UNTIL and (source.slimes.train_hopped.is_empty() or _any_in_the_air(source)):
		_run(source, 1)
	assert_lt(source.tick, RELAY_SEARCH_UNTIL, "a take-off with no slime in the air by tick %d" % RELAY_SEARCH_UNTIL)
	var label := "%s saved at tick %d" % [RELAY_FIXTURE, source.tick]
	var reloaded := _load(_save_text(source), NATIVE, label)
	if reloaded == null:
		return
	assert_eq(_dump_differences(reloaded, source), PackedStringArray(), label + ": equal at the load")
	_run(source, 1)
	_run(reloaded, 1)
	assert_eq(_dump_differences(reloaded, source), PackedStringArray(), label + ": equal 1 tick later")
	_run(source, TICKS - 1)
	_run(reloaded, TICKS - 1)
	assert_eq(_dump_differences(reloaded, source), PackedStringArray(), label + ": equal %d ticks later" % TICKS)
