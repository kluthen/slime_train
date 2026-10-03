---
id: rule_left_alone_and_lost
status: REVIEW
human_name: Left-alone and lost safety net
tags: [free-slime,safety-net]
parents:
  - [[req_call_mechanic]]
layer: BUSINESS
dependents: []
version: 1.1
type: RULE
priority: 4
---

# Left-alone and lost safety net

## INTENT
Guarantee that a free slime is never permanently stranded off the loop.

## THE RULE / LOGIC
A free slime off screen for more than 10 s is left alone. A left-alone slime not back on the loop after 1 min is lost, and a lost slime is moved to the start of the loop. A free slime that stays on screen is never lost. Because of the level design rules (every exploration branch has its own route back, and gravity leads back toward the loop from anywhere a free slime can reach), 'lost' is meant to be a safety net rather than something that happens in normal play.

## TECHNICAL INTERFACE
Parented to req_call_mechanic. Interacts with req_offscreen_simulation (a free slime that leaves the screen is placed on its area's route back, or is lost if none is near) and level rules rule_gravity_leads_back_to_loop, rule_exploration_branch_has_route_back. Implemented in src/sim/offscreen.gd: the off-screen count ('away', saved) finds the lost slimes; the loop-start queue (src/sim/loop_start_queue.gd) moves each at its turn with Offscreen.lose and LoopStart.move (src/sim/loop_start.gd), the move shared with rule_stuck_slimes_moved_to_start and rule_stalled_train_slime_moved_to_start, and the case is logged in Offscreen.lost.

Pending the user's sign-off (the user set the direction on 2026-10-02; the wording and details below are proposed, not settled; the rule and expectation above are what is settled until then; the build already does this): a lost slime is no longer moved the tick it is lost. It waits its turn in one queue shared with stuck and stalled slimes, one move at a time, the next turn 30 to 120 ticks (0.5 to 2 s) after the last move; while it waits it carries on as it would, and if it comes back on screen or is no longer free it leaves the queue without a move. It lands on a random free spot on the loop's first 240 px (up to 8 draws, inside a split zone, no other slime's ring overlapping; with every draw taken the queue tries again on the next multiple of 30 ticks). Two moves stay immediate, outside the queue: the debug overlay's kill tool (debug builds only), which still counts as a move for the next turn's wait, and a slime lost while a save loads. So the expectation's 'it reappears at the start of the loop' holds after the slime's turn.

## EXPECTATION
A free slime off screen for 10 s is left alone; if it isn't back on the loop 1 min later, it reappears at the start of the loop; a free slime kept on screen is never lost (definition of done item 5).
