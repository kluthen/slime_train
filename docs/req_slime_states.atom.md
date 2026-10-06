---
id: req_slime_states
status: REVIEW
tags: [slimes,states]
version: 1.1
layer: BUSINESS
parents:
  - [[req_loop_and_world]]
dependents:
  - [[req_call_mechanic]]
  - [[req_hopping_behavior]]
  - [[req_waking_sleepers]]
  - [[rule_contact_pushes_slimes_apart]]
  - [[rule_stuck_slimes_moved_to_start]]
type: REQUIREMENT
priority: 5
human_name: Slime states
---

# Slime states

## INTENT
Define the five states a slime can be in and what each one does.

## THE RULE / LOGIC
A slime is in exactly one of five states. Sleeper: asleep and still, never sits on the loop, wakes only when a free slime touches it on screen; the game wakes the very first slime itself. Train slime: awake, following the loop, ignores tilt. Free slime: awake, away from the loop after answering a call, driven by physics alone and feels tilt. Bedtime-asleep: asleep because the session ended; unlike a sleeper, the game wakes it at sunrise and play carries on. In a basket: caught by a basket's box; in any basket, filling or full, it doesn't hop, isn't part of the train and doesn't answer calls, and it falls and settles in the basket's pile; it leaves only when the basket releases it, and then rides the train again; at bedtime it sleeps in place, and sunrise doesn't move it out of the basket.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Governs req_call_mechanic, req_waking_sleepers, req_hopping_behavior, which describe behaviour per state.

## EXPECTATION
A sleeper wakes only when touched, on screen, by a free slime; a train slime touching it doesn't wake it (definition of done item 2).
