class_name BucketLoads
extends RefCounted
## The loop buckets' loads and bucket caps (chunk 22i, D151 points 1 and 6).
##
## The cut. The loop is cut into loop buckets as LoopBuckets cuts it: max(1,
## ceil(loop length / bucket length)) of them, bucket k holding the
## distances along the loop in [k * bucket length, (k + 1) * bucket length),
## the last one shorter. Unlike LoopBuckets, a distance outside the loop
## WRAPS (the loop is one cycle in v1): past its end is bucket 0 again (a hop
## aimed past the loop's end lands at its start), and the bucket after the
## last is bucket 0 (next()).
##
## The caps. A bucket's cap is the density (slimes per 100 px of loop)
## times its own length, rounded down, never below MIN_CAP (the largest
## size, so any slime fits an empty bucket): 12 for a 300 px bucket at 4 per
## 100 px. The density used is the larger of the one asked for and
## DENSITY_FLOOR_FACTOR x the level's base slimes per 100 px of loop (the
## density floor: the caps summed, the total room, at least twice the most
## the train can weigh), fixed when the loop is cut (configure()).
##
## The loads. A bucket's load is a weight: the summed sizes of the slimes
## counted in it (a size-n slime counts n). The owner (Train) decides which
## slimes count and keeps each one where it is: place() counts a slime in the
## bucket of a distance, carry() moves a counted slime's weight to the
## bucket of a new distance (nothing for one not counted), drop() stops
## counting it; add() and move() change a bucket's weight directly. A bucket
## is overfilled at or over its cap; has_room() says whether a slime of a
## size fits under it.
##
## Deterministic, no randomness; the loads are sums of whole numbers, so
## they never depend on the order slimes are counted in, and the id lookups
## (dictionaries) are never iterated for an output. Plain data, no scene
## nodes: meant to port to C++ as is.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[req_platform_and_performance_targets]]

## The bucket cap's density asked for by default, slimes (weighted by size)
## per 100 px of loop (D151, proposed).
const DEFAULT_DENSITY := 4.0
## No bucket's cap is below this: the largest slime size, so any slime fits
## an empty bucket.
const MIN_CAP := SlimeBodies.MAX_SIZE
## The density floor: the total room at least this many times the level's
## base slimes (the most the train can weigh).
const DENSITY_FLOOR_FACTOR := 2.0
## Added before rounding a cap down, so a product that is a whole number in
## exact arithmetic (4.0 x 300 / 100) never rounds down to one less.
const CAP_EPSILON := 1e-6

var _loop_length := 0.0
var _bucket_length := 0.0
var _density := 0.0
var _base_slimes := 0
var _density_used := 0.0
var _caps := PackedInt32Array()
var _loads := PackedInt32Array()
## Counted slime id -> its bucket, and -> its weight. Lookups only.
var _bucket_of: Dictionary[int, int] = {}
var _weight_of: Dictionary[int, int] = {}


## Cuts a loop of loop_length px into buckets of bucket_length px, with the
## caps of density_per_100px raised to the density floor of base_slimes.
## When anything changed, the caps are set again, every load emptied and
## every slime forgotten, and true is returned: the caller counts every
## slime again. Both lengths and the density must be positive.
func configure(loop_length: float, bucket_length: float, density_per_100px: float, base_slimes: int) -> bool:
	assert(loop_length > 0.0, "BucketLoads: the loop length must be positive")
	assert(bucket_length > 0.0, "BucketLoads: the bucket length must be positive")
	assert(density_per_100px > 0.0, "BucketLoads: the density must be positive")
	assert(base_slimes >= 0, "BucketLoads: base slimes can't be negative")
	if loop_length == _loop_length and bucket_length == _bucket_length \
			and density_per_100px == _density and base_slimes == _base_slimes:
		return false
	_loop_length = loop_length
	_bucket_length = bucket_length
	_density = density_per_100px
	_base_slimes = base_slimes
	_density_used = maxf(density_per_100px, DENSITY_FLOOR_FACTOR * base_slimes * 100.0 / loop_length)
	var count := maxi(1, ceili(loop_length / bucket_length))
	_caps.resize(count)
	for b in count:
		var span := minf((b + 1) * bucket_length, loop_length) - b * bucket_length
		_caps[b] = maxi(MIN_CAP, floori(_density_used * span / 100.0 + CAP_EPSILON))
	_loads = PackedInt32Array()
	_loads.resize(count)
	_bucket_of.clear()
	_weight_of.clear()
	return true


## How many buckets the loop is cut into (0 before configure()).
func count() -> int:
	return _caps.size()


## The density the caps use, slimes per 100 px: the one asked for, or the
## density floor when it is larger.
func density_used() -> float:
	return _density_used


## The bucket a distance along the loop falls in, wrapping (see the class
## doc): the loop's end and beyond are bucket 0 again.
func bucket_index(distance: float) -> int:
	assert(not _caps.is_empty(), "BucketLoads: configure() first")
	return clampi(floori(fposmod(distance, _loop_length) / _bucket_length), 0, _caps.size() - 1)


## The bucket ahead of bucket b: the one after the last is bucket 0.
func next(b: int) -> int:
	return (b + 1) % _caps.size()


## The distance along the loop where bucket b ends (the loop's length for
## the last one).
func front_edge(b: int) -> float:
	return minf((b + 1) * _bucket_length, _loop_length)


## Bucket b's cap.
func cap(b: int) -> int:
	return _caps[b]


## Bucket b's load: the summed sizes of the slimes counted in it.
func load(b: int) -> int:
	return _loads[b]


## Empties every load and forgets every slime; the cut and caps are kept.
func clear_loads() -> void:
	_loads.fill(0)
	_bucket_of.clear()
	_weight_of.clear()


## Adds weight to bucket b's load.
func add(b: int, weight: int) -> void:
	_loads[b] += weight


## Moves weight from bucket from_b's load to bucket to_b's.
func move(from_b: int, to_b: int, weight: int) -> void:
	_loads[from_b] -= weight
	_loads[to_b] += weight


## Counts slime id, of weight `weight`, in the bucket of `distance` (taken
## out of the one it was counted in first, with its old weight).
func place(slime_id: int, distance: float, weight: int) -> void:
	drop(slime_id)
	var b := bucket_index(distance)
	_loads[b] += weight
	_bucket_of[slime_id] = b
	_weight_of[slime_id] = weight


## Moves counted slime id's weight to the bucket of `distance`; nothing for
## a slime not counted.
func carry(slime_id: int, distance: float) -> void:
	var old: int = _bucket_of.get(slime_id, -1)
	if old == -1:
		return
	var b := bucket_index(distance)
	if b != old:
		move(old, b, _weight_of[slime_id])
		_bucket_of[slime_id] = b


## Stops counting slime id. Returns false if it wasn't counted.
func drop(slime_id: int) -> bool:
	var old: int = _bucket_of.get(slime_id, -1)
	if old == -1:
		return false
	_loads[old] -= _weight_of[slime_id]
	_bucket_of.erase(slime_id)
	_weight_of.erase(slime_id)
	return true


## The bucket slime id is counted in, -1 when it isn't counted.
func bucket_of(slime_id: int) -> int:
	return _bucket_of.get(slime_id, -1)


## Whether a slime of `size` fits in bucket b: its load plus the size at
## most its cap.
func has_room(b: int, size: int) -> bool:
	return _loads[b] + size <= _caps[b]


## Whether bucket b is overfilled: its load at or over its cap.
func overfilled(b: int) -> bool:
	return _loads[b] >= _caps[b]


## The highest load of any bucket (0 before configure()).
func max_load() -> int:
	var top := 0
	for value in _loads:
		top = maxi(top, value)
	return top


## How many buckets are over their cap (load above it, not at it).
func over_count() -> int:
	var over := 0
	for b in _loads.size():
		if _loads[b] > _caps[b]:
			over += 1
	return over


## Every bucket's load, bucket 0 first (a copy, for the probes).
func loads() -> PackedInt32Array:
	return _loads.duplicate()


## Every bucket's cap, bucket 0 first (a copy, for the probes).
func caps() -> PackedInt32Array:
	return _caps.duplicate()
