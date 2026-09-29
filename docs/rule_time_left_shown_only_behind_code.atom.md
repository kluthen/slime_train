---
id: rule_time_left_shown_only_behind_code
status: DRAFT
priority: 3
tags: [parent-gate,session]
version: 1.0
type: RULE
parents:
  - [[req_parent_gate_and_access]]
human_name: Time left shown only behind the parent code
dependents: []
layer: BUSINESS
---

# Time left shown only behind the parent code

## INTENT
Let the parent see how much time is left without the child being able to see it or reach it.

## THE RULE / LOGIC
The time left, in the session or, during bedtime, until sunrise, is shown to the parent only behind the code: in the settings header and on the wake-early prompt. It is never shown on the parent buttons, which anyone can reveal, nor anywhere else the child can reach without the code.

## TECHNICAL INTERFACE
Parented to req_parent_gate_and_access. Reads the session and cooldown timers defined by req_session_lifecycle. Serves user_story_parent_p4's goal of taking the phone back or giving more time at will.

## EXPECTATION
The time left (in the session, or until sunrise during bedtime) shows in the settings header and on the wake-early prompt, and nowhere the child can reach without the code, the parent buttons included (definition of done item 24).
