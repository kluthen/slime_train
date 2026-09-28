extends GutTest
## LoopData: the loop as plain data for the simulation core. A loop is an
## ordered list of route segments. Each section has its outgoing segments and
## may have a return route, in use while that section's gate is closed.
## Opening the gate replaces the return route with the next section's
## segments, so the loop grows.
##
## The synthetic loop below has two sections on a 100 px grid:
##   s1 outgoing (0,0) -> (100,0), s1 return (100,0) -> (100,50) -> (0,50) -> (0,0)
##   s2 outgoing (100,0) -> (200,0), s2 return (200,0) -> (200,60) -> (0,60) -> (0,0)

# @test-link [[req_loop_and_world]]


func _two_sections() -> LoopData:
	var loop := LoopData.new("start.loop")
	loop.add_segment("s1.loop", 1, LoopData.OUTGOING,
			PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]))
	loop.add_segment("s1.slide", 1, LoopData.RETURN,
			PackedVector2Array([Vector2(100, 0), Vector2(100, 50), Vector2(0, 50), Vector2(0, 0)]), "s1.gate")
	loop.add_segment("s2.loop", 2, LoopData.OUTGOING,
			PackedVector2Array([Vector2(100, 0), Vector2(200, 0)]))
	loop.add_segment("s2.slide", 2, LoopData.RETURN,
			PackedVector2Array([Vector2(200, 0), Vector2(200, 60), Vector2(0, 60), Vector2(0, 0)]), "s2.gate")
	return loop


func _ids(segments: Array) -> PackedStringArray:
	var ids := PackedStringArray()
	for segment in segments:
		ids.append(segment["id"])
	return ids


func test_segments_keep_their_order_and_marks() -> void:
	var loop := _two_sections()
	assert_eq(_ids(loop.segments), PackedStringArray(["s1.loop", "s1.slide", "s2.loop", "s2.slide"]))
	var slide := loop.segment("s1.slide")
	assert_eq(slide["kind"], LoopData.RETURN)
	assert_eq(slide["section"], 1)
	assert_eq(slide["gate"], "s1.gate")
	assert_almost_eq(slide["length"], 200.0, 0.001)
	assert_eq(loop.segment("nope"), {})


func test_with_every_gate_closed_the_loop_is_section_1_and_its_return_route() -> void:
	var loop := _two_sections()
	assert_eq(_ids(loop.current_segments()), PackedStringArray(["s1.loop", "s1.slide"]))
	assert_almost_eq(loop.length(), 300.0, 0.001)


func test_opening_a_gate_grows_the_loop() -> void:
	var loop := _two_sections()
	var open := ["s1.gate"]
	assert_eq(_ids(loop.current_segments(open)), PackedStringArray(["s1.loop", "s2.loop", "s2.slide"]))
	assert_almost_eq(loop.length(open), 100.0 + 100.0 + 320.0, 0.001)


func test_the_last_return_route_stays_when_every_gate_is_open() -> void:
	# The last section's return route has a gate here; once it is open there
	# is nothing past it, so the route stays the end of the loop.
	var loop := _two_sections()
	var open := ["s1.gate", "s2.gate"]
	assert_eq(_ids(loop.current_segments(open)), PackedStringArray(["s1.loop", "s2.loop", "s2.slide"]))


func test_position_at_a_distance_along_the_loop() -> void:
	var loop := _two_sections()
	assert_eq(loop.position_at(0.0), Vector2(0, 0))
	assert_eq(loop.position_at(50.0), Vector2(50, 0))
	assert_eq(loop.position_at(125.0), Vector2(100, 25))
	assert_eq(loop.position_at(150.0), Vector2(100, 50))
	assert_eq(loop.position_at(250.0), Vector2(0, 50))


func test_position_wraps_round_the_loop() -> void:
	var loop := _two_sections()
	assert_eq(loop.position_at(310.0), Vector2(10, 0))
	assert_eq(loop.position_at(-10.0), Vector2(0, 10), "10 px before the start is the end of the return route")


func test_frontier_is_where_the_outgoing_part_ends() -> void:
	var loop := _two_sections()
	var frontier := loop.frontier()
	assert_eq(frontier["gate"], "s1.gate")
	assert_eq(frontier["section"], 1)
	assert_almost_eq(frontier["distance"], 100.0, 0.001)
	assert_eq(frontier["position"], Vector2(100, 0))
	var grown := loop.frontier(["s1.gate"])
	assert_eq(grown["gate"], "s2.gate")
	assert_eq(grown["section"], 2)
	assert_almost_eq(grown["distance"], 200.0, 0.001)


func test_closest_point_on_the_current_loop() -> void:
	var loop := _two_sections()
	var closest := loop.closest(Vector2(40, -10))
	assert_almost_eq(closest["distance"], 40.0, 0.001)
	assert_almost_eq(closest["gap"], 10.0, 0.001)
	assert_eq(closest["segment"], "s1.loop")
	assert_eq(closest["position"], Vector2(40, 0))


func test_gap_counts_every_segment_whatever_the_gates() -> void:
	# Placement checks (no sleeper on the loop) look at every segment, even
	# one not in use yet.
	var loop := _two_sections()
	assert_almost_eq(loop.gap(Vector2(150, -20)), 20.0, 0.001, "s2.loop, not in use yet, still counts")
	assert_almost_eq(loop.gap(Vector2(50, 55)), 5.0, 0.001)


func test_a_well_formed_loop_validates() -> void:
	assert_eq(_two_sections().validate(), PackedStringArray())


func test_validate_finds_a_break_in_the_loop() -> void:
	var loop := LoopData.new("start.loop")
	loop.add_segment("s1.loop", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]))
	loop.add_segment("s1.slide", 1, LoopData.RETURN,
			PackedVector2Array([Vector2(300, 0), Vector2(0, 0)]), "s1.gate")
	var errors := loop.validate()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "s1.slide")


func test_validate_finds_a_return_route_that_does_not_reach_the_start() -> void:
	var loop := LoopData.new("start.loop")
	loop.add_segment("s1.loop", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]))
	loop.add_segment("s1.slide", 1, LoopData.RETURN,
			PackedVector2Array([Vector2(100, 0), Vector2(100, 100)]), "s1.gate")
	var errors := loop.validate()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "start")


func test_validate_refuses_an_empty_loop_and_short_segments() -> void:
	assert_eq(LoopData.new("start.loop").validate().size(), 1)
	var loop := LoopData.new("start.loop")
	loop.add_segment("s1.loop", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(0, 0)]))
	assert_false(loop.validate().is_empty())


func test_round_trip_through_plain_data() -> void:
	var loop := _two_sections()
	var copy := LoopData.from_dict(loop.to_dict())
	assert_eq(copy.to_dict(), loop.to_dict())
	assert_eq(copy.position_at(125.0), Vector2(100, 25))
	assert_eq(StateHash.canonical_json(copy.to_dict()), StateHash.canonical_json(loop.to_dict()))
