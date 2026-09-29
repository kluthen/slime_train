---
id: rule_stalled_train_slime_moved_to_start
status: DRAFT
layer: BUSINESS
version: 1.2
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
A train slime is stalled when its progress along the loop has not advanced by at least 24 px within 60 s, on screen or off, or when its centre leaves the level's bounds. A stalled train slime is moved to the start of the loop and rides the train again, as a lost free slime or a stuck slime is: it lands on the first free spot of a short row of spots there, one slime width apart. Each case is logged, with the reason 'stalled' or 'out_of_bounds', and the 60 s count starts again from the move. A slime asleep at bedtime is never counted as stalled, and never moved. Stalled is distinct from lost: lost applies to free slimes only. It is a safety net for play, not something that happens in normal play.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Implemented in src/sim/train.gd: after the bodies tick, Train.follow re-derives each train slime's progress (Train.advance) and asks Train.stall_of for a reason: STALLED when the progress hasn't advanced STALL_ADVANCE (24 px) in STALL_SECONDS (60 s), OUT_OF_BOUNDS when the centre is outside Train.bounds (the level's extent, Train.bounds_for). The slime is then moved by LoopStart.move (src/sim/loop_start.gd: the first free spot of SPOTS = 8, one slime width apart; shared with rule_left_alone_and_lost and rule_stuck_slimes_moved_to_start) and logged in Train.stalled, which keeps the last STALL_LOG_SIZE (64) cases and is saved under the train's 'stalled' key. Sibling of rule_left_alone_and_lost, which covers free slimes.

## EXPECTATION
A train slime whose progress does not advance 24 px in 60 s, or that leaves the level's bounds, is moved to a free spot at the start of the loop, carries on as part of the train, and is logged as 'stalled' or 'out_of_bounds'; wedged again, it is moved and logged again. No slime asleep at bedtime is counted as stalled or moved. In a no-input session over the whole current loop no train slime stalls, and a stall the safety net moved still fails that check (definition of done item 1).
