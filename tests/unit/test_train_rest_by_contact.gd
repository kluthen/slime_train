extends GutTest
## Rest by contact with a holder (chunk 22f, D147 5 (a) and (c); Train.steer,
## TrainHold): a train slime that isn't holding may rest while it touches one
## or more holders ahead of it along the loop, or in its stack zone (on or
## under it), unless one of its contacts counts toward fusion. Its hop timer
## stands still while it rests. It wakes when the holder hops away (the local
## wake) or, the Train checking every tick, when it no longer touches a holder
## ahead or in its stack zone. A train slime resting by contact counts as a
## holder for the holder rule.
##
## The world is test_train_hold.gd's: a floor slab, its top at y = 0, the loop
## along it at y = -24 from x = -1500 (loop distance d is x = d - 1500), and
## a crowd of free slimes held still from x = 0 on (hold_crowd_support.gd):
## a train slime NEAR px before it holds for the crowd.

const Crowd := preload("res://tests/unit/hold_crowd_support.gd")
const DT := Simulation.TICK_SECONDS
const STAND_Y := Crowd.STAND_Y
const LOOP_START_X := -1500.0
const CROWD_COLUMNS := 8
const CROWD_ABOVE_ROWS := 4
const NEAR := Crowd.NEAR
const SPECIES_A := 0
const SPECIES_B := 1
## Two base rings' centres when they touch side by side, px: the radii plus 1
## (TrainQueues.touches: within the radii plus 2).
const TOUCH := 2.0 * SlimeBodies.RING_RADIUS_SIZE_1 + 1.0
## How far behind a holder a slime holds for it by the holder rule: in its
## hop corridor, out of its stack zone, not touching it, px.
const QUEUE_GAP := 120.0
## A groove's blocks (_sim): how far a block's face is from the centre of the
## base slime it holds (its drawn radius plus 1), their width and height, px.
const BLOCK_FACE := SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE + 1.0
const BLOCK_WIDTH := 20.0
const BLOCK_HEIGHT := 30.0


# --- The harness ---------------------------------------------------------------

## The loop of the world (see the class doc).
func _level() -> LevelData:
	var data := LevelData.new("rest-by-contact", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	return data


## A simulation on the world, its first slime removed, the view on the
## crowd's start, the crowd placed; with a groove (`groove_x` not INF), two
## blocks on the floor holding two base slimes standing TOUCH apart from x =
## `groove_x`, so a third one sits on them (_groove_at).
func _sim(groove_x := INF) -> Simulation:
	var spots := Crowd.spots(0.0, 1.0, CROWD_COLUMNS, CROWD_ABOVE_ROWS)
	var sim := Simulation.new(5)
	var polygons := Crowd.polygons(spots)
	if groove_x != INF:
		polygons.append(_block(groove_x - BLOCK_FACE, -1.0))
		polygons.append(_block(groove_x + TOUCH + BLOCK_FACE, 1.0))
	sim.slimes.terrain = TerrainSegments.new(polygons)
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(-150, -50), 1.0, ScreenView.DEFAULT_SIZE)
	Crowd.place(sim.slimes, spots)
	return sim


## A block on the floor, its face at x = `face_x`, going `way` (1 right, -1
## left) from it.
func _block(face_x: float, way: float) -> PackedVector2Array:
	var far := face_x + way * BLOCK_WIDTH
	return PackedVector2Array([Vector2(minf(face_x, far), -BLOCK_HEIGHT), Vector2(maxf(face_x, far), -BLOCK_HEIGHT),
			Vector2(maxf(face_x, far), 0), Vector2(minf(face_x, far), 0)])


## A base train slime centred at `at` (on the floor: y = STAND_Y), its next
## hop 10 s away, followed from its x.
func _train_slime(sim: Simulation, at: Vector2, slime_species := SPECIES_A) -> int:
	var slime := sim.slimes.create(slime_species, 1, at, SlimeBodies.TRAIN)
	sim.slimes.set_hop_timer(slime, 10.0)
	sim.train.track(slime, at.x - LOOP_START_X)
	return slime


## A base train slime standing on the floor at x = `x`.
func _on_floor(sim: Simulation, x: float, slime_species := SPECIES_A) -> int:
	return _train_slime(sim, Vector2(x, STAND_Y), slime_species)


## The centre of a base slime sitting on two base slimes standing TOUCH apart
## from x = `left_x`, in the groove between them.
func _groove_at(left_x: float) -> Vector2:
	var half := TOUCH * 0.5
	return Vector2(left_x + half, STAND_Y - sqrt(TOUCH * TOUCH - half * half))


## One tick in Simulation.step's order (test_train_hold.gd's harness).
func _step(sim: Simulation) -> void:
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	sim.slimes.tick(DT)
	sim.fusion.step(sim)
	sim.train.follow(sim.slimes, sim.tick)
	sim.tick += 1


func _settle(sim: Simulation) -> void:
	for i in 30:
		_step(sim)


func _resting(sim: Simulation, slime: int) -> bool:
	return sim.slimes.calm_of(slime) == SlimeBodies.RESTING


## Steps until `slime` rests (at most `limit` ticks); whether it does.
func _until_resting(sim: Simulation, slime: int, limit: int) -> bool:
	for i in limit:
		if _resting(sim, slime):
			return true
		_step(sim)
	return _resting(sim, slime)


## Makes `slime`'s hop due now and steps once: it holds (asserted).
func _hold(sim: Simulation, slime: int) -> void:
	sim.slimes.set_hop_timer(slime, 0.0)
	_step(sim)
	assert_true(sim.train.is_holding(slime), "slime %d holds" % slime)


## A holder at x = -NEAR, holding for the crowd, and a slime of another
## species touching it from behind: [holder, behind], settled, the holder
## holding.
func _holder_and_behind(sim: Simulation) -> Array[int]:
	var holder := _on_floor(sim, -NEAR)
	var behind := _on_floor(sim, -NEAR - TOUCH, SPECIES_B)
	_settle(sim)
	assert_true(TrainQueues.touches(sim.slimes, holder, behind), "they touch")
	_hold(sim, holder)
	return [holder, behind]


# --- Rest by contact ------------------------------------------------------------

# @test-link [[req_offscreen_simulation]]
func test_a_slime_touching_a_holder_ahead_rests_its_timer_standing_still() -> void:
	var sim := _sim()
	var pair := _holder_and_behind(sim)
	var behind: int = pair[1]
	assert_true(_until_resting(sim, behind, 90), "it rests by contact")
	assert_false(sim.train.is_holding(behind), "without holding")
	assert_true(sim.slimes.may_rest_of(behind))
	var timer := sim.slimes.hop_timer_of(behind)
	for i in 30:
		_step(sim)
	assert_true(_resting(sim, behind), "it rests on")
	assert_eq(sim.slimes.hop_timer_of(behind), timer, "its hop timer stands still")
	assert_eq(sim.train.hold_snapshot(sim.slimes)["contact_resting"], 1, "counted resting by contact")


# @test-link [[req_offscreen_simulation]]
func test_a_slime_touching_only_a_holder_behind_it_does_not_rest() -> void:
	var sim := _sim()
	var front := _on_floor(sim, -NEAR)
	var holder := _on_floor(sim, -NEAR - QUEUE_GAP)
	var ahead := _on_floor(sim, -NEAR - QUEUE_GAP + TOUCH, SPECIES_B)
	_settle(sim)
	assert_true(TrainQueues.touches(sim.slimes, holder, ahead), "it touches the holder behind it")
	assert_false(TrainQueues.touches(sim.slimes, front, ahead), "not the front")
	var along := absf(sim.slimes.centre_of(holder).x - sim.slimes.centre_of(ahead).x)
	assert_gte(along, 2.0 * SlimeBodies.RING_RADIUS_SIZE_1, "beside it, out of its stack zone")
	_hold(sim, front)
	_hold(sim, holder)
	for i in 120:
		_step(sim)
		assert_false(_resting(sim, ahead), "never rests")
	assert_false(sim.slimes.may_rest_of(ahead))
	assert_true(sim.train.is_holding(holder), "the holder held throughout")


# The holder (holding for the front ahead of it) stands under the slime, a
# little behind it along the loop: in its stack zone.
# @test-link [[req_offscreen_simulation]]
func test_a_slime_on_a_holder_in_its_stack_zone_rests_once_the_holder_rests() -> void:
	var left_x := -NEAR - QUEUE_GAP
	var sim := _sim(left_x)
	var front := _on_floor(sim, -NEAR)
	var holder := _on_floor(sim, left_x)
	var beside := _on_floor(sim, left_x + TOUCH, SPECIES_B)
	var top := _train_slime(sim, _groove_at(left_x), 2 + SPECIES_B)
	_settle(sim)
	assert_lt(sim.slimes.centre_of(top).y, sim.slimes.centre_of(holder).y - SlimeBodies.RING_RADIUS_SIZE_1, "on it")
	assert_true(TrainQueues.touches(sim.slimes, holder, top), "touching")
	_hold(sim, front)
	_hold(sim, holder)
	assert_true(_until_resting(sim, top, 150), "it rests by contact")
	assert_true(_resting(sim, holder), "on its resting holder")
	assert_false(sim.train.is_holding(top))


# The holder sits on the slime and another one beside it, a little behind
# the slime along the loop: in its stack zone.
# @test-link [[req_offscreen_simulation]]
func test_a_slime_under_a_holder_in_its_stack_zone_rests() -> void:
	var left_x := -NEAR - QUEUE_GAP - TOUCH
	var sim := _sim(left_x)
	var front := _on_floor(sim, -NEAR)
	var beside := _on_floor(sim, left_x, SPECIES_B)
	var under := _on_floor(sim, left_x + TOUCH, 2 + SPECIES_B)
	var holder := _train_slime(sim, _groove_at(left_x))
	_settle(sim)
	assert_true(TrainQueues.touches(sim.slimes, holder, under), "touching")
	assert_lt(sim.slimes.centre_of(holder).x, sim.slimes.centre_of(under).x, "the holder a little behind it")
	_hold(sim, front)
	_hold(sim, holder)
	assert_true(_until_resting(sim, under, 150), "it rests by contact")
	assert_false(sim.train.is_holding(under))


# --- Waking -----------------------------------------------------------------------

# @test-link [[req_offscreen_simulation]]
func test_a_slime_resting_by_contact_wakes_when_the_holder_hops_away() -> void:
	var sim := _sim()
	var pair := _holder_and_behind(sim)
	var holder: int = pair[0]
	var behind: int = pair[1]
	assert_true(_until_resting(sim, behind, 90), "it rests by contact")
	Crowd.thin(sim.slimes, sim.slimes.centre_of(holder),
			sim.train.hop_target(sim.train.distance_of(holder), Train.hop_reach(1)), holder, false)
	var hopped := false
	var woke_before := false
	for i in 120:
		woke_before = woke_before or not _resting(sim, behind)
		_step(sim)
		if sim.slimes.train_hopped.has(holder):
			hopped = true
			break
	assert_true(hopped, "the holder's way cleared: it hops")
	assert_false(woke_before, "it rested on until then")
	if _resting(sim, behind):
		_step(sim)
	assert_false(_resting(sim, behind), "woken by that tick's local wake, or the next steer's (no holder left)")


# Parking the holder ends its hold without a touch: the Train wakes the
# slime, only it, on its next steer.
# @test-link [[req_offscreen_simulation]]
func test_the_train_wakes_a_slime_resting_by_contact_once_it_touches_no_holder() -> void:
	var sim := _sim()
	var pair := _holder_and_behind(sim)
	var holder: int = pair[0]
	var behind: int = pair[1]
	assert_true(_until_resting(sim, behind, 90), "it rests by contact")
	sim.slimes.park(holder)
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	assert_false(_resting(sim, behind), "woken by the Train")
	assert_false(sim.slimes.may_rest_of(behind), "may rest no more")


# --- The holder rule --------------------------------------------------------------

# The arriving slime's hop corridor reaches the resting slime but not the
# holder it rests against, nor the crowd: at low occupancy, it holds for the
# slime resting by contact.
# @test-link [[req_hopping_behavior]]
func test_a_slime_resting_by_contact_makes_a_slime_arriving_behind_it_hold() -> void:
	var sim := _sim()
	var pair := _holder_and_behind(sim)
	var behind: int = pair[1]
	var reach := Train.hop_reach(1) + TrainHold.CORRIDOR_PAST
	var arriving := _on_floor(sim, -NEAR - TOUCH - (reach - 0.5 * TOUCH))
	assert_true(_until_resting(sim, behind, 90), "it rests by contact")
	var from := sim.slimes.centre_of(arriving)
	var target := sim.train.hop_target(sim.train.distance_of(arriving), Train.hop_reach(1))
	assert_lte(TrainHold.occupancy_of(sim.slimes, from, target, arriving), TrainHold.HOLD_OCCUPANCY, "no crowd")
	var holders_before: int = sim.train.hold_counters()["holder_holds"]
	_hold(sim, arriving)
	assert_eq(sim.train.hold_counters()["holder_holds"], holders_before + 1, "held by the holder rule")


# --- Fusion -------------------------------------------------------------------------

# @test-link [[rule_fusion_contact_time]]
# @test-link [[req_offscreen_simulation]]
func test_no_rest_by_contact_while_a_contact_counts_toward_fusion() -> void:
	var sim := _sim()
	var holder := _on_floor(sim, -NEAR)
	var behind := _on_floor(sim, -NEAR - TOUCH, SPECIES_B)
	var partner := _on_floor(sim, -NEAR - 2.0 * TOUCH, SPECIES_B)
	_settle(sim)
	assert_true(TrainQueues.touches(sim.slimes, holder, behind), "it touches the holder")
	assert_true(sim.fusion.counts_toward_fusion(behind), "and a partner, its contact counting")
	_hold(sim, holder)
	var rested := false
	for i in Fusion.CONTACT_TICKS:
		_step(sim)
		if not sim.slimes.has(partner):
			break
		rested = rested or _resting(sim, behind)
	assert_false(sim.slimes.has(partner), "they fused")
	assert_false(rested, "it didn't rest while its contact counted")
