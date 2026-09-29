extends GutTest
## The debug overlay's pure parts (src/debug/): the accessible-section rule
## and the "woken / available" counter (DebugCounts), the slime counts (on
## screen, simulated off screen, parked) and the fps text, the bar showing
## them at most every STATS_MS, the sped-up session clock (DebugClock), the
## kill tool's slime picking and its move to the start of the loop
## (DebugKill), speed stepping giving the same ticks, and the lint keeping
## src/debug/ out of release builds. The overlay itself, through the game
## scene, is tests/e2e/test_debug_overlay_e2e.gd.

const DEBUG_DIR := "res://src/debug/"
const SRC_ROOT := "res://src/"


## A clock whose reading a test sets.
class FakeClock:
	extends RefCounted
	var reading := {}

	func now() -> Dictionary:
		return reading


## Three sections: s1 and s2 each with an outgoing segment and a return
## route behind their gate, s3 with an outgoing segment and a return route
## without one. Two sleepers each in s1 and s2, one in s3.
func _level() -> LevelData:
	var data := LevelData.new("debug", 1)
	var loop := LoopData.new("start.loop")
	loop.add_segment("s1.loop", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(0, -24), Vector2(2000, -24)]))
	loop.add_segment("s1.slide", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(2000, -24), Vector2(2000, 400), Vector2(0, 400), Vector2(0, -24)]), "s1.gate")
	loop.add_segment("s2.loop", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(2000, -24), Vector2(4000, -24)]))
	loop.add_segment("s2.slide", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(4000, -24), Vector2(4000, 400), Vector2(0, 400), Vector2(0, -24)]), "s2.gate")
	loop.add_segment("s3.loop", 3, LoopData.OUTGOING, PackedVector2Array([Vector2(4000, -24), Vector2(6000, -24)]))
	loop.add_segment("s3.slide", 3, LoopData.RETURN, PackedVector2Array([
			Vector2(6000, -24), Vector2(6000, 400), Vector2(0, 400), Vector2(0, -24)]))
	data.loop = loop
	data.first_slime = {"id": "start.first-slime", "species": "A", "position": Vector2(100, -24)}
	data.add_sleeper("s1.sleeper.01", "A", Vector2(500, -300))
	data.add_sleeper("s1.sleeper.02", "B", Vector2(700, -300))
	data.add_sleeper("s2.sleeper.01", "A", Vector2(2500, -300))
	data.add_sleeper("s2.sleeper.02", "C", Vector2(2700, -300))
	data.add_sleeper("s3.sleeper.01", "A", Vector2(4500, -300))
	return data


func _sim() -> Simulation:
	var sim := Simulation.new(4242)
	sim.load_level(_level())
	return sim


func _id_of(sim: Simulation, stable_id: String) -> int:
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) == stable_id:
			return slime_id
	return -1


# --- Sections and the counter ---------------------------------------------------

func test_section_of_reads_the_stable_id_place() -> void:
	assert_eq(DebugCounts.section_of("s1.sleeper.01"), 1)
	assert_eq(DebugCounts.section_of("s2.basket"), 2)
	assert_eq(DebugCounts.section_of("s10.sleeper.03"), 10)
	assert_eq(DebugCounts.section_of("start.first-slime"), 1, "the start basin is section 1's")
	assert_eq(DebugCounts.section_of("t.first-slime"), 1, "an unknown place counts as section 1")
	assert_eq(DebugCounts.section_of("seed.x"), 1)
	assert_eq(DebugCounts.section_of(""), 1)


func test_accessible_sections_follow_the_open_gates() -> void:
	var loop := _level().loop
	assert_eq(DebugCounts.accessible_sections(loop, []), [1] as Array[int], "section 1 only")
	assert_eq(DebugCounts.accessible_sections(loop, ["s1.gate"]), [1, 2] as Array[int], "gate 1 opens section 2")
	assert_eq(DebugCounts.accessible_sections(loop, ["s1.gate", "s2.gate"]), [1, 2, 3] as Array[int])
	assert_eq(DebugCounts.accessible_sections(loop, ["s2.gate"]), [1] as Array[int],
			"gate 2 alone opens nothing: section 2 isn't reached")
	assert_eq(DebugCounts.accessible_sections(null, []), [1] as Array[int], "no loop: section 1")


func test_open_gates_come_from_the_train_or_the_gate_states() -> void:
	var sim := _sim()
	sim.train.set_open_gates(["s1.gate"])
	assert_eq(DebugCounts.open_gates(sim), ["s1.gate"])
	var bare := Simulation.new(1)
	bare.gate_states = {"s1.gate": {"open": true}, "s2.gate": {"open": false}}
	assert_eq(DebugCounts.open_gates(bare), ["s1.gate"])


func test_fresh_level_counts_the_first_slime_woken_and_section_1_available() -> void:
	var counts := DebugCounts.count(_sim())
	assert_eq(counts, {"woken": 1, "available": 3}, "the first slime and s1's two sleepers")


func test_opening_a_gate_adds_its_section_sleepers() -> void:
	var sim := _sim()
	sim.train.set_open_gates(["s1.gate"])
	assert_eq(DebugCounts.count(sim), {"woken": 1, "available": 5})
	sim.train.set_open_gates(["s1.gate", "s2.gate"])
	assert_eq(DebugCounts.count(sim), {"woken": 1, "available": 6})


func test_every_awake_state_counts_as_woken() -> void:
	var sim := _sim()
	sim.train.set_open_gates(["s1.gate"])
	sim.slimes.set_state(_id_of(sim, "s1.sleeper.01"), SlimeBodies.FREE)
	sim.slimes.set_state(_id_of(sim, "s1.sleeper.02"), SlimeBodies.IN_BASKET)
	sim.slimes.set_state(_id_of(sim, "s2.sleeper.01"), SlimeBodies.BEDTIME_ASLEEP)
	assert_eq(DebugCounts.count(sim), {"woken": 4, "available": 5}, "only s2.sleeper.02 still a sleeper")


func test_counts_are_in_base_slimes() -> void:
	var sim := _sim()
	var fused := sim.slimes.create(Species.from_letter("A"), 2, Vector2(300, -200), SlimeBodies.TRAIN)
	sim.identities.assign(fused, PackedStringArray(["s1.sleeper.03", "s1.sleeper.04"]))
	var anonymous := sim.slimes.create(Species.from_letter("B"), 3, Vector2(900, -200), SlimeBodies.FREE)
	assert_gt(anonymous, 0)
	var hidden := sim.slimes.create(Species.from_letter("A"), 1, Vector2(3000, -200), SlimeBodies.TRAIN)
	sim.identities.assign(hidden, PackedStringArray(["s2.sleeper.09"]))
	assert_eq(DebugCounts.count(sim), {"woken": 1 + 2 + 3, "available": 3 + 2 + 3},
			"a fused slime counts its members, one without identity its size, s2 not reached")


# --- The slime counts and the fps --------------------------------------------------

## The level's simulation with its own slimes removed and five sleepers (they
## stay put) placed around the view on (0, 0), zoom 1 (x -576 to 576): two
## on screen, one within NEAR_MARGIN of the view, one between NEAR_MARGIN and
## PARK_MARGIN, one far off. Off-screen simulation on, not stepped yet.
func _placed_sim() -> Simulation:
	var sim := _sim()
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	var half := ScreenView.DEFAULT_SIZE.x * 0.5
	var band := (Offscreen.NEAR_MARGIN + Offscreen.PARK_MARGIN) * 0.5
	for at in [Vector2(0, 0), Vector2(400, 100), Vector2(half + 100.0, 0), Vector2(half + band, 0),
			Vector2(3000, 0)]:
		sim.slimes.create(Species.from_letter("A"), 1, at, SlimeBodies.SLEEPER)
	sim.offscreen.enabled = true
	sim.view.set_to(Vector2.ZERO, 1.0, ScreenView.DEFAULT_SIZE)
	return sim


func _slimes(on_screen: int, simulated: int, off_screen: int) -> Dictionary:
	return {"on_screen": on_screen, "simulated": simulated, "off_screen": off_screen}


func test_slime_counts_split_on_screen_simulated_and_parked() -> void:
	var sim := _placed_sim()
	assert_eq(DebugCounts.count_slimes(sim), _slimes(2, 3, 0), "nothing parked before a step")
	sim.step()
	assert_eq(DebugCounts.count_slimes(sim), _slimes(2, 2, 1),
			"the near and the in-between one stay simulated, the far one parks")
	sim.view.set_to(Vector2(3000, 0), 1.0, ScreenView.DEFAULT_SIZE)
	assert_eq(DebugCounts.count_slimes(sim), _slimes(1, 4, 0),
			"a parked slime whose centre is in the view counts on screen (the next step unparks it)")
	sim.step()
	assert_eq(DebugCounts.count_slimes(sim), _slimes(1, 0, 4), "the four far from the new view park")
	sim.view.set_to(Vector2.ZERO, 1.0, ScreenView.DEFAULT_SIZE)
	sim.step()
	assert_eq(DebugCounts.count_slimes(sim), _slimes(2, 1, 2),
			"back: the near one simulates again, the in-between one stays parked")


func test_slime_counts_with_the_offscreen_simulation_off_never_count_parked() -> void:
	var sim := _placed_sim()
	sim.offscreen.enabled = false
	sim.step()
	assert_eq(DebugCounts.count_slimes(sim), _slimes(2, 3, 0))


func test_slime_counts_count_bodies_not_base_slimes() -> void:
	var sim := _placed_sim()
	var fused := sim.slimes.create(Species.from_letter("B"), 3, Vector2(-200, 0), SlimeBodies.TRAIN)
	sim.identities.assign(fused, PackedStringArray(["s1.sleeper.07", "s1.sleeper.08", "s1.sleeper.09"]))
	assert_eq(DebugCounts.count_slimes(sim), _slimes(3, 3, 0), "a size-3 slime counts once")


func test_the_stats_texts() -> void:
	assert_eq(DebugCounts.slimes_text(_slimes(12, 5, 63)), "Slimes 12 on screen : 5 simulated : 63 off screen")
	assert_eq(DebugCounts.fps_text(59.6), "60 fps", "a whole number")
	assert_eq(DebugCounts.fps_text(0.0), "0 fps")


func test_the_bar_shows_the_fps_and_the_slime_counts_at_most_every_stats_ms() -> void:
	var host := Node.new()
	add_child_autofree(host)
	var overlay := DebugOverlay.new()
	host.add_child(overlay)
	assert_eq(overlay.fps_label.get_parent(), overlay.bar)
	assert_eq(overlay.slimes_label.get_parent(), overlay.bar)
	var sim := _placed_sim()
	assert_true(overlay.update_stats(sim, 58.7, 1000))
	assert_eq(overlay.fps_label.text, "59 fps")
	assert_eq(overlay.slimes_label.text, "Slimes 2 on screen : 3 simulated : 0 off screen")
	sim.step()
	assert_false(overlay.update_stats(sim, 30.0, 1000 + DebugOverlay.STATS_MS - 1), "too soon")
	assert_eq(overlay.fps_label.text, "59 fps")
	assert_eq(overlay.slimes_label.text, "Slimes 2 on screen : 3 simulated : 0 off screen")
	assert_true(overlay.update_stats(sim, 30.0, 1000 + DebugOverlay.STATS_MS))
	assert_eq(overlay.fps_label.text, "30 fps")
	assert_eq(overlay.slimes_label.text, "Slimes 2 on screen : 2 simulated : 1 off screen")


# --- The sped-up clock ----------------------------------------------------------

func test_clock_at_1x_passes_the_reading_through() -> void:
	var inner := FakeClock.new()
	var clock := DebugClock.new(inner)
	inner.reading = Session.reading(1_000_000, 500, "e")
	assert_eq(clock.now(), Session.reading(1_000_000, 500, "e"))
	inner.reading = Session.reading(1_001_000, 1500, "e")
	assert_eq(clock.now(), Session.reading(1_001_000, 1500, "e"))


func test_clock_at_10x_adds_nine_ms_per_real_ms_to_both_clocks() -> void:
	var inner := FakeClock.new()
	var clock := DebugClock.new(inner)
	clock.speed = 10
	inner.reading = Session.reading(1_000_000, 500, "e")
	assert_eq(clock.now(), Session.reading(1_000_000, 500, "e"), "the first reading has no offset")
	inner.reading = Session.reading(1_000_100, 600, "e")
	assert_eq(clock.now(), Session.reading(1_001_000, 1500, "e"), "100 real ms read as 1000")
	clock.speed = 1
	inner.reading = Session.reading(1_000_200, 700, "e")
	assert_eq(clock.now(), Session.reading(1_001_100, 1600, "e"), "back to 1x keeps the offset")
	assert_eq(clock.extra_ms, 900)


func test_clock_never_runs_backwards_and_passes_an_empty_reading() -> void:
	var inner := FakeClock.new()
	var clock := DebugClock.new(inner)
	clock.speed = 5
	inner.reading = {}
	assert_eq(clock.now(), {})
	inner.reading = Session.reading(0, 1000, "e")
	clock.now()
	inner.reading = Session.reading(0, 900, "e")
	assert_eq(clock.now()["mono_ms"], 900, "a monotonic step back adds nothing")
	assert_eq(clock.extra_ms, 0)


# --- The kill tool --------------------------------------------------------------

func test_slime_at_picks_the_slime_under_the_tap() -> void:
	var sim := _sim()
	sim.view.set_to(Vector2(600, -300), 1.0, ScreenView.DEFAULT_SIZE)
	var first := _id_of(sim, "s1.sleeper.01")
	var at := sim.view.world_to_screen(sim.slimes.centre_of(first))
	assert_eq(DebugKill.slime_at(sim, at), first, "on its centre")
	var reach := sim.slimes.radius_of(first) + SlimeBodies.EDGE + DebugKill.TAP_MARGIN
	assert_eq(DebugKill.slime_at(sim, at + Vector2(0, reach - 1)), first, "just inside the margin")
	assert_eq(DebugKill.slime_at(sim, at + Vector2(0, reach + 1)), -1, "just outside")
	var second := _id_of(sim, "s1.sleeper.02")
	var between := sim.view.world_to_screen(Vector2(640, -300))
	assert_eq(DebugKill.slime_at(sim, between), -1, "between two, out of both reaches")
	var nearer := sim.view.world_to_screen(Vector2(660, -300))
	assert_eq(DebugKill.slime_at(sim, nearer, 20.0), second, "the nearer centre wins")


func test_slime_at_scales_the_margin_with_zoom() -> void:
	var sim := _sim()
	sim.view.set_to(Vector2(600, -300), 0.5, ScreenView.DEFAULT_SIZE)
	var first := _id_of(sim, "s1.sleeper.01")
	var reach := sim.slimes.radius_of(first) + SlimeBodies.EDGE + DebugKill.TAP_MARGIN / 0.5
	var at := sim.view.world_to_screen(sim.slimes.centre_of(first) + Vector2(0, reach - 1))
	assert_eq(DebugKill.slime_at(sim, at), first)


func test_send_to_start_moves_a_free_slime_as_a_lost_one() -> void:
	var sim := _sim()
	var slime := _id_of(sim, "s1.sleeper.01")
	sim.slimes.set_state(slime, SlimeBodies.FREE)
	assert_true(DebugKill.send_to_start(sim, slime))
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "back on the train")
	assert_true(sim.train.tracks(slime))
	# The first slime sits at the start: the next free spot along the loop
	# (LoopStart.move), one width on.
	var width := 2.0 * (SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE)
	var distance := sim.train.distance_of(slime)
	assert_true(is_equal_approx(fmod(distance, width), 0.0), "on a spot")
	assert_lt(distance, LoopStart.SPOTS * width, "at the start of the loop")
	var start := sim.train.position_at(distance) + Vector2(0.0, -Offscreen.lift(1))
	assert_almost_eq(sim.slimes.centre_of(slime).distance_to(start), 0.0, 0.5)
	assert_eq(sim.offscreen.lost.back()["id"], slime, "logged as lost")
	sim.run(30)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "it rides on")


func test_send_to_start_refuses_a_missing_slime_or_no_train() -> void:
	var sim := _sim()
	assert_false(DebugKill.send_to_start(sim, 999))
	var bare := Simulation.new(1)
	var slime := bare.slimes.create(Species.from_letter("A"), 1, Vector2.ZERO, SlimeBodies.FREE)
	assert_false(DebugKill.send_to_start(bare, slime))


# --- Speed ------------------------------------------------------------------------

func test_each_speed_runs_that_many_ticks_per_60hz_frame() -> void:
	for speed in [1, 2, 5, 10]:
		var clock := FixedStep.new()
		var total := 0
		for frame in 60:
			total += clock.advance(Simulation.TICK_SECONDS * speed, 8 * speed)
		assert_eq(total, 60 * speed, "%dx" % speed)


func test_ticks_run_in_batches_give_the_same_hash() -> void:
	var one := _sim()
	var ten := _sim()
	for frame in 240:
		one.step()
	for frame in 24:
		for k in 10:
			ten.step()
	assert_eq(ten.tick, one.tick)
	assert_eq(ten.state_hash(), one.state_hash())


# --- Release guard lint -----------------------------------------------------------

## src/debug/ stays strippable: nothing outside it names a debug class; the
## game root loads the overlay by path, after the guard (add_debug_overlay()).
func test_code_outside_debug_never_names_it() -> void:
	var offenders := PackedStringArray()
	var pattern := RegEx.create_from_string(
			"\\b(DebugOverlay|DebugCounts|DebugClock|DebugKill|DebugSlimeLabels)\\b")
	for path in _gd_files(SRC_ROOT):
		if path.begins_with(DEBUG_DIR):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].split("#")[0]
			if pattern.search(code):
				offenders.append("%s:%d" % [path, i + 1])
	assert_eq(offenders, PackedStringArray())


func test_main_loads_the_overlay_only_after_the_guard() -> void:
	var text := FileAccess.get_file_as_string("res://src/main.gd")
	var loads := text.count("load(DEBUG_OVERLAY_SCRIPT)")
	assert_eq(loads, 1, "one place loads it")
	var body := text.get_slice("func add_debug_overlay()", 1).get_slice("\nfunc ", 0)
	assert_true(body.find("test_mode_guard.allows()") >= 0
			and body.find("test_mode_guard.allows()") < body.find("load(DEBUG_OVERLAY_SCRIPT)"),
			"add_debug_overlay() asks the guard before loading")


func _gd_files(dir_path: String) -> PackedStringArray:
	var files := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir_path):
		files.append_array(_gd_files(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			files.append(dir_path.path_join(file))
	return files
