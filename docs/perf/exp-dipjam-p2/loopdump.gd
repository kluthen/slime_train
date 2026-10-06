extends SceneTree
func _initialize() -> void:
	var game: Node = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var parsed: Dictionary = load("res://src/test_mode/test_mode.gd").config_from_args(PackedStringArray(
			["--test-mode", "--level=test", "--fixture=s3-basket-59of60", "--seed=1"]))
	game.enable_test_mode(parsed["config"])
	var train: Train = game.simulation.train
	print("len=", train.length(), " out=", train.outgoing_length())
	var d := 0.0
	var run_from := -1.0
	while d < train.length():
		var dir := train.direction_at(d)
		var rise := -dir.y / maxf(absf(dir.x), 0.001)
		var p := train.position_at(d)
		print("d=%d x=%d y=%d rise=%.2f slide=%s" % [d, p.x, p.y, rise, train.is_slide_at(d)])
		d += 40.0
	quit(0)
