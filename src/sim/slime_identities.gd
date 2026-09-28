class_name SlimeIdentities
extends RefCounted
## Stable slime identities, for saves (D72): which placed base slimes each
## slime is made of. A slime's "members" are the stable IDs of those base
## slimes (a sleeper's `s1.sleeper.07`, the first slime's
## `start.first-slime`), kept sorted. Runtime ids (SlimeBodies) change with
## every fusion and split and are only good within one run of a save; the
## members name a slime across level versions.
##
## The rule:
## - a placed slime (a sleeper woken, the first slime) has one member, its
##   own stable ID;
## - a fused slime has the union of both members, under the lower runtime id
##   (the one SlimeBodies.merge keeps);
## - a split hands the members out one per part, in sorted order: part 0 (the
##   original runtime id) takes the first, part k the k-th. Members beyond
##   the part count stay with part 0; parts beyond the member count get none.
## - a slime with no placed origin (made by a test or a debug tool) has none.
##
## A slime's stable ID, as a save names it, is its first member, or none.
##
## Simulation keeps one: load_level() names the first slime, step() hands
## split parts their members, Simulation.fuse() merges them, and every tick
## forgets the slimes that are gone.
# @spec-link [[req_persistence_and_saves]]

## Runtime slime id -> PackedStringArray of stable IDs, sorted. Only slimes
## with members are listed.
var _members := {}


## Sets slime `slime_id`'s members (sorted here). Empty clears them.
func assign(slime_id: int, members: PackedStringArray) -> void:
	if members.is_empty():
		_members.erase(slime_id)
		return
	var sorted := members.duplicate()
	sorted.sort()
	_members[slime_id] = sorted


## The slime's members, sorted (empty: no placed origin).
func members_of(slime_id: int) -> PackedStringArray:
	return (_members[slime_id] as PackedStringArray).duplicate() if _members.has(slime_id) else PackedStringArray()


## The slime's stable ID: its first member, or "" without one.
func stable_id_of(slime_id: int) -> String:
	return _members[slime_id][0] if _members.has(slime_id) else ""


## Slimes `a` and `b` fused: the union of their members goes to the lower id
## (the one SlimeBodies.merge keeps), the higher has none.
func merge(a: int, b: int) -> void:
	var keep := mini(a, b)
	var gone := maxi(a, b)
	var union := members_of(keep)
	union.append_array(members_of(gone))
	_members.erase(gone)
	assign(keep, union)


## Hands the members of `parts[0]` out to the parts of its split (the ids
## SlimeBodies.split returned, the original first).
func split(parts: PackedInt32Array) -> void:
	if parts.size() < 2:
		return
	var members := members_of(parts[0])
	assign(parts[0], members.slice(0, 1) + members.slice(parts.size()))
	for k in range(1, parts.size()):
		assign(parts[k], members.slice(k, k + 1))


## Forgets the slimes `bodies` no longer has.
func tidy(bodies: SlimeBodies) -> void:
	for slime_id in _members.keys():
		if not bodies.has(slime_id):
			_members.erase(slime_id)


## The named slimes in id order, as plain data: [{"id", "members"}].
func dump() -> Array:
	var ids := _members.keys()
	ids.sort()
	var out := []
	for slime_id in ids:
		out.append({"id": slime_id, "members": Array(_members[slime_id])})
	return out
