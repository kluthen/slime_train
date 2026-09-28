---
id: rule_left_alone_and_lost
status: DRAFT
human_name: Left-alone and lost safety net
tags: [free-slime,safety-net]
parents:
  - [[req_call_mechanic]]
layer: BUSINESS
dependents: []
version: 1.0
type: RULE
priority: 4
---

# Left-alone and lost safety net

## INTENT
Guarantee that a free slime is never permanently stranded off the loop.

## THE RULE / LOGIC
A free slime off screen for more than 10 s is left alone. A left-alone slime not back on the loop after 1 min is lost, and a lost slime is moved to the start of the loop. A free slime that stays on screen is never lost. Because of the level design rules (every exploration branch has its own route back, and gravity leads back toward the loop from anywhere a free slime can reach), 'lost' is meant to be a safety net rather than something that happens in normal play.

## TECHNICAL INTERFACE
Parented to req_call_mechanic. Interacts with req_offscreen_simulation (a free slime that leaves the screen is placed on its area's route back, or is lost if none is near) and level rules rule_gravity_leads_back_to_loop, rule_exploration_branch_has_route_back.

## EXPECTATION
A free slime off screen for 10 s is left alone; if it isn't back on the loop 1 min later, it reappears at the start of the loop; a free slime kept on screen is never lost (definition of done item 5).
