extends GutTest
## The native rest pass with the local wake (SlimeSolver.rest, chunk 5N U5)
## against the GDScript one (SlimeBodies._rest, _rest_piles, _wake_at), on
## the equivalence harness (tests/unit/native_equivalence_support.gd): every
## scene at several ticks; the wake by a slime faster than WAKE_SPEED (and
## none at or below it); the pile ids of the union-find; rest_enabled off;
## two native runs bit-equal. Then the cases of test_slime_rest.gd replayed
## in lockstep: the scenario runs on the GDScript tick, and at every tick the
## rest pass runs natively on a copy of the same moment and is compared, so
## each of those behaviours (a pile resting whole, a local wake leaving the
## rest of the pile resting, a slime woken alone resting again in a pile of
## its own...) is checked on the native pass too.
# @test-link [[req_offscreen_simulation]]

const Eq := preload("res://tests/unit/native_equivalence_support.gd")
const Scenes := preload("res://tests/unit/native_equivalence_scenes.gd")
const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := 1.0 / 60.0
const BOX_HALF_WIDTH := 130.0
## The extra GDScript ticks a scene runs before the rest pass is compared.
const MOMENTS: Array[int] = [0, 1, 5, 20]
## Covers every slime of every scene.
const EVERYWHERE := Rect2(-1e6, -1e6, 2e6, 2e6)
## How many problems a lockstep run keeps for its message.
const KEEP := 5


func _skip() -> bool:
	var why := Eq.skip_reason(Eq.REST)
	if why != "":
		pending(why)
		return true
	return false


## A copy of scene `name` run `ticks` more ticks in GDScript, then brought to
## its rest pass.
func _at_rest_pass(name: String, ticks := 0) -> SlimeBodies:
	var bodies := Eq.scene(name)
	for t in ticks:
		bodies.tick(DT)
	assert_true(Eq.prepare(bodies, Eq.REST), "%s: prepared" % name)
	return bodies


## The native pass on a copy of `bodies`; the copy.
func _native(bodies: SlimeBodies) -> SlimeBodies:
	var copy := Eq.clone(bodies)
	assert_true(Eq.run_phase(copy, Eq.REST, Eq.NATIVE), "the native rest pass ran")
	return copy


func _indices_with_calm(bodies: SlimeBodies, calm: int) -> Array:
	var out := []
	for s in bodies.slime_count:
		if bodies.calm[s] == calm:
			out.append(s)
	return out


func test_rest_matches_gdscript_in_every_scene_at_several_ticks() -> void:
	if _skip():
		return
	for name in Eq.SCENES:
		for ticks in MOMENTS:
			var label := "%s +%d" % [name, ticks]
			var bodies := _at_rest_pass(name, ticks)
			var problems := Eq.check(bodies, Eq.REST, label)
			assert_true(problems.is_empty(), "\n".join(problems))
			var exact := Eq.check(bodies, Eq.REST, label, Eq.EXACT)
			gut.p("%s: %s" % [label, "bit for bit" if exact.is_empty() else "\n".join(exact)])


func test_two_native_runs_are_bit_equal() -> void:
	if _skip():
		return
	for name in Eq.SCENES:
		var bodies := _at_rest_pass(name, 1)
		var problems := Eq.check_kinds(bodies, Eq.REST, name, Eq.NATIVE, Eq.NATIVE, Eq.EXACT)
		assert_true(problems.is_empty(), "\n".join(problems))
		var ready := _all_ready(_at_rest_pass_woken(name))
		problems = Eq.check_kinds(ready, Eq.REST, name + " ready", Eq.NATIVE, Eq.NATIVE, Eq.EXACT)
		assert_true(problems.is_empty(), "\n".join(problems))


## The synthetic scene at its rest pass with every active slime's drift
## zero but slime `mover`'s, at `speed` px/s (straight down).
func _with_one_mover(mover: int, speed: float) -> SlimeBodies:
	var bodies := _at_rest_pass(Eq.SYNTHETIC)
	for s in bodies.slime_count:
		if bodies.calm[s] == SlimeBodies.ACTIVE:
			bodies._drift[s] = Vector2.ZERO
	bodies._drift[mover] = Vector2(0.0, speed * bodies._h)
	return bodies


## The resting slimes touching active non-sleeper `mover` at the rest pass.
func _resting_touching(bodies: SlimeBodies, mover: int) -> Array:
	var out := []
	for k in bodies._pair_touch.size():
		if bodies._pair_touch[k] == 0:
			continue
		var a: int = bodies._pairs[2 * k]
		var b: int = bodies._pairs[2 * k + 1]
		var other := b if a == mover else (a if b == mover else -1)
		if other >= 0 and bodies.calm[other] == SlimeBodies.RESTING and other not in out:
			out.append(other)
	return out


# @test-link [[req_offscreen_simulation]]
func test_only_a_touch_faster_than_wake_speed_wakes_and_only_the_slime_touched() -> void:
	if _skip():
		return
	var mover := Scenes.ON_PILE
	var probe := _at_rest_pass(Eq.SYNTHETIC)
	var touched := _resting_touching(probe, mover)
	assert_false(touched.is_empty(), "synthetic: the slime on the pile touches resting slimes")
	var resting := _indices_with_calm(probe, SlimeBodies.RESTING)
	assert_gt(resting.size(), touched.size(), "and the pile has others")
	var at := SlimeBodies.WAKE_SPEED
	var at_drift := Vector2(0.0, at * probe._h)
	var fast2 := SlimeBodies.WAKE_SPEED * probe._h * SlimeBodies.WAKE_SPEED * probe._h
	var at_wakes := at_drift.length_squared() > fast2
	for speed in [0.0, 0.5 * at, 0.999 * at, at, 1.001 * at, 2.0 * at]:
		var bodies := _with_one_mover(mover, speed)
		var label := "synthetic, mover at %.3f px/s" % speed
		var problems := Eq.check(bodies, Eq.REST, label, Eq.EXACT)
		assert_true(problems.is_empty(), "\n".join(problems))
		var after := _native(bodies)
		var wakes: bool = speed > at or (speed == at and at_wakes)
		for s in resting:
			if wakes and s in touched:
				assert_eq(after.calm[s], SlimeBodies.ACTIVE, "%s: slime %d, touched, wakes" % [label, s])
				assert_eq(after.pile[s], 0, "%s: slime %d leaves its pile" % [label, s])
				# Its count starts again where it is, and the same pass counts
				# its first still tick (a resting slime keeps its support).
				assert_eq(after.rest_anchor[s], after.centre[s], "%s: slime %d's anchor" % [label, s])
				assert_eq(after.still_ticks[s], 1 if after.supported[s] != 0 else 0, "%s: slime %d's count" % [label, s])
			else:
				assert_eq(after.calm[s], SlimeBodies.RESTING, "%s: slime %d rests on" % [label, s])
				assert_eq(after.pile[s], bodies.pile[s], "%s: slime %d keeps its pile" % [label, s])
	gut.p("at exactly WAKE_SPEED, the drift's squared length %.10f against %.10f: %s"
			% [at_drift.length_squared(), fast2, "wakes" if at_wakes else "no wake"])


## A copy of scene `name` whose resting slimes were all woken before the
## tick, at its rest pass: its pile slimes active and paired with each other.
func _at_rest_pass_woken(name: String) -> SlimeBodies:
	var bodies := Eq.scene(name)
	bodies.wake_resting_in(EVERYWHERE)
	assert_true(Eq.prepare(bodies, Eq.REST), "%s: prepared" % name)
	return bodies


## `bodies` with every active pile slime one tick short of resting
## (supported, still at its anchor, REST_TICKS - 1 counted).
func _all_ready(bodies: SlimeBodies) -> SlimeBodies:
	for s in bodies.slime_count:
		if bodies.calm[s] == SlimeBodies.ACTIVE and bodies._can_rest(s):
			bodies.still_ticks[s] = SlimeBodies.REST_TICKS - 1
			bodies.supported[s] = 1
			bodies.rest_anchor[s] = bodies.centre[s]
	return bodies


# @test-link [[req_offscreen_simulation]]
func test_the_groups_that_rest_together_get_the_same_pile_ids() -> void:
	if _skip():
		return
	for name in [Scenes.S3_BASKET, Scenes.STRESS_STILL, Eq.SYNTHETIC]:
		var bodies := _all_ready(_at_rest_pass_woken(name))
		var candidates := []
		for s in bodies.slime_count:
			if bodies.calm[s] == SlimeBodies.ACTIVE and bodies._can_rest(s):
				candidates.append(s)
		assert_gt(candidates.size(), 1, "%s: active pile slimes" % name)
		# Every group rests; then all but the one of a slime short of support.
		for short in [-1, candidates[candidates.size() / 2]]:
			if short >= 0:
				bodies.supported[short] = 0
			var label := "%s, short %d" % [name, short]
			var problems := Eq.check(bodies, Eq.REST, label, Eq.EXACT)
			assert_true(problems.is_empty(), "\n".join(problems))
			var after := _native(bodies)
			var piles := {}
			var rested := 0
			for s in candidates:
				if after.calm[s] == SlimeBodies.RESTING:
					rested += 1
					piles[after.pile[s]] = true
					assert_lte(after.pile[s], after.id[s], "%s: a pile is its group's lowest id" % label)
			if short < 0:
				assert_eq(rested, candidates.size(), "%s: every group rests" % label)
			else:
				assert_eq(after.calm[short], SlimeBodies.ACTIVE, "%s: the short slime's group waits" % label)
			gut.p("%s: %d of %d rest, in %d piles" % [label, rested, candidates.size(), piles.size()])


# @test-link [[req_offscreen_simulation]]
func test_with_the_rule_off_every_slime_wakes() -> void:
	if _skip():
		return
	for name in Eq.SCENES:
		var bodies := _at_rest_pass(name)
		bodies.rest_enabled = false
		var problems := Eq.check(bodies, Eq.REST, name + ", rule off", Eq.EXACT)
		assert_true(problems.is_empty(), "\n".join(problems))
		var after := _native(bodies)
		assert_eq(after.calm.count(SlimeBodies.RESTING), 0, "%s: nothing rests" % name)
		assert_eq(after.calm.count(SlimeBodies.PARKED), bodies.calm.count(SlimeBodies.PARKED),
				"%s: parked slimes stay parked" % name)
		for s in after.slime_count:
			if after.calm[s] == SlimeBodies.ACTIVE:
				assert_eq(after.still_ticks[s], 0, "%s: no slime counts" % name)
				assert_eq(after.pile[s], 0, "%s: no slime is in a pile" % name)


# --- test_slime_rest.gd's cases, in lockstep ------------------------------------

## `count` base slimes in `slime_state`, shelf-packed in a box, falling into a
## pile (test_slime_rest.gd's _pile), on the GDScript tick.
func _pile(count: int, slime_state := SlimeBodies.IN_BASKET, master_seed := 7) -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(master_seed))
	bodies.use_native(false)
	bodies.terrain = TerrainSegments.new(Support.box_polygons(BOX_HALF_WIDTH))
	var d := 2.0 * (SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE) + 2.0
	var per_row := int((2.0 * BOX_HALF_WIDTH - 8.0) / d)
	for i in count:
		var at := Vector2(-BOX_HALF_WIDTH + 4.0 + d * (0.5 + i % per_row), -d * (0.5 + i / per_row))
		bodies.create(i % Species.COUNT, 1, at, slime_state)
	return bodies


## One tick of `bodies` in GDScript, its rest pass checked against the
## native one on a copy of the same moment (exact). `tally` counts the
## ticks checked ("ticks") and those that differ ("failed"), and keeps the
## first KEEP problems ("problems").
func _checked_tick(bodies: SlimeBodies, label: String, tally: Dictionary) -> void:
	Eq.prepare(bodies, Eq.REST)
	var native := Eq.clone(bodies)
	Eq.run_phase(bodies, Eq.REST, Eq.GDSCRIPT)
	tally["ticks"] = tally.get("ticks", 0) + 1
	var problems := PackedStringArray()
	if not Eq.run_phase(native, Eq.REST, Eq.NATIVE):
		problems.append("%s: the native rest pass didn't run" % label)
	else:
		problems = Eq.compare(bodies, native, "%s, tick %d" % [label, tally["ticks"]], Eq.EXACT, Eq.SCRATCH,
				PackedStringArray([Eq.GDSCRIPT, Eq.NATIVE]))
	var kept: PackedStringArray = tally.get("problems", PackedStringArray())
	for p in problems:
		if kept.size() < KEEP:
			kept.append(p)
	tally["problems"] = kept
	tally["failed"] = tally.get("failed", 0) + (0 if problems.is_empty() else 1)


## Checked ticks until every slime rests; how many (-1 if not within `limit`).
func _checked_ticks_to_rest(bodies: SlimeBodies, limit: int, label: String, tally: Dictionary) -> int:
	for t in limit:
		_checked_tick(bodies, label, tally)
		if bodies.calm.count(SlimeBodies.RESTING) == bodies.slime_count:
			return t + 1
	return -1


func _checked_run(bodies: SlimeBodies, ticks: int, label: String, tally: Dictionary) -> void:
	for t in ticks:
		_checked_tick(bodies, label, tally)


func _assert_lockstep(tally: Dictionary, label: String) -> void:
	gut.p("%s: %d ticks in lockstep" % [label, tally.get("ticks", 0)])
	assert_eq(tally.get("failed", 0), 0, "%s: %d of %d ticks differ\n%s"
			% [label, tally.get("failed", 0), tally.get("ticks", 0), "\n".join(tally.get("problems", []))])


func test_lockstep_a_basket_pile_rests_whole_and_bedtime_slimes_rest_too() -> void:
	if _skip():
		return
	var tally := {}
	var bodies := _pile(24)
	assert_gt(_checked_ticks_to_rest(bodies, 900, "basket 24", tally), SlimeBodies.REST_TICKS - 1, "the pile rests")
	var group := bodies.pile[0]
	for s in bodies.slime_count:
		assert_eq(bodies.pile[s], group, "one pile")
	_checked_run(bodies, 30, "basket 24, resting", tally)
	_assert_lockstep(tally, "basket 24")
	tally = {}
	assert_gt(_checked_ticks_to_rest(_pile(6, SlimeBodies.BEDTIME_ASLEEP), 900, "bedtime 6", tally), 0)
	_assert_lockstep(tally, "bedtime 6")


func test_lockstep_train_free_and_sleeper_slimes_never_rest_nor_with_the_rule_off() -> void:
	if _skip():
		return
	for slime_state in [SlimeBodies.TRAIN, SlimeBodies.FREE, SlimeBodies.SLEEPER]:
		var tally := {}
		var bodies := _pile(6, slime_state)
		bodies.auto_hops = false
		_checked_run(bodies, 200, SlimeBodies.STATE_NAMES[slime_state], tally)
		assert_eq(bodies.calm.count(SlimeBodies.RESTING), 0)
		_assert_lockstep(tally, SlimeBodies.STATE_NAMES[slime_state])
	var tally := {}
	var off := _pile(12)
	off.rest_enabled = false
	_checked_run(off, 200, "rule off", tally)
	assert_eq(off.calm.count(SlimeBodies.RESTING), 0)
	_assert_lockstep(tally, "rule off")


# @test-link [[req_offscreen_simulation]]
func test_lockstep_a_landing_wakes_only_the_slimes_it_touches_and_they_rest_again() -> void:
	if _skip():
		return
	var tally := {}
	var bodies := _pile(12)
	assert_gt(_checked_ticks_to_rest(bodies, 900, "landing", tally), 0)
	var group := bodies.pile[0]
	var dropped := bodies.create(0, 1, Vector2(0, -400), SlimeBodies.IN_BASKET)
	var woken := []
	for t in 120:
		_checked_tick(bodies, "landing", tally)
		woken = _indices_with_calm(bodies, SlimeBodies.ACTIVE)
		woken.erase(bodies.index_of(dropped))
		if not woken.is_empty():
			break
	assert_false(woken.is_empty(), "the landing woke the slimes it hit")
	for s in woken:
		assert_true(bodies.touching(dropped, bodies.id[s]), "slime %d: touched by the landing" % bodies.id[s])
		assert_eq(bodies.pile[s], 0, "a woken slime leaves its pile")
	assert_eq(bodies.calm.count(SlimeBodies.RESTING), 12 - woken.size(), "the rest of the pile rests on")
	for s in _indices_with_calm(bodies, SlimeBodies.RESTING):
		assert_eq(bodies.pile[s], group, "and keeps its pile")
	assert_gt(_checked_ticks_to_rest(bodies, 900, "landing, again", tally), 0, "it rests again, the new slime with it")
	_assert_lockstep(tally, "landing")


# @test-link [[req_offscreen_simulation]]
func test_lockstep_a_slime_woken_alone_rests_again_in_a_pile_of_its_own() -> void:
	if _skip():
		return
	var tally := {}
	var bodies := _pile(12)
	assert_gt(_checked_ticks_to_rest(bodies, 900, "wake one", tally), 0)
	var group := bodies.pile[0]
	bodies.wake(bodies.id[5])
	assert_gt(_checked_ticks_to_rest(bodies, 900, "wake one, again", tally), 0)
	assert_eq(bodies.pile[5], bodies.id[5], "a group of one: its own id")
	for s in bodies.slime_count:
		if s != 5:
			assert_eq(bodies.pile[s], group, "the others keep theirs")
	# A slime taken out wakes the ones it touched; they rest again.
	bodies.remove(bodies.id[0])
	assert_gt(bodies.calm.count(SlimeBodies.ACTIVE), 0, "the removal woke its neighbours")
	assert_gt(_checked_ticks_to_rest(bodies, 900, "removed", tally), 0)
	_assert_lockstep(tally, "wake one")
