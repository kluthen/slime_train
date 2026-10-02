extends GutTest
## LoopBuckets (src/sim/loop_buckets.gd): the loop cut into fixed-length
## logical buckets, used to order the train slimes front-first (the highest
## bucket first, down to bucket 0; ascending id inside a bucket). Order only:
## the buckets never move, hold or place a slime.
##
## The synthetic loop: 1000 px cut into 300 px buckets, so 4 buckets
## ([0, 300), [300, 600), [600, 900), [900, 1000]); the last one is short.

# @test-link [[req_hopping_behavior]]

const LOOP := 1000.0
const BUCKET := 300.0


func _buckets() -> LoopBuckets:
	var buckets := LoopBuckets.new()
	buckets.configure(LOOP, BUCKET)
	return buckets


func test_the_bucket_count_rounds_up() -> void:
	assert_eq(_buckets().count(), 4, "ceil(1000 / 300)")
	var exact := LoopBuckets.new()
	exact.configure(900.0, BUCKET)
	assert_eq(exact.count(), 3, "an exact multiple adds no empty bucket")
	var short := LoopBuckets.new()
	short.configure(100.0, BUCKET)
	assert_eq(short.count(), 1, "a loop shorter than a bucket is one bucket")


func test_the_default_bucket_length() -> void:
	assert_eq(LoopBuckets.DEFAULT_BUCKET_LENGTH, 300.0)


func test_a_distance_falls_in_its_bucket() -> void:
	var buckets := _buckets()
	assert_eq(buckets.bucket_index(0.0), 0)
	assert_eq(buckets.bucket_index(299.9), 0)
	assert_eq(buckets.bucket_index(300.0), 1)
	assert_eq(buckets.bucket_index(650.0), 2)
	assert_eq(buckets.bucket_index(900.0), 3)
	assert_eq(buckets.bucket_index(999.9), 3)


func test_a_distance_outside_the_loop_is_clamped() -> void:
	var buckets := _buckets()
	assert_eq(buckets.bucket_index(LOOP), 3, "the loop's end is in the last bucket")
	assert_eq(buckets.bucket_index(LOOP + 0.5), 3, "slightly past the end")
	assert_eq(buckets.bucket_index(5000.0), 3)
	assert_eq(buckets.bucket_index(-0.5), 0, "slightly before the start")


func test_place_adds_a_slime() -> void:
	var buckets := _buckets()
	assert_false(buckets.has(7))
	assert_eq(buckets.bucket_of(7), -1, "absent")
	assert_true(buckets.place(7, 120.0), "added")
	assert_true(buckets.has(7))
	assert_eq(buckets.bucket_of(7), 0)
	assert_eq(buckets.size(), 1)


func test_place_moves_a_slime_only_when_its_bucket_changes() -> void:
	var buckets := _buckets()
	buckets.place(7, 120.0)
	assert_false(buckets.place(7, 250.0), "same bucket: not moved")
	assert_eq(buckets.bucket_of(7), 0)
	assert_true(buckets.place(7, 310.0), "into the next bucket: moved")
	assert_eq(buckets.bucket_of(7), 1)
	assert_true(buckets.place(7, 950.0), "on to the last bucket")
	assert_eq(buckets.bucket_of(7), 3)
	assert_eq(buckets.size(), 1, "a move never duplicates")
	assert_eq(buckets.order(), PackedInt32Array([7]))


func test_order_is_front_first_then_ascending_id() -> void:
	var buckets := _buckets()
	# Inserted in a scrambled order on purpose.
	buckets.place(9, 50.0)
	buckets.place(4, 650.0)
	buckets.place(12, 950.0)
	buckets.place(2, 100.0)
	buckets.place(8, 610.0)
	buckets.place(3, 990.0)
	buckets.place(1, 899.0)
	assert_eq(buckets.order(), PackedInt32Array([3, 12, 1, 4, 8, 2, 9]),
			"bucket 3, then 2, then 0 (1 is empty); ascending id within each")


func test_order_follows_a_move() -> void:
	var buckets := _buckets()
	buckets.place(5, 100.0)
	buckets.place(2, 400.0)
	assert_eq(buckets.order(), PackedInt32Array([2, 5]))
	buckets.place(5, 450.0)
	assert_eq(buckets.order(), PackedInt32Array([2, 5]), "same bucket now: ascending id")
	buckets.place(5, 700.0)
	assert_eq(buckets.order(), PackedInt32Array([5, 2]), "5 now ahead")


func test_remove() -> void:
	var buckets := _buckets()
	buckets.place(1, 100.0)
	buckets.place(2, 100.0)
	buckets.place(3, 700.0)
	assert_true(buckets.drop(2))
	assert_false(buckets.has(2))
	assert_eq(buckets.bucket_of(2), -1)
	assert_eq(buckets.size(), 2)
	assert_eq(buckets.order(), PackedInt32Array([3, 1]))
	assert_false(buckets.drop(2), "already gone")
	assert_true(buckets.place(2, 800.0), "added again after a remove")
	assert_eq(buckets.order(), PackedInt32Array([2, 3, 1]))


func test_clear() -> void:
	var buckets := _buckets()
	buckets.place(1, 100.0)
	buckets.place(2, 700.0)
	buckets.clear()
	assert_eq(buckets.size(), 0)
	assert_false(buckets.has(1))
	assert_eq(buckets.order(), PackedInt32Array())
	assert_eq(buckets.count(), 4, "the cut is kept")


func test_reconfigure_on_loop_growth_clears_and_replacing_orders_again() -> void:
	var buckets := _buckets()
	buckets.place(1, 950.0)
	buckets.place(2, 100.0)
	# A gate opens: the loop grows from 1000 to 1600 px, 6 buckets.
	assert_true(buckets.configure(1600.0, BUCKET), "the cut changed: cleared")
	assert_eq(buckets.count(), 6)
	assert_eq(buckets.size(), 0)
	assert_eq(buckets.order(), PackedInt32Array())
	# The caller re-places every slime at its distance on the new loop.
	buckets.place(1, 950.0)
	buckets.place(2, 100.0)
	buckets.place(3, 1550.0)
	assert_eq(buckets.bucket_of(3), 5)
	assert_eq(buckets.order(), PackedInt32Array([3, 1, 2]))


func test_reconfigure_keeps_membership_when_the_cut_is_unchanged() -> void:
	var buckets := _buckets()
	buckets.place(1, 950.0)
	assert_false(buckets.configure(LOOP, BUCKET), "same cut")
	assert_eq(buckets.size(), 1)
	assert_true(buckets.configure(LOOP, 250.0), "a new bucket length")
	assert_eq(buckets.size(), 0)


func test_boundaries() -> void:
	assert_eq(_buckets().boundaries(), PackedFloat32Array([300.0, 600.0, 900.0]))
	var exact := LoopBuckets.new()
	exact.configure(900.0, BUCKET)
	assert_eq(exact.boundaries(), PackedFloat32Array([300.0, 600.0]),
			"no boundary at the loop's end")
	var short := LoopBuckets.new()
	short.configure(100.0, BUCKET)
	assert_eq(short.boundaries(), PackedFloat32Array(), "one bucket, no boundary")


func test_the_order_does_not_depend_on_insertion_order() -> void:
	var placements := [[11, 20.0], [3, 640.0], [7, 980.0], [1, 20.0], [5, 640.0],
			[9, 310.0], [2, 999.0], [6, 590.0], [4, 0.0], [8, 900.0]]
	var forward := _buckets()
	for p: Array in placements:
		forward.place(p[0], p[1])
	var backward := _buckets()
	for i in range(placements.size() - 1, -1, -1):
		backward.place(placements[i][0], placements[i][1])
	# And a third one that reaches the same places through moves.
	var moved := _buckets()
	for p: Array in placements:
		moved.place(p[0], 0.0)
	for p: Array in placements:
		moved.place(p[0], p[1])
	var expected := PackedInt32Array([2, 7, 8, 3, 5, 6, 9, 1, 4, 11])
	assert_eq(forward.order(), expected)
	assert_eq(backward.order(), expected)
	assert_eq(moved.order(), expected)
