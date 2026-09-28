---
id: user_story_watching_sibling_p2
status: DRAFT
tags: [persona,secondary]
version: 1.0
layer: BUSINESS
human_name: Watching sibling persona (P2)
parents: []
dependents: []
type: USER_STORY
priority: 3
---

# Watching sibling persona (P2)

## INTENT
Describe the secondary persona, a 2-year-old sibling who watches and sometimes pokes the screen, and how v1 serves his goals without letting him disrupt play.

## THE RULE / LOGIC
P2 is the newcomer's 2-year-old brother, who watches and sometimes pokes the screen at the same time she plays. His goals and how v1 serves them: (1) Watch the slimes, served fully the same way as P1's goal to watch (the train running with no input, idle camera, screensaver mode). (2) Poke the screen without breaking anything, served only partially by design: only the first finger down counts, so while his sister's finger is down his poke does nothing, and every parent button asks for the code so he can't trigger a parent action; two simultaneous calls are explicitly deferred to a later version, which is why this goal is only partially served rather than fully.

## TECHNICAL INTERFACE
Restated from the master spec's persona table (section 2) and its persona-tension note 'P2 pokes while P1 plays: the first touch wins, so P1's play isn't hijacked.'

## EXPECTATION
While one finger is down, a second touch does nothing (definition of done item 17); no parent action is triggered by a child's touch without the correct code.
