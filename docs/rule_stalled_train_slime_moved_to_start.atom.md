---
id: rule_stalled_train_slime_moved_to_start
status: DRAFT
layer: BUSINESS
version: 1.4
tags: [train,safety-net,stalled]
parents:
  - [[req_loop_and_world]]
human_name: Stalled train slime moved to the loop start
priority: 4
dependents: []
type: RULE
---

# Stalled train slime moved to the loop start

## INTENT
Guarantee that a train slime is never permanently wedged somewhere on or off the loop, in the same way a lost free slime is never stranded.

## THE RULE / LOGIC
A train slime is stalled when its progress along the loop has not advanced by at least 24 px within 60 s of being simulated (the count pauses while the slime is parked off screen and resumes where it was; progress made while parked still counts), or when its centre leaves the level's bounds, parked or not. A stalled train slime is due a move to the start of the loop, as a lost free slime or a stuck slime is: at its turn, one move at a time, it is moved there and rides the train again, landing on a random free spot on the loop's first stretch. Each case is logged, with the reason 'stalled' or 'out_of_bounds', and the 60 s count starts again from the move. A slime asleep at bedtime is never counted as stalled, and never moved. Stalled is distinct from lost: lost applies to free slimes only. It is a safety net for play, not something that happens in normal play.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Implemented in src/sim/train.gd: after the bodies tick, Train.follow re-derives each train slime's progress (Train.advance) and asks Train.stall_of for a reason: STALLED when the progress hasn't advanced STALL_ADVANCE (24 px) in STALL_SECONDS (60 s), OUT_OF_BOUNDS when the centre is outside Train.bounds (the level's extent, Train.bounds_for). The Train no longer moves the slime itself: the slime is due a move, and the loop-start queue (src/sim/loop_start_queue.gd, LoopStartQueue.step, last in Simulation.step) moves it at its turn with LoopStart.move (src/sim/loop_start.gd), the move shared with rule_left_alone_and_lost and rule_stuck_slimes_moved_to_start. The case is logged in Train.stalled, which keeps the last STALL_LOG_SIZE (64) cases and is saved under the train's 'stalled' key. Sibling of rule_left_alone_and_lost, which covers free slimes.

Settled by the user (the direction, 2026-10-02; the wording and details below approved as proposed, 2026-10-07; the build does this), except the pause's scope in (1):
(1) The 60 s count runs only while the train slime is simulated. While it is parked the count pauses; once it is simulated again the count resumes where it was, not from zero. Progress made while parked still counts as progress, and a slime outside the level's bounds is still due at once, parked or not. Still open, its proposed default unanswered: whether the pause covers every parked train slime, as built, or only one waiting in the single-file line kept behind the train slime ahead. Built in Train.follow, which moves a parked slime's last-mark tick ('marked_at', already saved) on by one for each parked tick; no new save key.
(2) Moves to the loop start go one at a time, through one queue shared with lost and stuck slimes. After each move the next turn comes 30 to 120 ticks (0.5 to 2 s) later, drawn from a derived random stream. Slimes out of bounds go first, then first due, first moved, ties by id. While it waits a slime carries on as it would; one whose reason no longer holds leaves the queue without a move. The queue is rebuilt from saved state, never saved itself.
(3) The slime lands on a random free spot: up to 8 draws along the loop's first 240 px (LoopStart.free_spot), a spot being free when it lies inside a split zone and no other slime's ring there would overlap the slime's. With every draw taken nobody moves, and the queue tries again on the next multiple of 30 ticks.

## EXPECTATION
A train slime whose progress does not advance 24 px in 60 s, or that leaves the level's bounds, is moved at its turn to a free spot at the start of the loop, carries on as part of the train, and is logged as 'stalled' or 'out_of_bounds'; wedged again, it is moved and logged again. No slime asleep at bedtime is counted as stalled or moved. In a no-input session over the whole current loop no train slime stalls, and a stall the safety net moved still fails that check (definition of done item 1).
