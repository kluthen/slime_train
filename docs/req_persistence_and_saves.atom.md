---
id: req_persistence_and_saves
status: DRAFT
version: 1.0
type: REQUIREMENT
layer: BUSINESS
priority: 4
human_name: Persistence and saves
tags: [persistence,saves]
dependents:
  - [[rule_saves_never_wiped]]
parents:
  - [[req_loop_and_world]]
---

# Persistence and saves

## INTENT
Define what a save contains and the rules that keep it safe and stable across updates.

## THE RULE / LOGIC
The save holds each slime's species, size, state and position, and the state of every interactive object and gate. There is one save file per level; a parent can delete one level's save from settings. The game saves every 15 s and whenever the app goes to the background. On load, a slime saved in mid-air is put on the ground or back at the start of its jump, whichever is easier to build; if neither works, it is lost. Saves are never wiped: a released level isn't meant to change, and if one does, the change is minor and ships with a save migration, with slimes it displaces treated as lost; the save records the level's version, and slimes, objects and gates have stable IDs. Saves are written atomically, and the previous one is kept as a backup used if the latest can't be read.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. The delete-one-level-save action is gated by req_parent_gate_and_access.

## EXPECTATION
Killing the app at any moment and reopening it restores slimes, objects and gates as of the last save (at most about 15 s old), with no slime left in mid-air (definition of done item 28). Deleting one level's save resets that level only (definition of done item 29).
