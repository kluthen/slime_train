extends GutTest
## EXPERIMENT (exp/geyser): the geyser at the return route's end
## (src/sim/geyser.gd, D157 (5), O117), "high and wide". A train slime whose
## progress wraps past the loop's end is lifted above the pile over it and
## launched high onto a spot LAND_MIN to LAND_MAX px along the loop, its
## flight clear of the terrain; the draws are seeded; off, nothing is
## launched; the landing limits (gate, zone for a fused slime, guarded
## ledge, the loop's own route) turn spots down, and with none left the
## arrival is left alone; a parked arrival is put on a free spot, or left in
## its single file.
##
## The world: a floor whose top is at y = 0 from x = -6000 to 6000. The loop
## runs along it at y = -24 from x = -5000 to 5000 and returns under the
## floor (y = 400), ending at the loop's start (-5000, -24). Loop distance d
## is x = d - 5000 on the outgoing part. Split zone t.split covers the loop's
## first 300 px. An arrival: a slime at the loop's start whose record says
## it is 1 px before the loop's end, so the next follow wraps it (_arrival).
# No ATD link: an experiment, not in the spec (the user decides first).

const SPLIT_END := 300.0


func _level(split_end := SPLIT_END) -> LevelData:
	var data := LevelData.new("geyser", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-5000, -24), Vector2(5000, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(5000, -24), Vector2(5000, 400), Vector2(-5000, 400), Vector2(-5000, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-4900, -24)}
	data.add_split_zone("t.split", Rect2(-5000, -300, split_end, 400))
	return data


func _terrain(extra: Array = []) -> TerrainSegments:
	var polygons := [PackedVector2Array([Vector2(-6000, 0), Vector2(6000, 0), Vector2(6000, 300),
			Vector2(-6000, 300)])]
	polygons.append_array(extra)
	return TerrainSegments.new(polygons)


## A simulation on the synthetic level, no slime yet, nobody hopping, the
## geyser on (whatever the run's arguments say).
func _sim(master_seed := 5, split_end := SPLIT_END, extra: Array = []) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = _terrain(extra)
	sim.load_level(_level(split_end))
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(-4800, -200), 1.0, ScreenView.DEFAULT_SIZE)
	sim.slimes.auto_hops = false
	sim.geyser.enabled = true
	return sim


## A base train slime arriving: just past the loop's start (5 px, so its
## centre projects onto the outgoing route, not the return's last, vertical
## stretch), its record 1 px short of the loop's end. Returns its id.
func _arrival(sim: Simulation, species := 0) -> int:
	var slime := sim.spawn_train_slime(species, 1, 5.0)
	sim.train.track(slime, sim.train.length() - 1.0)
	return slime


func test_an_arrival_is_launched_high_and_wide() -> void:
	var sim := _sim()
	var slime := _arrival(sim)
	sim.step()
	assert_eq(sim.geyser.arrivals, 1, "the wrap is an arrival")
	assert_eq(sim.geyser.launches, 1, "and it is launched")
	assert_eq(sim.train.laps_of(slime), 1)
	var launch: Dictionary = sim.geyser.launches_log[0]
	assert_eq(launch["id"], slime)
	assert_false(launch["parked"])
	assert_between(launch["distance"], Geyser.LAND_MIN, Geyser.LAND_MAX, "a spot of the landing stretch")
	var velocity := sim.slimes.velocity_of(slime)
	assert_lt(velocity.y, -700.0, "launched high")
	assert_gt(velocity.x, 0.0, "the loop's way")
	assert_lt(velocity.length(), sim.slimes.max_speed, "under the speed limit")


func test_it_comes_down_on_its_spot() -> void:
	var sim := _sim()
	var slime := _arrival(sim)
	sim.step()
	var at: Vector2 = sim.geyser.launches_log[0]["at"]
	var top := 0.0
	for k in 150:
		sim.step()
		top = minf(top, sim.slimes.centre_of(slime).y)
	assert_lt(top, -24.0 - Geyser.APEX * (1.0 - Geyser.APEX_JITTER) + 30.0, "it flew about APEX high")
	assert_almost_eq(sim.slimes.centre_of(slime).x, at.x, 40.0, "it landed near its spot")
	assert_gt(sim.train.distance_of(slime), Geyser.LAND_MIN - 40.0, "its progress is past the start")


func test_the_draws_repeat_with_the_seed() -> void:
	var a := _sim(11)
	var b := _sim(11)
	var c := _sim(12)
	for sim in [a, b, c]:
		_arrival(sim)
		for k in 120:
			sim.step()
	assert_eq(a.geyser.launches_log[0]["distance"], b.geyser.launches_log[0]["distance"], "same seed, same spot")
	assert_eq(a.state_hash(), b.state_hash(), "same seed, same run")
	assert_ne(a.geyser.launches_log[0]["distance"], c.geyser.launches_log[0]["distance"], "another seed, another spot")


func test_its_stream_is_its_own() -> void:
	var sim := _sim(7)
	var master_state := sim.rng.state
	_arrival(sim)
	sim.step()
	assert_eq(sim.rng.state, master_state, "no draw from the master stream")


func test_off_nothing_is_launched() -> void:
	var sim := _sim()
	sim.geyser.enabled = false
	var slime := _arrival(sim)
	sim.step()
	assert_eq(sim.geyser.arrivals, 1, "the arrival is still counted")
	assert_eq(sim.geyser.launches, 0)
	assert_gt(sim.slimes.velocity_of(slime).y, -100.0, "not launched")
	assert_true(sim.train.lapped.is_empty(), "the arrivals are consumed either way")


func test_a_base_slime_may_land_past_the_split_zone() -> void:
	var sim := _sim(5, Geyser.LAND_MIN - 20.0)
	_arrival(sim)
	sim.step()
	assert_eq(sim.geyser.launches, 1)
	assert_false(sim.split_zones.covers(sim.geyser.launches_log[0]["at"]), "past the split zone")


func test_a_fused_arrival_lands_only_in_a_split_zone() -> void:
	var sim := _sim(5, Geyser.LAND_MIN - 20.0)
	# Launched straight away: a step would split it in the start's zone first.
	var slime := sim.spawn_train_slime(0, 2, 5.0)
	assert_false(sim.geyser.launch(sim, slime))
	assert_eq(sim.geyser.refused, 1)
	assert_eq(sim.geyser.rejects, {"zone": Geyser.CANDIDATES})
	var wide := _sim(5, Geyser.LAND_MAX + 100.0)
	var fused := wide.spawn_train_slime(0, 2, 5.0)
	assert_true(wide.geyser.launch(wide, fused))
	assert_true(wide.split_zones.covers(wide.geyser.launches_log[0]["at"]))


func test_a_flight_into_an_overhang_is_refused() -> void:
	# A slab 80 px over the start: every flight from it hits it.
	var roof := PackedVector2Array([Vector2(-5100, -120), Vector2(-4600, -120), Vector2(-4600, -100),
			Vector2(-5100, -100)])
	var sim := _sim(5, SPLIT_END, [roof])
	var slime := _arrival(sim)
	sim.step()
	assert_eq(sim.geyser.launches, 0)
	assert_eq(sim.geyser.refused, 1)
	assert_true(sim.geyser.rejects.has("flight"))
	assert_gt(sim.slimes.velocity_of(slime).y, -100.0, "not launched: the plain arrival")


func test_flight_clear_sees_a_ledge_beside_the_landing() -> void:
	var sim := _sim()
	var bodies := sim.slimes
	var from := Vector2(-5000, -24)
	var at := Vector2(-4800, -24)
	var velocity := Train.aim(from, at, Geyser.APEX, bodies.gravity.y, bodies.max_speed)
	assert_true(Geyser.flight_clear(bodies, 1, from, velocity, at), "open sky")
	var ledge := PackedVector2Array([Vector2(-4795, -110), Vector2(-4700, -110), Vector2(-4700, -90),
			Vector2(-4795, -90)])
	bodies.terrain = _terrain([ledge])
	assert_false(Geyser.flight_clear(bodies, 1, from, velocity, at), "the ring clips the ledge coming down")


func test_the_emptiest_kept_spot_is_taken() -> void:
	var sim := _sim()
	# Slimes along part of the landing stretch.
	for d in range(160, 400, 30):
		sim.spawn_train_slime(1, 1, d)
	var slime := sim.spawn_train_slime(0, 1, 0.0)
	# The draws launch() will make: the apex, then the candidates.
	var draws := sim.rng.derive("geyser:%d:%d" % [sim.tick, slime])
	draws.randf()
	var rooms := []
	for k in Geyser.CANDIDATES:
		var distance := draws.randf_range(Geyser.LAND_MIN, Geyser.LAND_MAX)
		var at := LoopStart.landing_point(sim.train, 1, distance)
		if sim.geyser.landing_limit(sim, slime, distance, at) == "":
			rooms.append(Geyser.room_at(sim.slimes, slime, at))
	assert_false(rooms.is_empty())
	assert_true(sim.geyser.launch(sim, slime))
	var launch: Dictionary = sim.geyser.launches_log[0]
	assert_eq(launch["id"], slime)
	assert_eq(Geyser.room_at(sim.slimes, slime, launch["at"]), rooms.max(), "the emptiest of the kept draws")


func test_never_onto_a_slime_off_the_route() -> void:
	var sim := _sim()
	var slime := sim.spawn_train_slime(0, 1, 0.0)
	var sitting := sim.spawn_train_slime(1, 1, 300.0)
	var on := LoopStart.landing_point(sim.train, 1, 300.0)
	assert_eq(sim.geyser.landing_limit(sim, slime, 300.0, on), "route", "it would come down on the slime there")
	assert_eq(sim.geyser.landing_limit(sim, slime, 330.0, on + Vector2(30, 0)), "route", "its ring overlaps")
	assert_eq(sim.geyser.landing_limit(sim, slime, 360.0, on + Vector2(60, 0)), "", "beside it, on the ground")
	# A slime in the air counts where it comes down.
	sim.slimes.launch(sitting, Vector2(300.0, -600.0))
	var down := Geyser.where_down(sim.slimes, sitting, on.y)
	assert_gt(down.x, on.x + 100.0)
	var d := 300.0 + (down.x - on.x)
	assert_eq(sim.geyser.landing_limit(sim, slime, d, LoopStart.landing_point(sim.train, 1, d)), "route")
	assert_eq(sim.geyser.landing_limit(sim, slime, 300.0, on), "", "where it took off is free now")


func test_never_onto_a_spot_with_no_ground() -> void:
	var sim := _sim()
	# The floor with a 100 px hole 500 to 600 px along the loop.
	sim.slimes.terrain = TerrainSegments.new([
			PackedVector2Array([Vector2(-6000, 0), Vector2(-4500, 0), Vector2(-4500, 300), Vector2(-6000, 300)]),
			PackedVector2Array([Vector2(-4400, 0), Vector2(6000, 0), Vector2(6000, 300), Vector2(-4400, 300)])])
	var slime := sim.spawn_train_slime(0, 1, 0.0)
	var at := LoopStart.landing_point(sim.train, 1, 550.0)
	assert_true(is_nan(Geyser.rest_height(sim.slimes, slime, at)))
	assert_eq(sim.geyser.landing_limit(sim, slime, 550.0, at), "route")
	assert_eq(sim.geyser.landing_limit(sim, slime, 450.0, at - Vector2(100, 0)), "")


func test_never_under_a_guarded_ledge() -> void:
	# A ledge 400 to 500 px along the loop, its top 120 px over the ground (a
	# called base slime reaches it), a sleeper on it; another, 160 px up, out
	# of reach, 600 to 650 px along, a sleeper on it too.
	var low := PackedVector2Array([Vector2(-4600, -120), Vector2(-4500, -120), Vector2(-4500, -100),
			Vector2(-4600, -100)])
	var high := PackedVector2Array([Vector2(-4400, -160), Vector2(-4350, -160), Vector2(-4350, -140),
			Vector2(-4400, -140)])
	var sim := _sim(5, SPLIT_END, [low, high])
	sim.level.add_sleeper("t.sleeper.low", "A", Vector2(-4550, -144))
	sim.level.add_sleeper("t.sleeper.high", "A", Vector2(-4375, -184))
	assert_eq(sim.geyser.guarded_ledges(sim).size(), 2, "both pieces a sleeper rests on")
	var slime := sim.spawn_train_slime(0, 1, 0.0)
	for d in [450.0, 380.0, 520.0]:
		assert_eq(sim.geyser.landing_limit(sim, slime, d, LoopStart.landing_point(sim.train, 1, d)), "ledge",
				"under it or beside it, at %.0f" % d)
	for d in [360.0, 540.0, 625.0]:
		assert_eq(sim.geyser.landing_limit(sim, slime, d, LoopStart.landing_point(sim.train, 1, d)), "",
				"clear of it, or under one out of reach, at %.0f" % d)


func test_never_at_or_past_a_gate() -> void:
	var sim := _sim()
	# Added to the level's data after the load (the frontier sets don't know
	# it, so launches only, no step): the geyser reads the gates when asked.
	sim.level.add_gate("t.gate", Rect2(-4620, -100, 40, 100))
	assert_almost_eq(sim.geyser.gate_limit(sim), 400.0, 0.5, "the gate's loop point")
	for k in 8:
		var slime := sim.spawn_train_slime(0, 1, 5.0)
		assert_true(sim.geyser.launch(sim, slime))
		sim.slimes.remove(slime)
	for launch in sim.geyser.launches_log:
		assert_lt(launch["distance"], 400.0, "before the gate")
	assert_gt(sim.geyser.rejects.get("gate", 0), 0)


func test_with_no_spot_left_the_arrival_is_plain() -> void:
	var sim := _sim()
	# The whole landing stretch taken, one slime every 40 px.
	for d in range(int(Geyser.LAND_MIN) - 40, int(Geyser.LAND_MAX) + 40, 40):
		sim.spawn_train_slime(1, 1, d)
	var slime := _arrival(sim)
	var from := sim.slimes.centre_of(slime)
	sim.step()
	assert_eq(sim.geyser.launches, 0)
	assert_eq(sim.geyser.refused, 1)
	assert_eq(sim.geyser.lifted, 0, "not lifted either")
	assert_almost_eq(sim.slimes.centre_of(slime).x, from.x, 5.0, "left at the loop's start")
	assert_gt(sim.slimes.velocity_of(slime).y, -100.0, "not launched")


func test_a_parked_arrival_is_put_on_a_free_spot() -> void:
	var sim := _sim()
	var slime := _arrival(sim)
	sim.slimes.park(slime)
	sim.train.advance(slime, sim.slimes.centre_of(slime), 0)
	assert_true(sim.train.lapped.has(slime), "Offscreen's proxy wraps it")
	sim.geyser.step(sim)
	assert_eq(sim.geyser.launches, 1)
	var launch: Dictionary = sim.geyser.launches_log[0]
	assert_true(launch["parked"])
	assert_almost_eq(sim.train.distance_of(slime), launch["distance"], 0.001, "its progress moved there")
	assert_almost_eq(sim.slimes.centre_of(slime).distance_to(launch["at"]), 0.0, 0.01, "and its body")


func test_a_parked_arrival_with_no_free_spot_stays_in_line() -> void:
	var sim := _sim()
	# The whole landing stretch taken, one slime every 20 px.
	for d in range(int(Geyser.LAND_MIN) - 20, int(Geyser.LAND_MAX) + 40, 20):
		sim.spawn_train_slime(1, 1, d)
	var slime := _arrival(sim)
	sim.slimes.park(slime)
	sim.train.advance(slime, sim.slimes.centre_of(slime), 0)
	var before := sim.train.distance_of(slime)
	sim.geyser.step(sim)
	assert_eq(sim.geyser.launches, 0)
	assert_eq(sim.geyser.refused, 1)
	assert_eq(sim.train.distance_of(slime), before, "left where the proxy has it")


func test_it_lifts_the_arrival_above_the_pile() -> void:
	var sim := _sim()
	var slime := _arrival(sim)
	var from := sim.slimes.centre_of(slime)
	var above := sim.slimes.create(1, 1, from + Vector2(5, -44), SlimeBodies.TRAIN)
	sim.train.track(above, 10.0)
	var pile_top := sim.slimes.centre_of(above).y - sim.slimes.radius_of(above)
	sim.step()
	assert_eq(sim.geyser.launches, 1)
	assert_eq(sim.geyser.lifted, 1, "lifted out from under the pile")
	assert_lt(sim.slimes.centre_of(slime).y + sim.slimes.radius_of(slime), pile_top, "its ring above the pile's")
	assert_gt(sim.slimes.velocity_of(above).y, -300.0, "the one above isn't launched")


func test_lift_origin_leaves_a_free_or_buried_slime_where_it_is() -> void:
	var sim := _sim()
	var bodies := sim.slimes
	var slime := bodies.create(0, 1, Vector2(-5000, -24), SlimeBodies.TRAIN)
	assert_eq(Geyser.lift_origin(bodies, slime), bodies.centre_of(slime), "nothing above")
	var y := -24.0 - 44.0
	while -24.0 - y < Geyser.LIFT_MAX + 50.0:
		bodies.create(1, 1, Vector2(-5000, y), SlimeBodies.TRAIN)
		y -= 44.0
	assert_eq(Geyser.lift_origin(bodies, slime), bodies.centre_of(slime), "a pile higher than LIFT_MAX")
