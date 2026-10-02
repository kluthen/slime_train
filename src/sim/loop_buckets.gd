class_name LoopBuckets
extends RefCounted
## The loop buckets (chunk 22g, experimental, switchable): the loop cut into
## fixed-length LOGICAL segments, bucket k holding the train slimes whose
## loop progress (a distance along the loop, 0 to its length) is in
## [k * bucket length, (k + 1) * bucket length); the last bucket may be
## shorter and takes the loop's end, and any distance outside the loop is
## clamped to the first or the last bucket. They give the order the train
## slimes are processed in, front-first: the last bucket (the front of the
## loop) first, down to bucket 0, by ascending id inside a bucket (order()).
## So the front of the train decides before the slimes behind it, which then
## see the front's decision of the same tick.
##
## Logical only: a bucket decides an ORDER, never a placement. It never
## moves, holds or places a slime; nothing reads a slime's bucket but the
## order. The membership is incremental: place() moves a slime only when its
## bucket changes, and each bucket keeps its ids sorted (inserted in place by
## binary search), so no per-tick sort is needed. A new cut (configure(): the
## loop grows when a gate opens) clears the membership; the caller then
## re-places every slime.
##
## Deterministic, no randomness, and the output never depends on a
## Dictionary's iteration order (the dictionary is a lookup only; order()
## reads the sorted buckets). Plain data, no scene nodes: meant to port to
## C++ as is (a vector of sorted int vectors and an id -> bucket map).
# @spec-link [[req_hopping_behavior]]
# @spec-link [[req_platform_and_performance_targets]]

## A bucket's length, px (proposed, to be tuned by measurement).
const DEFAULT_BUCKET_LENGTH := 300.0

var _loop_length := 0.0
var _bucket_length := 0.0
## One PackedInt32Array per bucket, its ids ascending.
var _buckets: Array[PackedInt32Array] = []
## id -> its bucket's index, a lookup only (never iterated for the output).
var _bucket_of: Dictionary[int, int] = {}


## Cuts a loop of loop_length px into buckets of bucket_length px: max(1,
## ceil(loop_length / bucket_length)) of them. When the bucket count or the
## bucket length changes, the membership is cleared and true is returned:
## the caller re-places every slime. Both lengths must be positive.
func configure(loop_length: float, bucket_length: float) -> bool:
	assert(loop_length > 0.0, "LoopBuckets: the loop length must be positive")
	assert(bucket_length > 0.0, "LoopBuckets: the bucket length must be positive")
	var new_count := maxi(1, ceili(loop_length / bucket_length))
	_loop_length = loop_length
	if new_count == _buckets.size() and bucket_length == _bucket_length:
		return false
	_bucket_length = bucket_length
	_buckets.clear()
	_buckets.resize(new_count)
	_bucket_of.clear()
	return true


## How many buckets the loop is cut into (0 before configure()).
func count() -> int:
	return _buckets.size()


## The bucket a distance along the loop falls in: floor(distance / bucket
## length), clamped to the first and the last bucket (the loop's end, or a
## distance slightly outside the loop, is in the last bucket).
func bucket_index(distance: float) -> int:
	assert(not _buckets.is_empty(), "LoopBuckets: configure() first")
	return clampi(floori(distance / _bucket_length), 0, _buckets.size() - 1)


## Puts slime id in the bucket of its distance along the loop. Returns true
## if it was added or moved to another bucket, false if it was already in
## that bucket (nothing changes then).
func place(id: int, distance: float) -> bool:
	var b := bucket_index(distance)
	var old: int = _bucket_of.get(id, -1)
	if old == b:
		return false
	if old != -1:
		_take_out(id, old)
	var ids := _buckets[b]
	ids.insert(ids.bsearch(id, true), id)
	_buckets[b] = ids
	_bucket_of[id] = b
	return true


## Takes slime id out of its bucket. Returns false if it wasn't in one.
func drop(id: int) -> bool:
	var old: int = _bucket_of.get(id, -1)
	if old == -1:
		return false
	_take_out(id, old)
	_bucket_of.erase(id)
	return true


## Whether slime id is in a bucket.
func has(id: int) -> bool:
	return _bucket_of.has(id)


## The bucket slime id is in, -1 if it isn't in one.
func bucket_of(id: int) -> int:
	return _bucket_of.get(id, -1)


## How many slimes are in the buckets.
func size() -> int:
	return _bucket_of.size()


## Empties every bucket; the cut is kept.
func clear() -> void:
	for b in _buckets.size():
		_buckets[b] = PackedInt32Array()
	_bucket_of.clear()


## Every slime's id, front-first: the last bucket first, down to bucket 0,
## ascending id inside a bucket.
func order() -> PackedInt32Array:
	var out := PackedInt32Array()
	for b in range(_buckets.size() - 1, -1, -1):
		out.append_array(_buckets[b])
	return out


## The distances along the loop where one bucket ends and the next begins
## (bucket length, twice it, ... below the loop's length), for a debug
## overlay.
func boundaries() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in range(1, _buckets.size()):
		out.append(k * _bucket_length)
	return out


## Removes id from bucket b's sorted ids (it must be there).
func _take_out(id: int, b: int) -> void:
	var ids := _buckets[b]
	var at := ids.bsearch(id, true)
	assert(at < ids.size() and ids[at] == id, "LoopBuckets: id not in its bucket")
	ids.remove_at(at)
	_buckets[b] = ids
