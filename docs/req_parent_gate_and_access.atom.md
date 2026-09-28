---
id: req_parent_gate_and_access
status: DRAFT
version: 1.0
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
---

# Parent gate and parent access

## INTENT
Define the 6-digit parent code and every flow that uses it to gate a parent-only action.

## THE RULE / LOGIC
The parent code has 6 digits. At first launch, a one-time setup screen appears before anything else: the parent types the code twice, and the screen explains screen pinning and states plainly that on a phone with no screen lock, a forgotten code can only be reset by clearing the app's data, which erases all progress. A tap at the top of the screen reveals the parent buttons: wake early (ends bedtime or the cooldown, shown only during bedtime), leave (ends screen pinning and lets the parent leave the app), and settings (change the code, delete one level's save). Every button asks for the code before doing anything, immediately before the action; deleting a level's save asks for a second confirmation after the code, since it erases that level's progress. 'Forgot the code?' on the code prompt hands off to the phone's own screen lock through Android's system prompt (PIN, pattern or fingerprint); if it succeeds, the parent sets a new code. (proposed, D95, pending the user's approval — O73) On a phone with no screen lock, 'forgot the code?' explains that clearing the app's data is the only way, and that it erases all progress; nothing else changes. Cancelling or failing Android's prompt returns to the code prompt, with nothing changed and no wrong try counted. After passing it, the new code is typed twice, as at setup, and the parent is then back at the code prompt for the action they started, with the wrong tries and any wait cleared. A wrong code makes the entry shake and clear; tries are unlimited, but 5 wrong tries in a row bring a 30 s wait; the code prompt closes after about 15 s with no input, and the settings screen also closes by itself after a short time with no input. Opening the parent buttons or the code prompt pauses nothing: the world keeps running and the session keeps counting. Changing the code takes effect immediately and the old code stops working; there is no 'remember me', so every new parent action asks for the code again. There is exactly one code for the whole app; if it's forgotten and the phone has no screen lock, clearing the app's data in Android settings is the only way out and it erases all progress. (proposed, D95, pending the user's approval — O77, a guess to confirm) The parent-facing text (setup, the code prompt, settings) follows the phone's language when v1 has it, and is in English otherwise; v1 ships English and French.

## TECHNICAL INTERFACE
Parented to req_controls_tap_zones (zone 1, top of screen). Governs req_session_lifecycle's wake-early path and req_persistence_and_saves's delete-a-save path. See also req_actor_roles_and_permissions and req_denial_and_stepup_behavior for the formal role/permission model this access flow implements.

## EXPECTATION
On first launch the parent setup appears before anything else and requires the 6-digit code twice; it is never shown again (definition of done item 23). Every parent action (wake early, leave, change the code, delete a level's save) is refused without the correct code (definition of done item 24). 'Forgot the code?' lets the parent set a new code after passing the phone's own screen lock (definition of done item 26). (proposed, D95, pending the user's approval — O73) With no screen lock, that flow explains that clearing the app's data is the only way and erases all progress; cancelling or failing the phone's own prompt changes nothing and counts no wrong try; passing it asks for the new code twice and clears the wrong tries and any wait. (proposed, D95, pending the user's approval — O77, a guess to confirm) Parent-facing text follows the phone's language when v1 ships it (English and French), falling back to English otherwise.
