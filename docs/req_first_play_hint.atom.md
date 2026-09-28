---
id: req_first_play_hint
status: DRAFT
version: 1.0
parents:
  - [[req_controls_tap_zones]]
human_name: First-play hint
priority: 4
tags: [hint,first-play,discoverability]
dependents: []
type: REQUIREMENT
layer: BUSINESS
---

# First-play hint

## INTENT
Define the wordless first-play hint that nudges a newcomer toward the first call, and the O71 default that settles when its 10 s wait starts and what resets it.

## THE RULE / LOGIC
On the very first play, if the child hasn't made a call after about 10 s, a wordless pulsing mark appears near the first sleeper. (proposed, D95, pending the user's approval — O71) "The very first play" is the world showing on a fresh save of the level: on first launch, in screensaver mode right after setup, or after that level's save has been deleted. The 10 s count starts from the first frame the world shows, not from the session start, and restarts each time the world shows while the hint is still due. The first call marks the hint as done in the level's save, so it never appears again for that save; deleting the save brings it back. The hint is never shown during bedtime.

## TECHNICAL INTERFACE
Parented to req_controls_tap_zones, whose zone-4 (call) description names the hint only in passing; this atom is its dedicated record. Also serves user_story_newcomer_p1 goal 3 (discovering the call with no one explaining it) and depends on rule_first_sleeper_near_first_awake_slime for the first sleeper's placement.

## EXPECTATION
On a fresh save, if the child hasn't called within about 10 s of the world's first frame, a wordless pulsing mark appears near the first sleeper; it never appears again once the first call is made (definition of done item 16). (proposed, D95, pending the user's approval) The 10 s count restarts each time the world's first frame shows while the hint is still due, screensaver mode included, and deleting the level's save brings the hint back.
