extends GutTest
## The celebration's lasting mark and double hop (item 23.11, ux D4; master
## spec §5.1) on the synthetic level of test_frontier_sets.gd: once the
## celebration has played (the level's saved done mark), the mark stands at
## the start of the loop, after a reload too, and never on a level whose
## celebration hasn't played; when the burst begins, every awake slime on
## screen hops twice, and nobody else hops for it; the hops still due are
## saved and hashed.

# @test-link [[req_level_completion_celebration]]
# @test-link [[req_hopping_behavior]]
# @test-link [[req_persistence_and_saves]]

const F := preload("res://tests/unit/frontier_test_support.gd")


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
