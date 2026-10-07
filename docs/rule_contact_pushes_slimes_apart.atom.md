---
id: rule_contact_pushes_slimes_apart
status: DRAFT
dependents: []
version: 1.0
tags: [slimes,contacts,stuck]
parents:
  - [[req_slime_states]]
type: RULE
layer: BUSINESS
priority: 4
human_name: Slimes in contact are pushed apart however deep they overlap
---

# Slimes in contact are pushed apart however deep they overlap

## INTENT
Keep one slime from ever being drawn inside another by their contact.

## THE RULE / LOGIC
However deep two slimes in contact are inside each other, even when a point of one has gone past the other's centre, their contact pushes them apart and never draws them together, so they part instead of one ending up inside the other. Slimes that can fuse still fuse after their contact time (rule_fusion_contact_time); this rule governs only which way the contact pushes.

## TECHNICAL INTERFACE
Parented to req_slime_states. Implemented in SlimeSolverGD.solve_contacts (src/sim/slime_solver.gd) and its native port, contact_side (native/slime_native/src/solver_contacts.cpp), bit for bit: a ring point of slime a inside b that has gone past b's centre, seen from a's centre (the rings deeper in each other than a's radius), moves out along its offset from b's centre mirrored back to a's side (across the line through b's centre square to the centres' line), with the same size of push; friction uses the same mirrored normal. While the centres stay at least a's radius apart nothing changes. Pushed straight out from b's centre instead, such a point drew a further into b until the two centres met and nothing pushed any more: that was the cause of slimes of different species ending up inside each other. rule_stuck_slimes_moved_to_start stays in place as the backstop for a pair something else keeps on one spot. Diagnostic tool, not a test: tools/gobble_probe.gd (counts overlaps lasting 2 s or more and stuck moves over a run).

## EXPECTATION
Two slimes that can't fuse, one put inside the other with their centres 0.1 to 0.95 of the smaller ring radius apart, no gravity: within 30 ticks their centres are farther apart than the sum of their ring radii, at the lowest and the highest detail level. A smaller slime put inside a bigger one on the floor is out of it within 240 ticks, its centre outside the bigger ring and the two side by side. The native contacts give the same positions as the GDScript ones bit for bit for such deep pairs, at every substep.
