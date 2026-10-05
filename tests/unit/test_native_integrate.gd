extends GutTest
## The native integrate pass (SlimeSolver.integrate,
## native/slime_native/src/solver_integrate.cpp, chunk 5N unit U1) against
## the GDScript one (SlimeBodies._integrate) through the equivalence harness
## (tests/unit/native_equivalence_support.gd): every scene at every substep
## of a tick, a tilt (free slimes fall along free_down), a tilted gravity, the
## max_speed clamp biting, the walls (sleepers, resting and parked slimes)
## left in place, and two native runs bit for bit.

# @test-link [[req_tilt_input]]
# @test-link [[req_slime_states]]

const Eq := preload("res://tests/unit/native_equivalence_support.gd")
const Scenes := preload("res://tests/unit/native_equivalence_scenes.gd")

## A tilt of the phone: free slimes fall down and to the right.
const TILTED_DOWN := Vector2(0.6, 0.8)


## Whether `bodies`' slime index `s` is a wall for the pass (it doesn't move).
func _is_wall(bodies: SlimeBodies, s: int) -> bool:
	return bodies.state[s] == SlimeBodies.STATE_SLEEPER or bodies.calm[s] != SlimeBodies.ACTIVE


## How many slimes of `bodies` are free and simulate.
func _free_movers(bodies: SlimeBodies) -> int:
	var count := 0
	for s in bodies.slime_count:
		if bodies.state[s] == SlimeBodies.STATE_FREE and not _is_wall(bodies, s):
			count += 1
	return count


## The fastest point of a slime that simulates in `bodies`, px/s (its
## Verlet velocity over the substep).
func _top_speed(bodies: SlimeBodies) -> float:
	var top := 0.0
	for s in bodies.slime_count:
		if _is_wall(bodies, s):
			continue
		for i in range(bodies.first[s], bodies.first[s] + bodies.npts[s]):
			top = maxf(top, (bodies.pos[i] - bodies.prev[i]).length() / bodies._h)
	return top


## Whether the GDScript pass gives another state on `changed` than on
## `bodies` (a change made to a copy bites).
func _bites(bodies: SlimeBodies, changed: SlimeBodies) -> bool:
	var a := Eq.clone(bodies)
	var b := Eq.clone(changed)
	Eq.run_phase(a, Eq.INTEGRATE, Eq.GDSCRIPT)
	Eq.run_phase(b, Eq.INTEGRATE, Eq.GDSCRIPT)
	return a.pos != b.pos


func test_every_scene_at_every_substep_matches_gdscript() -> void:
	var why := Eq.skip_reason(Eq.INTEGRATE)
	if why != "":
		pending(why)
		return
	for name in Eq.SCENES:
		for sub in Eq.scene(name).substeps:
			var bodies := Eq.prepared(name, Eq.INTEGRATE, sub)
			assert_not_null(bodies, "%s, substep %d prepares" % [name, sub])
			if bodies == null:
				continue
			var label := "%s, substep %d" % [name, sub]
			var problems := Eq.check(bodies, Eq.INTEGRATE, label)
			assert_eq(problems, PackedStringArray(), "\n".join(problems))


## A tilt (free_down off straight down) turns a free slime's gravity: the
## native pass reads it as gravity_for() does.
func test_a_tilt_matches_gdscript() -> void:
	var why := Eq.skip_reason(Eq.INTEGRATE)
	if why != "":
		pending(why)
		return
	var tested := 0
	for name in Eq.SCENES:
		for sub in Eq.scene(name).substeps:
			var bodies := Eq.prepared(name, Eq.INTEGRATE, sub)
			if bodies == null or _free_movers(bodies) == 0:
				continue
			var tilted := Eq.clone(bodies)
			tilted.free_down = TILTED_DOWN
			assert_true(_bites(bodies, tilted), "%s, substep %d: the tilt moves a free slime" % [name, sub])
			var problems := Eq.check(tilted, Eq.INTEGRATE, "%s, substep %d, tilted" % [name, sub])
			assert_eq(problems, PackedStringArray(), "\n".join(problems))
			tested += 1
	assert_gt(tested, 0, "some scene has a free slime that simulates")


## A gravity that isn't straight down (with and without a tilt): every state
## takes it, the free ones at its length along free_down.
func test_a_slanted_gravity_matches_gdscript() -> void:
	var why := Eq.skip_reason(Eq.INTEGRATE)
	if why != "":
		pending(why)
		return
	for name in [Eq.SYNTHETIC, Scenes.STRESS_MOVING]:
		for down in [Vector2.DOWN, TILTED_DOWN]:
			var bodies := Eq.prepared(name, Eq.INTEGRATE, 1)
			bodies.gravity = Vector2(-250.0, 1300.0)
			bodies.free_down = down
			var problems := Eq.check(bodies, Eq.INTEGRATE, "%s, gravity %s, free_down %s" % [name, bodies.gravity, down])
			assert_eq(problems, PackedStringArray(), "\n".join(problems))


## A low max_speed (half the fastest point's speed) clamps the points'
## velocities (limit_length) the same way.
func test_the_max_speed_clamp_matches_gdscript() -> void:
	var why := Eq.skip_reason(Eq.INTEGRATE)
	if why != "":
		pending(why)
		return
	for name in Eq.SCENES:
		var bodies := Eq.prepared(name, Eq.INTEGRATE, 1)
		if bodies.crowd_count() == 0:
			continue
		var top := _top_speed(bodies)
		assert_gt(top, 0.0, "%s: some point moves" % name)
		var slow := Eq.clone(bodies)
		slow.max_speed = top * 0.5
		assert_true(_bites(bodies, slow), "%s: max_speed %.3f clamps some point" % [name, slow.max_speed])
		var problems := Eq.check(slow, Eq.INTEGRATE, "%s, max_speed %.3f" % [name, slow.max_speed])
		assert_eq(problems, PackedStringArray(), "\n".join(problems))
		# Clamped to nothing: only gravity moves the points.
		var still := Eq.clone(bodies)
		still.max_speed = 0.0
		problems = Eq.check(still, Eq.INTEGRATE, "%s, max_speed 0" % name)
		assert_eq(problems, PackedStringArray(), "\n".join(problems))


## Sleepers, resting and parked slimes don't move: their points, previous
## points and centre stay as they were, their drift is zero, their point-0
## angle is refreshed from their points (as the GDScript pass leaves them).
func test_walls_are_left_in_place() -> void:
	var why := Eq.skip_reason(Eq.INTEGRATE)
	if why != "":
		pending(why)
		return
	var seen := {}
	for name in Eq.SCENES:
		var before := Eq.prepared(name, Eq.INTEGRATE, 1)
		var after := Eq.clone(before)
		assert_true(Eq.run_phase(after, Eq.INTEGRATE, Eq.NATIVE), "%s: the native pass runs" % name)
		for s in before.slime_count:
			if not _is_wall(before, s):
				continue
			var kind := "sleeper" if before.state[s] == SlimeBodies.STATE_SLEEPER else str(before.calm[s])
			seen[kind] = true
			var where := "%s, slime index %d (%s)" % [name, s, kind]
			var f: int = before.first[s]
			var end: int = f + before.npts[s]
			assert_eq(after.pos.slice(f, end), before.pos.slice(f, end), where + ": its points stay")
			assert_eq(after.prev.slice(f, end), before.prev.slice(f, end), where + ": its previous points stay")
			assert_eq(after.centre[s], before.centre[s], where + ": its centre stays")
			assert_eq(after._drift[s], Vector2.ZERO, where + ": no drift")
			var r: Vector2 = before.pos[f] - before.centre[s]
			assert_almost_eq(after.angle0[s], atan2(r.y, r.x), 1e-6, where + ": its point-0 angle")
	assert_true(seen.has("sleeper"), "a sleeper is checked")
	assert_true(seen.has(str(SlimeBodies.RESTING)), "a resting slime is checked")
	assert_true(seen.has(str(SlimeBodies.PARKED)), "a parked slime is checked")


## A scene where nothing simulates (stress-still's resting pile): the
## native pass changes no point.
func test_a_scene_at_rest_keeps_its_points() -> void:
	var why := Eq.skip_reason(Eq.INTEGRATE)
	if why != "":
		pending(why)
		return
	var before := Eq.prepared(Scenes.STRESS_STILL, Eq.INTEGRATE)
	assert_eq(before.crowd_count(), 0, "stress-still: nothing simulates")
	var after := Eq.clone(before)
	assert_true(Eq.run_phase(after, Eq.INTEGRATE, Eq.NATIVE))
	assert_eq(after.pos, before.pos)
	assert_eq(after.prev, before.prev)
	assert_eq(after.centre, before.centre)


## Two native runs give the same state, bit for bit.
func test_two_native_runs_are_bit_equal() -> void:
	var why := Eq.skip_reason(Eq.INTEGRATE)
	if why != "":
		pending(why)
		return
	for name in Eq.SCENES:
		for sub in Eq.scene(name).substeps:
			var bodies := Eq.prepared(name, Eq.INTEGRATE, sub)
			bodies.free_down = TILTED_DOWN
			var label := "%s, substep %d" % [name, sub]
			var problems := Eq.check_kinds(bodies, Eq.INTEGRATE, label, Eq.NATIVE, Eq.NATIVE, Eq.EXACT)
			assert_eq(problems, PackedStringArray(), "\n".join(problems))
