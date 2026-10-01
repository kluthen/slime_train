extends SceneTree
## Throwaway probe (22e BEFORE): loads a fixture in test mode (seed 1), steps it
## TICKS ticks and logs, per second, the Physics / resting / in-basket counts,
## RESTING->ACTIVE transitions by state, whole-pile wakes, the largest awake
## cluster, catches and releases, basket 3's phase; plus, per tick where basket
## slimes wake, the trigger (needs the worktree's probe_* instrumentation in
## SlimeBodies), and why the active basket pile does not rest.
## godot --headless --path <wt> -s probe_pile_wakes.gd -- --fixture=s3-basket-59of60 [--ticks=2400] [--detail=1]

var fixture := "s3-basket-59of60"
var ticks := 2400
var detail := 1

const STATE_NAMES := ["sleeper", "train", "free", "bedtime", "in_basket"]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var p := arg.trim_prefix("--").split("=", true, 1)
		if p[0] == "fixture": fixture = p[1]
		if p[0] == "ticks": ticks = int(p[1])
		if p[0] == "detail": detail = int(p[1])
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
	var b: SlimeBodies = sim.slimes
	var has_b3: bool = sim.object_states.has("s3.basket")
	var box3: Rect2 = sim.level.baskets["s3.basket"]["box"] if has_b3 else Rect2()
	print("fixture=%s tick0=%d slimes=%d box3=%s" % [fixture, sim.tick, b.slime_count, box3])
	# Totals.
	var tot := {"trans": 0, "trans_basket": 0, "trans_train": 0, "trans_other": 0, "whole_pile": 0,
			"releases": 0, "catches": 0}
	var cause_events := {}   # cause -> [events, slimes woken] for basket piles
	var toucher_hist := {}   # "state speedbucket supported" -> events
	var toucher_speeds := []
	var reset_hist := {"unsupported": 0, "drift": 0}  # active basket members reset per tick
	var reset_call := {}
	var blocker_count := {}  # id -> resets while pile active
	var drift_speeds := []
	var fired_tick := -1
	var sec := {}
	var release_due := 0
	var release_blocked := 0
	var rest_touch_ticks := 0
	var rest_touch_states := {}
	var rest_touch_maxspeed := 0.0
	var pile_active_after_fire := 0
	var act_touch_ticks := 0
	var act_touch_states := {}
	var act_touch_fast := 0
	var release_ranks := []
	var pile_resting_after_fire := 0
	for t in ticks:
		# Snapshot before.
		var before_calm := {}
		var before_state := {}
		var before_pile := {}
		for s in b.slime_count:
			before_calm[b.id[s]] = b.calm[s]
			before_state[b.id[s]] = b.state[s]
			before_pile[b.id[s]] = b.pile[s]
		var centres_before := {}
		for s in b.slime_count:
			if b.state[s] == SlimeBodies.IN_BASKET:
				centres_before[b.id[s]] = b.centre_of(b.id[s])
		b.probe_log.clear()
		b.probe_tick = sim.tick
		b.probe_cause = "pre_step"
		var phase_before = sim.object_states["s3.basket"]["phase"] if has_b3 else ""
		var due: bool = has_b3 and phase_before == "fired" and not centres_before.is_empty() and sim.tick >= int(sim.object_states["s3.basket"]["next_release"])
		game.step_simulation()
		var phase_after = sim.object_states["s3.basket"]["phase"] if has_b3 else ""
		if phase_before != "fired" and phase_after == "fired" and fired_tick < 0:
			fired_tick = sim.tick
		# Transitions.
		var woke := []
		var rel := 0
		var cat := 0
		for s in b.slime_count:
			var i := b.id[s]
			if not before_calm.has(i):
				continue
			if before_calm[i] == SlimeBodies.RESTING and b.calm[s] == SlimeBodies.ACTIVE:
				woke.append(i)
			if before_state[i] == SlimeBodies.IN_BASKET and b.state[s] != SlimeBodies.IN_BASKET:
				rel += 1
				var below := 0
				for j in centres_before:
					if centres_before[j].y > centres_before[i].y + 1.0:
						below += 1
				release_ranks.append("id%d below=%d/%d" % [i, below, centres_before.size() - 1])
			if before_state[i] != SlimeBodies.IN_BASKET and b.state[s] == SlimeBodies.IN_BASKET:
				cat += 1
		if due:
			release_due += 1
			if rel == 0:
				release_blocked += 1
		# Active slimes touching a resting basket slime (after the tick).
		var touched := false
		for pr in b.touching_pairs():
			for side in 2:
				var r: int = pr[side]
				var o: int = pr[1 - side]
				if b.state_of(r) == SlimeBodies.IN_BASKET and b.calm_of(r) == SlimeBodies.ACTIVE and b.state_of(o) != SlimeBodies.IN_BASKET and b.calm_of(o) == SlimeBodies.ACTIVE and b.state_of(o) != SlimeBodies.SLEEPER:
					act_touch_ticks += 1
					var key3: String = STATE_NAMES[b.state_of(o)]
					act_touch_states[key3] = act_touch_states.get(key3, 0) + 1
					if b.velocity_of(o).length() > SlimeBodies.WAKE_SPEED:
						act_touch_fast += 1
				if b.state_of(r) == SlimeBodies.IN_BASKET and b.calm_of(r) == SlimeBodies.RESTING and b.calm_of(o) == SlimeBodies.ACTIVE and b.state_of(o) != SlimeBodies.SLEEPER:
					touched = true
					var key2: String = STATE_NAMES[b.state_of(o)]
					rest_touch_states[key2] = rest_touch_states.get(key2, 0) + 1
					rest_touch_maxspeed = maxf(rest_touch_maxspeed, b.velocity_of(o).length())
		if touched:
			rest_touch_ticks += 1
		var wb := 0
		var wt := 0
		var wo := 0
		for i in woke:
			match before_state[i]:
				SlimeBodies.IN_BASKET: wb += 1
				SlimeBodies.TRAIN: wt += 1
				_: wo += 1
		var whole := woke.size() if woke.size() >= 11 else 0
		tot["trans"] += woke.size(); tot["trans_basket"] += wb; tot["trans_train"] += wt; tot["trans_other"] += wo
		tot["whole_pile"] += whole; tot["releases"] += rel; tot["catches"] += cat
		var k := int(t / 60)
		if not sec.has(k):
			sec[k] = {"trans": 0, "tb": 0, "tt": 0, "to": 0, "whole": 0, "rel": 0, "cat": 0, "active_ticks": 0, "minshort": 999}
		var row: Dictionary = sec[k]
		row["trans"] += woke.size(); row["tb"] += wb; row["tt"] += wt; row["to"] += wo
		row["whole"] += whole; row["rel"] += rel; row["cat"] += cat
		# Triggers of basket wakes this tick.
		if wb > 0:
			var parts := []
			for e in b.probe_log:
				if e["kind"] != "wake":
					continue
				var pid: int = e["pile"]
				var n := 0
				var nb := 0
				for i in before_pile:
					if before_calm[i] == SlimeBodies.RESTING and before_pile[i] == pid:
						n += 1
						if before_state[i] == SlimeBodies.IN_BASKET:
							nb += 1
				if nb == 0 and e["state"] != SlimeBodies.IN_BASKET:
					continue
				var c: String = e["cause"]
				if not cause_events.has(c):
					cause_events[c] = [0, 0]
				cause_events[c][0] += 1
				cause_events[c][1] += n
				var desc := "%s(id%d %s pile%d n%d)" % [c, e["id"], STATE_NAMES[e["state"]], pid, n]
				if c == "touch":
					var tch: Dictionary = e["toucher"]
					var sp: float = tch["speed"]
					toucher_speeds.append(sp)
					var bucket := "30-60" if sp < 60 else ("60-150" if sp < 150 else (">=150"))
					var key := "%s %s sup=%d held=%d" % [STATE_NAMES[tch["state"]], bucket, tch["supported"], tch["held"]]
					toucher_hist[key] = toucher_hist.get(key, 0) + 1
					desc += " by id%d %s %.0fpx/s sup=%d held=%d" % [tch["id"], STATE_NAMES[tch["state"]], sp, tch["supported"], tch["held"]]
				parts.append(desc)
			if detail > 0:
				print("  WAKE t=%d (%.2fs) basket_woke=%d train_woke=%d rel=%d cat=%d phase=%s: %s" % [sim.tick, sim.tick / 60.0, wb, wt, rel, cat, phase_after, "; ".join(parts)])
		# Why the active basket pile does not rest.
		var active_b := 0
		var short := 0
		var unsup := 0
		var drift := 0
		var called := {}
		for e in b.probe_log:
			if e["kind"] == "reset" and e["state"] == SlimeBodies.IN_BASKET:
				called[e["id"]] = e["cause"]
		for s in b.slime_count:
			if b.state[s] != SlimeBodies.IN_BASKET or b.calm[s] != SlimeBodies.ACTIVE:
				continue
			active_b += 1
			var i := b.id[s]
			if b.still_ticks[s] < SlimeBodies.REST_TICKS:
				short += 1
			if b.still_ticks[s] == 0 and before_calm.get(i, -1) == SlimeBodies.ACTIVE:
				var why := ""
				if called.has(i):
					why = "call:" + str(called[i])
					reset_call[why] = reset_call.get(why, 0) + 1
				elif b.supported[s] == 0:
					why = "unsupported"
					unsup += 1
				else:
					why = "drift"
					drift += 1
					if centres_before.has(i):
						drift_speeds.append(centres_before[i].distance_to(b.centre_of(i)) * 60.0)
				if why == "unsupported" or why == "drift":
					reset_hist[why] += 1
				blocker_count[i] = blocker_count.get(i, 0) + 1
		if fired_tick >= 0 and not centres_before.is_empty():
			if active_b > 0:
				pile_active_after_fire += 1
			else:
				pile_resting_after_fire += 1
		if active_b > 0:
			row["active_ticks"] += 1
			row["minshort"] = mini(row["minshort"], short)
			row["unsup"] = row.get("unsup", 0) + unsup
			row["drift"] = row.get("drift", 0) + drift
		if (t + 1) % 60 == 0:
			var rest := 0
			var inb := 0
			var inb_rest := 0
			for s in b.slime_count:
				if b.calm[s] == SlimeBodies.RESTING:
					rest += 1
				if b.state[s] == SlimeBodies.IN_BASKET:
					inb += 1
					if b.calm[s] == SlimeBodies.RESTING:
						inb_rest += 1
			var w = sim.object_states["s3.basket"]["weight"] if has_b3 else 0
			print("SEC %2d physics=%d resting=%d in_basket=%d (resting %d) trans=%d [basket %d train %d other %d] whole_pile=%d cluster=%d rel=%d cat=%d phase=%s weight=%s bodies=%d pile_active_ticks=%d min_short=%s unsup_resets=%d drift_resets=%d"
					% [k + 1, b.crowd_count(), rest, inb, inb_rest, row["trans"], row["tb"], row["tt"], row["to"], row["whole"],
					DebugCounts.largest_cluster(b), row["rel"], row["cat"], phase_after, w, b.slime_count,
					row["active_ticks"], row["minshort"] if row["active_ticks"] > 0 else "-", row.get("unsup", 0), row.get("drift", 0)])
	print("TOTAL ", tot)
	print("BASKET_WAKE_CAUSES [events, slimes woken] ", cause_events)
	print("TOUCHERS ", toucher_hist)
	toucher_speeds.sort()
	if not toucher_speeds.is_empty():
		print("TOUCHER_SPEED min=%.0f med=%.0f max=%.0f" % [toucher_speeds[0], toucher_speeds[toucher_speeds.size() / 2], toucher_speeds[-1]])
	print("ACTIVE_PILE_RESETS ", reset_hist, " calls ", reset_call)
	drift_speeds.sort()
	if not drift_speeds.is_empty():
		print("DRIFT_RESET_STEP px/s min=%.1f med=%.1f max=%.1f n=%d" % [drift_speeds[0], drift_speeds[drift_speeds.size() / 2], drift_speeds[-1], drift_speeds.size()])
	var bl := []
	for i in blocker_count:
		bl.append([blocker_count[i], i])
	bl.sort()
	bl.reverse()
	print("TOP_RESETTERS [resets, id] ", bl.slice(0, 12))
	print("BASKET3_FIRED_TICK ", fired_tick)
	print("RELEASES due_ticks=%d blocked_ticks=%d (outlet not clear)" % [release_due, release_blocked])
	print("RESTING_PILE_TOUCHED ticks=%d pair-ticks by toucher state %s max toucher speed %.1f px/s" % [rest_touch_ticks, rest_touch_states, rest_touch_maxspeed])
	print("ACTIVE_PILE_TOUCHED_BY_OTHERS pair-ticks=%d by state %s faster_than_wake=%d" % [act_touch_ticks, act_touch_states, act_touch_fast])
	print("RELEASED (slimes of the pile lower than it) ", release_ranks)
	print("PILE_AFTER_FIRE active_ticks=%d resting_ticks=%d" % [pile_active_after_fire, pile_resting_after_fire])
	quit(0)
