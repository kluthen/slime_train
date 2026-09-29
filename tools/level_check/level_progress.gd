class_name LevelProgress
extends RefCounted
## Whether each section of a level can progress by play (chunk LD3), for
## LevelChecker (rule 12's warnings) and the level report: a static
## estimate, not a proof. Play it to be sure (a level's own test can, see
## tools/new_level/test_level.gd.template).
##
## A sleeper wakes only when an awake slime reaches it, and a slime gets
## there by answering a call (rule 17: waking always takes a call). A called
## slime walks toward the call point along the ground and makes the last
## climb in one hop: at most Train.hop_reach(size) sideways and
## FreeSlimes.max_rise(size) up. So a sleeper is taken as reachable by a
## called slime of `size` when some point of the loop's outgoing routes in
## use at its section, within that hop's reach sideways of the sleeper,
## is at most that rise below it (take_off()). Obstacles on the way (a ledge
## overhead, a lip) aren't modelled.
##
## A section progresses when its basket can be filled: the base slimes the
## train can have by then (the first slime, and every sleeper of that
## section or an earlier one a called slime of a size the train can make
## reaches) weigh at least its quota. The sizes the train can make grow as
## it wakes slimes: n base slimes of one species fuse up to size n
## (SlimeBodies.MAX_SIZE at most), and only the same species fuse. So the
## estimate wakes what it can, grows the sizes, and repeats until nothing
## more wakes (estimate()).

## How often the loop's routes are sampled for take-off points, px.
const SAMPLE := 8.0
## The most sleepers a warning names by ID; the rest are counted.
const NAMED := 6


## The best take-off point on the loop for a called slime of `size` to hop
## up to `at` with the loop in use at `section`: the point of an outgoing
## route within Train.hop_reach(size) sideways of `at` that is the least
## below it. {"from" (Vector2), "rise" (px, up is positive), "reaches"
## (the rise is within FreeSlimes.max_rise(size))}; "from" is null and
## "rise" INF when no route point is within reach sideways.
# @spec-link [[rule_sleepers_never_on_loop]]
static func take_off(c: LevelChecker, section: int, at: Vector2, size := 1) -> Dictionary:
	return _take_off_from(_route_points(c, section), at, size)


## take_off() among the route points `points`.
static func _take_off_from(points: PackedVector2Array, at: Vector2, size: int) -> Dictionary:
	var reach := Train.hop_reach(size)
	var best := {"from": null, "rise": INF, "reaches": false}
	for point in points:
		if absf(point.x - at.x) <= reach and point.y - at.y < best["rise"]:
			best["from"] = point
			best["rise"] = point.y - at.y
	best["reaches"] = best["rise"] <= max_rise(size)
	return best


## The smallest size (1 to SlimeBodies.MAX_SIZE) whose called hop reaches
## `at` from the loop in use at `section` (take_off()), or 0 for none.
static func smallest_size(c: LevelChecker, section: int, at: Vector2) -> int:
	return _smallest_size_from(_route_points(c, section), at)


## smallest_size() among the route points `points`.
static func _smallest_size_from(points: PackedVector2Array, at: Vector2) -> int:
	for size in range(1, SlimeBodies.MAX_SIZE + 1):
		if _take_off_from(points, at, size)["reaches"]:
			return size
	return 0


## The highest a called slime of `size` hops up onto a ledge, px
## (FreeSlimes.max_rise at the slime bodies' gravity).
static func max_rise(size: int) -> float:
	return FreeSlimes.max_rise(size, SlimeBodies.new(Rng.new(0)).gravity.length())


## Per section with a basket, in order: whether it can progress. Each
## {"section", "basket" (its stable ID), "quota", "woken" (the stable IDs of
## the sleepers of sections 1 to it the estimate wakes by then), "unreached"
## (those it doesn't), "species" (letter -> base slimes the train can have
## by then, the first slime included), "available" (their total),
## "largest" (the largest size the train can make by then), "progresses"
## (available >= quota)}.
# @spec-link [[rule_gate_opens_via_switch_basket_set]]
static func estimate(c: LevelChecker) -> Array:
	var out := []
	var pool := {}
	if not c.data.first_slime.is_empty():
		pool[c.data.first_slime["species"]] = 1
	var woken := []
	var sizes := {}
	for section in c.sections():
		var basket := _basket_of(c, section)
		var waiting := c.data.sleepers.keys().filter(func(id): return LevelChecker.section_of(id) <= section \
				and not id in woken)
		waiting.sort_custom(func(a: String, b: String): return a.naturalnocasecmp_to(b) < 0)
		var points := _route_points(c, section)
		for id in waiting:
			sizes[id] = _smallest_size_from(points, c.data.sleepers[id]["position"])
		var more := true
		while more:
			more = false
			var largest := _largest(pool)
			for id in waiting.duplicate():
				if sizes[id] > 0 and sizes[id] <= largest:
					woken.append(id)
					waiting.erase(id)
					var letter: String = c.data.sleepers[id]["species"]
					pool[letter] = pool.get(letter, 0) + 1
					more = true
		if basket.is_empty():
			continue
		var available := 0
		for letter in pool:
			available += pool[letter]
		var quota: int = c.data.baskets[basket]["quota"]
		out.append({"section": section, "basket": basket, "quota": quota, "woken": woken.duplicate(),
				"unreached": waiting, "species": _sorted(pool), "available": available, "largest": _largest(pool),
				"progresses": available >= quota})
	return out


## Rule 12's warnings: a finding for each section whose basket the estimate
## can't fill, saying what is short and what to change.
# @spec-link [[rule_gate_opens_via_switch_basket_set]]
static func warnings(c: LevelChecker) -> Array:
	var out := []
	for one in estimate(c):
		if one["progresses"]:
			continue
		var box: Rect2 = c.data.baskets[one["basket"]]["box"]
		var named: Array = one["unreached"].slice(0, NAMED)
		var rest: int = one["unreached"].size() - named.size()
		out.append(LevelChecker.finding(one["basket"], box.get_center().x,
				("section %d may not progress: its basket's quota is %d, but only about %d base slimes can be awake "
				+ "by then (%s; largest size %d). Out of a called slime's reach: %s%s. Bring sleepers within a called "
				+ "base slime's hop of the loop (%.0f px up, %.0f px sideways), let same-species pairs wake first, or "
				+ "lower the quota. A static estimate: play it to be sure")
				% [one["section"], one["quota"], one["available"], _counts_text(one["species"]), one["largest"],
				", ".join(named) if not named.is_empty() else "none",
				" and %d more" % rest if rest > 0 else "", max_rise(1), Train.hop_reach(1)]))
	return out


## The outgoing routes' points of the loop in use at `section`, every
## SAMPLE px and at every route point.
static func _route_points(c: LevelChecker, section: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for segment in c.data.loop.current_segments(c.gates_before(section)):
		if segment["kind"] == LoopData.OUTGOING:
			points.append_array(LevelGeometry.sample(segment["points"], SAMPLE))
	return points


## Section `section`'s basket (the one whose switch, or itself when it has
## none, is placed in that section), or "".
static func _basket_of(c: LevelChecker, section: int) -> String:
	var ids := c.data.baskets.keys()
	ids.sort()
	for basket in ids:
		var switch := LevelStates.switch_of(c.data, basket)
		if LevelChecker.section_of(switch if not switch.is_empty() else basket) == section:
			return basket
	return ""


## The largest size the slimes of `pool` (letter -> base slimes) can fuse
## to: the most of one species, SlimeBodies.MAX_SIZE at most; 0 for none.
static func _largest(pool: Dictionary) -> int:
	var most := 0
	for letter in pool:
		most = maxi(most, pool[letter])
	return mini(most, SlimeBodies.MAX_SIZE)


## `counts` with its keys sorted.
static func _sorted(counts: Dictionary) -> Dictionary:
	var keys := counts.keys()
	keys.sort()
	var out := {}
	for key in keys:
		out[key] = counts[key]
	return out


## "A 2, B 1".
static func _counts_text(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in counts:
		parts.append("%s %d" % [key, counts[key]])
	return ", ".join(parts)
