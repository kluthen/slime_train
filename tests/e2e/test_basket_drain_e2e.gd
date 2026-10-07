extends GutTest
## A fired basket lets its slimes go (build plan item 24.3, D128; master spec
## 5.2 "in a basket" and 5.4; D86, D91, D105), through the real game scene and
## test mode on the test level. From `s3-basket-59of60` with the camera on
## basket 3, the basket fills, fires (the celebration) and is empty within
## its quota x 0.3 s plus 10 s of firing (28 s); from `s2-basket-offscreen`
## with the camera on basket 2, it fires and is empty within 14.5 s. In both,
## every slime released is a train slime with the size and species it had in
## the basket, and none falls back in. From basket 3 releasing, bedtime
## pauses the releases until sunrise, and they then resume.
## A released slime hops away at once (O126): it hops on the tick after it
## lands on the outlet's ground, 3 ticks after its release, so basket 2 empties within 5 s of firing (13.1 s before, when a
## released slime waited at the outlet for its own hop timer), and basket 1
## (from `s1-basket-5of6`, quota 6) is empty within its 11.8 s.

# @test-link [[req_switch_basket_gate_set]]
# @test-link [[rule_frontier_set_inert_after_gate_open]]
# @test-link [[req_slime_states]]
# @test-link [[req_session_lifecycle]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 14
const TICK_RATE := Simulation.TICK_RATE
## The camera on basket 3's framing zone (as test_frontier_e2e.gd), and on
## basket 2 (the s2-basket-offscreen sidecar's basket view).
const BASKET_3_VIEW := Vector2(15.875 * 1152.0, -150.0)
const BASKET_2_VIEW := Vector2(12.4 * 1152.0, -50.0)
## The camera on basket 1 (the s1-basket-5of6 sidecar's).
const BASKET_1_VIEW := Vector2(7948.8, -50.0)
## O126: basket 2 is empty within this of firing, in seconds (its 6 slimes
## at the 0.3 s pace take 1.5 s; it took 13.1 s when a released slime waited
## for its own hop timer at the outlet).
const BASKET_2_FAST := 5.0
## A released slime hops within this many ticks of its release. It is put
## at the outlet unsupported, at the loop's height: at basket 2 it lands on
## the 2nd tick (it falls about 0.6 px) and hops on the 3rd, the first tick
## its timer can act on its landing. (O126's brief said 1 or 2 ticks; 2 would
## need a slime put down already standing, which an outlet over a drop, as
## basket 3's, can't be.)
const HOP_WITHIN := 3
## How long each basket has to fill and fire from its fixture (seconds).
const FIRE_WITHIN := 60
## D128: a fired basket empties within its quota x RELEASE_SECONDS plus this.
const DRAIN_SLACK := 10.0
## How long the bedtime check watches, seconds.
const WATCH := 10


func _boot(fixture: String) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "fixture": fixture}), PackedStringArray())
	return game


## One tick with the camera held at `at`.
func _tick(game: Node, at: Vector2) -> void:
	game.simulation.camera.place(at, 1.0)
	game.sync_view()
	game.test_mode.run_ticks(1)


## The slimes in the basket on the tick before it fired (id -> [size,
## species]): the first release can come on the firing tick itself.
var _held_at_fire := {}


## Runs until `basket` has fired, at most FIRE_WITHIN s. Returns the ticks
## it took, or -1.
func _run_until_fired(game: Node, basket: String, at: Vector2) -> int:
	var state: Dictionary = game.simulation.object_states[basket]
	for i in FIRE_WITHIN * TICK_RATE:
		if state["phase"] == FrontierSets.FIRED:
			return i
		if state["phase"] == FrontierSets.REWARD:
			_held_at_fire = _in_basket(game.simulation)
		_tick(game, at)
	return -1


## Stable order of the slimes in a basket now: id -> [size, species].
static func _in_basket(sim: Simulation) -> Dictionary:
	var out := {}
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.IN_BASKET:
			out[slime_id] = [sim.slimes.size_of(slime_id), sim.slimes.species_of(slime_id)]
	return out


## Watches basket `basket` drain for at most `limit` ticks from now (the
## tick after it fired), the camera at `at`; the slimes it held are those of
## _held_at_fire. Returns {"empty_after": ticks or -1, "released": id ->
## tick, "changed": ids released with another size or species, "back_in":
## ids caught again after their release, "left_as": ids that left the basket
## in a state other than a train slime}.
func _drain(game: Node, basket: String, at: Vector2, limit: int) -> Dictionary:
	var sim: Simulation = game.simulation
	var held := _held_at_fire
	var out := {"empty_after": -1, "released": {}, "changed": [], "back_in": [], "left_as": []}
	var inside := _in_basket(sim)
	for slime_id in held:
		if not inside.has(slime_id):
			out["released"][slime_id] = sim.tick
			if sim.slimes.state_of(slime_id) != SlimeBodies.TRAIN:
				out["left_as"].append(slime_id)
			if [sim.slimes.size_of(slime_id), sim.slimes.species_of(slime_id)] != held[slime_id]:
				out["changed"].append(slime_id)
	for i in limit:
		_tick(game, at)
		var now := _in_basket(sim)
		for slime_id in inside:
			if now.has(slime_id):
				continue
			var state := sim.slimes.state_of(slime_id)
			if state != SlimeBodies.TRAIN:
				out["left_as"].append(slime_id)
			if [sim.slimes.size_of(slime_id), sim.slimes.species_of(slime_id)] != held.get(slime_id, inside[slime_id]):
				out["changed"].append(slime_id)
			out["released"][slime_id] = sim.tick
		for slime_id in now:
			if not inside.has(slime_id) and out["released"].has(slime_id):
				out["back_in"].append(slime_id)
		inside = now
		if inside.is_empty() and sim.object_states[basket]["weight"] == 0:
			out["empty_after"] = i + 1
			break
	return out


static func _drain_limit(sim: Simulation, basket: String) -> int:
	var quota := int(sim.level.baskets[basket]["quota"])
	return int(round((quota * FrontierSets.RELEASE_SECONDS + DRAIN_SLACK) * TICK_RATE))


## Asserts basket `basket` fires and drains as D128 says; returns _drain's
## result ({} when it didn't fire).
func _assert_drains(game: Node, basket: String, at: Vector2) -> Dictionary:
	var sim: Simulation = game.simulation
	var fired := _run_until_fired(game, basket, at)
	assert_gt(fired, -1, "%s fires within %d s" % [basket, FIRE_WITHIN])
	if fired < 0:
		return {}
	var held := _held_at_fire.size()
	var limit := _drain_limit(sim, basket)
	var drain := _drain(game, basket, at, limit)
	gut.p("%s: fired after %d ticks holding %d slimes; empty after %d ticks (limit %d), %d released, %d back in"
			% [basket, fired, held, drain["empty_after"], limit, drain["released"].size(), drain["back_in"].size()])
	assert_gt(drain["empty_after"], 0, "%s is empty within %.1f s of firing" % [basket, limit / float(TICK_RATE)])
	var kept := _held_at_fire.keys().filter(func(slime_id): return not drain["released"].has(slime_id))
	assert_eq(kept, [], "every slime it held is released")
	assert_eq(drain["back_in"], [], "no released slime falls back in")
	assert_eq(drain["left_as"], [], "every released slime rides the train")
	assert_eq(drain["changed"], [], "each with the size and species it had")
	return drain


# --- Basket 3: the celebration, then empty within 28 s ---------------------------

func test_basket_3_fired_is_empty_within_28_s_and_none_falls_back_in() -> void:
	var game := _boot("s3-basket-59of60")
	var sim: Simulation = game.simulation
	assert_eq(_drain_limit(sim, "s3.basket"), 28 * TICK_RATE, "60 x 0.3 s + 10 s")
	_assert_drains(game, "s3.basket", BASKET_3_VIEW)
	assert_true(sim.frontier.celebration_done, "the last basket fired: the celebration")


# --- Basket 2: empty within 14.5 s, and within 5 s since O126 ----------------------

func test_basket_2_fired_is_empty_within_14_5_s_and_none_falls_back_in() -> void:
	var game := _boot("s2-basket-offscreen")
	var sim: Simulation = game.simulation
	assert_eq(_drain_limit(sim, "s2.basket"), int(14.5 * TICK_RATE), "15 x 0.3 s + 10 s")
	var drain := _assert_drains(game, "s2.basket", BASKET_2_VIEW)
	assert_true(sim.gate_states["s2.gate"]["open"], "gate 2 open")
	var empty_after: int = drain.get("empty_after", -1)
	gut.p("s2.basket: empty %.2f s after firing" % (empty_after / float(TICK_RATE)))
	assert_between(empty_after, 1, int(BASKET_2_FAST * TICK_RATE),
			"a released slime hops away at once: basket 2 is empty within %.0f s (13.1 s before)" % BASKET_2_FAST)


# --- Basket 1: empty within 11.8 s ------------------------------------------------

func test_basket_1_fired_is_empty_within_11_8_s_and_none_falls_back_in() -> void:
	var game := _boot("s1-basket-5of6")
	var sim: Simulation = game.simulation
	assert_eq(_drain_limit(sim, "s1.basket"), int(round(11.8 * TICK_RATE)), "6 x 0.3 s + 10 s")
	_assert_drains(game, "s1.basket", BASKET_1_VIEW)
	assert_true(sim.gate_states["s1.gate"]["open"], "gate 1 open")


# --- A released slime hops away at once (O126) -------------------------------------

func test_a_released_slime_hops_on_the_tick_after_it_lands() -> void:
	var game := _boot("s2-basket-offscreen")
	var sim: Simulation = game.simulation
	var bodies := sim.slimes
	assert_gt(_run_until_fired(game, "s2.basket", BASKET_2_VIEW), -1, "basket 2 fires")
	var inside := _in_basket(sim)
	var waiting := {}  # released slime id -> [ticks since its release, tick it landed or -1]
	var hops := {}  # released slime id -> [ticks from release to landing, to hop]
	for slime_id in _held_at_fire:
		if not inside.has(slime_id):
			waiting[slime_id] = [0, -1]  # released on the firing tick
	for i in int(BASKET_2_FAST * TICK_RATE):
		_tick(game, BASKET_2_VIEW)
		for slime_id in waiting.keys():
			var seen: Array = waiting[slime_id]
			seen[0] += 1
			if slime_id in bodies.hopped:
				hops[slime_id] = [seen[1], seen[0]]
				waiting.erase(slime_id)
			elif seen[1] < 0 and bodies.supported[bodies.index_of(slime_id)] != 0:
				seen[1] = seen[0]
		var now := _in_basket(sim)
		for slime_id in inside:
			if not now.has(slime_id):
				waiting[slime_id] = [0, -1]
		inside = now
		if inside.is_empty() and waiting.is_empty():
			break
	gut.p("ticks from release to [landing, hop]: %s" % hops)
	assert_eq(hops.size(), _held_at_fire.size(), "every slime it held hopped after its release")
	for slime_id in hops:
		var landed: int = hops[slime_id][0]
		var hopped: int = hops[slime_id][1]
		assert_gt(landed, 0, "slime %d lands on the outlet's ground" % slime_id)
		assert_eq(hopped, landed + 1, "slime %d hops on the tick after it lands" % slime_id)
		assert_between(hopped, 1, HOP_WITHIN, "slime %d hops within %d ticks of its release" % [slime_id, HOP_WITHIN])


# --- Bedtime still pauses a fired basket's releases ------------------------------

func test_bedtime_pauses_basket_3s_releases_until_sunrise() -> void:
	var game := _boot("s3-basket-59of60")
	var sim: Simulation = game.simulation
	assert_gt(_run_until_fired(game, "s3.basket", BASKET_3_VIEW), -1, "basket 3 fires")
	for i in 2 * TICK_RATE:
		_tick(game, BASKET_3_VIEW)
	sim.session.start(sim)
	sim.session.jump(sim, Session.BEDTIME_MS)
	assert_eq(sim.session.phase, Session.BEDTIME, "bedtime")
	var held := _in_basket(sim)
	assert_gt(held.size(), 0, "the basket still holds slimes")
	for i in WATCH * TICK_RATE:
		_tick(game, BASKET_3_VIEW)
	assert_eq(_in_basket(sim).keys(), held.keys(), "no slime released at bedtime")
	sim.session.sunrise(sim)
	assert_eq(_in_basket(sim).keys(), held.keys(), "sunrise doesn't move them out")
	for i in 3 * TICK_RATE:
		_tick(game, BASKET_3_VIEW)
	assert_lt(_in_basket(sim).size(), held.size(), "the releases resume at sunrise")
