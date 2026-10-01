extends SceneTree
## Throwaway probe (22e, back-of-queue question). Loads a fixture in test
## mode (seed 1) and steps it TICKS ticks with Simulation.step() replicated
## (same calls, same order) so that, right before train.steer(), every train
## slime whose hop decision is made this tick is recorded: what _blocked sees
## (crowd count split, jam), its queue position; after the step, the outcome.
## One CSV line per decision to --out. --plain: game.step_simulation() only
## (to check the replicated step gives the same hops).
## godot --headless --path <repo> -s queue_probe.gd -- --fixture=stress-moving --ticks=2400 --out=<csv>

var fixture := "stress-moving"
var ticks := 2400
var plain := false
var out_path := ""
const QUEUE_RANGE := 300.0
## Beyond this forward loop distance (reach 150 + radius 240 + slack) a
## counted train slime is on another part of the loop, not the queue ahead.
const FAR_RANGE := 450.0


## The decisions made this tick (before steer): one dictionary each.
func _decisions(sim: Simulation) -> Array:
	var b: SlimeBodies = sim.slimes
	var train: Train = sim.train
	var dt := Simulation.TICK_SECONDS
	var tick := sim.tick
	var length := train.length()
	var out := []
	var tracked := train.tracked_ids()
	for slime_id in tracked:
		var s := b.index_of(slime_id)
		if s < 0 or b.state[s] != SlimeBodies.TRAIN or b.calm[s] == SlimeBodies.PARKED:
			continue
		var from := b.centre_of(slime_id)
		var progress := train.steering_distance(train.distance_of(slime_id), from)
		if train.is_slide_at(progress):
			continue
		var holding := train.is_holding(slime_id)
		var elapsed := -1
		if holding:
			elapsed = tick - train.hold_began_at(slime_id)
			if elapsed < Train.HOLD_CAP_TICKS and (elapsed <= 0 or elapsed % Train.HOLD_RECHECK_TICKS != 0):
				continue
		else:
			if b.hop_timer[s] > dt * 1.5 or b.supported[s] == 0:
				continue
		var target := train.hop_target(progress, Train.hop_reach(b.size[s]))
		var count := b.awake_count_ahead(target, Train.HOLD_CROWD_RADIUS, from, slime_id)
		var jam: bool = train._jammed(b, slime_id, progress)
		# Split the counted slimes, as awake_count_ahead counts them.
		var n_hold := 0; var n_train := 0; var n_other := 0; var n_behind := 0; var n_far := 0
		var dist_sum := 0.0
		var forward := target - from
		for o in b.slime_count:
			if b.calm[o] != SlimeBodies.ACTIVE or b.state[o] == SlimeBodies.STATE_SLEEPER or b.state[o] == SlimeBodies.STATE_IN_BASKET:
				continue
			var oid := b.id[o]
			if oid == slime_id:
				continue
			var c := b.centre_of(oid)
			if c.distance_squared_to(target) >= Train.HOLD_CROWD_RADIUS * Train.HOLD_CROWD_RADIUS or (c - from).dot(forward) <= 0.0:
				continue
			dist_sum += c.distance_to(target)
			if b.state[o] == SlimeBodies.TRAIN and train.tracks(oid):
				if train.is_holding(oid):
					n_hold += 1
				else:
					n_train += 1
				var fwd := fposmod(train.distance_of(oid) - progress, length)
				if fwd > length * 0.5:
					n_behind += 1
				elif fwd > FAR_RANGE:
					n_far += 1
			else:
				n_other += 1
		# Queue position: train slimes ahead along the loop within QUEUE_RANGE.
		var ahead := 0
		for other in tracked:
			if other == slime_id or b.state_of(other) != SlimeBodies.TRAIN:
				continue
			var d := fposmod(train.distance_of(other) - progress, length)
			if d > 0.0 and d <= QUEUE_RANGE:
				ahead += 1
		out.append({"id": slime_id, "tick": tick, "holding": holding, "elapsed": elapsed,
				"began": train.hold_began_at(slime_id), "count": count, "jam": jam,
				"blocked": count > Train.HOLD_CROWD or jam, "hold": n_hold, "train": n_train,
				"other": n_other, "behind": n_behind, "far": n_far,
				"mean_dist": dist_sum / maxf(count, 1), "ahead": ahead,
				"resting": b.calm[s] == SlimeBodies.RESTING, "size": b.size[s]})
	return out


## The outcome of decision `d` after the step.
func _outcome(sim: Simulation, d: Dictionary) -> String:
	var train: Train = sim.train
	var slime_id: int = d["id"]
	var now_holding := train.is_holding(slime_id)
	var hopped := sim.slimes.train_hopped.has(slime_id)
	if not d["holding"]:
		if now_holding:
			return "start"
		return "hop" if hopped else "nohop_nohold"
	if now_holding and train.hold_began_at(slime_id) == d["began"]:
		return "still"
	if now_holding:
		return "restarted"
	if d["elapsed"] >= Train.HOLD_CAP_TICKS:
		return "end_cap" if hopped else "end_cap_nohop"
	return "end_pass" if hopped else "end_pass_nohop"


## Simulation.step(), replicated, with the decisions recorded before steer.
func _probed_step(game: Node, f: FileAccess) -> void:
	var sim: Simulation = game.simulation
	game.sync_view()
	sim.session.read_clock(game.test_mode.clock_at(sim.tick))
	for event in game.test_mode.inputs_for_tick(sim.tick):
		sim.push_input(event)
	for event in sim._pending_input:
		sim._apply_input(event)
	sim._pending_input.clear()
	sim.session.advance(sim)
	sim.offscreen.step(sim)
	var decisions := _decisions(sim)
	var gates: Array = sim.train.open_gates if sim.train != null else []
	if sim.train != null:
		sim.train.steer(sim.slimes, Simulation.TICK_SECONDS, sim.tick, sim.fusion)
	sim.free_slimes.steer(sim.slimes, Simulation.TICK_SECONDS, sim.level, gates)
	sim.slimes.free_down = sim.phone_tilt.down()
	sim.slimes.tick(Simulation.TICK_SECONDS)
	Sleepers.wake(sim)
	sim.free_slimes.paced(sim.slimes)
	sim._face_hops()
	for p in sim.split_zones.apply(sim.slimes):
		sim.identities.split(p)
		if sim.train != null:
			sim.train.inherit(p)
		sim.free_slimes.inherit(p, sim.tick)
	sim.fusion.step(sim)
	sim.frontier.step(sim)
	gates = sim.train.open_gates if sim.train != null else []
	sim.free_slimes.follow(sim.slimes, sim.tick, sim.level, gates)
	if sim.train != null:
		sim.train.follow(sim.slimes, sim.tick)
	for d in decisions:
		var o := _outcome(sim, d)
		f.store_line("%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.1f,%d,%d,%d,%s" % [d["tick"], d["id"], int(d["holding"]),
				d["elapsed"], d["count"], int(d["jam"]), int(d["blocked"]), d["hold"], d["train"], d["other"],
				d["behind"], d["mean_dist"], d["ahead"], int(d["resting"]), d["far"], o])
	sim.stuck_slimes.step(sim)
	sim.camera.watch(sim.slimes, not sim.fingers_down.is_empty(), sim.screensaver, sim.session.phase == Session.BEDTIME)
	for gate_id in sim.frontier.gates_fired_open(sim):
		sim.camera.show_gate(sim.level.gates[gate_id]["box"], sim.view, sim.level.loop, gates, sim.tick)
	sim.camera.step(sim.level.loop if sim.level != null else null, gates, Simulation.TICK_SECONDS, sim.tick)
	sim._tidy()
	sim.tick += 1
	sim.hint.update(sim.tick)
	assert(not sim.session.save_due)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var p := arg.trim_prefix("--").split("=", true, 1)
		if p[0] == "fixture": fixture = p[1]
		if p[0] == "ticks": ticks = int(p[1])
		if p[0] == "plain": plain = true
		if p[0] == "out": out_path = p[1]
	var game: Node = load("res://src/main.tscn").instantiate()
	game.save_store = null
	root.add_child(game)
	await process_frame
	var errs = game.enable_test_mode({"seed": 1, "time_scale": 0, "fixture": fixture})
	if not errs.is_empty():
		print("ERR ", errs)
		quit(1)
		return
	var sim: Simulation = game.simulation
	print("fixture=%s tick0=%d slimes=%d consts=(%d, %.0f, %.0f) plain=%s loop_len=%.0f" % [fixture, sim.tick,
			sim.slimes.slime_count, Train.HOLD_CROWD, Train.HOLD_CROWD_RADIUS, Train.JAM_GAP, plain, sim.train.length()])
	var f: FileAccess = null
	if not plain:
		f = FileAccess.open(out_path, FileAccess.WRITE)
		f.store_line("tick,id,holding,elapsed,count,jam,blocked,n_hold,n_train,n_other,n_behind,mean_dist,ahead,resting,n_far,outcome")
	for t in ticks:
		if plain:
			game.step_simulation()
		else:
			_probed_step(game, f)
	if f != null:
		f.close()
	print("RESULT tick=%d hops=%d short=%d hash=%s" % [sim.tick, sim.train.hops_taken, sim.train.short_hops_taken,
			sim.state_hash()])
	quit(0)
