extends GutTest
## The level scaffolding without a level scene: stable IDs, the registry a
## Level builds at load, and the shared rule format ("when this basket is
## full, open that gate").

# @test-link [[req_interactive_objects_general]]
# @test-link [[rule_released_level_stable_with_migration]]


func _level_with(children: Array) -> Level:
	var level := Level.new()
	level.level_id = "unit"
	level.level_version = 3
	level.add_child(_minimal_loop())
	for child in children:
		level.add_child(child)
	autofree(level)
	return level


## Every level needs a loop; this one is a single straight segment.
func _minimal_loop() -> Loop:
	var loop := Loop.new()
	loop.stable_id = "start.loop"
	var segment := LoopSegment.new()
	segment.stable_id = "s1.loop"
	segment.curve = Curve2D.new()
	segment.curve.add_point(Vector2(0, 0))
	segment.curve.add_point(Vector2(500, 0))
	loop.add_child(segment)
	return loop


func _sleeper(id: String, species := "A") -> Sleeper:
	var sleeper := Sleeper.new()
	sleeper.stable_id = id
	sleeper.species = species
	return sleeper


func _basket(id: String, target: String) -> Basket:
	var basket := Basket.new()
	basket.stable_id = id
	basket.quota = 6
	basket.on_full_object = target
	return basket


func _gate(id: String) -> Gate:
	var gate := Gate.new()
	gate.stable_id = id
	return gate


func test_stable_id_pattern() -> void:
	for good in ["start.split-zone", "start.first-slime", "s1.sleeper.01", "s1.sleeper.29",
			"s1.switch", "s1.route-back.tree", "s2.frame.parade", "s12.gate"]:
		assert_true(StableId.is_valid(good), good)
	for bad in ["", "s1", "S1.sleeper.01", "s1.Sleeper.01", "level.gate", "s1.sleeper.01.x",
			"s1 .gate", "s1.sleeper.1a b", "s1..gate", "s1.gate-", "-s1.gate", "s1.sleeper_01"]:
		assert_false(StableId.is_valid(bad), bad)


func test_registry_maps_every_stable_id_to_its_node() -> void:
	var gate := _gate("s1.gate")
	var sleeper := _sleeper("s1.sleeper.01")
	var level := _level_with([gate, sleeper])
	assert_eq(level.build(), PackedStringArray())
	assert_eq(level.find("s1.gate"), gate)
	assert_eq(level.find("s1.sleeper.01"), sleeper)
	assert_null(level.find("s1.sleeper.02"))
	assert_eq(level.ids(), PackedStringArray(["s1.gate", "s1.loop", "s1.sleeper.01", "start.loop"]))


func test_registry_finds_nested_components() -> void:
	var group := Node2D.new()
	var sleeper := _sleeper("s1.sleeper.07")
	group.add_child(sleeper)
	var level := _level_with([group])
	assert_eq(level.build(), PackedStringArray())
	assert_eq(level.find("s1.sleeper.07"), sleeper)


func test_registry_rejects_a_duplicate_id() -> void:
	var level := _level_with([_sleeper("s1.sleeper.01"), _sleeper("s1.sleeper.01", "B")])
	var errors := level.build()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "s1.sleeper.01")
	assert_string_contains(errors[0], "duplicate")
	assert_eq(level.load_errors, errors)


func test_registry_rejects_a_missing_or_malformed_id() -> void:
	var level := _level_with([_sleeper(""), _sleeper("S1.Sleeper")])
	var errors := level.build()
	assert_eq(errors.size(), 2)


func test_a_reference_to_an_unknown_id_is_an_error() -> void:
	var route_back := RouteBack.new()
	route_back.stable_id = "s1.route-back.tree"
	route_back.serves = "s1.branch.tree"
	var errors := _level_with([route_back]).build()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "s1.branch.tree")


func test_level_id_and_version_are_read() -> void:
	var level := _level_with([])
	assert_eq(level.build(), PackedStringArray())
	assert_eq(level.data.level_id, "unit")
	assert_eq(level.data.level_version, 3)
	assert_almost_eq(level.data.loop.length(), 500.0, 0.01)


func test_a_level_without_a_loop_is_an_error() -> void:
	var level := Level.new()
	level.level_id = "unit"
	autofree(level)
	var errors := level.build()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "loop")


func test_a_level_id_and_a_version_are_required() -> void:
	var level := _level_with([])
	level.level_id = ""
	level.level_version = 0
	assert_eq(level.build().size(), 2)


func test_rule_round_trips_the_shared_format() -> void:
	var text := {"when": {"object": "s1.basket", "event": "full"}, "then": {"object": "s1.gate", "action": "open"}}
	var rule := Rule.from_dict(text)
	assert_eq(rule.when_object, "s1.basket")
	assert_eq(rule.when_event, "full")
	assert_eq(rule.then_object, "s1.gate")
	assert_eq(rule.then_action, "open")
	assert_eq(rule.to_dict(), text)


func test_a_basket_holds_its_rule() -> void:
	var basket: Basket = autofree(_basket("s1.basket", "s1.gate"))
	var rules := basket.rules()
	assert_eq(rules.size(), 1)
	assert_eq(rules[0].to_dict(), {"when": {"object": "s1.basket", "event": "full"},
			"then": {"object": "s1.gate", "action": "open"}})


func test_rule_validates_against_the_registry() -> void:
	var level := _level_with([_basket("s1.basket", "s1.gate"), _gate("s1.gate")])
	assert_eq(level.build(), PackedStringArray())
	var rule := Rule.from_dict({"when": {"object": "s1.basket", "event": "full"},
			"then": {"object": "s1.gate", "action": "open"}})
	assert_eq(rule.validate(level.registry), PackedStringArray())


func test_rule_refuses_unknown_objects_events_and_actions() -> void:
	var level := _level_with([_basket("s1.basket", "s1.gate"), _gate("s1.gate")])
	level.build()
	var missing := Rule.from_dict({"when": {"object": "s1.basket", "event": "full"},
			"then": {"object": "s2.gate", "action": "open"}})
	assert_eq(missing.validate(level.registry).size(), 1)
	var bad_event := Rule.from_dict({"when": {"object": "s1.basket", "event": "empty"},
			"then": {"object": "s1.gate", "action": "open"}})
	assert_eq(bad_event.validate(level.registry).size(), 1)
	var bad_action := Rule.from_dict({"when": {"object": "s1.basket", "event": "full"},
			"then": {"object": "s1.gate", "action": "explode"}})
	assert_eq(bad_action.validate(level.registry).size(), 1)
	var not_a_trigger := Rule.from_dict({"when": {"object": "s1.gate", "event": "full"},
			"then": {"object": "s1.basket", "action": "open"}})
	assert_eq(not_a_trigger.validate(level.registry).size(), 2)


func test_a_basket_aimed_at_a_missing_gate_fails_the_load() -> void:
	var errors := _level_with([_basket("s1.basket", "s1.gate")]).build()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "s1.gate")


func test_rules_held_on_the_level_are_validated_too() -> void:
	var level := _level_with([_gate("s1.gate")])
	level.rules = [Rule.from_dict({"when": {"object": "s1.switch", "event": "full"},
			"then": {"object": "s1.gate", "action": "open"}})]
	var errors := level.build()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "s1.switch")
