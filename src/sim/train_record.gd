class_name TrainRecord
extends RefCounted
## Train's record of one train slime (Train's `_records`, by slime id): its
## progress along the loop, whether it is on a slide, and its stall clock's
## last mark (see Train's class doc). Saves and dumps read it as the
## Dictionary of to_dict(); Train.restore_record() takes one back.

## Its distance along the loop from the start, px (0 to Train.length()).
var distance := 0.0
## The laps of the loop it has completed.
var laps := 0
## Whether it is on a return route (a slide; set by Train.steer()).
var on_slide := false
## The progress (laps included) last counted as an advance.
# @spec-link [[rule_stalled_train_slime_moved_to_start]]
var mark := 0.0
## The tick of that mark, moved on by the ticks parked since (Train's class
## doc); -1 before the first Train.follow().
var marked_at := -1


## A fresh record at `at` px along the loop: no laps, off the slide, marked
## there with no tick yet (Train.track()).
func _init(at := 0.0) -> void:
	distance = at
	mark = at


## A copy of this record (a split part carries on from where the slime was).
func copy() -> TrainRecord:
	var out := TrainRecord.new(distance)
	out.laps = laps
	out.on_slide = on_slide
	out.mark = mark
	out.marked_at = marked_at
	return out


## The record as plain data, for saves (Train.record_of()): {"distance",
## "laps", "on_slide", "mark", "marked_at"}.
# @spec-link [[req_persistence_and_saves]]
func to_dict() -> Dictionary:
	return {"distance": distance, "laps": laps, "on_slide": on_slide, "mark": mark, "marked_at": marked_at}
