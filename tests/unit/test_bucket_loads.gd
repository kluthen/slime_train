extends GutTest
## BucketLoads (src/sim/bucket_loads.gd, chunk 22i, D151): the loop cut into
## loop buckets, each with a load (the summed sizes of the train slimes
## counted in it) and a bucket cap (the density times its length, rounded
## down, never below 3; the density raised to 2 x base slimes per 100 px of
## loop when that is larger). A distance past the loop's end wraps to
## bucket 0: the loop is one cycle.
##
## The synthetic loop: 1000 px cut into 300 px buckets, so 4 buckets
## ([0, 300), [300, 600), [600, 900), [900, 1000)); the last one is short.

# @test-link [[req_hopping_behavior]]

const LOOP := 1000.0
const BUCKET := 300.0
const DENSITY := 4.0


func _loads(loop := LOOP, base_slimes := 0) -> BucketLoads:
	var loads := BucketLoads.new()
	loads.configure(loop, BUCKET, DENSITY, base_slimes)
	return loads


# --- The cut ---------------------------------------------------------------------

func test_the_cut_rounds_up_and_a_distance_falls_in_its_bucket() -> void:
	var loads := _loads()
	assert_eq(loads.count(), 4, "ceil(1000 / 300)")
	assert_eq(loads.bucket_index(0.0), 0)
	assert_eq(loads.bucket_index(299.9), 0)
	assert_eq(loads.bucket_index(300.0), 1)
	assert_eq(loads.bucket_index(650.0), 2)
	assert_eq(loads.bucket_index(999.9), 3)
	assert_eq(_loads(100.0).count(), 1, "a loop shorter than a bucket is one bucket")


func test_a_distance_past_the_loops_end_wraps_and_the_next_of_the_last_is_bucket_0() -> void:
	var loads := _loads()
	assert_eq(loads.bucket_index(LOOP), 0, "the loop's end is its start")
	assert_eq(loads.bucket_index(LOOP + 350.0), 1, "a hop past the end lands in bucket 1")
	assert_eq(loads.bucket_index(-50.0), 3, "behind the start is the last bucket")
	assert_eq(loads.next(0), 1)
	assert_eq(loads.next(2), 3)
	assert_eq(loads.next(3), 0, "one cycle")


func test_a_buckets_front_edge() -> void:
	var loads := _loads()
	assert_eq(loads.front_edge(0), 300.0)
	assert_eq(loads.front_edge(2), 900.0)
	assert_eq(loads.front_edge(3), LOOP, "the short last bucket ends at the loop's end")


func test_configure_reports_a_new_cut_only_when_something_changed() -> void:
	var loads := BucketLoads.new()
	assert_eq(loads.count(), 0, "no cut before configure")
	assert_true(loads.configure(LOOP, BUCKET, DENSITY, 0))
	loads.add(1, 5)
	assert_false(loads.configure(LOOP, BUCKET, DENSITY, 0), "the same cut")
	assert_eq(loads.load(1), 5, "kept")
	assert_true(loads.configure(2000.0, BUCKET, DENSITY, 0), "a gate opened: a longer loop")
	assert_eq(loads.count(), 7)
	assert_eq(loads.load(1), 0, "a new cut empties the loads")
	assert_true(loads.configure(2000.0, 500.0, DENSITY, 0), "another bucket length")
	assert_true(loads.configure(2000.0, 500.0, 2.0, 0), "another density")
	assert_true(loads.configure(2000.0, 500.0, 2.0, 30), "other base slimes")


# --- The caps ----------------------------------------------------------------------

func test_a_300_px_bucket_caps_at_12_and_the_short_last_one_gets_its_share() -> void:
	var loads := _loads()
	assert_eq(loads.caps(), PackedInt32Array([12, 12, 12, 4]), "4 per 100 px: 100 px left for the last")
	assert_eq(loads.cap(0), 12)
	assert_eq(loads.density_used(), DENSITY)


func test_no_cap_is_below_3() -> void:
	var loads := _loads(950.0)
	assert_eq(loads.caps(), PackedInt32Array([12, 12, 12, 3]), "a 50 px last bucket: 2 by its share, 3 at least")
	var tiny := BucketLoads.new()
	tiny.configure(100.0, 20.0, DENSITY, 0)
	assert_eq(tiny.cap(0), 3, "20 px buckets: 0.8 by the density, 3 at least")


# @test-link [[rule_loop_travelable_with_no_input]]
func test_the_density_floor_binds_when_the_level_holds_many_base_slimes() -> void:
	var loose := _loads(LOOP, 10)
	assert_eq(loose.density_used(), DENSITY, "2 x 10 per 1000 px is 2 per 100 px: 4 stays")
	var tight := _loads(LOOP, 100)
	assert_eq(tight.density_used(), 20.0, "2 x 100 per 1000 px is 20 per 100 px")
	assert_eq(tight.caps(), PackedInt32Array([60, 60, 60, 20]))
	var room := 0
	for cap in tight.caps():
		room += cap
	assert_gte(room, 2 * 100, "the total room at least twice the most the train can weigh")


# --- The loads -------------------------------------------------------------------

func test_add_and_move_carry_weights_and_the_reads_follow() -> void:
	var loads := _loads()
	loads.add(0, 3)
	loads.add(0, 2)
	loads.add(2, 13)
	assert_eq(loads.loads(), PackedInt32Array([5, 0, 13, 0]))
	loads.move(0, 1, 2)
	assert_eq(loads.load(0), 3)
	assert_eq(loads.load(1), 2)
	assert_eq(loads.max_load(), 13)
	assert_eq(loads.over_count(), 1, "bucket 2 is over its cap of 12")
	loads.clear_loads()
	assert_eq(loads.loads(), PackedInt32Array([0, 0, 0, 0]))
	assert_eq(loads.max_load(), 0)
	assert_eq(loads.over_count(), 0)
	assert_eq(loads.count(), 4, "clearing keeps the cut")


func test_room_and_overfilled() -> void:
	var loads := _loads()
	loads.add(0, 10)
	assert_true(loads.has_room(0, 2), "10 + 2 <= 12")
	assert_false(loads.has_room(0, 3), "10 + 3 > 12")
	assert_false(loads.overfilled(0), "under its cap")
	loads.add(0, 2)
	assert_true(loads.overfilled(0), "at its cap")
	assert_eq(loads.over_count(), 0, "at its cap is not over it")
	loads.add(0, 1)
	assert_true(loads.overfilled(0), "over its cap")
	assert_eq(loads.over_count(), 1)
	assert_true(loads.has_room(3, 3), "an empty bucket has room for any slime")
	assert_false(loads.has_room(3, 5), "but its cap of 4 holds")


func test_a_counted_slime_follows_its_distance_and_one_not_counted_does_not() -> void:
	var loads := _loads()
	loads.place(7, 100.0, 2)
	loads.place(8, 950.0, 3)
	assert_eq(loads.loads(), PackedInt32Array([2, 0, 0, 3]))
	assert_eq(loads.bucket_of(7), 0)
	loads.carry(7, 450.0)
	assert_eq(loads.loads(), PackedInt32Array([0, 2, 0, 3]), "7 moved its weight to bucket 1")
	loads.carry(8, LOOP + 20.0)
	assert_eq(loads.loads(), PackedInt32Array([3, 2, 0, 0]), "8 went round the end: bucket 0")
	loads.carry(9, 700.0)
	assert_eq(loads.loads(), PackedInt32Array([3, 2, 0, 0]), "9 isn't counted: nothing moves")
	assert_eq(loads.bucket_of(9), -1)
	loads.place(7, 800.0, 3)
	assert_eq(loads.loads(), PackedInt32Array([3, 0, 3, 0]), "placed again with its new weight")
	assert_true(loads.drop(7))
	assert_false(loads.drop(7), "no longer counted")
	assert_eq(loads.loads(), PackedInt32Array([3, 0, 0, 0]))
	loads.clear_loads()
	assert_eq(loads.bucket_of(8), -1, "clearing forgets every slime")
