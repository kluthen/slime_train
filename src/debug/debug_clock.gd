class_name DebugClock
extends RefCounted
## The session's real clocks, sped up with the debug overlay's speed
## (DebugOverlay). Debug builds only. It wraps the game's clock (SessionClock,
## or a test's stand-in: anything with a now() returning a Session.reading())
## and adds `extra_ms` to both its wall and its monotonic clock: while the
## speed is N, every real millisecond adds N - 1 more. At 10x a session so
## runs ten times faster, like the simulation, and bedtime comes after 90
## real seconds instead of 15 minutes.
##
## Both clocks get the same offset, so the session's rule (the larger of the
## two within an epoch) counts it once. The offset only grows: going back to
## 1x keeps it, so time never runs backwards. A restarted app starts a new
## epoch without the offset; the session then counts the wall clock's gap
## since the last reading, which is 0 until the real wall clock has caught up
## with the sped-up one (the time played fast is not counted twice).

## The clock wrapped.
var inner: RefCounted
## Simulated seconds per real second (DebugOverlay.SPEEDS).
var speed := 1
## Milliseconds added to both clocks so far.
var extra_ms := 0

var _last_mono := -1


func _init(wrapped: RefCounted) -> void:
	inner = wrapped


## The wrapped clock's reading, sped up (see the class doc).
func now() -> Dictionary:
	var reading: Dictionary = inner.now()
	if reading.is_empty():
		return reading
	var mono := int(reading["mono_ms"])
	if _last_mono >= 0 and mono > _last_mono:
		extra_ms += (maxi(1, speed) - 1) * (mono - _last_mono)
	_last_mono = mono
	return Session.reading(int(reading["wall_ms"]) + extra_ms, mono + extra_ms, str(reading["epoch"]))
