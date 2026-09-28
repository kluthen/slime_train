class_name SessionClock
extends RefCounted
## The real clocks for sessions (Session): the scene layer reads them here,
## the simulation never does. now() is a Session.reading():
##   - "wall_ms": the wall clock, Unix time in milliseconds (it survives a
##     killed app and a phone restart, and the player can change it);
##   - "mono_ms": Godot's monotonic clock (Time.get_ticks_usec()), which
##     starts at 0 with the process;
##   - "epoch": this process's run of that monotonic clock, so a session can
##     tell a restart (a new epoch) from time passing (see Session).
## The game root reads it before every tick in normal play; tests replace it
## with anything that has a now() returning a reading.
# @spec-link [[req_session_lifecycle]]

static var _epoch := ""


## The clocks now.
func now() -> Dictionary:
	return Session.reading(int(Time.get_unix_time_from_system() * 1000.0), floori(Time.get_ticks_usec() / 1000.0), epoch())


## This process's epoch: its ID and when it started, wall clock (unique
## enough across restarts).
static func epoch() -> String:
	if _epoch.is_empty():
		var started_ms := int(Time.get_unix_time_from_system() * 1000.0) - Time.get_ticks_msec()
		_epoch = "%d@%d" % [OS.get_process_id(), started_ms]
	return _epoch
