---
id: vision_atd
status: DRAFT
layer: BUSINESS
dependents: []
type: VISION
priority: 5
tags: [vision,scope]
parents: []
version: 1.0
human_name: Vision
---

# Vision Atd

## INTENT
State what Slime Train v1 is meant to become, so every business-level atom can be checked against its scope and design philosophy.

## THE RULE / LOGIC
Slime Train is an interactive screensaver for Android, aimed at children aged 3 to 5, inspired by LocoRoco Cocoreccho!. A train of squishy slimes hops around a loop through a soft, curved, side-view world. The child calls slimes off the loop to wake sleeping slimes, lets same-species slimes fuse into bigger ones, and fills baskets to open gates so the loop grows into new sections.

Design stance (in scope for every version, not just v1):
- Watching is playing: the world keeps moving and stays pleasant to watch with no input at all; input adds to it but is never needed to keep things alive.
- Nothing to fail: no failure state, no score, no text for the child; the worst case is a slime that got lost and reappears at the start of the loop.
- Every touch is answered: any tap anywhere does something visible.
- Sessions end softly: a session lasts 15 minutes and ends with the slimes falling asleep; leaving the app needs a parent code.
- Simple, curved, high contrast, low detail visual style.

v1's objective is one level in which a child can discover every core mechanic, a session lock the parent trusts, and a code base built so that further levels are content rather than code (no per-level scripts).

In scope for v1: one level of 4 sections; 6 species told apart by colour; the core slime mechanics (train, sleepers, calls, free slimes, fusion up to size 3, the split zone at the loop start); the frontier switch-plus-basket-plus-gate set as the only way to open a gate; tap-to-call, tilt for free slimes, edge-button camera, parent access; screensaver mode, timed sessions, bedtime, parent code with setup and recovery, screen pinning; one save per level; a non-shipped test level and test mode; Godot 4 targeting Android with a Linux desktop dev build; a paid app with no purchases inside it.

Out of scope for v1 (each deferred to a later version, per the master spec's own scope table, not abandoned): sound of any kind; every interactive object beyond the frontier set (bending pathways, other split zones, tilt objects, reveal zones, filters/size-sorting forks, other switches and baskets); large branch-choosing signposts; turning the parent code off; a parent-chosen session length and cooldown; a freeform drag camera; species behaviour quirks, a maximum size above 3, cross-species fusion; other frontier-gate patterns; paid extra levels, theming, a music generator, procedural generation, iOS; two simultaneous calls. The design of the real first level itself (levels/01/) is also out of v1's specified scope: it is designed later, once the test level has been built and checked.

## TECHNICAL INTERFACE
Read by documentalist before creating or altering any BUSINESS-layer atom (VISION gate). Never listed in any atom's parents/dependents.

## EXPECTATION
A BUSINESS-layer atom proposed for this project can be checked against this statement: if its rule falls outside the in-scope list above and is not explicitly named as deferred, it is out of scope and VISION must be revised (with human sign-off) before the atom is accepted.
