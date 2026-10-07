extends GutTest
## Train (src/sim/train.gd), chunk 24g: the hold on a climb (a train slime
## standing between hops on an outgoing rise doesn't slide back; not on the
## return route's slide, nor while it hops or is in the air) and the relay
## (when a train slime takes off, the one right behind it, within its reach,
## has its hop timer cut to RELAY_DELAY; only that one, never across a gap).

# @test-link [[req_hopping_behavior]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := 1.0 / 60.0
## The climb: rise over run of the test terrain's slope (about 22°, like the
## start basin's exit on the test level, 0.24 to 0.75).
const RISE := 0.4
## A base slime's centre height over the ground, px.
const LIFT := 24.0


## Terrain: flat at y = 0 up to x = 0, a climb rising RISE to x = 1000, flat
## again at y = -1000 * RISE.
func _climb_terrain() -> TerrainSegments:
	var top := -1000.0 * RISE
	return TerrainSegments.new([PackedVector2Array([Vector2(-2000, 0), Vector2(0, 0), Vector2(1000, top),
			Vector2(2000, top), Vector2(2000, 300), Vector2(-2000, 300)])])


## A loop along the climb at a base slime's centre height: outgoing left to
## right over the terrain, the return route back under it. With `slide_on_climb`
## the climb itself is a return route instead (a slide carrying slimes up it).
func _climb_loop(slide_on_climb := false) -> LoopData:
	var top := -1000.0 * RISE - LIFT
	var loop := LoopData.new("climb.loop")
	if slide_on_climb:
		loop.add_segment("climb.out", 1, LoopData.OUTGOING, PackedVector2Array([
				Vector2(-1500, -LIFT), Vector2(-100, -LIFT)]))
		loop.add_segment("climb.slide", 1, LoopData.RETURN, PackedVector2Array([
				Vector2(-100, -LIFT), Vector2(0, -LIFT), Vector2(1000, top), Vector2(1500, top),
				Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -LIFT)]))
		return loop
	loop.add_segment("climb.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -LIFT), Vector2(0, -LIFT), Vector2(1000, top), Vector2(1500, top)]))
	loop.add_segment("climb.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, top), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -LIFT)]))
	return loop


## The unit vector up the climb.
func _up() -> Vector2:
	return Vector2(1.0, -RISE).normalized()


## A base train slime standing on the climb at x = 500, settled for 30 ticks
## (steered, its next hop 10 s away). Returns [bodies, train, its id].
func _on_the_climb(slide_on_climb := false) -> Array:
	var bodies := SlimeBodies.new(Rng.new(1))
	bodies.terrain = _climb_terrain()
	var train := Train.new(_climb_loop(slide_on_climb))
	var slime := bodies.create(0, 1, Vector2(500, -500.0 * RISE - LIFT * 1.1))
	bodies.set_hop_timer(slime, 10.0)
	for tick in 30:
		_step(bodies, train, tick)
	return [bodies, train, slime]


## One tick as Simulation.step orders it: steer, the bodies tick, follow.
func _step(bodies: SlimeBodies, train: Train, tick: int) -> void:
	train.steer(bodies, DT)
	bodies.tick(DT)
	train.follow(bodies, tick)


# --- Hold on a climb ---------------------------------------------------------

func test_a_train_slime_standing_on_an_outgoing_climb_does_not_slide_back() -> void:
	var setup := _on_the_climb()
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var slime: int = setup[2]
	assert_true(bodies.supported[bodies.index_of(slime)] != 0, "standing on the climb")
	var start := bodies.centre_of(slime)
	for tick in range(30, 150):
		_step(bodies, train, tick)
	var back := -(bodies.centre_of(slime) - start).dot(_up())
	# Alone on a rise it still slides about 2 px/s (the Verlet substeps;
	# 4.3 px over these 2 s when written): at most 3 px/s. GRIP alone: 13 px/s.
	assert_lt(back, 6.0, "held: %.1f px down the climb in 2 s" % back)


func test_grip_alone_lets_a_slime_on_the_climb_slide_back() -> void:
	# What the hold is for: braked by GRIP alone each tick (the train before
	# chunk 24g), the same slime creeps back down the climb.
	var setup := _on_the_climb()
	var bodies: SlimeBodies = setup[0]
	var slime: int = setup[2]
	var start := bodies.centre_of(slime)
	for tick in 120:
		bodies.brake(slime, Train.GRIP)
		bodies.tick(DT)
	var back := -(bodies.centre_of(slime) - start).dot(_up())
	# 26 px over these 2 s when written (13 px/s): at least 9 px/s.
	assert_gt(back, 18.0, "GRIP alone: %.1f px down the climb in 2 s" % back)


func test_the_hold_cancels_motion_down_the_climb_between_hops() -> void:
	var setup := _on_the_climb()
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var slime: int = setup[2]
	bodies.set_velocity(slime, -_up() * 40.0)
	train.steer(bodies, DT)
	var along := bodies.velocity_of(slime).dot(_up())
	assert_gte(along, 0.0, "no motion down the climb left (%.2f px/s along it)" % along)
	assert_lt(along, -bodies.gravity.dot(_up()) * DT, "only a share of one tick's pull up it")


func test_no_hold_on_the_tick_a_hop_is_due() -> void:
	# Its hop is due: GRIP brakes it by half, the hold leaves it alone (the
	# hop's aim is the train's then).
	var setup := _on_the_climb()
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var slime: int = setup[2]
	bodies.set_hop_timer(slime, 0.0)
	bodies.set_velocity(slime, -_up() * 40.0)
	train.steer(bodies, DT)
	assert_almost_eq(bodies.velocity_of(slime).dot(_up()), -40.0 * (1.0 - Train.GRIP), 0.01,
			"braked by GRIP only")


func test_no_hold_in_the_air() -> void:
	var setup := _on_the_climb()
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var slime: int = setup[2]
	bodies.supported[bodies.index_of(slime)] = 0
	bodies.set_velocity(slime, -_up() * 40.0)
	train.steer(bodies, DT)
	assert_almost_eq(bodies.velocity_of(slime).dot(_up()), -40.0, 0.01, "unsupported: untouched")


func test_no_hold_once_knocked_off_the_route() -> void:
	# Found by rule 2's lap run on a fresh 4-section skeleton: a size-2 slime
	# whose progress had reached the flat top of a 0.87 climb slid back down
	# it past OFF_ROUTE, steered from the climb behind, was held there, and
	# every hop from that spot skimmed the slope and was braked away: stalled.
	# Knocked off the route (here its progress 100 px further up the climb), a
	# slime isn't held: GRIP alone brakes it, it slides back to where it hops.
	var setup := _on_the_climb()
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var slime: int = setup[2]
	var at := train.distance_of(slime)
	train.track(slime, at + 100.0)
	assert_ne(train.steering_distance(at + 100.0, bodies.centre_of(slime)), at + 100.0, "knocked off the route")
	bodies.set_velocity(slime, -_up() * 40.0)
	train.steer(bodies, DT)
	assert_almost_eq(bodies.velocity_of(slime).dot(_up()), -40.0 * (1.0 - Train.GRIP), 0.01,
			"braked by GRIP only")


func test_the_return_routes_slide_up_a_climb_is_not_held() -> void:
	# The climb is a return route here: the slime is carried along it at
	# the slide's pace (Train._carry), and nothing else. The same slime
	# carried by hand on a copy of the bodies ends bit for bit where the
	# train's steering takes it.
	var setup := _on_the_climb(true)
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var slime: int = setup[2]
	assert_true(train.is_slide_at(train.distance_of(slime)), "on the slide")
	var by_hand := _on_the_climb(true)
	var hand_bodies: SlimeBodies = by_hand[0]
	var hand_train: Train = by_hand[1]
	for tick in range(30, 90):
		_step(bodies, train, tick)
		if hand_bodies.supported[hand_bodies.index_of(slime)] != 0:
			var centre := hand_bodies.centre_of(slime)
			hand_train._carry(hand_bodies, slime, hand_train.steering_distance(hand_train.distance_of(slime), centre))
		hand_bodies.tick(DT)
		hand_train.follow(hand_bodies, tick)
	assert_eq(bodies.centre_of(slime), hand_bodies.centre_of(slime))
	assert_gt(bodies.velocity_of(slime).dot(_up()), 0.0, "carried up the climb")


# --- The relay ---------------------------------------------------------------

## A flat floor at y = 0 and a loop along it at a base slime's centre height,
## x -1500 to 1500, returning under the floor (loop distance d is x = d - 1500
## on the outgoing part); base train slimes standing at `xs` (left to right,
## the back of the queue first), settled for 30 ticks, their next hops 10 s
## away. Returns [bodies, train, their ids in the order of `xs`].
func _queue(xs: Array) -> Array:
	var bodies := Support.bodies_on_floor()
	var loop := LoopData.new("flat.loop")
	loop.add_segment("flat.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -LIFT), Vector2(1500, -LIFT)]))
	loop.add_segment("flat.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -LIFT), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -LIFT)]))
	var train := Train.new(loop)
	var ids := []
	for x: float in xs:
		var slime := bodies.create(0, 1, Vector2(x, -LIFT))
		bodies.set_hop_timer(slime, 10.0)
		ids.append(slime)
	for tick in 30:
		_step(bodies, train, tick)
	for slime: int in ids:
		bodies.set_hop_timer(slime, 10.0)
	return [bodies, train, ids]


## Makes train slime `slime` take off on the next tick, steps that tick, and
## steers once more (the relay reads the take-offs then).
func _take_off(bodies: SlimeBodies, train: Train, slime: int) -> void:
	bodies.set_hop_timer(slime, 0.0)
	_step(bodies, train, 30)
	assert_true(bodies.train_hopped.has(slime), "it took off")
	train.steer(bodies, DT)


func test_the_slime_right_behind_a_take_off_follows_at_once() -> void:
	# Three in a row, 60 px apart (within a hop's reach): the front one hops.
	var setup := _queue([-1120.0, -1060.0, -1000.0])
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var ids: Array = setup[2]
	_take_off(bodies, train, ids[2])
	assert_almost_eq(bodies.hop_timer_of(ids[1]), Train.RELAY_DELAY, 1e-6, "right behind: relayed")
	assert_gt(bodies.hop_timer_of(ids[0]), 9.0, "only the one right behind")


func test_the_relay_wave_runs_down_the_queue() -> void:
	var setup := _queue([-1120.0, -1060.0, -1000.0])
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var ids: Array = setup[2]
	_take_off(bodies, train, ids[2])
	var tick := 31
	while not bodies.train_hopped.has(ids[1]) and tick < 60:
		bodies.tick(DT)
		train.follow(bodies, tick)
		train.steer(bodies, DT)
		tick += 1
	assert_lt(tick, 60, "the one right behind hopped within RELAY_DELAY")
	assert_almost_eq(bodies.hop_timer_of(ids[0]), Train.RELAY_DELAY, 1e-6, "then the next one")


func test_no_relay_across_a_gap() -> void:
	# 300 px behind: more than a hop's reach plus the two radii.
	var setup := _queue([-1300.0, -1000.0])
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var ids: Array = setup[2]
	_take_off(bodies, train, ids[1])
	assert_gt(bodies.hop_timer_of(ids[0]), 9.0, "too far back: its own timer")


func test_the_relay_never_delays_a_hop() -> void:
	var setup := _queue([-1060.0, -1000.0])
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var ids: Array = setup[2]
	bodies.set_hop_timer(ids[0], 0.1)
	_take_off(bodies, train, ids[1])
	assert_lt(bodies.hop_timer_of(ids[0]), 0.1, "already sooner: kept")
