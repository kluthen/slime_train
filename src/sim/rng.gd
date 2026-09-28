class_name Rng
extends RefCounted
## The one seeded random generator. Every gameplay random number (hop timing,
## unsure hops, anything later chunks add) comes from an Rng, never from
## Godot's global randi()/randf()/randomize() or Array.shuffle()/pick_random():
## those use a process-wide generator that tests can't seed, so runs would not
## repeat. tests/unit/test_no_global_random.gd enforces the rule on src/.
##
## The simulation owns the master Rng. derive(name) gives an independent
## stream (for one slime, say) whose seed depends only on the master seed and
## the name, so streams repeat however many numbers other streams have drawn
## and whatever order they were created in.

var seed_value: int:
	get:
		return _generator.seed

## The generator's position in its sequence. Save it to resume the sequence.
var state: int:
	get:
		return _generator.state
	set(value):
		_generator.state = value

var _generator := RandomNumberGenerator.new()


func _init(initial_seed: int) -> void:
	_generator.seed = initial_seed


## A seed for a stream named `name` under `master_seed`: the first 8 bytes,
## little-endian, of SHA-256("<master_seed>/<name>"). Stable across processes
## and platforms (String.hash() isn't documented as stable, so it isn't used).
static func derive_seed(master_seed: int, name: String) -> int:
	return ("%d/%s" % [master_seed, name]).sha256_buffer().decode_s64(0)


## A fresh seed for normal play, where runs don't need to repeat. The only
## place allowed to draw from the system's entropy.
static func random_seed() -> int:
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	return generator.seed


## An independent stream, repeatable from the master seed and `name` alone.
## Doesn't draw from this generator.
func derive(name: String) -> Rng:
	return Rng.new(derive_seed(seed_value, name))


## A random 32-bit unsigned integer.
func randi() -> int:
	return _generator.randi()


## A random integer between `from` and `to`, both included.
func randi_range(from: int, to: int) -> int:
	return _generator.randi_range(from, to)


## A random float between 0 and 1.
func randf() -> float:
	return _generator.randf()


## A random float between `from` and `to`.
func randf_range(from: float, to: float) -> float:
	return _generator.randf_range(from, to)


## A random element of `items` (null when it is empty).
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_generator.randi_range(0, items.size() - 1)]
