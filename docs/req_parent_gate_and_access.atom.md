---
id: req_parent_gate_and_access
status: DRAFT
version: 1.1
priority: 5
human_name: Parent gate and parent access
parents:
  - [[req_controls_tap_zones]]
type: REQUIREMENT
layer: BUSINESS
tags: [parent-gate,access]
dependents:
  - [[req_actor_roles_and_permissions]]
  - [[req_screen_pinning]]
  - [[rule_no_network_connection]]
  - [[rule_parent_code_not_stored_plaintext]]
  - [[rule_time_left_shown_only_behind_code]]
---

# Parent gate and parent access

## INTENT
Define the 6-digit parent code and every flow that uses it to gate a parent-only action.

## THE RULE / LOGIC
The parent code has 6 digits; it is stored only on the phone, never in plain text (see rule_parent_code_not_stored_plaintext). First launch: a one-time setup appears before anything else, in four steps: welcome, the code (typed twice), what happens if the code is forgotten, and screen pinning. It explains screen pinning and states plainly that on a phone with no screen lock, a forgotten code can only be reset by clearing the app's data, which erases all progress. The code is saved only when setup finishes; an interruption before that keeps no code and restarts setup from the first step. Parent access: a tap on the parent zone (the band along the top of the screen) reveals the parent buttons: wake early (ends bedtime or the cooldown; shown only during bedtime), leave (ends screen pinning and lets the parent leave the app), and settings (change the code, delete one level's save). Every button asks for the code before doing anything, immediately before the action; deleting a level's save asks for a second confirmation after the code. The buttons hide after 5 s with no press; another tap on the parent zone restarts the 5 s. A tap outside an open parent surface (the buttons or the code prompt) closes it and also does its normal job: it calls, operates an object or moves the camera, and starts a session if it reaches the world. Settings and setup fill the screen. The time left is shown to the parent only behind the code (see rule_time_left_shown_only_behind_code). Forgotten code: 'forgot the code?' on the code prompt hands off to the phone's own screen lock through Android's system prompt (PIN, pattern or fingerprint); if it succeeds, the parent sets a new code, typed twice as at setup, which replaces the old one at once; the parent is then back at the code prompt for the action they started, with the wrong tries and any wait cleared. Cancelling or failing Android's prompt returns to the code prompt, with nothing changed and no wrong try counted. On a phone with no screen lock, 'forgot the code?' explains that clearing the app's data in Android settings is the only way, and that it erases all progress; nothing else happens. A wrong code makes the entry shake and clear; tries are unlimited, but 5 wrong tries in a row bring a 30 s wait (req_denial_and_stepup_behavior says how the count is kept). The code prompt closes after about 15 s with no input. The settings screen closes by itself after 30 s with no input, with a warning over the last 10 s; any touch resets it, and the same 30 s covers the screens opened from settings. Opening the parent buttons or the code prompt pauses nothing: the world keeps running and the session keeps counting. Changing the code takes effect immediately and the old code stops working; there is no 'remember me', so every new parent action asks for the code again. There is exactly one code for the whole app. Language: the parent-facing text (setup, the code prompt, settings, the forgotten-code screens) follows the phone's language when v1 has it, and is in English otherwise; v1 ships English and French, and the French addresses the parent as 'vous'. The child sees no text. Everything the parent taps is at least 9 x 9 mm on the screen, with at least 2 mm between neighbours.

## TECHNICAL INTERFACE
Parented to req_controls_tap_zones (zone 1, top of screen). Governs req_session_lifecycle's wake-early path and req_persistence_and_saves's delete-a-save path. See also req_actor_roles_and_permissions and req_denial_and_stepup_behavior for the formal role/permission model this access flow implements.

## EXPECTATION
On first launch the parent setup appears before anything else, runs in four steps and requires the 6-digit code twice; it is never shown again; its text is in French on a French phone and in English otherwise; a setup interrupted before its last step keeps no code and starts again from the first step (definition of done item 23). Every parent action (wake early, leave, change the code, delete a level's save) is refused without the correct code; the parent buttons hide after 5 s; a tap outside the buttons or the code prompt closes it and also does its normal job; settings close after 30 s with no input, warning over the last 10 s (definition of done item 24). 'Forgot the code?' lets the parent set a new code, typed twice, after passing the phone's own screen lock; cancelling or failing the phone's prompt changes nothing and counts no wrong try; with no screen lock, it explains that clearing the app's data is the only way (definition of done item 26).
