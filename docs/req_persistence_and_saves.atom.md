---
id: req_persistence_and_saves
status: DRAFT
version: 1.3
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
The save holds each slime's species, size, state and position, and the state of every interactive object and gate. There is one save file per level; a parent can delete one level's save from settings. Deleting removes the save and its backup; if that level is running, it reloads fresh at once, as on a fresh install: the first-play hint is due again, and the celebration can play again when the level is completed again. The session or bedtime and their timers carry on untouched. Where the session lives: while v1 has one level, the session (its phase, elapsed time and clock anchor) is kept in the level's save, so a killed app resumes where it was; deleting the level's save keeps the running session and writes it into the fresh save, so deleting a save can't dodge bedtime. With several levels (a later version), the session moves to a store of its own, outside any level's save. The game saves every 15 s and whenever the app goes to the background. On load, a slime saved in mid-air is put on the ground or back at the start of its jump, whichever is easier to build; if neither works, it is lost. Saves are never wiped: a released level isn't meant to change, and if one does, the change is minor and ships with a save migration, with slimes it displaces treated as lost; the save records the level's version, and slimes, objects and gates have stable IDs. Saves are written atomically, and the previous one is kept as a backup used if the latest can't be read; if neither can be read, that level starts fresh.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. The delete-one-level-save action is gated by req_parent_gate_and_access. Implemented in src/sim/save_data.gd (save format 1). Additions to the format so far are additive and keep format 1, so older saves still load: optional keys with safe defaults when absent (the celebration's double hops still due, 'transient.frontier.celebration_hops'; the camera's gate-show progress, 'show_distance' and 'show_tick', also in the state hash; the stuck-slime counts and log, 'stuck_slimes'; each slime body's ring detail level, 'detail', absent meaning 0, full detail; the off-screen state's crowd level, 'offscreen.crowd_level', absent meaning 0), and the train's log of stalled slimes under 'train.stalled' (an older 'train.lost' key is ignored). An older save's 'low': true on a body, from before 'detail' existed, loads as detail level 2, so those saves still load with the same rings. A reload with these keys is exact: the same state and the same run after it. The user approved this format change (2026-09-30).

Pending the user's sign-off (proposed, not settled; the rule above, slimes a migration displaces treated as lost, is what is settled until then; the build already does this): a migration keeps a displaced sleeper asleep. A sleeper the migration displaces (its stable ID is no longer a sleeper of the level, its spot moved, or its species changed) is put back asleep, with no body, its species, size and runtime id kept: at its own stable ID's spot when the level still has that sleeper (the save's species kept), otherwise at the level's empty sleeper spot (one no slime of the save holds) nearest its saved centre, whose stable ID it then takes; each spot takes one sleeper, in save order, ties going to the first stable ID. Only awake displaced slimes, and a displaced sleeper left with no spot, are treated as lost. Implemented in src/sim/save_migration.gd (SaveMigration.sleeper_homes and the migration's resettling of sleepers); guarded by tests/unit/test_save_migration.gd, including the phone's save of the test level's version 1 (2026-09-30), which now migrates with every sleeper asleep and nothing lost. rule_saves_never_wiped (STABLE, on the contract's guaranteed surface) states the settled wording too, and changes only with the user's sign-off.

## EXPECTATION
Killing the app at any moment and reopening it restores slimes, objects and gates as of the last save (at most about 15 s old), with no slime left in mid-air (definition of done item 28). Deleting one level's save resets that level only; its backup goes too, and a running level reloads fresh at once, with the hint and the celebration due again, while the session timers carry on (definition of done item 29): a session or bedtime running when the save is deleted is still running in the fresh save and ends on time.
