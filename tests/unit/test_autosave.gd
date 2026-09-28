extends GutTest
## Autosave (src/save/autosave.gd): due every 15 s of wall time since the
## last save, and whenever the app goes to the background (the notifications
## listed in Autosave.is_background). Off, it is never due.

# @test-link [[req_persistence_and_saves]]


func test_due_every_fifteen_seconds_of_wall_time() -> void:
	var autosave := Autosave.new()
	assert_eq(Autosave.INTERVAL_SECONDS, 15.0)
	autosave.start(100.0)
	assert_false(autosave.due(100.0))
	assert_false(autosave.due(114.9))
	assert_true(autosave.due(115.0))
	autosave.saved(115.2)
	assert_false(autosave.due(130.0))
	assert_true(autosave.due(130.2))


func test_never_due_when_off() -> void:
	var autosave := Autosave.new()
	autosave.enabled = false
	autosave.start(0.0)
	assert_false(autosave.due(1000.0))


func test_the_interval_can_be_changed() -> void:
	var autosave := Autosave.new()
	autosave.interval = 0.5
	autosave.start(10.0)
	assert_false(autosave.due(10.4))
	assert_true(autosave.due(10.5))


func test_background_notifications() -> void:
	for what in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT,
			Node.NOTIFICATION_WM_CLOSE_REQUEST, Node.NOTIFICATION_WM_GO_BACK_REQUEST]:
		assert_true(Autosave.is_background(what), str(what))
	for what in [Node.NOTIFICATION_APPLICATION_RESUMED, Node.NOTIFICATION_APPLICATION_FOCUS_IN,
			Node.NOTIFICATION_READY, Node.NOTIFICATION_PROCESS]:
		assert_false(Autosave.is_background(what), str(what))
