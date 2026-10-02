extends GutTest
## The celebration's lasting mark and double hop (item 23.11, ux D4; master
## spec §5.1) on the synthetic level of test_frontier_sets.gd: once the
## celebration has played (the level's saved done mark), the mark stands at
## the start of the loop, after a reload too, and never on a level whose
## celebration hasn't played; when the burst begins, every awake slime on
## screen hops twice, and nobody else hops for it, but holders and resting
## train slimes, which it spares (no hop, no wake: a drawn bounce instead,
## D147 (6)); the hops still due are saved and hashed.

# @test-link [[req_level_completion_celebration]]
# @test-link [[req_hopping_behavior]]
# @test-link [[req_persistence_and_saves]]

const F := preload("res://tests/unit/frontier_test_support.gd")
const DT := Simulation.TICK_SECONDS


## A simulation whose only basket is full and in view, with its reward
## about to play: it fires, and the celebration begins, REWARD_TICKS + 2
## steps later.
func _about_to_celebrate(master_seed := 3) -> Simulation:
	var sim := F.sim(master_seed)
	sim.frontier.tap_switch(sim, F.SWITCH)
	F.slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	return sim


# --- The lasting mark ---------------------------------------------------------------

func test_the_mark_stands_at_the_start_of_the_loop_once_the_celebration_has_played() -> void:
	var sim := _about_to_celebrate()
	assert_false(sim.frontier.mark_showing(sim.tick), "no mark before")
	F.frontier_steps(sim, F.REWARD_TICKS + 2)
	assert_true(sim.frontier.celebration_playing(sim.tick))
	assert_false(sim.frontier.mark_showing(sim.tick), "the burst first")
	F.frontier_steps(sim, F.CELEBRATION_TICKS)
	assert_false(sim.frontier.celebration_playing(sim.tick))
	assert_true(sim.frontier.mark_showing(sim.tick), "then the lasting mark")
	assert_eq(FrontierSets.mark_point(sim.level), Vector2(-1500, -24), "at the start of the loop")
	F.frontier_steps(sim, 600)
	assert_true(sim.frontier.mark_showing(sim.tick), "for good")


func test_the_mark_is_still_there_after_a_save_and_reload() -> void:
	var sim := _about_to_celebrate()
	F.frontier_steps(sim, F.REWARD_TICKS + 2 + F.CELEBRATION_TICKS)
	var save := sim.to_save()
	save.erase("transient")
	var again := Simulation.from_save(save, F.level(), sim.slimes.terrain, 3)
	assert_true(again.frontier.mark_showing(again.tick), "the saved done mark shows it")


func test_no_mark_on_a_level_whose_celebration_has_not_played() -> void:
	var sim := F.sim(3, true)
	sim.frontier.tap_switch(sim, F.SWITCH)
	F.slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	F.frontier_steps(sim, F.REWARD_TICKS + 2 + F.CELEBRATION_TICKS)
	assert_eq(sim.object_states[F.BASKET]["phase"], FrontierSets.FIRED)
	assert_false(sim.frontier.celebration_done, "basket 2 is still to fire")
	assert_false(sim.frontier.mark_showing(sim.tick), "no mark")
	var fresh := F.sim()
	assert_false(fresh.frontier.mark_showing(fresh.tick), "nor on a fresh level")


# --- The double hop ----------------------------------------------------------------

func test_every_awake_slime_on_screen_hops_twice_during_the_burst() -> void:
	var sim := _about_to_celebrate()
	sim.slimes.auto_hops = false
	var train := sim.spawn_train_slime(Species.from_letter("A"), 1, 300.0)
	var free := F.slime(sim, 1, -300, SlimeBodies.FREE)
	var off_screen := F.slime(sim, 1, 1400, SlimeBodies.FREE)
	var sleeper := F.slime(sim, 1, -450, SlimeBodies.SLEEPER)
	var hops := {}
	var began := -1
	for i in F.REWARD_TICKS + 2 + F.CELEBRATION_TICKS:
		sim.step()
		if began < 0 and sim.frontier.celebration_playing(sim.tick):
			began = sim.tick
		for slime_id in sim.slimes.hopped:
			hops[slime_id] = hops.get(slime_id, 0) + 1
	gut.p("hops %s, the burst from tick %d" % [hops, began])
	assert_gt(began, 0, "the celebration plays")
	assert_eq(hops.get(train, 0), 2, "a train slime on screen: a double hop")
	assert_eq(hops.get(free, 0), 2, "a free slime on screen too")
	assert_eq(hops.get(off_screen, 0), 0, "not off screen")
	assert_eq(hops.get(sleeper, 0), 0, "not a sleeper")
	assert_eq(sim.frontier.dump()["celebration_hops"], [], "all done within the burst")


func test_slimes_asleep_or_in_a_basket_do_not_hop_for_it() -> void:
	var sim := _about_to_celebrate()
	sim.slimes.auto_hops = false
	var caught := F.slime(sim, 1, -650, SlimeBodies.IN_BASKET)
	var asleep := F.slime(sim, 1, -300, SlimeBodies.BEDTIME_ASLEEP)
	var hops := {}
	for i in F.REWARD_TICKS + 2 + F.CELEBRATION_TICKS:
		sim.step()
		for slime_id in sim.slimes.hopped:
			hops[slime_id] = hops.get(slime_id, 0) + 1
	assert_true(sim.frontier.celebration_done)
	assert_eq(hops.get(caught, 0), 0, "in a basket: no hop")
	assert_eq(hops.get(asleep, 0), 0, "asleep: no hop")


func test_the_hops_still_due_are_saved_and_hashed() -> void:
	var sim := _about_to_celebrate(9)
	sim.slimes.auto_hops = false
	sim.spawn_train_slime(Species.from_letter("A"), 1, 300.0)
	sim.spawn_train_slime(Species.from_letter("C"), 1, 380.0)
	while not sim.frontier.celebration_playing(sim.tick):
		sim.step()
	sim.step()
	assert_false(sim.frontier.dump()["celebration_hops"].is_empty(), "hops still due")
	# (D12, chunk 19: a load puts mid-air slimes down)
	MidairLanding.apply(sim)
	var text := JSON.stringify(sim.to_save(), "", true, true)
	var again := Simulation.from_save(JSON.parse_string(text), F.level(), sim.slimes.terrain, 9)
	again.view.set_to(sim.view.centre, sim.view.zoom, sim.view.screen_size)
	again.slimes.auto_hops = false
	assert_eq(again.frontier.dump()["celebration_hops"], sim.frontier.dump()["celebration_hops"])
	assert_eq(again.state_hash(), sim.state_hash(), "the same state")
	for run in [sim, again]:
		for i in F.CELEBRATION_TICKS:
			run.step()
	assert_eq(again.state_hash(), sim.state_hash(), "and it goes on the same")


func test_same_seed_same_hash() -> void:
	var hashes := []
	for run in 2:
		var sim := _about_to_celebrate(21)
		for k in 3:
			sim.spawn_train_slime(Species.from_letter("C"), 1, 100.0 + 90.0 * k)
		for i in F.REWARD_TICKS + 2 + F.CELEBRATION_TICKS:
			sim.step()
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1])


# --- Holders and resting train slimes (D147 (6)) -----------------------------------

## A simulation on test_frontier_sets.gd's level whose celebration begins
## at its next tick, the bodies and the frontier sets ticked alone (no steer: the holds
## stay as set, nothing else hops), with on screen, 100 px apart or more: a
## resting holder, an awake holder, a train slime resting by contact (resting,
## not holding), an awake train slime that doesn't hold and a free slime.
## Returns [sim, {name: id}].
func _burst_with_holders() -> Array:
	var sim := F.sim(3)
	sim.frontier.tap_switch(sim, F.SWITCH)
	F.slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	sim.slimes.auto_hops = false
	var ids := {"resting_holder": sim.spawn_train_slime(Species.from_letter("A"), 1, 200.0),
			"awake_holder": sim.spawn_train_slime(Species.from_letter("A"), 1, 300.0),
			"by_contact": sim.spawn_train_slime(Species.from_letter("A"), 1, 950.0),
			"awake": sim.spawn_train_slime(Species.from_letter("A"), 1, 1100.0),
			"free": F.slime(sim, 1, -250, SlimeBodies.FREE)}
	for name in ids:
		assert_true(Fusion.view_rect(sim.view).has_point(sim.slimes.centre_of(ids[name])), "%s on screen" % name)
	for slime in [ids["resting_holder"], ids["awake_holder"]]:
		var record := sim.train.record_of(slime)
		record["hold"] = sim.tick
		sim.train.restore_record(slime, record)
	for slime in [ids["resting_holder"], ids["by_contact"]]:
		sim.slimes.set_may_rest(slime, true)
	for i in 90:
		sim.slimes.tick(DT)
	assert_eq(sim.slimes.calm_of(ids["resting_holder"]), SlimeBodies.RESTING, "a resting holder")
	assert_ne(sim.slimes.calm_of(ids["awake_holder"]), SlimeBodies.RESTING, "an awake holder")
	assert_eq(sim.slimes.calm_of(ids["by_contact"]), SlimeBodies.RESTING, "a train slime resting, not holding")
	assert_false(sim.train.is_holding(ids["by_contact"]))
	F.frontier_steps(sim, F.REWARD_TICKS + 1)
	assert_false(sim.frontier.celebration_playing(sim.tick), "the burst begins at the next tick")
	return [sim, ids]


## One burst tick of _burst_with_holders()'s simulation: the bodies, then the
## frontier sets (Simulation.step's order).
func _burst_step(sim: Simulation) -> void:
	sim.slimes.tick(DT)
	sim.frontier.step(sim)
	sim.tick += 1


# D147 (6): the burst neither wakes nor hops a holder, resting or awake, nor
# a train slime resting by contact; an awake train slime that doesn't hold
# and a free slime still double hop.
# @test-link [[req_level_completion_celebration]]
# @test-link [[req_hopping_behavior]]
func test_the_celebration_neither_wakes_nor_hops_holders_and_resting_train_slimes() -> void:
	var run := _burst_with_holders()
	var sim: Simulation = run[0]
	var ids: Dictionary = run[1]
	var hops := {}
	for i in F.CELEBRATION_TICKS:
		_burst_step(sim)
		if i == 0:
			assert_true(sim.frontier.celebration_playing(sim.tick), "the burst began")
			for name in ["resting_holder", "by_contact"]:
				assert_eq(sim.slimes.calm_of(ids[name]), SlimeBodies.RESTING, "%s: not woken by its start" % name)
		for slime_id in sim.slimes.hopped:
			hops[slime_id] = hops.get(slime_id, 0) + 1
	gut.p("hops %s" % hops)
	assert_false(sim.frontier.celebration_playing(sim.tick), "the burst is over")
	assert_eq(hops.get(ids["awake"], 0), CelebrationHops.HOPS, "an awake train slime: the double hop")
	assert_eq(hops.get(ids["free"], 0), CelebrationHops.HOPS, "a free slime too")
	for name in ["resting_holder", "awake_holder", "by_contact"]:
		assert_eq(hops.get(ids[name], 0), 0, "%s: spared the hop" % name)
	for name in ["resting_holder", "by_contact"]:
		assert_eq(sim.slimes.calm_of(ids[name]), SlimeBodies.RESTING, "%s: resting throughout" % name)
	assert_true(sim.train.is_holding(ids["resting_holder"]) and sim.train.is_holding(ids["awake_holder"]),
			"the holds go on")


# D147 (6): the slimes the burst spares bounce in drawing only
# (CelebrationHops.lift_of: two arcs from the burst's start, timed like the
# double hop), the others not at all; the bounce is over well inside the
# burst, and it is no state (the dump and the hash don't see it).
# @test-link [[req_level_completion_celebration]]
func test_the_slimes_the_celebration_spares_bounce_in_drawing_only() -> void:
	var run := _burst_with_holders()
	var sim: Simulation = run[0]
	var ids: Dictionary = run[1]
	var hops := sim.frontier.hops
	var arcs := CelebrationHops.HOPS * CelebrationHops.BOUNCE_ARC_TICKS
	var highest := {}
	var lifted_ticks := {}
	for i in arcs + 10:
		_burst_step(sim)
		for name in ids:
			var lift := hops.lift_of(ids[name])
			highest[name] = maxf(highest.get(name, 0.0), lift)
			lifted_ticks[name] = lifted_ticks.get(name, 0) + (1 if lift > 0.0 else 0)
	for name in ["resting_holder", "awake_holder", "by_contact"]:
		assert_almost_eq(highest[name], CelebrationHops.BOUNCE_HEIGHT, 0.5, "%s: lifted at the arcs' tops" % name)
		assert_between(lifted_ticks[name], arcs - 4, arcs, "%s: for the two arcs" % name)
	for name in ["awake", "free"]:
		assert_eq(highest[name], 0.0, "%s hops for real, no drawn bounce" % name)
	assert_false(hops.bouncing(), "over after its two arcs")
	assert_true(sim.frontier.celebration_playing(sim.tick), "inside the burst")
	var dumped := JSON.stringify(sim.dump())
	assert_false(dumped.contains("spared") or dumped.contains("bounce"), "no state")
