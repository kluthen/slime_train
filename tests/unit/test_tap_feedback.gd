extends GutTest
## TapFeedback (src/taps/tap_feedback.gd) draws each slime's eye only when
## the slime can be seen (SlimeRenderer.is_seen): not parked and on the
## shown part of the world, give or take its reach. Drawing only: the
## simulation doesn't change.

const SHOWN := Rect2(0, 0, 1000, 600)


func test_only_seen_slimes_get_an_eye() -> void:
	var slimes := SlimeBodies.new(Rng.new(3))
	var near := slimes.create(0, 1, Vector2(500, 300))
	var edge := slimes.create(1, 2, Vector2(-10, 300))
	var far := slimes.create(2, 1, Vector2(5000, 300))
	var parked := slimes.create(3, 1, Vector2(600, 300))
	slimes.park(parked)
	var eyed := TapFeedback.eyed_slimes(slimes, SHOWN)
	assert_true(near in eyed)
	assert_true(edge in eyed, "a slime straddling the edge keeps its eye")
	assert_false(far in eyed, "off the view")
	assert_false(parked in eyed, "parked")
	assert_eq(eyed.size(), 2)


func test_no_slimes_no_eyes() -> void:
	assert_eq(TapFeedback.eyed_slimes(SlimeBodies.new(Rng.new(3)), SHOWN).size(), 0)
