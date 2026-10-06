extends SceneTree
func _initialize() -> void:
	var game: Node = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var fx := OS.get_environment("FX") if OS.get_environment("FX") != "" else "s3-basket-59of60"
	var parsed: Dictionary = load("res://src/test_mode/test_mode.gd").config_from_args(PackedStringArray(
			["--test-mode", "--level=test", "--fixture=" + fx, "--seed=1"]))
	game.enable_test_mode(parsed["config"])
	var sim: Simulation = game.simulation
	var train: Train = sim.train
	var bodies: SlimeBodies = sim.slimes
	var seen := {}
	var takeoff := {}
	var shown := 0
	var until := int(OS.get_environment("UNTIL")) if OS.get_environment("UNTIL") != "" else 11000
	for i in until:
		game.step_simulation()
		if sim.tick >= 9000 and fx == "s3-basket-59of60":
			sim.camera.position = Vector2(720, 361)
		for id: int in train.last_hops:
			var h: Dictionary = train.last_hops[id]
			if h["kind"] != Train.TARGET_OVER:
				continue
			if h["landed"] < 0 and not takeoff.has(id):
				takeoff[id] = [bodies.centre_of(id), bodies.velocity_of(id), h["tick"]]
			if h["landed"] >= 0 and seen.get(id, -1) != h["landed"] and takeoff.has(id):
				seen[id] = h["landed"]
				var t0: Array = takeoff[id]
				takeoff.erase(id)
				if shown < 25:
					shown += 1
					print("OVER id=%d t=%d from=%s v=%s target=%s land=%s at=%d adv=%.1f" % [id, t0[2], t0[0], t0[1], h["target"], bodies.centre_of(id), h["landed"], h["advance"]])
	quit(0)
