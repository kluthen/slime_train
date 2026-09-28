---
id: req_waking_sleepers
status: DRAFT
layer: BUSINESS
human_name: Waking sleepers
tags: [sleepers,waking]
parents:
  - [[req_slime_states]]
version: 1.0
type: REQUIREMENT
priority: 4
dependents: []
---

# Waking sleepers

## INTENT
Define how a sleeper is woken and by whom.

## THE RULE / LOGIC
Tapping a sleeper is a call centred on it. A sleeper wakes only when a free slime touches it on screen; train slimes never wake sleepers. The woken slime becomes free and, in time, heads back to the train through the normal free-slime phases.

## TECHNICAL INTERFACE
Parented to req_slime_states. Depends on req_call_mechanic for the free-slime phases the woken slime then goes through.

## EXPECTATION
A sleeper wakes only when touched, on screen, by a free slime; a train slime touching it doesn't wake it (definition of done item 2).
