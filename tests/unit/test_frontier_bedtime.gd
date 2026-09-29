extends GutTest
## Baskets at bedtime (item 23.5, D105; master spec §5.4, §5.7) on the
## synthetic level of test_frontier_sets.gd: at bedtime a basket's releases
## pause and resume at sunrise; the slimes in it stay in it, and sunrise
## doesn't move them out; a reward that is due or playing waits for sunrise,
## so no gate opens and no celebration plays during bedtime; a celebration
## already playing stands still and hidden, and plays the rest at sunrise.
## All of it is saved: a save taken during bedtime reloads the same.

# @test-link [[req_switch_basket_gate_set]]
# @test-link [[req_session_lifecycle]]
# @test-link [[req_slime_states]]
# @test-link [[req_level_completion_celebration]]
# @test-link [[req_persistence_and_saves]]

const F := preload("res://tests/unit/frontier_test_support.gd")


func _basket(sim: Simulation, id := F.BASKET) -> Dictionary:
	return sim.object_states[id]


# --- Releases pause ---------------------------------------------------------------

func test_a_releasing_basket_lets_no_slime_go_at_bedtime_and_resumes_at_sunrise() -> void:
	var sim := F.sim()
	# The switch isn't flipped: the basket isn't holding, it lets its slimes go.
	var a := F.slime(sim, 1, -850, SlimeBodies.IN_BASKET)
	var b := F.slime(sim, 2, -700, SlimeBodies.IN_BASKET)
	F.bedtime(sim)
	assert_true(FrontierSets.paused(sim), "bedtime: the sets stand still")
	F.frontier_steps(sim, 10 * Simulation.TICK_RATE)
	assert_eq(sim.slimes.state_of(a), SlimeBodies.IN_BASKET, "not released at bedtime")
	assert_eq(sim.slimes.state_of(b), SlimeBodies.IN_BASKET)
	assert_eq(_basket(sim)["weight"], 3, "still weighed")
	F.sunrise(sim)
	assert_false(FrontierSets.paused(sim))
	assert_eq(sim.slimes.state_of(a), SlimeBodies.IN_BASKET, "sunrise doesn't move them out")
	assert_eq(sim.slimes.state_of(b), SlimeBodies.IN_BASKET)
	F.frontier_steps(sim, 1)
	assert_eq(sim.slimes.state_of(a), SlimeBodies.TRAIN, "the releases resume: the lowest id first")
	assert_eq(sim.slimes.state_of(b), SlimeBodies.IN_BASKET, "one at a time")


func test_the_slimes_in_a_basket_are_not_put_to_sleep_nor_woken_out_of_it() -> void:
	var sim := F.sim()
	sim.frontier.tap_switch(sim, F.SWITCH)
	var caught := F.slime(sim, 2, -800, SlimeBodies.IN_BASKET)
	var riding := F.slime(sim, 1, -1300)
	F.bedtime(sim)
	assert_eq(sim.slimes.state_of(riding), SlimeBodies.BEDTIME_ASLEEP)
	assert_eq(sim.slimes.state_of(caught), SlimeBodies.IN_BASKET, "it sleeps in place, in the basket")
	F.sunrise(sim)
	assert_eq(sim.slimes.state_of(riding), SlimeBodies.TRAIN)
	assert_eq(sim.slimes.state_of(caught), SlimeBodies.IN_BASKET, "still in the basket after sunrise")


# --- Rewards wait -----------------------------------------------------------------

func test_a_due_reward_waits_for_sunrise_and_no_gate_opens() -> void:
	var sim := F.sim()
	sim.frontier.tap_switch(sim, F.SWITCH)
	F.slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	F.look(sim, F.AWAY)
	F.frontier_steps(sim, 1)
	assert_eq(_basket(sim)["phase"], FrontierSets.FULL, "full, off screen")
	F.bedtime(sim)
	F.look(sim, F.BASKET_BOX.get_center())
	F.frontier_steps(sim, 10 * Simulation.TICK_RATE)
	assert_eq(_basket(sim)["phase"], FrontierSets.FULL, "in view at bedtime: the reward waits")
	assert_false(sim.gate_states[F.GATE]["open"], "no gate opens")
	F.sunrise(sim)
	F.frontier_steps(sim, 1)
	assert_eq(_basket(sim)["phase"], FrontierSets.REWARD, "sunrise: the reward plays")
	F.frontier_steps(sim, F.REWARD_TICKS)
	assert_eq(_basket(sim)["phase"], FrontierSets.FIRED)
	assert_true(sim.gate_states[F.GATE]["open"], "then the gate opens")


func test_a_playing_reward_stands_still_through_bedtime_then_plays_the_rest() -> void:
	var sim := F.sim()
	sim.frontier.tap_switch(sim, F.SWITCH)
	F.slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	F.frontier_steps(sim, 2)
	assert_eq(_basket(sim)["phase"], FrontierSets.REWARD)
	var played := 30
	F.frontier_steps(sim, played - 1)
	F.bedtime(sim)
	F.frontier_steps(sim, 10 * Simulation.TICK_RATE)
	assert_eq(_basket(sim)["phase"], FrontierSets.REWARD, "the reward waits")
	assert_eq(sim.tick - _basket(sim)["since"], played, "its clock stands still")
	assert_false(sim.gate_states[F.GATE]["open"])
	F.sunrise(sim)
	F.frontier_steps(sim, F.REWARD_TICKS - played)
	assert_eq(_basket(sim)["phase"], FrontierSets.REWARD, "the rest of the reward")
	F.frontier_steps(sim, 1)
	assert_eq(_basket(sim)["phase"], FrontierSets.FIRED, "then it fires")
	assert_true(sim.gate_states[F.GATE]["open"])


# --- The celebration waits ----------------------------------------------------------

func test_the_last_basket_due_at_bedtime_celebrates_only_after_sunrise() -> void:
	var sim := F.sim()
	sim.frontier.tap_switch(sim, F.SWITCH)
	F.slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	F.bedtime(sim)
	F.frontier_steps(sim, 10 * Simulation.TICK_RATE)
	assert_false(sim.frontier.celebration_done, "no celebration at bedtime")
	F.sunrise(sim)
	# Full, then the reward, then it fires: no phase changed at bedtime.
	F.frontier_steps(sim, F.REWARD_TICKS + 2)
	assert_true(sim.frontier.celebration_done, "at sunrise, the reward, then the celebration")
	assert_true(sim.frontier.celebration_showing(sim))


func test_a_celebration_playing_at_bedtime_hides_and_plays_the_rest_at_sunrise() -> void:
	var sim := F.sim()
	sim.frontier.tap_switch(sim, F.SWITCH)
	F.slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	F.frontier_steps(sim, F.REWARD_TICKS + 2)
	assert_true(sim.frontier.celebration_showing(sim))
	var played := 60
	F.frontier_steps(sim, played - 1)
	var age := sim.tick - sim.frontier.celebration_since
	F.bedtime(sim)
	assert_false(sim.frontier.celebration_showing(sim), "no celebration plays during bedtime")
	F.frontier_steps(sim, 10 * Simulation.TICK_RATE)
	assert_false(sim.frontier.celebration_showing(sim))
	assert_eq(sim.tick - sim.frontier.celebration_since, age, "it stands still")
	F.sunrise(sim)
	assert_true(sim.frontier.celebration_showing(sim), "sunrise: the rest of it")
	F.frontier_steps(sim, F.CELEBRATION_TICKS - age)
	assert_false(sim.frontier.celebration_playing(sim.tick), "then it ends")


# --- Saved -----------------------------------------------------------------------

func test_a_save_taken_at_bedtime_reloads_the_same_and_goes_on_the_same() -> void:
	var sim := F.sim(5, true)
	sim.frontier.tap_switch(sim, F.SWITCH)
	F.slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	F.slime(sim, 1, 700, SlimeBodies.IN_BASKET)
	F.slime(sim, 1, -1300)
	for i in 40:
		sim.step()
	assert_eq(_basket(sim)["phase"], FrontierSets.REWARD, "a reward playing")
	F.bedtime(sim)
	for i in 120:
		sim.step()
	var text := JSON.stringify(sim.to_save(), "", true, true)
	var again := Simulation.from_save(JSON.parse_string(text), F.level(true), sim.slimes.terrain, 5)
	again.view.set_to(sim.view.centre, sim.view.zoom, sim.view.screen_size)
	assert_eq(again.session.phase, Session.BEDTIME)
	assert_eq(again.state_hash(), sim.state_hash(), "the same state")
	for run in [sim, again]:
		for i in 120:
			run.step()
		F.sunrise(run)
		for i in 300:
			run.step()
	assert_eq(_basket(again)["phase"], FrontierSets.FIRED, "after sunrise the reward ends and fires")
	assert_eq(again.state_hash(), sim.state_hash(), "and goes on the same")
