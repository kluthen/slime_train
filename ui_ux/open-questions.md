# Open questions

Unresolved UI/UX questions, with stable IDs. Each entry points into the
document that holds the matter. A question leaves this file only when it is
resolved and logged in `decisions.md`.

Tags: **[user]** is a design call for the user; **[tech]** needs a technical
check before it can be decided; **[spec]** is blocked on `spec-writer`,
because it is product behaviour, not interface. The [spec] entries are
grouped at the end.

## Foundations

- **Q1 [user][tech]: Where the design tokens live in a Godot project.** The
  stack isn't CSS: a Godot Theme resource, a constants script, shader
  parameters, or a mix. Decide the format and path of the one canonical
  token source before the design-system pass.
- **Q2 [user]: Scope of the design system.** Parent surfaces only (setup,
  code prompt, settings), or also the in-world feedback (ripple, hint, edge
  buttons, object states). See `surface-inventory.md` sections 1 and 3.
- **Q3 [user]: Who owns the species palette.** The spec fixes 6 species told
  apart by colour, with clearly different lightness, on black ground. Tokens
  here, or level art? Its contrast floor against the ground is ours either
  way. See `surface-inventory.md` 1.5 and 1.8.
- **Q4 [user]: Hit-target floors per audience.** A 3-year-old's tap (objects,
  edge buttons, parent zone) versus the parent's (code digits, settings).
  See `surface-inventory.md` 1.3.
- **Q5 [user][tech]: Full screen, system bars and insets.** Immersive mode or
  not; the parent zone against the notification-shade swipe and display
  cutouts in landscape; the edge buttons against the gesture-navigation back
  swipe. See `surface-inventory.md` 1.3, 1.4, 3.1.
- **Q6 [user]: Visual language of the parent surfaces.** The world's style or
  a plainer, adult one; whether a child can tell at a glance that a surface
  isn't for her. See `surface-inventory.md` section 3.

## The world

- **Q7 [user]: The ripple.** Its form, and whether it differs by what the tap
  did: call, object, edge button, parent zone, inert at bedtime. See
  `surface-inventory.md` 1.2.
- **Q8 [user]: The parent zone.** Its size, whether it is marked at all, and
  the cost of a band of screen that never calls, given that the siblings
  will tap there often. See `surface-inventory.md` 1.3 and 3.1.
- **Q9 [user]: Edge buttons.** Form, placement, visibility in screensaver
  mode and under the idle camera, and the feedback when a framing zone holds
  the camera back. Depends on Q39. See `surface-inventory.md` 1.4.
- **Q10 [user]: Object state visuals and hit-area affordance.** Switch
  (default, flipped, inert), basket (outlines, filling, full, opting out,
  releasing, inert), gate (closed, opening, open), signpost. See
  `surface-inventory.md` 1.5.
- **Q11 [user]: The first-play hint.** Its form, where it appears if the
  first sleeper is out of view (screensaver mode starts on the idle camera),
  and how it leaves. Depends on Q40. See `surface-inventory.md` 1.6.
- **Q12 [user]: The idle camera.** Anything in the cue beyond the slow
  zoom-out, and how taking back control looks. See `surface-inventory.md`
  1.7.
- **Q13 [user]: Motion of the world moments.** Waking, fusion, the split zone,
  a lost slime reappearing at the start. See `surface-inventory.md` 1.8.
- **Q14 [user]: Staging of the basket reward and the gate opening.** Whether
  the camera shows the new section, and what input does meanwhile. See
  `surface-inventory.md` 1.9.
- **Q15 [user]: The level-completion celebration.** Form, length, camera,
  input during it, and whether the world shows it is complete afterwards.
  See `surface-inventory.md` 1.10.

## Session states

- **Q16 [user]: Screensaver mode.** Any wordless invitation to tap, and
  whether it looks different from a session. See `surface-inventory.md` 2.1.
- **Q17 [user]: The wind-down.** How the dusk light is treated, within "no
  text, no countdown". See `surface-inventory.md` 2.3.
- **Q18 [user]: Bedtime.** The sleep visuals, what the camera does while
  everyone sleeps, how the edge buttons leave, what the inert ripple looks
  like. See `surface-inventory.md` 2.4.
- **Q19 [user]: Sunrise.** The transition, and whether wake early looks
  different from the cooldown running out. See `surface-inventory.md` 2.5.

## Parent surfaces

- **Q20 [user]: Parent buttons.** Icons or words, where they appear, how they
  are dismissed (timeout, tap elsewhere), and whether a dismissing tap also
  calls. See `surface-inventory.md` 3.1.
- **Q21 [user]: Parent buttons while the session state changes.** Bedtime
  starting while they're open (wake early appears), sunrise arriving (it
  disappears). See `surface-inventory.md` 3.1 and 3.3.
- **Q22 [user][tech]: Code entry.** An in-game digit pad or Android's
  keyboard; masking; an overlay over the running world or a full screen;
  whether it shows which action it is for. See `surface-inventory.md` 3.2.
- **Q23 [user]: Code prompt states.** Empty, partial, wrong, the 30 s wait,
  closed by timeout, success; and bedtime or sunrise arriving while it's open
  (for example, the correct code for wake early entered just after sunrise).
  Depends on Q46. See `surface-inventory.md` 3.2.
- **Q24 [user]: "Forgot the code?"** Placement and prominence on the prompt,
  knowing a child may press it too. See `surface-inventory.md` 3.2 and 3.8.
- **Q25 [user]: The forgotten-code screens.** The hand-off to Android's
  prompt, coming back after a cancel or failure, the new-code entry, success.
  Depends on Q42. See `surface-inventory.md` 3.8.
- **Q26 [user]: Settings.** Contents and structure, a warning before it closes
  by itself, how the level is identified in the save list (one level in v1).
  Depends on Q43. See `surface-inventory.md` 3.5.
- **Q27 [user]: Changing the code.** The two entries, a mismatch, the
  confirmation that it worked. See `surface-inventory.md` 3.6.
- **Q28 [user]: Deleting a level's save.** The second confirmation's form and
  the feedback afterwards. Depends on Q41. See `surface-inventory.md` 3.7.
- **Q29 [user]: Leave.** Whether anything in the app comes between the
  correct code and Android's unpinning. See `surface-inventory.md` 3.4.
- **Q30 [user][spec?]: Time left, for the parent.** Would the parent surfaces
  show the time left in the session or the cooldown (P4.G1, P4.G4)? The spec
  neither asks for it nor rules it out. If the user wants it, it goes to
  `spec-writer` as scope first. See `surface-inventory.md` 3.1.

## Setup and platform

- **Q31 [user]: The first-launch setup.** One screen or several steps; the
  order of the code, the pinning explanation, the "Ask for PIN before
  unpinning" advice and the no-screen-lock warning; resuming after an
  interruption. Depends on Q44. See `surface-inventory.md` 4.1.
- **Q32 [tech]: What setup can tailor.** Can the app tell whether the phone
  has a screen lock (to show the warning only when it matters), and can it
  open Android's pinning settings directly? See `surface-inventory.md` 4.1.
- **Q33 [user]: Life after pinning is declined.** Any lasting sign in the app,
  a later reminder, a way to read the pinning explanation again (settings?).
  See `surface-inventory.md` 4.2.
- **Q34 [user]: Opening the app.** Splash and loading while the save loads;
  whether falling back to the backup save is silent. Depends on Q37 and Q47.
  See `surface-inventory.md` 4.3.
- **Q35 [user]: Parent-facing text.** Tone and amount of the only text in the
  game (setup, prompt, settings). Languages are Q48. See
  `surface-inventory.md` sections 3 and 4.

## Waiting on spec-writer

Gaps or contradictions in settled behaviour. Not ours to resolve; recorded
here so they aren't lost, and reported to `spec-writer`.

- **Q36 [spec]: Does a second finger get a ripple?** The master spec says
  every tap produces a visible ripple, including taps that do nothing else,
  and also that a second touch while one finger is down does nothing. See
  `surface-inventory.md` 1.2.
- **Q37 [spec]: What reopening the app lands on.** The master spec says
  opening the app always lands in screensaver mode; it also says the session
  and cooldown timers survive kills and restarts, and the access model says
  reopening resumes where it was. Mid-session and mid-bedtime reopens need
  one answer. See `surface-inventory.md` 2.1 and 4.3.
- **Q38 [spec]: Which taps start a session.** "The first tap in screensaver
  mode" starts it. Does a tap on the parent zone, an edge button or an object
  count? If the parent zone counts, a parent opening the buttons to leave
  from screensaver mode starts a 15 min session. See `surface-inventory.md`
  2.2 and 3.1.
- **Q39 [spec]: What one press of an edge button does.** v1 has no hold
  gesture, yet leaving a framing zone "takes a slightly longer push". Is a
  press a step per tap, or continuous while the finger stays down? See
  `surface-inventory.md` 1.4.
- **Q40 [spec]: When the first-play hint's 10 s starts.** From screensaver
  mode showing, or from the session start? "Very first play" (mechanics) and
  "fresh install" (definition of done) differ: does deleting the level's save
  re-arm it? See `surface-inventory.md` 1.6.
- **Q41 [spec]: Deleting the save of the level that is running.** What happens
  to the live world and the running session right away; do the first-play
  hint and the celebration re-arm? See `surface-inventory.md` 3.7.
- **Q42 [spec]: Forgotten code, edge cases.** What "forgot the code?" does on a
  phone with no screen lock; what happens when Android's prompt is cancelled
  or failed; whether the new code is entered twice (as for a change). See
  `surface-inventory.md` 3.8.
- **Q43 [spec]: How long settings stays open with no input.** "A short time";
  the tuning table has no value for it. See `surface-inventory.md` 3.5.
- **Q44 [spec]: When pinning is asked.** On first launch, before or after
  setup, given setup explains pinning and what declining changes. Does
  "each time it opens" include coming back from the background? See
  `surface-inventory.md` 4.1 and 4.2.
- **Q45 [spec]: Android back when pinning is declined.** Does back in the
  world leave the app, letting the child out without the code, or does the
  app catch it? See `surface-inventory.md` 4.2.
- **Q46 [spec]: What the wrong-code wait survives.** Do the count of wrong
  tries and the 30 s wait survive the prompt closing, or the app being
  killed? Is "forgot the code?" usable during the wait? See
  `surface-inventory.md` 3.2.
- **Q47 [spec]: The save and its backup both unreadable.** No behaviour is
  specified. See `surface-inventory.md` 4.3.
- **Q48 [spec]: The languages of the parent-facing text.** The spec has no
  text for the child, but setup, the prompt and settings have text for the
  parent, and no locale is named. See `surface-inventory.md` sections 3 and 4.
