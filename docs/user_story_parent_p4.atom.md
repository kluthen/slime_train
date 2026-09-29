---
id: user_story_parent_p4
status: DRAFT
type: USER_STORY
human_name: Parent persona (P4)
tags: [persona,supporting]
parents: []
version: 1.1
layer: BUSINESS
priority: 4
dependents: []
---

# Parent persona (P4)

## INTENT
Describe the supporting persona, the parent who owns and sets up the phone, and how v1 serves her oversight goals.

## THE RULE / LOGIC
P4 owns the phone and buys and sets up the game. Her goals and how v1 serves them: (1) A calm activity that ends on its own, served fully by 15-minute sessions, a gentle wind-down and bedtime, and a 10-minute cooldown. (2) The child can't leave, change or buy anything, served only partially: screen pinning plus the parent code are best-effort by design, not a guarantee (see req_screen_pinning), and there are no purchases inside v1. (3) Set it up once, easily, served fully by a one-time setup at first launch. (4) Take the phone back or give more time at will, served fully by the parent buttons (wake early, leave, and settings) and by the time left, shown to her behind the code.

Persona tensions settled for v1 that bear on P4: the parent code is 6 digits even though a 4-year-old (P3) may know digits, a risk knowingly accepted; and P1's unknown hold on the phone means tilt is a bonus, never needed to make progress, so P4 never has to worry about accidental tilt blocking play.

## TECHNICAL INTERFACE
Restated from the persona table and persona-tensions list decided for v1. Served by req_parent_gate_and_access, rule_time_left_shown_only_behind_code, req_session_lifecycle and req_screen_pinning.

## EXPECTATION
Every parent-only action (wake early, leave, change the code, delete a level's save) is refused without the correct code (definition of done item 24); a session started with no parent input still ends on its own within 15 minutes plus the wind-down.
