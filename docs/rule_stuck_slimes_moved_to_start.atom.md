---
id: rule_stuck_slimes_moved_to_start
status: DRAFT
type: RULE
human_name: Stuck slimes: the smaller one moved to the loop start
priority: 4
tags: [slimes,safety-net,stuck]
version: 1.0
layer: BUSINESS
parents:
  - [[req_slime_states]]
dependents: []
---

# Stuck slimes: the smaller one moved to the loop start

## INTENT
Guarantee that two slimes that can't fuse never stay lodged inside each other.

## THE RULE / LOGIC
Two slimes that can't fuse whose centres stay almost on top of each other for about 2 s are stuck. The smaller of the two is then moved to the start of the loop and rides the train again. Only a train slime or a free slime is ever moved: never a sleeper, a slime in a basket or a bedtime-asleep slime. Each case is logged with the reason 'stuck'. Stuck is its own case, distinct from lost: it doesn't count as a lost slime, but it has the same effect. This is a safety net that stays in place until the cause of slimes ending up inside each other is found and prevented; it is not meant to happen in normal play.

## TECHNICAL INTERFACE
Parented to req_slime_states. Sibling of rule_left_alone_and_lost (free slimes) and rule_stalled_train_slime_moved_to_start (train slimes), which move a slime to the start of the loop the same way. Which pairs can't fuse is decided by rule_fusion_contact_time (same species only) and rule_max_size_three (sizes summing above 3 just bump).

## EXPECTATION
Two slimes of different species placed on the same centre: after about 2 s the smaller one is at the start of the loop, back on the train, and the case is logged as 'stuck'. A same-species pair that can fuse is left to fuse; a pair touching normally is never moved; a sleeper, a slime in a basket or a bedtime-asleep slime is never moved.
