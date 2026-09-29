# Decisions

Append-only log of UI/UX decisions: what was decided, briefly why, and which
question it closed, if any. Entries are numbered D1, D2, … in this tree;
outside `ui_ux/`, cite them as `ux D<n>`. Spec decisions are cited as
`spec D<n>`.

## D1 — The spec gaps came back from spec-writer (2026-09-29)

Closes Q36 to Q48, the "Waiting on spec-writer" group. The spec answered
every one; nothing here is a design choice of ours. Each answer is now
settled behaviour that the design honours, and `surface-inventory.md`
carries it in the section named.

| Question | Settled by | The answer, in short | Inventory |
|---|---|---|---|
| Q36 second finger | spec D102 (approving spec D95, O67); master spec 5.5 | A touch that starts while another finger is down gets nothing at all, not even a ripple, and stays ignored until it lifts. | 1.2, 5 |
| Q37 reopening the app | spec D102 (O68); spec D104; master spec 5.7 | It resumes in the state the stored timers give: a session (wind-down included), bedtime with the rest of its cooldown, or screensaver mode if the cooldown ran out (sunrise isn't replayed). Tilt's neutral is taken again on resuming a session. | 2.1, 4.3 |
| Q38 which taps start a session | spec D102 (O69); spec D99; master spec 5.7 | A tap that reaches the world: a call or an object. Not the top band, not an edge strip; the edge strips still move the camera in screensaver mode. | 2.2, 3.1 |
| Q39 edge-button press | spec D102 (O70); spec D99; master spec 5.5, 5.6 | At least one fixed step per press, a steady pace while the finger stays down, an eased stop on release. Leaving a framing zone takes about 1 s of holding. Holding is the same button pressed longer, not a gesture of its own. Each button is a whole-height strip, 10% of the screen's width, below the top band; it takes the whole tap and still ripples. | 1.3, 1.4 |
| Q40 first-play hint timing | spec D102 (O71); master spec 5.5 | The 10 s count from the first frame the world shows on a fresh save of the level, and again each time the world shows while the hint is due. The first call marks it done in the level's save, so deleting the save re-arms it. Never during bedtime. | 1.6 |
| Q41 deleting the running level's save | spec D102 (O72); spec D104; master spec 5.10 | The level reloads fresh at once; the hint is due again and the celebration can play again. The session or bedtime and their timers carry on and are written into the fresh save. The backup goes too. | 3.7 |
| Q42 forgotten code, edge cases | spec D102 (O73); master spec 5.8 | No screen lock: "forgot the code?" explains that clearing the app's data is the only way and erases all progress; nothing else happens. Cancel or failure of Android's prompt: back to the code prompt, nothing changed, no wrong try counted. The new code is typed twice; then the parent is back at the code prompt for the action they started, wrong tries and wait cleared. | 3.8 |
| Q43 how long settings stays open | spec D83; `specs/tuning.md` | "A short time, to try": the spec sets no value. The value is left to tuning; our proposal for it is under Q26. | 3.5 |
| Q44 when pinning is asked | spec D102 (O74); master spec 5.9 | Each launch: on first launch right after setup is completed; on later launches as soon as the app opens, before the world takes a tap. Coming back from the background doesn't ask. "Leave" closes the app. | 4.1, 4.2 |
| Q45 back without pinning | spec D102 (O75); master spec 5.9 | The back gesture leaves the app as Android normally does; the session keeps counting and reopening resumes. Setup says so. Catching back is not taken. | 4.2 |
| Q46 the wrong-code wait | spec D102 (O76); master spec 5.8 | The count and the end of the wait are stored on disk and survive the prompt closing and the app being killed. One count for every parent button, reset by a correct code or a code reset. "Forgot the code?" works during the wait. | 3.2 |
| Q47 save and backup both unreadable | master spec 5.10 | That level starts fresh. | 4.3 |
| Q48 languages of the parent text | spec D102 (O77); master spec 5.8 | The phone's language when v1 has it, English otherwise. v1 ships English and French. The child sees no text. | 3, 4 |

Why this matters for the design: these answers remove the branches the flows
would otherwise have had to guess at. In particular, reopening the app no
longer always lands in screensaver mode, the top band and the edge strips
never start a session, and the edge strips are large, whole-height controls
rather than small buttons.

Spec decisions taken after the inventory also narrow open questions that
stay ours: spec D99 (edge strips) narrows Q4, Q5 and Q9; spec D100 (the
"stuck" state, a slime moved to the start of the loop like a lost one)
narrows Q13; spec D101 (the call's camera dead zone) settles when a call
moves the camera; spec D103 (the idle zoom never zooms in; tilt isn't input
for the idle clock) narrows Q12; spec D105 and D106 (baskets and their
slimes at bedtime, no opting out of a full basket, the "in a basket" state)
narrow Q10, Q14, Q15 and Q18. The open questions now say so.
