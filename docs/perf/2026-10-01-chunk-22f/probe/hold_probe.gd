extends SceneTree
## Diagnostic probe (chunk 22f, D147 (4)): what the hold's checks see at each
## hop decision. Written in step 2 under 22e's rules; since step 3 the hold
## runs the hop corridor (TrainHold.check: the occupancy and the holder rule,
## the `occ`, `n_corr`, `holder_corr`, `crowd_corr` columns and the outcome's
## cause come from it), and 22e's 240 px disc and jam check, gone from the
## game, are computed here (DISC_RADIUS, DISC_CROWD, JAM_GAP: the `count`,
## `crowded`, `jam` and disc columns) for comparison. Not game code: read
## only, it never changes the simulation (its final state hash must equal a
## plain --run-ticks run's).
##
## It loads a fixture in test mode and steps it with Simulation.step()
## replicated, call for call, with Train.steer()'s loop replicated too (its
## start of the tick's holder snapshot, TrainHold.begin_tick, included), so
## each train slime's decision is read in the exact state its own steer sees
## (the slimes before it in id order already steered). A decision is a due
## train slime standing on something (not holding, hop timer <= 1.5 ticks),
## or a holder at one of its checks (since 22f step 4, TrainHold.check_at: a
## re-check from its phase, or its period's end; the `check` column). The
## hold guard (TrainHold.guard) runs right after the snapshot, as in
## Train.steer: a slime it releases has a due row with `guard` 1. One CSV
## row per decision. The totals add the guard's releases ([tick, id]) and
## the period-end checks (how many, and how many held on).
## Every 120 ticks it samples the Train's hold snapshot, the Physics count and
## the largest awake cluster; at the end it writes the Train's counters.
##
## godot --headless --path <repo> -s docs/perf/2026-10-01-chunk-22f/probe/hold_probe.gd -- \
##     --fixture=stress-moving --seed=1 --ticks=2400 --out=<base>.csv
## writes <base>.csv, <base>-snap.csv, <base>-totals.json; prints the hash.
## --plain: game.step_simulation() only, no rows (the hash reference).

var fixture := "stress-moving"
var seed_value := 1
var ticks := 2400
var plain := false
var out_path := ""
## Queue position: train slimes ahead along the loop within this, px (22e's).
const QUEUE_RANGE := 300.0
## 22e's crowd check and jam check (gone from the game in 22f step 3),
## replicated: more than DISC_CROWD awake slimes within DISC_RADIUS of the
## hop's target, ahead of the slime; a hop within the two radii plus JAM_GAP
## of the rearmost holder ahead along the loop.
const DISC_RADIUS := 240.0
const DISC_CROWD := 30
const JAM_GAP := 24.0
## Snapshot period, ticks.
const SNAP_EVERY := 120
## check_at()'s answers, by name (the `check` column).
const CHECK_NAMES := ["", "recheck", "period_end"]

## This tick's touching queues: slime id -> [position from the front, size].
var _queue_of := {}
var _queues_built := false
## This tick's ids with a decision row, for the hops not covered.
var _decided := {}
var uncovered_hops := 0
## The holder the hold guard released this tick, -1 for none; every release
## as [tick, id]; the period-end checks and those that held on.
var _released_now := -1
var guard_log := []
var period_end_checks := 0
var period_end_held_on := 0

## Diagnostic 2 (who blocks whom, who hops, who keeps the guard off). Files
## next to the csv: -blocks.csv (one row per responsible holder of a
## holder-rule failure), -graph.csv (every SNAP_EVERY ticks, each holder
## with its last check's cause and responsible holders), -ends.csv (every
## hold end with its cause), -hops.csv (every train hop with its kind),
## -load.csv (every SNAP_EVERY ticks, the loop's load). The guard window's
## aggregates go in the totals ("guard_window").
## Recency window for a slime's last origin event (hops, blockers), ticks.
const RECENT := 600
## The guard window: ticks from GUARD_FROM on.
const GUARD_FROM := 1200
var _blocks: FileAccess
var _graph: FileAccess
var _ends: FileAccess
var _hops: FileAccess
var _load: FileAccess
## Holder id -> its last failed check's bits; -> its responsible holders.
var _last_cause := {}
var _last_resp := {}
## Slime id -> [tick, kind]: its latest origin event (end:<cause>, unpark,
## join, split); ids that ever held; this tick's split parts.
var _events := {}
var _ever_held := {}
var _split_now := {}
var _prev_parked := {}
var _prev_tracked := {}
## Guard window aggregates.
var _gw := {"ticks": 0, "no_blockers": 0, "age_ok": 0, "both": 0, "blockers_sum": 0, "air_sum": 0,
		"ground_sum": 0, "kind_ticks": {}, "age_sum": 0}
var _blocker_ticks := {}
## Every followed slime's progress (laps included) at GUARD_FROM.
var _progress_at_from := {}
var _window_hops := {}


## Parses the arguments, runs, writes, quits.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var p := arg.trim_prefix("--").split("=", true, 1)
		match p[0]:
			"fixture": fixture = p[1]
			"seed": seed_value = int(p[1])
			"ticks": ticks = int(p[1])
			"plain": plain = true
			"out": out_path = p[1]
	var game: Node = load("res://src/main.tscn").instantiate()
	game.save_store = null
	root.add_child(game)
	await process_frame
	# The same run configuration as `-- --test-mode --fixture=X --seed=N`.
	var errs = game.enable_test_mode({"seed": seed_value, "fixture": fixture})
	if not errs.is_empty():
		print("ERR ", errs)
		quit(1)
		return
	var sim: Simulation = game.simulation
	print("fixture=%s seed=%d tick0=%d slimes=%d loop_len=%.0f plain=%s" % [fixture, seed_value, sim.tick,
			sim.slimes.slime_count, sim.train.length(), plain])
	var base := out_path.trim_suffix(".csv")
	var f: FileAccess = null
	var snap: FileAccess = null
	if not plain:
		f = FileAccess.open(out_path, FileAccess.WRITE)
		f.store_line(",".join(COLUMNS))
		snap = FileAccess.open(base + "-snap.csv", FileAccess.WRITE)
		snap.store_line("tick,holding,holding_resting,contact_resting,queue_back,queue_back_held,physics,cluster")
		_blocks = FileAccess.open(base + "-blocks.csv", FileAccess.WRITE)
		_blocks.store_line("tick,checker,c_holding,check,c_front,c_qsize,occ,holder,gap,euclid,along,h_cause,h_resting,h_front")
		_graph = FileAccess.open(base + "-graph.csv", FileAccess.WRITE)
		_graph.store_line("tick,id,dist,cause,resting,front,began,resp")
		_ends = FileAccess.open(base + "-ends.csv", FileAccess.WRITE)
		_ends.store_line("tick,id,began,cause")
		_hops = FileAccess.open(base + "-hops.csv", FileAccess.WRITE)
		_hops.store_line("tick,id,kind,decided,front,occ,n_corr,stack_only,gap_holder_ahead")
		_load = FileAccess.open(base + "-load.csv", FileAccess.WRITE)
		_load.store_line("tick,loop_len,n_sim,n_parked,n_other_state,diam_sim,diam_all,coverage_sim,holders,blockers," +
				"front_holder,ahead_of_front,far_ahead,pinned")
		for slime_id in sim.train.tracked_ids():
			_prev_tracked[slime_id] = true
			if sim.slimes.calm_of(slime_id) == SlimeBodies.PARKED:
				_prev_parked[slime_id] = true
	for t in ticks:
		if plain:
			game.step_simulation()
		else:
			_probed_step(game, f)
			if sim.tick % SNAP_EVERY == 0:
				_snapshot(sim, snap)
				_graph_rows(sim)
				_load_row(sim)
	var train: Train = sim.train
	var totals := {"fixture": fixture, "seed": seed_value, "ticks": sim.tick, "hops": train.hops_taken,
			"short_hops": train.short_hops_taken, "stalled": train.stalled.size(),
			"uncovered_hops": uncovered_hops, "guard_log": guard_log, "period_end_checks": period_end_checks,
			"period_end_held_on": period_end_held_on, "hash": sim.state_hash()}
	totals.merge(train.hold_counters())
	if f != null:
		f.close()
		snap.close()
		for file: FileAccess in [_blocks, _graph, _ends, _hops, _load]:
			file.close()
		var top := []
		for slime_id: int in _blocker_ticks:
			var entry := [slime_id, _blocker_ticks[slime_id], _window_hops.get(slime_id, 0),
					int(_ever_held.has(slime_id)), _kind(slime_id, sim.tick)]
			var s := sim.slimes.index_of(slime_id)
			if s >= 0 and train.tracks(slime_id):
				# The blocker's state at the end: distance, progress since GUARD_FROM, supported,
				# hop timer, held, calm, on a slide, size, speed.
				entry.append_array([snappedf(train.distance_of(slime_id), 0.1),
						snappedf(train.progress_of(slime_id) - float(_progress_at_from.get(slime_id, NAN)), 0.1),
						sim.slimes.supported[s], snappedf(sim.slimes.hop_timer[s], 0.001), sim.slimes.held[s],
						sim.slimes.calm[s], train._records[slime_id]["on_slide"], sim.slimes.size[s],
						snappedf(sim.slimes.velocity_of(slime_id).length(), 0.1),
						snappedf(rad_to_deg(train.direction_at(train.distance_of(slime_id)).angle()), 1.0)])
			top.append(entry)
		top.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
		_gw["top_blockers"] = top.slice(0, 15)
		_gw["distinct_blockers"] = top.size()
		totals["guard_window"] = _gw
		var tf := FileAccess.open(base + "-totals.json", FileAccess.WRITE)
		tf.store_string(JSON.stringify(totals, "  "))
		tf.close()
	print("TOTALS ", JSON.stringify(totals))
	print("RESULT tick=%d hash=%s" % [sim.tick, sim.state_hash()])
	quit(0)


const COLUMNS := ["tick", "id", "size", "holding", "elapsed", "ahead", "qpos", "qsize", "front", "count",
		"crowded", "jam", "n_train", "n_hold", "n_other", "n_behind", "n_missed", "n_rest", "n_rest_hold",
		"n_rest_loop", "count_rest", "count_loop", "count_all_loop", "occ", "occ_hold", "occ_rest", "n_corr", "holder_corr",
		"holder_stack_only", "crowd_corr", "check", "guard", "outcome", "hopped"]


## Simulation.step(), replicated (same calls, same order), Train.steer()
## replaced by _probed_steer(); the decisions' outcomes written after it.
func _probed_step(game: Node, f: FileAccess) -> void:
	var sim: Simulation = game.simulation
	var held_before := {}
	if sim.train != null:
		for slime_id: int in sim.train._records:
			if sim.train._records[slime_id].has("hold"):
				held_before[slime_id] = sim.train._records[slime_id]["hold"]
	_split_now.clear()
	game.sync_view()
	sim.session.read_clock(game.test_mode.clock_at(sim.tick))
	for event in game.test_mode.inputs_for_tick(sim.tick):
		sim.push_input(event)
	for event in sim._pending_input:
		sim._apply_input(event)
	sim._pending_input.clear()
	sim.session.advance(sim)
	sim.offscreen.step(sim)
	var gates: Array = sim.train.open_gates if sim.train != null else []
	var decisions := []
	if sim.train != null:
		decisions = _probed_steer(sim)
	sim.free_slimes.steer(sim.slimes, Simulation.TICK_SECONDS, sim.level, gates)
	sim.slimes.free_down = sim.phone_tilt.down()
	sim.slimes.tick(Simulation.TICK_SECONDS)
	Sleepers.wake(sim)
	sim.free_slimes.paced(sim.slimes)
	sim._face_hops()
	for parts in sim.split_zones.apply(sim.slimes):
		sim.identities.split(parts)
		for k in range(1, parts.size()):
			_split_now[parts[k]] = true
		if sim.train != null:
			sim.train.inherit(parts, sim.slimes)
		sim.free_slimes.inherit(parts, sim.tick)
	sim.fusion.step(sim)
	sim.frontier.step(sim)
	gates = sim.train.open_gates if sim.train != null else []
	sim.free_slimes.follow(sim.slimes, sim.tick, sim.level, gates)
	if sim.train != null:
		for slime_id in sim.slimes.train_hopped:
			if not _decided.has(slime_id):
				uncovered_hops += 1
		sim.train.follow(sim.slimes, sim.tick)
	for d in decisions:
		_write(f, d, sim)
	sim.stuck_slimes.step(sim)
	sim.camera.watch(sim.slimes, not sim.fingers_down.is_empty(), sim.screensaver,
			sim.session.phase == Session.BEDTIME)
	for gate_id in sim.frontier.gates_fired_open(sim):
		sim.camera.show_gate(sim.level.gates[gate_id]["box"], sim.view, sim.level.loop, gates, sim.tick)
	sim.camera.step(sim.level.loop if sim.level != null else null, gates, Simulation.TICK_SECONDS, sim.tick)
	sim._tidy()
	if sim.train != null:
		_bookkeep(sim, held_before, decisions)
	sim.tick += 1
	sim.hint.update(sim.tick)
	assert(not sim.session.save_due)


## Train.steer(), replicated line for line, each decision read right before
## its slime's _steer_one(). Returns the decisions, outcomes still open.
func _probed_steer(sim: Simulation) -> Array:
	var train: Train = sim.train
	var b: SlimeBodies = sim.slimes
	var tick := sim.tick
	var out := []
	_queue_of.clear()
	_queues_built = false
	_decided.clear()
	train.hold().begin_tick(b)
	_released_now = train.hold().guard(b, tick, train.length())
	if _released_now >= 0:
		guard_log.append([tick, _released_now])
	if tick >= GUARD_FROM:
		_guard_window(sim)
	for slime_id in train.tracked_ids():
		var s := b.index_of(slime_id)
		var record: Dictionary = train._records[slime_id]
		if s < 0 or b.state[s] != SlimeBodies.TRAIN or b.calm[s] == SlimeBodies.PARKED:
			train.hold().drop(slime_id)
			if s >= 0:
				b.set_may_rest(slime_id, false)
			continue
		var d := _decision(sim, slime_id, s)
		train._steer_one(b, slime_id, s, Simulation.TICK_SECONDS, tick)
		if not d.is_empty():
			d["after_holding"] = train.is_holding(slime_id)
			d["after_began"] = train.hold_began_at(slime_id)
			out.append(d)
			_decided[slime_id] = true
			if d["holder_corr"]:
				_block_rows(sim, d)
			if d["after_holding"]:
				_ever_held[slime_id] = true
				_last_cause[slime_id] = d["failed"]
				_last_resp[slime_id] = d["resp"]
			else:
				_last_cause.erase(slime_id)
				_last_resp.erase(slime_id)
		b.set_may_rest(slime_id, record.has("hold") and not sim.fusion.counts_toward_fusion(slime_id))
	return out


## The decision of simulated train slime `slime_id` (index `s`) this tick, as
## _steer_one() is about to make it, or {} when it makes none.
func _decision(sim: Simulation, slime_id: int, s: int) -> Dictionary:
	var train: Train = sim.train
	var b: SlimeBodies = sim.slimes
	var tick := sim.tick
	var record: Dictionary = train._records[slime_id]
	var from := b.centre_of(slime_id)
	var progress := train.steering_distance(record["distance"], from)
	if train.is_slide_at(progress):
		return {}
	var holding: bool = record.has("hold")
	var elapsed := -1
	var check := TrainHold.NO_CHECK
	if holding:
		elapsed = tick - int(record["hold"])
		check = train.hold().check_at(b, slime_id, tick)
		if check == TrainHold.NO_CHECK:
			return {}
	elif b.hop_timer[s] > Simulation.TICK_SECONDS * 1.5 or b.supported[s] == 0:
		return {}
	if not _queues_built:
		_build_queues(sim)
	var length := train.length()
	var target := train.hop_target(progress, Train.hop_reach(b.size[s]))
	var count := _awake_count_ahead(b, target, from, slime_id)
	var d := {"tick": tick, "id": slime_id, "size": b.size[s], "holding": int(holding), "elapsed": elapsed,
			"began": int(record["hold"]) if holding else -1, "count": count,
			"crowded": int(count > DISC_CROWD),
			"jam": int(_jammed(train, b, slime_id, progress)), "check": CHECK_NAMES[check],
			"guard": int(slime_id == _released_now)}
	d["ahead"] = _ahead(train, b, slime_id, progress)
	var q: Array = _queue_of.get(slime_id, [0, 1])
	d["qpos"] = q[0]
	d["qsize"] = q[1]
	d["front"] = int(TrainQueues.is_front(train._records, b, slime_id, length))
	d.merge(_disc(sim, slime_id, progress, from, target))
	d.merge(_corridor(sim, slime_id, from, target))
	return d


## 22e's crowd check count (SlimeBodies.awake_count_ahead, gone in 22f step
## 3): calm ACTIVE slimes, not sleepers nor in a basket, all but `except_id`,
## strictly within DISC_RADIUS of `target` and on its side of `from`.
func _awake_count_ahead(b: SlimeBodies, target: Vector2, from: Vector2, except_id: int) -> int:
	var count := 0
	var forward := target - from
	for o in b.slime_count:
		if b.calm[o] != SlimeBodies.ACTIVE or b.state[o] == SlimeBodies.STATE_SLEEPER \
				or b.state[o] == SlimeBodies.STATE_IN_BASKET or b.id[o] == except_id:
			continue
		var c := b.centre_of(b.id[o])
		if c.distance_squared_to(target) < DISC_RADIUS * DISC_RADIUS and (c - from).dot(forward) > 0.0:
			count += 1
	return count


## 22e's jam check (TrainHold.jammed, gone in 22f step 3): whether the hop
## of `slime_id` at `progress` comes within the two radii plus JAM_GAP of the
## rearmost holder ahead along the loop, or past it.
func _jammed(train: Train, b: SlimeBodies, slime_id: int, progress: float) -> bool:
	var length := train.length()
	if length <= 0.0:
		return false
	var nearest := INF
	var holder_radius := 0.0
	for other: int in train._records:
		if other == slime_id or not train._records[other].has("hold"):
			continue
		var gap := fposmod(train._records[other]["distance"] - progress, length)
		var radius := b.radius_of(other)
		if gap > 0.0 and (gap < nearest or (gap == nearest and radius > holder_radius)):
			nearest = gap
			holder_radius = radius
	if nearest == INF:
		return false
	return Train.hop_reach(b.size_of(slime_id)) + b.radius_of(slime_id) + holder_radius + JAM_GAP >= nearest


## Train slimes ahead of `progress` along the loop within QUEUE_RANGE (22e's).
func _ahead(train: Train, b: SlimeBodies, slime_id: int, progress: float) -> int:
	var length := train.length()
	var n := 0
	for other in train.tracked_ids():
		if other == slime_id or b.state_of(other) != SlimeBodies.TRAIN:
			continue
		var gap := fposmod(train.distance_of(other) - progress, length)
		if gap > 0.0 and gap <= QUEUE_RANGE:
			n += 1
	return n


## This tick's touching queues (TrainQueues.queues over the simulated train
## slimes), each member's position from the front and the queue's size.
func _build_queues(sim: Simulation) -> void:
	var train: Train = sim.train
	var members := []
	for slime_id in train.tracked_ids():
		if TrainQueues.simulated(sim.slimes, slime_id):
			members.append(slime_id)
	for queue: Array in TrainQueues.queues(train._records, sim.slimes, members):
		for k in queue.size():
			_queue_of[queue[k]] = [queue.size() - 1 - k, queue.size()]
	_queues_built = true


## Whether slime `o_id` (centre `c`) is ahead of `progress` along the loop:
## a followed train slime by its record's distance, any other by projecting
## its centre onto the loop within PROGRESS_WINDOW either side (a proxy).
func _ahead_on_loop(train: Train, b: SlimeBodies, o_id: int, c: Vector2, progress: float) -> bool:
	var length := train.length()
	var at: float
	if b.state_of(o_id) == SlimeBodies.TRAIN and train.tracks(o_id):
		at = train.distance_of(o_id)
	else:
		var back := train.project(progress - Train.PROGRESS_WINDOW, c)
		var fwd := train.project(progress, c)
		at = back if c.distance_squared_to(train.position_at(back)) < c.distance_squared_to(train.position_at(fwd)) \
				else fwd
	var gap := fposmod(at - progress, length)
	return gap > 0.0 and gap < length * 0.5


## The 240 px disc round the hop target split (reading (a), (d), (e)).
func _disc(sim: Simulation, slime_id: int, progress: float, from: Vector2, target: Vector2) -> Dictionary:
	var train: Train = sim.train
	var b: SlimeBodies = sim.slimes
	var r2 := DISC_RADIUS * DISC_RADIUS
	var forward := target - from
	var n := {"n_train": 0, "n_hold": 0, "n_other": 0, "n_behind": 0, "n_missed": 0, "n_rest": 0,
			"n_rest_hold": 0, "n_rest_loop": 0}
	for o in b.slime_count:
		var oid := b.id[o]
		if oid == slime_id or b.calm[o] == SlimeBodies.PARKED or b.state[o] == SlimeBodies.STATE_SLEEPER \
				or b.state[o] == SlimeBodies.STATE_IN_BASKET:
			continue
		var c := b.centre_of(oid)
		if c.distance_squared_to(target) >= r2:
			continue
		var half_plane := (c - from).dot(forward) > 0.0
		var on_loop := _ahead_on_loop(train, b, oid, c, progress)
		var is_holder := b.state[o] == SlimeBodies.TRAIN and train.is_holding(oid)
		if b.calm[o] == SlimeBodies.RESTING:
			if half_plane:
				n["n_rest"] += 1
				n["n_rest_hold"] += int(is_holder)
			n["n_rest_loop"] += int(on_loop)
			continue
		if not half_plane:
			n["n_missed"] += int(on_loop)
			continue
		if is_holder:
			n["n_hold"] += 1
		elif b.state[o] == SlimeBodies.TRAIN:
			n["n_train"] += 1
		else:
			n["n_other"] += 1
		n["n_behind"] += int(not on_loop)
	var count: int = n["n_train"] + n["n_hold"] + n["n_other"]
	n["count_rest"] = count + n["n_rest"]
	n["count_loop"] = count - n["n_behind"] + n["n_missed"]
	n["count_all_loop"] = n["count_loop"] + n["n_rest_loop"]
	return n


## The hop corridor (D147 (4)), from the game's own check (TrainHold.check,
## read right before the slime's _steer_one(), in the state it sees):
## `occ` its occupancy, `crowd_corr` the crowd check failing, `holder_corr`
## the holder rule failing (a snapshot holder outside the stack zone),
## `n_corr` the slimes counted (SlimeBodies.corridor_scan), and
## `holder_stack_only` snapshot holders in it, all in the stack zone.
func _corridor(sim: Simulation, slime_id: int, from: Vector2, target: Vector2) -> Dictionary:
	var hold: TrainHold = sim.train.hold()
	var b: SlimeBodies = sim.slimes
	var failed := hold.check(b, slime_id, target)
	var ids: Array[int] = []
	b.corridor_scan(from, target, TrainHold.CORRIDOR_PAST, TrainHold.CORRIDOR_HALF_WIDTH, slime_id, ids)
	var stacked := 0
	var occ_hold := 0.0
	var occ_rest := 0.0
	var area := TrainHold.corridor_area(from, target)
	var resp := []
	var resp_along := []
	var way := (target - from).normalized()
	for oid in ids:
		stacked += int(hold.was_holder(oid))
		var piece := PI * b.radius_of(oid) * b.radius_of(oid) / area
		if hold.was_holder(oid):
			occ_hold += piece
		elif b.calm_of(oid) == SlimeBodies.RESTING:
			occ_rest += piece
		# check()'s holder rule, replicated: the snapshot holders outside the stack zone.
		var along := absf((b.centre_of(oid) - from).dot(way))
		if hold.was_holder(oid) and along >= b.radius_of(slime_id) + b.radius_of(oid):
			resp.append(oid)
			resp_along.append(along)
	assert(resp.is_empty() == ((failed & TrainHold.HOLDER_AHEAD) == 0))
	return {"failed": failed, "resp": resp, "resp_along": resp_along, "occ_hold": occ_hold, "occ_rest": occ_rest, "occ": hold.last_occupancy, "n_corr": ids.size(),
			"holder_corr": int((failed & TrainHold.HOLDER_AHEAD) != 0),
			"crowd_corr": int((failed & TrainHold.CROWDED) != 0),
			"holder_stack_only": int((failed & TrainHold.HOLDER_AHEAD) == 0 and stacked > 0)}


## Writes decision `d`'s row with its outcome, after the tick's step.
func _write(f: FileAccess, d: Dictionary, sim: Simulation) -> void:
	var hopped := sim.slimes.train_hopped.has(d["id"])
	var outcome: String
	if d["holding"] == 0:
		if d["after_holding"]:
			var cause := "both" if d["crowd_corr"] and d["holder_corr"] else "crowd" if d["crowd_corr"] else \
					"holder" if d["holder_corr"] else "none"
			outcome = "start_" + cause
		else:
			outcome = "hop" if hopped else "pending"
	elif d["after_holding"] and d["after_began"] == d["began"]:
		outcome = "still"
	elif d["after_holding"]:
		outcome = "restarted"
	else:
		outcome = "end_period" if d["check"] == "period_end" else "end_clear"
	if d["check"] == "period_end":
		period_end_checks += 1
		period_end_held_on += int(outcome == "still")
	d["outcome"] = outcome
	d["hopped"] = int(hopped)
	var cells := PackedStringArray()
	for column in COLUMNS:
		var v: Variant = d[column]
		cells.append("%.4f" % v if v is float else str(v))
	f.store_line(",".join(cells))


## One snapshot row: the Train's hold snapshot, Physics, the largest cluster.
func _snapshot(sim: Simulation, snap: FileAccess) -> void:
	var shot := sim.train.hold_snapshot(sim.slimes)
	snap.store_line("%d,%d,%d,%d,%d,%d,%d,%d" % [sim.tick, shot["holding"], shot["holding_resting"],
			shot["contact_resting"], shot["queue_back"], shot["queue_back_held"],
			DebugCounts.physics_slime_ids(sim.slimes).size(), DebugCounts.largest_cluster(sim.slimes)])


# --- Diagnostic 2 -----------------------------------------------------------

## The signed loop gap from `from_id` to `to_id`, px, by the records'
## distances: the forward gap wrapped into (-length / 2, length / 2], ahead
## > 0, behind < 0 (the shorter way round the loop).
func _signed_gap(train: Train, from_id: int, to_id: int) -> float:
	var length := train.length()
	var g := fposmod(train.distance_of(to_id) - train.distance_of(from_id), length)
	return g - length if g > length * 0.5 else g


## A holder's last check's cause: crowd, holder, both, or inherited (no
## check of its own seen: a split part).
func _cause_name(slime_id: int) -> String:
	if not _last_cause.has(slime_id):
		return "inherited"
	var bits: int = _last_cause[slime_id]
	var crowd := (bits & TrainHold.CROWDED) != 0
	var holder := (bits & TrainHold.HOLDER_AHEAD) != 0
	return "both" if crowd and holder else "crowd" if crowd else "holder" if holder else "none"


## One -blocks.csv row per responsible holder of decision `d` (the holder
## rule failing).
func _block_rows(sim: Simulation, d: Dictionary) -> void:
	var train: Train = sim.train
	var b: SlimeBodies = sim.slimes
	var c: int = d["id"]
	var from := b.centre_of(c)
	for k in d["resp"].size():
		var h: int = d["resp"][k]
		var euclid := from.distance_to(b.centre_of(h))
		var h_front := int(TrainQueues.is_front(train._records, b, h, train.length()))
		_blocks.store_line("%d,%d,%d,%s,%d,%d,%.4f,%d,%.1f,%.1f,%.1f,%s,%d,%d" % [d["tick"], c, d["holding"], d["check"],
				d["front"], d["qsize"], d["occ"], h, _signed_gap(train, c, h), euclid, d["resp_along"][k], _cause_name(h),
				int(b.calm_of(h) == SlimeBodies.RESTING), h_front])


## The hold guard's condition read as guard() reads it (after the snapshot):
## the simulated train slimes neither holding, resting nor held (the
## blockers), the latest hold start's age; aggregated over the window.
func _guard_window(sim: Simulation) -> void:
	var train: Train = sim.train
	var b: SlimeBodies = sim.slimes
	var hold: TrainHold = train.hold()
	if sim.tick == GUARD_FROM:
		for slime_id in train.tracked_ids():
			_progress_at_from[slime_id] = train.progress_of(slime_id)
	var latest := -1
	for slime_id: int in hold._holders:
		latest = maxi(latest, int(train._records[slime_id]["hold"]))
	var age := sim.tick - latest if latest >= 0 else -1
	var blockers := 0
	var air := 0
	for slime_id: int in train._records:
		var s := b.index_of(slime_id)
		if s < 0 or b.state[s] != SlimeBodies.TRAIN or b.calm[s] == SlimeBodies.PARKED:
			continue
		if hold._holders.has(slime_id) or b.calm[s] == SlimeBodies.RESTING or b.held[s] != 0:
			continue
		blockers += 1
		air += int(b.supported[s] == 0)
		_blocker_ticks[slime_id] = _blocker_ticks.get(slime_id, 0) + 1
		var kind := _kind(slime_id, sim.tick)
		_gw["kind_ticks"][kind] = _gw["kind_ticks"].get(kind, 0) + 1
	_gw["ticks"] += 1
	_gw["blockers_sum"] += blockers
	_gw["air_sum"] += air
	_gw["ground_sum"] += blockers - air
	_gw["no_blockers"] += int(blockers == 0 and latest >= 0)
	_gw["age_ok"] += int(age >= TrainHold.HOLD_GUARD_TICKS)
	_gw["both"] += int(blockers == 0 and age >= TrainHold.HOLD_GUARD_TICKS)
	_gw["age_sum"] += maxi(age, 0)


## Slime `slime_id`'s kind at `tick`: its latest origin event within RECENT
## ticks (end:<cause>, unpark, join, split), else held_before or never_held.
func _kind(slime_id: int, tick: int) -> String:
	var ev: Array = _events.get(slime_id, [])
	if not ev.is_empty() and tick - int(ev[0]) <= RECENT:
		return ev[1]
	return "held_before" if _ever_held.has(slime_id) else "never_held"


## After the tick's step: every hold that ended this tick with its cause
## (-ends.csv), the origin events (unpark, join, split), every train hop with
## its kind (-hops.csv).
func _bookkeep(sim: Simulation, held_before: Dictionary, decisions: Array) -> void:
	var train: Train = sim.train
	var b: SlimeBodies = sim.slimes
	var tick := sim.tick
	var outcome_of := {}
	var decision_of := {}
	for d in decisions:
		outcome_of[d["id"]] = d["outcome"]
		decision_of[d["id"]] = d
	var stalled_now := {}
	for case: Dictionary in train.stalled:
		if case["tick"] == tick:
			stalled_now[case["id"]] = true
	for slime_id: int in held_before:
		if train.is_holding(slime_id) and train.hold_began_at(slime_id) == held_before[slime_id]:
			continue
		var cause: String
		var s := b.index_of(slime_id)
		if slime_id == _released_now:
			cause = "guard"
		elif outcome_of.get(slime_id, "") in ["end_clear", "end_period"]:
			cause = "clear"
		elif s < 0:
			cause = "gone_fusion"
		elif b.state[s] != SlimeBodies.TRAIN:
			cause = "left_train_state%d" % b.state[s]
		elif b.calm[s] == SlimeBodies.PARKED:
			cause = "parked"
		elif stalled_now.has(slime_id):
			cause = "stall_move"
		elif train._records.has(slime_id) and int(train._records[slime_id]["marked_at"]) < 0:
			cause = "stuck_or_lost_move"
		elif train._records.has(slime_id) and train._records[slime_id]["on_slide"]:
			cause = "slide"
		else:
			cause = "unknown"
		_ends.store_line("%d,%d,%d,%s" % [tick, slime_id, held_before[slime_id], cause])
		_events[slime_id] = [tick, "end:" + cause]
		_last_cause.erase(slime_id)
		_last_resp.erase(slime_id)
	var tracked := {}
	for slime_id in train.tracked_ids():
		tracked[slime_id] = true
		var parked := b.calm_of(slime_id) == SlimeBodies.PARKED
		if _split_now.has(slime_id):
			_events[slime_id] = [tick, "split"]
		elif not _prev_tracked.has(slime_id):
			_events[slime_id] = [tick, "join"]
		elif _prev_parked.has(slime_id) and not parked:
			_events[slime_id] = [tick, "unpark"]
		if parked:
			_prev_parked[slime_id] = true
		else:
			_prev_parked.erase(slime_id)
		if train.is_holding(slime_id):
			_ever_held[slime_id] = true
	_prev_tracked = tracked
	for slime_id in b.train_hopped:
		if not train.tracks(slime_id):
			continue
		var kind := "guard" if slime_id == _released_now else _kind(slime_id, tick)
		if tick >= GUARD_FROM:
			_window_hops[slime_id] = _window_hops.get(slime_id, 0) + 1
		var d: Dictionary = decision_of.get(slime_id, {})
		var front := int(TrainQueues.is_front(train._records, b, slime_id, train.length()))
		_hops.store_line("%d,%d,%s,%d,%d,%.4f,%d,%d,%.1f" % [tick, slime_id, kind, int(not d.is_empty()), front,
				d.get("occ", -1.0), d.get("n_corr", -1), d.get("holder_stack_only", -1),
				_nearest_holder_ahead(train, b, slime_id)])


## The loop gap to the nearest simulated holder ahead of `slime_id` (within
## half the loop), px; -1 for none.
func _nearest_holder_ahead(train: Train, b: SlimeBodies, slime_id: int) -> float:
	var best := INF
	for other: int in train._records:
		if other == slime_id or not train._records[other].has("hold") or not TrainQueues.simulated(b, other):
			continue
		var g := _signed_gap(train, slime_id, other)
		if g > 0.0:
			best = minf(best, g)
	return best if best < INF else -1.0


## -graph.csv rows: every simulated holder, its loop distance, its last
## check's cause and its responsible holders then (';'-joined ids).
func _graph_rows(sim: Simulation) -> void:
	var train: Train = sim.train
	var b: SlimeBodies = sim.slimes
	for slime_id in train.tracked_ids():
		if not train.is_holding(slime_id) or not TrainQueues.simulated(b, slime_id):
			continue
		var resp := PackedStringArray()
		for h in _last_resp.get(slime_id, []):
			resp.append(str(h))
		_graph.store_line("%d,%d,%.1f,%s,%d,%d,%d,%s" % [sim.tick, slime_id, train.distance_of(slime_id),
				_cause_name(slime_id), int(b.calm_of(slime_id) == SlimeBodies.RESTING),
				int(TrainQueues.is_front(train._records, b, slime_id, train.length())),
				train.hold_began_at(slime_id), ";".join(resp)])


## A -load.csv row: the loop's length, the train slimes simulated, parked
## and in another state with a record, their summed diameters, the share of
## the loop the simulated ones cover (union of [d - r, d + r]), the holders
## and the guard's blockers now.
func _load_row(sim: Simulation) -> void:
	var train: Train = sim.train
	var b: SlimeBodies = sim.slimes
	var length := train.length()
	var n_sim := 0
	var n_parked := 0
	var n_other := 0
	var diam_sim := 0.0
	var diam_all := 0.0
	var spans := []
	var holders := 0
	var blockers := 0
	var pinned := 0
	for slime_id in train.tracked_ids():
		var s := b.index_of(slime_id)
		if s < 0 or b.state[s] != SlimeBodies.TRAIN:
			n_other += 1
			continue
		var r := b.radius_of(slime_id)
		diam_all += 2.0 * r
		if b.calm[s] == SlimeBodies.PARKED:
			n_parked += 1
			continue
		n_sim += 1
		diam_sim += 2.0 * r
		spans.append([train.distance_of(slime_id) - r, train.distance_of(slime_id) + r])
		if train.is_holding(slime_id):
			holders += 1
		elif b.calm[s] != SlimeBodies.RESTING and b.held[s] == 0:
			blockers += 1
			# A dip nudge's pin (Fusion.DIP_HOLD_SECONDS) keeps a non-holder's timer at 0.25 s.
			pinned += int(is_equal_approx(b.hop_timer[s], Fusion.DIP_HOLD_SECONDS))
	var covered := 0.0
	if length > 0.0:
		var marks := PackedByteArray()
		marks.resize(int(length) + 1)
		for span: Array in spans:
			for x in range(int(floor(span[0])), int(ceil(span[1]))):
				marks[posmod(x, marks.size())] = 1
		for m in marks:
			covered += m
		covered /= marks.size()
	# The front-most holder (the one with no holder ahead within half the loop), and the
	# simulated train slimes ahead of it: within 1500 px (the front's climbers) and beyond.
	var front := -1
	for slime_id in train.tracked_ids():
		if train.is_holding(slime_id) and TrainQueues.simulated(b, slime_id) \
				and _nearest_holder_ahead(train, b, slime_id) < 0.0:
			front = slime_id
	var ahead := 0
	var far := 0
	if front >= 0:
		for slime_id in train.tracked_ids():
			if slime_id == front or not TrainQueues.simulated(b, slime_id):
				continue
			var g := _signed_gap(train, front, slime_id)
			ahead += int(g > 0.0 and g <= 1500.0)
			far += int(g > 1500.0)
	_load.store_line("%d,%.0f,%d,%d,%d,%.0f,%.0f,%.3f,%d,%d,%.0f,%d,%d,%d" % [sim.tick, length, n_sim, n_parked, n_other,
			diam_sim, diam_all, covered, holders, blockers, train.distance_of(front) if front >= 0 else -1.0, ahead, far,
			pinned])
