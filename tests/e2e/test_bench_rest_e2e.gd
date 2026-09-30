extends GutTest
## The resting-pile rule on open ground (chunk 22, D107 measurements;
## tools/bench_rest.gd's open case): a heap of size-1 slimes on the parade
## (section 2's flat floor) falls asleep at bedtime, as the session brings
## it (tools/bench_rest/open_pile.gd), and, stepped as the game steps it,
## comes to rest as one pile within the measured bound, every member
## RESTING, none parked. The bound is the tool's measurement plus margin
## (see the constants); a pile that no longer rests on open ground, or rests
## much sooner than measured (the rule or the solver changed), fails here.

const OPEN_PILE := preload("res://tools/bench_rest/open_pile.gd")
const PILE_REST := preload("res://tools/bench_level/pile_rest.gd")
const SLIMES := 20
const SEED := 1
## tools/bench_rest.gd measured 1329 ticks for this pile (seed 1; 1130 and
## 1215 on seeds 2 and 3): the heap spreads into one layer for about 20 s
## before it rests. The bounds are that with margin either way.
const RESTS_AFTER := 600
const RESTS_WITHIN := 2400


## One tick as the game runs it: the view follows the camera first.
func _step(sim: Simulation) -> void:
	sim.camera.apply_to(sim.view, ScreenView.DEFAULT_SIZE)
	sim.step()


# @test-link [[req_offscreen_simulation]]
func test_a_bedtime_pile_on_open_ground_rests_within_the_measured_bound() -> void:
	var level: Level = load(LevelCatalog.scene_path(LevelCatalog.DEFAULT_ID)).instantiate()
	autofree(level)
	assert_eq(level.build(), PackedStringArray(), "the test level builds")
	var built := OPEN_PILE.build(level, SlimeWorld.terrain_from(level), SLIMES, SEED)
	assert_eq(built["error"], "", "the open pile is built")
	var sim: Simulation = built["sim"]
	assert_eq(sim.session.phase, Session.BEDTIME, "bedtime")
	var pile: Array[int] = PILE_REST.pile_of(sim)
	assert_eq(pile.size(), SLIMES, "every slime of the heap is asleep for the night")
	assert_false(PILE_REST.rests(sim, pile), "at bedtime the heap doesn't rest yet")
	var rested_at: int = PILE_REST.ticks_to_rest(sim, pile, RESTS_WITHIN, _step.bind(sim))
	gut.p("open pile of %d, seed %d: rests %d ticks after bedtime" % [SLIMES, SEED, rested_at])
	assert_between(rested_at, RESTS_AFTER, RESTS_WITHIN, "rests within [%d, %d] ticks" % [RESTS_AFTER,
			RESTS_WITHIN])
	for slime_id in pile:
		assert_eq(sim.slimes.calm_of(slime_id), SlimeBodies.RESTING, "slime %d resting" % slime_id)
