extends SceneTree
## One-off diagnostic (chunk 22g, report only): who takes the stall and stuck
## moves in a fixture run. Steps the game's own step (game.step_simulation())
## and, for every slime moved to the start by the stall net (Train.stalled,
## reason STALLED) or the stuck net (StuckSlimes.stuck, moved), prints the
## slime's state on the tick before the move: state, species, size, loop
## distance, held / calm / supported, holding, nearest basket and its gap,
## in the bowl (loop distance 14000..18000, as thru.gd). Forwards
## --loop-buckets / --loop-bucket-length=PX like the 22f probes.
## godot --headless --path . -s docs/perf/2026-10-01-chunk-22g/stall_diag.gd -- --fixture=s3-basket-59of60 --seed=1 --ticks=10000

var fixture := "s3-basket-59of60"
var seed_n := 1
var ticks := 10000
const BOWL_LO := 14000.0
const BOWL_HI := 18000.0
const STATE_NAMES := ["sleeper", "train", "free", "asleep", "basket"]
const CALM_NAMES := ["active", "resting", "parked"]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var p := arg.trim_prefix("--").split("=", true, 1)
		if p[0] == "fixture": fixture = p[1]
		if p[0] == "seed": seed_n = int(p[1])
		if p[0] == "ticks": ticks = int(p[1])
	var game: Node = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var bucket_errs: PackedStringArray = game.use_loop_buckets(OS.get_cmdline_user_args())
	if not bucket_errs.is_empty():
		print("ERR ", bucket_errs)
		quit(1)
		return
	var errs = game.enable_test_mode({"seed": seed_n, "fixture": fixture})
	if not errs.is_empty():
		print("ERR ", errs)
		quit(1)
		return
	var sim: Simulation = game.simulation
	var train: Train = sim.train
	var bodies: SlimeBodies = sim.slimes
	print("DIAG fixture=%s seed=%d tick0=%d slimes=%d loop_len=%.0f" % [fixture, seed_n, sim.tick, bodies.slime_count,
			train.length()])
	var basket_ids := sim.level.baskets.keys()
	basket_ids.sort()
	for id in basket_ids:
		var box: Rect2 = sim.level.baskets[id]["box"]
		var d := train.project(0.0, box.get_center())
		print("BASKET %s box=%s quota=%s loop_d~%.0f" % [id, box, sim.level.baskets[id]["quota"], d])
	print("EV kind,tick,id,state,species,size,dist,laps,held,calm,supported,holding,x,y,basket,gap,bowl,other,o_state,o_size,o_dist")
	for i in ticks:
		var snap := {}
		var ids := bodies.ids()
		for s in ids.size():
			snap[ids[s]] = _row(sim, ids[s], bodies.index_of(ids[s]))
		var t := sim.tick
		game.step_simulation()
		for e in train.stalled:
			if e["tick"] == t and e["reason"] == Train.STALLED:
				print("EV stall,%d,%d,%s" % [t, e["id"], snap.get(e["id"], "?")])
		for e in sim.stuck_slimes.stuck:
			if e["tick"] == t and e["moved"]:
				var o := str(snap.get(e["other"], "?,?,?,?,?")).split(",")
				print("EV stuck,%d,%d,%s,%d,%s,%s,%s" % [t, e["id"], snap.get(e["id"], "?"), e["other"], o[0], o[2],
						o[3]])
	print("STATE tick=%d hash=%s" % [sim.tick, sim.state_hash()])
	quit(0)


func _row(sim: Simulation, id: int, s: int) -> String:
	var b := sim.slimes
	var train := sim.train
	var c: Vector2 = b.centre_of(id)
	var tracked := train.tracks(id)
	var dist := train.distance_of(id) if tracked else -1.0
	var best := ""
	var best_gap := INF
	for bid in sim.level.baskets:
		var box: Rect2 = sim.level.baskets[bid]["box"]
		var gap := 0.0 if box.has_point(c) else (box.get_center() - c).length()
		if gap < best_gap:
			best_gap = gap
			best = bid
	return "%s,%d,%d,%.0f,%d,%d,%s,%d,%d,%.0f,%.0f,%s,%.0f,%d" % [STATE_NAMES[b.state[s]], b.species[s], b.size[s], dist,
			train.laps_of(id) if tracked else -1, b.held[s], CALM_NAMES[b.calm[s]], b.supported[s],
			int(tracked and train.is_holding(id)), c.x, c.y, best, best_gap,
			int(dist >= BOWL_LO and dist <= BOWL_HI)]
