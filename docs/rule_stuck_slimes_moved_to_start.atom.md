---
id: rule_stuck_slimes_moved_to_start
status: DRAFT
type: RULE
human_name: Stuck slimes: the smaller one moved to the loop start
priority: 4
tags: [slimes,safety-net,stuck]
version: 1.1
layer: BUSINESS
parents:
  - [[req_slime_states]]
dependents: []
---

# Stuck slimes: the smaller one moved to the loop start

## INTENT
Guarantee that two slimes that can't fuse never stay lodged inside each other.

## THE RULE / LOGIC
Two slimes that can't fuse whose centres stay almost on top of each other for about 2 s are stuck. 'Can't fuse' means the two couldn't fuse right now: they are of different species, their sizes add up to more than 3, or one of them isn't awake; so a same-species sleeper caught inside a train slime counts as stuck. The smaller of the two is then moved to the start of the loop and rides the train again, landing on the first free spot of a short row of spots there, one slime width apart. Only a train slime or a free slime is ever moved: never a sleeper, a slime in a basket or a bedtime-asleep slime, so when only one of the two may move it is the one moved, whatever its size, and when neither may, nothing moves. Each case is logged with the reason 'stuck'. Stuck is its own case, distinct from lost: it doesn't count as a lost slime, but it has the same effect. This is a safety net that stays in place until the cause of slimes ending up inside each other is found and prevented; it is not meant to happen in normal play.

## TECHNICAL INTERFACE
Parented to req_slime_states. Implemented in src/sim/stuck_slimes.gd (StuckSlimes.step, every tick after the train follows): the simulated slimes are checked in pairs every CHECK_TICKS (30 ticks, 0.5 s); a pair whose centres are closer than CLOSE_SHARE (a quarter) of the smaller one's ring radius counts one check, and at CHECKS (4) checks in a row, 1.5 s after the first, it is stuck; on a size tie the higher id moves; a pair neither of which may move is logged once. The move is LoopStart.move (src/sim/loop_start.gd: the first free spot of SPOTS = 8, one slime width apart), shared with rule_left_alone_and_lost (free slimes) and rule_stalled_train_slime_moved_to_start (train slimes). The log keeps the last LOG_SIZE (64) cases and, with the counts, is saved under 'stuck_slimes'. Which pairs can fuse is decided by rule_fusion_contact_time (same species only) and rule_max_size_three (sizes summing above 3 just bump).

## EXPECTATION
Two slimes of different species placed on the same centre: after about 2 s the smaller one is on a free spot at the start of the loop, back on the train, and the case is logged as 'stuck'. A same-species pair too big to fuse is stuck too; a same-species pair that can fuse is left to fuse; a pair touching normally is never moved; a sleeper, a slime in a basket or a bedtime-asleep slime is never moved, even when it is the smaller of the pair.
