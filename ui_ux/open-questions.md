# Open questions

Unresolved UI/UX questions, with stable IDs. Each entry points into the
document that holds the matter. A question leaves this file only when it is
resolved and logged in `decisions.md`.

Tags: **[user]** is a design call for the user; **[tech]** needs a technical
check before it can be decided. A **[spec note]** under a proposal is for
`spec-writer`: the proposal would need the spec to change or be checked, and
isn't ours to settle.

The spec gaps once listed at the end (Q36 to Q48) were all answered by the
spec on 2026-09-29 and are closed in `decisions.md`.

## Proposed answers (2026-09-29)

At the user's request, every question below carries a **Proposed answer**,
written from the angle of interaction design for children aged 3 to 5
(pre-readers, imprecise taps, short attention, a parent nearby) and for the
parent's layer. They are **proposals, pending the user**: none is decided,
and each stays open until the user accepts or changes it. Sizes are given in
millimetres on the screen; on the reference phone (Galaxy S20 FE, landscape,
about 150 × 68 mm) one mm is about 9.6 of the build's screen units, and
Android's 48 dp minimum is about 9 mm by Google's own figure. Sources are
keyed in brackets and listed at the end.

Look here first: **Q11** (the evidence says a pulsing mark doesn't teach a
3-year-old to tap; a demonstrating hand does a little, a parent showing her
once does best), **Q20** (a tap outside a parent surface closes it and
still does its normal job), **Q4** and **Q10** (child hit floors of 20 mm,
held on the screen whatever the zoom), **Q9**'s spec note (a resting thumb
on an edge strip), **Q31** (setup order, and a line asking the parent to
show the first tap), **Q26** (the settings timeout, which the spec leaves
open).

| Q | Proposal in one line | Confidence |
|---|---|---|
| Q1 | One GDScript constants file is the token source; the Theme is built from it | medium |
| Q2 | The system covers the parent surfaces and the in-world feedback, not level art | high |
| Q3 | The 6 species colours are tokens, with contrast and lightness floors | high |
| Q4 | Child targets at least 20 mm on the screen at any zoom; adult targets at least 9 mm | medium |
| Q5 | Sticky immersive, world edge to edge, controls inside the safe area | medium |
| Q6 | Parent layer: charcoal panels, white text, one accent no species uses | high |
| Q7 | One ripple for every tap, in the world layer, drawn on touch-down | high |
| Q8 | Top band 7 mm, full width, unmarked | medium |
| Q9 | A faint arrow per strip, no strip outline; a fill ring while leaving a framing zone | medium |
| Q10 | One "touchable" rim-light shared by every operable object; inert objects lose it | medium |
| Q11 | A ghost hand tapping the first sleeper, each tap making a ripple; the parent shows the first tap | medium |
| Q12 | Nothing beyond the zoom-out; control comes back with no extra effect | high |
| Q13 | Motion that shows cause: fusion blends visibly over its 3 s | medium |
| Q14 | If the gate is off screen, one short camera glide to it; input stays live | medium |
| Q15 | A 4 s whole-screen burst, input live, a small lasting mark at the start | low |
| Q16 | No invitation; screensaver mode differs only by its zoom | high |
| Q17 | Dusk tint plus a slow sky change; nothing else | high |
| Q18 | Staggered falling asleep, a still camera, minimal motion | medium |
| Q19 | One sunrise, whether by cooldown or wake early | high |
| Q20 | Icon plus word, top right, hide after 5 s; an outside tap closes and still acts | medium |
| Q21 | Buttons keep their places; wake early appears or leaves at the far left | high |
| Q22 | In-game pad, masked, over the running world, titled with its action | high |
| Q23 | A prompt closes when its action disappears; otherwise state changes leave it alone | high |
| Q24 | A low-weight text link under the dots, away from the keys | medium |
| Q25 | One "new code" component shared by setup, change and reset | high |
| Q26 | One column, opaque, 30 s timeout with a 10 s warning | medium |
| Q27 | The shared "new code" component, then a confirmation line in settings | high |
| Q28 | A modal whose Delete button is not where the tap that opened it landed | medium |
| Q29 | Nothing between the code and Android's unpinning | high |
| Q30 | Yes, but only behind the code (settings and the wake-early prompt) | medium |
| Q31 | Four steps: welcome (with "show her the first tap"), code, what if you forget, pinning; the code is saved last | medium |
| Q32 | The app can detect a screen lock; it can't open the pinning page itself | medium |
| Q33 | No sign in the world; a pinning section in settings | high |
| Q34 | Black splash, world fades in; backup or fresh start silent, noted in settings | medium |
| Q35 | Plain, calm, short, "vous" in French; at most about 50 words a screen | high |

## Foundations

- **Q1 [user][tech]: Where the design tokens live in a Godot project.** The
  stack isn't CSS: a Godot Theme resource, a constants script, shader
  parameters, or a mix. Decide the format and path of the one canonical
  token source before the design-system pass.
  - **Proposed answer (proposed, pending the user):** one GDScript file of
    constants, `src/ui/tokens.gd` (a `class_name` with `const` values only,
    no logic), is the single canonical source, owned by `ux-writer`. It
    holds colours, sizes in mm, durations, easing curves and layer order.
    The parent surfaces' Godot Theme is built from it in code at startup
    (by a small builder the coders own), and shaders get their values from
    it as uniforms. Sizes are stored in mm and converted to screen units
    at runtime from the screen's density. No hand-edited `.tres` Theme.
  - *Why:* one file keeps the tokens from drifting apart, a `.tres` edited
    by hand is fragile text, and the world's feedback (ripple, hint, dusk)
    lives in shaders and `_draw` code that a Theme can't reach. Godot
    builds a Theme in code without trouble [Godot-theme].
  - *[tech] check:* whether Godot's screen density on Android is accurate
    enough to convert mm (it may report a rounded density bucket); if not,
    tokens hold screen units for the reference phone, with a floor.
- **Q2 [user]: Scope of the design system.** Parent surfaces only (setup,
  code prompt, settings), or also the in-world feedback (ripple, hint, edge
  buttons, object states). See `surface-inventory.md` sections 1 and 3.
  - **Proposed answer (proposed, pending the user):** both. The system
    covers the parent surfaces in full (type, colour, components and their
    state matrix) and the in-world feedback layer: the ripple, the
    first-play hint, the edge-strip arrows, the object accent and its
    states, the dusk tint, the celebration, and the species colours (Q3).
    It doesn't cover level art: terrain, backgrounds, object shapes.
  - *Why:* the in-world feedback is where the child actually interacts;
    its hit floors, contrast and timing have to hold across levels, and
    later levels (paid ones included) are content that must reuse it.
- **Q3 [user]: Who owns the species palette.** The spec fixes 6 species told
  apart by colour, with clearly different lightness, on black ground. Tokens
  here, or level art? Its contrast floor against the ground is ours either
  way. See `surface-inventory.md` 1.5 and 1.8.
  - **Proposed answer (proposed, pending the user):** tokens. The 6 species
    colours are design tokens that level art uses, never redefines. Floors:
    each colour at least 4.5:1 against the ground in daylight and at least
    3:1 under the full dusk tint; any two colours at least 8 apart in CIE
    L\* lightness, so they stay apart in greyscale and for red-green colour
    blindness; none of them used by a feedback element (ripple, hint,
    object accent, parent accent).
  - *Why:* colour is the only thing that tells species apart in v1, so it
    carries game meaning, like a status colour; the 3:1 non-text floor is
    WCAG's for meaningful graphics [WCAG], raised to 4.5:1 in daylight so
    that dusk, which darkens everything, still leaves 3:1.
- **Q4 [user]: Hit-target floors per audience.** A 3-year-old's tap (objects,
  edge buttons, parent zone) versus the parent's (code digits, settings).
  The spec now fixes the edge buttons as whole-height strips, 10% of the
  screen's width (about 15 mm on the reference phone). See
  `surface-inventory.md` 1.3.
  - **Proposed answer (proposed, pending the user):**
    - **Child targets** (interactive objects): the hit area is the drawn
      object grown by 5 mm on every side, and never smaller than 20 × 20
      mm, both **measured on the screen at the current zoom**. Zooming out
      shrinks the drawing, never the hit floor. Where two hit areas
      overlap, the spec's nearest-centre rule stays; level design keeps
      operable objects far enough apart that their floors rarely overlap.
    - **Edge strips**: the spec's 10% of the width, about 15 mm on the
      reference phone. Below the 20 mm floor, but they run flush with the
      screen's edge, where a finger that overshoots still lands on the
      strip, and edge-flush targets are the ones children hit best
      [Anthony]. No change proposed.
    - **Adult targets** (digits, buttons, links): at least 9 mm tall and
      9 mm wide, with at least 2 mm between neighbours.
    - Sleepers need no floor: a tap on one is a call centred on it, with a
      call radius of half the screen.
  - *Why:* 3-year-olds land on average 4.5 mm from a target's centre
    (adults about 2 mm), and the study that measured it counted any tap
    within about 10 mm, a 23 mm circle, as on target [Vatavu]; practitioner
    guidance for ages 3 to 5 is 2 × 2 cm [NNg]; a hit area larger than the
    drawing is the standard fix [Anthony] [Sesame]. The build's current
    margin (about 2.5 mm) is fixed in
    screen units but the drawn box shrinks with the zoom, so an object in
    the test level's widest framing zone gets harder to hit exactly where
    the child sees it smallest. The adult floor is Android's 48 dp, about
    9 mm [Material]; WCAG's own floors are lower [WCAG].
- **Q5 [user][tech]: Full screen, system bars and insets.** Immersive mode or
  not; the parent zone against the notification-shade swipe and display
  cutouts in landscape; the edge buttons against the gesture-navigation back
  swipe. See `surface-inventory.md` 1.3, 1.4, 3.1.
  - **Proposed answer (proposed, pending the user):** sticky immersive mode
    (no status or navigation bar). The world draws edge to edge, cutout
    area included; everything a finger has to find (the edge-strip arrows,
    the parent buttons, the pad) stays inside the safe area. On the
    reference phone in landscape the camera hole sits at mid-height on one
    side, so that side's arrow moves just below it. The top band stays a
    tap zone: a tap there isn't a swipe, so it doesn't pull the shade, and
    while pinned Android blocks the shade altogether [Android-pinning].
    Without pinning, a swipe from the top first shows the bars briefly;
    no Android call blocks the shade [Android-immersive].
  - *Why:* bars would be one more thing a child pokes, and a way out when
    pinning is off; controls under a cutout can't be seen.
  - *[tech] check:* the behaviour on Samsung's One UI, which the research
    checked only against Android's own source.
  - **[spec note]** Without pinning, a child's tap that slides off the
    left or right edge can become a back swipe and leave the app, which the
    spec accepts. Android lets an app exclude areas from the back gesture,
    and the usual 200 dp limit per edge doesn't apply while the bars are
    hidden in sticky immersive mode [Android-gesture]: the whole edge
    strips could be excluded, protecting the edge buttons. That changes the
    spec's "back leaves the app as Android normally does" (the home and
    recents gestures would still leave), so it is for `spec-writer`.
- **Q6 [user]: Visual language of the parent surfaces.** The world's style or
  a plainer, adult one; whether a child can tell at a glance that a surface
  isn't for her. See `surface-inventory.md` section 3.
  - **Proposed answer (proposed, pending the user):** plainer and adult,
    but related. Charcoal panels (not the world's pure black, so a panel
    reads as a layer), white text, one accent colour that no species and no
    world feedback uses, and the world's soft corner radius. No slimes, no
    decoration, no motion beyond functional transitions. Text at least
    4.5:1 against its panel, controls and their outlines at least 3:1
    [WCAG]. Overlays sit on a dimming scrim; the world keeps running under
    it.
  - *Why:* "grey and words is for grown-ups, colour and slimes is mine" is
    a distinction a pre-reader can make at a glance, and a dull surface
    doesn't invite the repeated poking a colourful one would [Sesame].

## The world

- **Q7 [user]: The ripple.** Its form, and whether it differs by what the tap
  did: call, object, edge button, parent zone, inert at bedtime. See
  `surface-inventory.md` 1.2.
  - **Proposed answer (proposed, pending the user):** one ripple for every
    tap, the same everywhere: a soft ring that appears on **touch-down**,
    grows from about 8 to 20 mm across and fades out over 0.5 s, light and
    translucent. What differs is the rest of the answer (slimes turn and
    come, the switch flips, the camera moves, the parent buttons appear),
    never the ripple. It is drawn in the world layer, so the dusk tint dims
    it at wind-down and bedtime by itself: the inert bedtime ripple is the
    same ripple, darker. A finger held down (an edge strip) makes one
    ripple, not a stream.
  - *Why:* one rule is learnable at 3; the ripple means "I felt you", and
    the cause-and-effect lesson comes from what happens next. Drawing on
    touch-down, not on lift, keeps the answer immediate even though a
    3-year-old's tap can last several seconds [Vatavu]; Sesame's guidance
    is the same [Sesame]. The build already acts on touch-down.
- **Q8 [user]: The parent zone.** Its size, whether it is marked at all, and
  the cost of a band of screen that never calls, given that the siblings
  will tap there often. See `surface-inventory.md` 1.3 and 3.1.
  - **Proposed answer (proposed, pending the user):** a band 7 mm high
    (about 10% of the screen's height on the reference phone; close to the
    build's 64-unit placeholder), the full width, **unmarked**: the world
    draws under it. The parent learns it from setup's last step. A child's
    tap there still gets its ripple and shows the parent buttons, which
    hide again on their own (Q20), so the tap is answered.
  - *Why:* a mark would draw the children to it; a thin band keeps the
    never-calling area small; a band at the screen's edge is easy for an
    adult who knows it's there [Sesame].
  - **[spec note]** Nothing stops a level from placing an interactive
    object under the top band at the camera's rail framing, where the
    child can't operate it and can't bring it lower (the call drag is the
    only vertical control). A level rule, "at the rails' framing, every
    interactive object sits fully below the top band", would close that,
    as the edge strips' consequence did sideways.
- **Q9 [user]: Edge buttons.** The spec now fixes them as whole-height strips
  that take the whole tap and still ripple; what stays open is how they are
  drawn, visibility in screensaver mode and under the idle camera, and the
  feedback when a framing zone holds the camera back. See
  `surface-inventory.md` 1.4.
  - **Proposed answer (proposed, pending the user):** no outline or tint
    over the strip (it would frame the world in a smaller box). Each strip
    shows one soft chevron, about 8 mm tall, light and translucent with a
    dark halo so it reads on the ground and on the sky (3:1 on both),
    vertically centred in the safe area. Pressed: the chevron brightens
    and nudges 1 mm in its direction; held, it stays bright. Held back by a
    framing zone: a ring fills round the chevron over the hold, and the
    camera goes when it is full. Same look in a session, in screensaver
    mode and under the idle camera. At bedtime the chevrons fade out over
    1 s; at sunrise they fade back in.
  - *Why:* the arrow says "this way" without text; a fill ring makes the
    one timed interaction visible, so a 4-year-old can learn "keep
    pressing" (P3.G2) and a 3-year-old's short press just stays put.
    Timed presses are unreliable at 2 to 3 [Nacher15], so nothing but
    leaving a framing zone depends on one, and the fill ring shows it.
  - **[spec note]** A child holding the phone in both hands may rest a
    thumb on a strip. Under "the first touch wins", that thumb holds the
    camera moving and makes every other touch get nothing, the child's own
    taps included. Worth a playtest check first; if it happens, one
    candidate rule: a strip touch held longer than about 5 s (the longest
    slow tap measured at 3 [Vatavu]) keeps the camera moving but stops
    blocking other touches. Resting hands along a device's edges are a
    known source of stray touches [Sesame] [Vatavu]. That changes the first
    touch rule, so it is for `spec-writer`.
- **Q10 [user]: Object state visuals and hit-area affordance.** Switch
  (default, flipped, not answering while its basket is full, inert), basket
  (outlines, filling, full, opting out, releasing, asleep at bedtime,
  inert), gate (closed, opening, open, lid), signpost. See
  `surface-inventory.md` 1.5.
  - **Proposed answer (proposed, pending the user):** one shared affordance:
    **every object that answers a tap carries a soft light rim that
    breathes slowly** (a 2 s cycle, small amplitude); nothing else in the
    world has it, and the hit area itself is never drawn. An object that
    stops answering (a switch while its basket is full, any object inert
    for good) loses the rim and reads as plain landscape.
    - Switch: its arrow points to where the flow goes; a tap swings it
      (0.3 s, with a small squash).
    - Basket: its quota as empty slime outlines (thin, light), filling in
      the colour of each slime caught; full: all outlines pulse through the
      2 s reward; opting out: the outlines drain back to empty (0.5 s);
      releasing: they empty one by one with the slimes; at bedtime its
      slimes sleep in place and the outlines stay; inert: outlines gone.
    - Gate: closed, it carries a small mark matching one on its basket
      (same shape), so "fill this, that opens" can be seen; opening takes
      about 1.5 s; open, it is landscape; a lid is landscape too.
    - Signpost: no rim (not operable), an arrow on a post.
  - *Why:* one learned signal ("the glowing edge can be touched") transfers
    to every object and to later levels; things should look touchable only
    when they are [Sesame]; the basket–gate mark gives P3.G1 a visible link
    between cause and effect. (A glow draws the eye but doesn't teach the
    tap itself [Hiniker15]; the ripple and the first-play hint do that.)
  - **[spec note]** The build makes the basket a tap target, and keeps the
    switch one while it doesn't answer; a tap there gets only the ripple.
    One rule would be clearer: "only something that answers a tap takes
    it", so a tap on a basket, a gate, a signpost or an object that isn't
    answering is a call. For `spec-writer`, since it moves a tap-zone
    boundary.
- **Q11 [user]: The first-play hint.** Its form, where it appears if the
  first sleeper is out of view (screensaver mode starts on the idle camera),
  and how it leaves. See `surface-inventory.md` 1.6.
  - **Proposed answer (proposed, pending the user):** a translucent ghost
    hand, about 12 mm tall, tapping the first sleeper once every 1.5 s,
    each tap making a real-looking ripple on the sleeper (no call). It fades
    in over 0.5 s, and fades out over 0.3 s at the first call, anywhere. If
    the sleeper is out of view when the hint is due, the hint waits and
    shows when the sleeper comes into view; there is no off-screen pointer.
  - *Why:* in the one study that compared prompts for ages 2 to 5, a glow
    or pulse on the item didn't teach the gesture at any age; an animated
    hand worked for fewer than a third of children at 3.0 and about two
    thirds at 3.5; under 3, only an adult showing it worked [Hiniker15].
    A moving hand also beat a static mark in a second study, though tap was
    the gesture neither taught well [Nacher14]. So the hand is the better
    wordless hint, and the strongest help for a 3-year-old is her parent
    showing her once, which setup can ask for (Q31). Hint delays in
    practitioner guidance are 6 to 8 s [Sesame], close to the spec's 10 s.
    On a fresh save the idle camera follows the first awake slime, and the
    first sleeper sits close to it, so the sleeper is normally in view.
  - **[spec note]** The spec calls the hint "a wordless pulsing mark". A
    demonstrating hand fits "wordless mark" but not a plain pulse; the
    wording should allow it.
  - **[spec note]** The personas say of P1.G3 that "there is no one to
    explain it". The evidence says that at 3 a parent's one demonstration
    is what works best, and the parent is there when handing the phone
    over. Whether the personas and setup may count on that is for
    `spec-writer`.
  - **[spec note]** "The first sleeper is close to the first awake slime"
    could be made measurable: within the view at the idle zoom when the
    camera centres on the first awake slime. That turns the hint's "in
    view" assumption into a level rule.
- **Q12 [user]: The idle camera.** Anything in the cue beyond the slow
  zoom-out, and how taking back control looks. The spec now says the idle
  zoom never zooms in and tilt isn't input for it. See
  `surface-inventory.md` 1.7.
  - **Proposed answer (proposed, pending the user):** nothing beyond the
    zoom-out. Taking back control has no effect of its own: the touch does
    its normal job (ripple and all) and the camera eases back to the
    normal zoom over about 0.6 s.
  - *Why:* the idle camera is for a child who has stopped touching; any
    extra cue pulls her back to the phone, which works against the calm
    stance.
- **Q13 [user]: Motion of the world moments.** Waking, fusion, the split zone,
  a lost or stuck slime reappearing at the start. See
  `surface-inventory.md` 1.8.
  - **Proposed answer (proposed, pending the user):** motion that shows the
    cause. Waking: eyes open, a stretch and a hop (about 0.5 s). Fusion:
    through its 3 s of contact the two bodies visibly blend more and more,
    then settle into one with a bounce, so the wait itself is watchable.
    Split zone: an instant split, the pieces bouncing apart. A lost or a
    stuck slime reappearing at the start: the same soft pop-in (it grows
    from small with a bounce, 0.3 s), never a flash; the moment it leaves
    has no effect, as it is usually off screen. Feedback motions stay
    under 0.5 s; rewards may take 1 to 2 s. With Android's "remove
    animations" setting on, the sparkles and bounces go, the moments stay.
  - *Why:* children link cause and effect through what they see change;
    a 3 s rule with nothing visible is a rule they can't discover (P1.G3).
- **Q14 [user]: Staging of the basket reward and the gate opening.** Whether
  the camera shows the new section, and what input does meanwhile. The
  reward and the gate wait for sunrise if bedtime comes first. See
  `surface-inventory.md` 1.9.
  - **Proposed answer (proposed, pending the user):** the reward plays
    where the basket is (it waits until the basket is in view). If the gate
    is then off screen, the camera glides to show it opening (about 1.5 s)
    and stays there, back under normal control. Input stays live
    throughout: a touch takes control back and does its normal job, as
    with the idle camera. No other staging.
  - *Why:* "I filled it, and *that* opened" is the payoff of P3.G1; one
    short glide makes the link, and live input keeps the child in charge.
- **Q15 [user]: The level-completion celebration.** Form, length, camera,
  input during it, and whether the world shows it is complete afterwards.
  It never plays during bedtime. See `surface-inventory.md` 1.10.
  - **Proposed answer (proposed, pending the user):** the build's 4 s:
    bursts of rings in the species colours across the whole screen, and
    every awake slime on screen does a double hop. The camera stays where
    it is; input stays live. Afterwards a small lasting decoration at the
    start of the loop (bunting, say) marks the level as complete, visible
    to anyone who passes.
  - *Why:* a celebration that locks input or takes over the camera would be
    the game's only moment of lost control; a lasting mark lets the parent
    see the achievement without text.
- **Q16 [user]: Screensaver mode.** Any wordless invitation to tap, and
  whether it looks different from a session. See `surface-inventory.md`
  2.1.
  - **Proposed answer (proposed, pending the user):** no invitation beyond
    the first-play hint when it is due. Screensaver mode looks like the
    world at the idle zoom, nothing more.
  - *Why:* screensaver mode follows sunrise, when the phone should be put
    down; an invitation to tap would undo bedtime's nudge (P4.G1); more
    content offered at the end undermined transitions in a study of
    preschoolers' video sessions [Hiniker18].
- **Q17 [user]: The wind-down.** How the dusk light is treated, within "no
  text, no countdown". See `surface-inventory.md` 2.3.
  - **Proposed answer (proposed, pending the user):** the build's dusk tint
    ramping over the minute, plus the sky shifting from day colour to a
    deep blue-violet and the first few stars fading in over the last 20 s.
    No sound (v1 has none), no UI element, the parent layer untinted.
  - *Why:* children aged 1 to 5 were less upset when the technology ended
    the session than when a parent did, and explicit warnings ("two more
    minutes") made transitions rockier [Hiniker16]; a gradual, wordless
    evening is the game ending the session with no warning to read. No
    study tested a wordless dimming itself; the support is indirect. It
    reads as "evening" to a 3-year-old with no clock.
- **Q18 [user]: Bedtime.** The sleep visuals, what the camera does while
  everyone sleeps, how the edge buttons leave, what the inert ripple looks
  like. See `surface-inventory.md` 2.4.
  - **Proposed answer (proposed, pending the user):** slimes fall asleep one
    by one over about 3 s (eyes close, bodies flatten a little), slimes in
    a basket included; asleep, they breathe slowly and nothing else moves.
    The camera stays still; the idle camera doesn't follow anyone while
    all sleep (it may settle at the idle zoom). The edge-strip chevrons
    fade out over 1 s. The inert ripple is the ordinary ripple, dimmed by
    the dusk tint (Q7).
  - *Why:* bedtime should be pleasant but boring, so the child lets go;
    motion and camera travel would keep her watching. Endings carried by a
    character ("it's time for bed") were taken on by preschoolers as their
    own [Hiniker18]; the slimes falling asleep are that character, without
    words.
  - *Note:* whether the idle camera follows at bedtime is camera behaviour;
    the spec says nothing either way. If the user prefers it to keep
    following, the proposal changes only here.
- **Q19 [user]: Sunrise.** The transition, and whether wake early looks
  different from the cooldown running out. See `surface-inventory.md` 2.5.
  - **Proposed answer (proposed, pending the user):** the build's 3 s fade
    from dusk to day, the stars going out, slimes waking one by one with a
    stretch, the chevrons fading back in. Wake early looks exactly the
    same, and a sunrise missed while the app was closed shows nothing.
  - *Why:* the child doesn't need to know a parent intervened; one sunrise
    is one thing to learn.

## Parent surfaces

- **Q20 [user]: Parent buttons.** Icons or words, where they appear, how they
  are dismissed (timeout, tap elsewhere), and whether a dismissing tap also
  calls. See `surface-inventory.md` 3.1.
  - **Proposed answer (proposed, pending the user):**
    - **Look:** an icon with a short word under it (a sun for wake early,
      a door for leave, a gear for settings), in the parent style (Q6),
      each at least 9 × 9 mm, in a row hanging from the top-right corner,
      over the right strip's top if needed.
    - **Dismissal:** they hide after 5 s with no press; a new tap on the
      top band restarts the 5 s (it doesn't toggle).
    - **One rule for every overlay:** a tap outside an open parent
      surface closes it **and does its normal job**: it calls, operates an
      object or moves the camera, and it starts a session if it reaches
      the world. The rule holds for the buttons and for the code prompt;
      settings and setup fill the screen, so there is no outside.
  - *Why:* the child will reveal the buttons often, and will sometimes
    press one. If her next tap on the world were eaten to close a grown-up
    thing, "every touch is answered" would break exactly when she is
    confused; with this rule, the world simply wins. A parent area that
    doesn't look enticing is the usual preschool guidance [Sesame]; the
    6-digit code is the "adult-level task" app stores ask for [Apple]
    [GooglePlay].
- **Q21 [user]: Parent buttons while the session state changes.** Bedtime
  starting while they're open (wake early appears), sunrise arriving (it
  disappears). See `surface-inventory.md` 3.1 and 3.3.
  - **Proposed answer (proposed, pending the user):** leave and settings
    keep fixed places (settings far right, leave to its left); wake early
    fades in or out at the far left, so nothing moves under a finger on
    its way. The 5 s timer isn't reset by the change.
  - *Why:* a button that jumps as the parent reaches for it gets the wrong
    press.
- **Q22 [user][tech]: Code entry.** An in-game digit pad or Android's
  keyboard; masking; an overlay over the running world or a full screen;
  whether it shows which action it is for. See `surface-inventory.md` 3.2.
  - **Proposed answer (proposed, pending the user):** an in-game pad, never
    Android's keyboard. An overlay panel over the running world, on a
    dimming scrim, about two thirds of the width. Left half: the action's
    icon and title ("Enter the code to leave", "…to open settings", "…to
    wake the slimes"), six dots that fill as digits go in (digits never
    shown), and "Forgot the code?". Right half: a 3 × 4 pad in the phone
    layout (1 2 3 on top; erase, 0 at the bottom), keys at least 9 mm tall.
    The code is checked as soon as the sixth digit goes in; there is no OK
    key.
  - *Why:* the keyboard brings other keys, a language switch and, in
    landscape, a full-screen edit field; the phone layout matches the PIN
    pad the parent's fingers already know; masking protects the code from
    a 4-year-old who knows digits (P3); the title tells a parent who
    didn't press the button themselves what they are unlocking.
- **Q23 [user]: Code prompt states.** Empty, partial, wrong, the 30 s wait,
  closed by timeout, success; and bedtime or sunrise arriving while it's open
  (for example, the correct code for wake early entered just after sunrise).
  The spec settled what the wait survives. See `surface-inventory.md` 3.2.
  - **Proposed answer (proposed, pending the user):**
    - Empty: six empty dots. Partial: filled dots. Wrong: the dots shake
      (about 0.4 s) and clear; with "remove animations" on, they flash the
      error colour instead.
    - The wait: the keys grey out, a line says "Too many tries. Try again
      in 0:27" and counts down (a countdown is fine for the parent);
      "Forgot the code?" stays live.
    - Closing by timeout: it fades out over the last 0.5 s of its 15 s.
    - Success: the dots turn to a check for 0.3 s, then the action runs.
    - **One rule for state changes:** a prompt closes itself when the
      action it was raised for disappears (wake early at sunrise), with
      nothing counted; otherwise the session changing underneath (bedtime
      arriving over a leave or settings prompt) changes nothing. A correct
      wake-early code that lands just after sunrise does nothing further.
  - *Why:* the parent is never left holding a prompt for an action that
    no longer exists, and never loses a prompt that still makes sense.
- **Q24 [user]: "Forgot the code?"** Placement and prominence on the prompt,
  knowing a child may press it too. See `surface-inventory.md` 3.2 and 3.8.
  - **Proposed answer (proposed, pending the user):** a text link of low
    weight under the dots, in the left half, at least 9 mm tall as a
    target, well away from the keys.
  - *Why:* the parent who needs it finds it where they are looking (at the
    dots); a child's stray press only opens Android's own prompt, which a
    cancel undoes with nothing changed.
- **Q25 [user]: The forgotten-code screens.** The hand-off to Android's
  prompt, coming back after a cancel or failure, the new-code entry, success.
  The spec settled the edge cases. See `surface-inventory.md` 3.8.
  - **Proposed answer (proposed, pending the user):**
    - With a screen lock: the link opens Android's prompt at once, titled
      "Confirm it's you to set a new code" (Android lets the app set that
      line) [Android-biometric]. Cancel or failure: back on the code prompt
      as it was, with nothing said.
    - Success: the full-screen **"new code" component**, the same one as
      setup and settings use (Q27): "Type a new code", then "Type it
      again"; a mismatch shakes, says "The codes didn't match", and starts
      over. Then back on the code prompt for the action started, with a
      line "New code saved. Enter it to continue." The prompt's 15 s
      timeout doesn't run while the parent is in Android's prompt or the
      new-code screen; the new-code screen uses the settings timeout.
    - Without a screen lock: the link opens a short panel in place of the
      prompt's left half, explaining that clearing the app's data in
      Android settings is the only way and erases all progress, with one
      "Back" button.
  - *Why:* one component for making a code, learned once at setup; a
    reset the parent passed shouldn't be lost to a 15 s timer.
- **Q26 [user]: Settings.** Contents and structure, a warning before it closes
  by itself, how the level is identified in the save list (one level in v1).
  The spec sets no timeout value ("short, to try"). See
  `surface-inventory.md` 3.5.
  - **Proposed answer (proposed, pending the user):**
    - Full screen, opaque, one column, a "Back to the game" button top
      right. Sections: **Parent code** (Change the code); **Saved
      progress** (one row per level: its name and how far it is, "2 of 4
      sections open", with a "Delete progress" button); **Screen pinning**
      (its current state and the explanation from setup, Q33); a small
      footer with the version.
    - **Timeout: 30 s with no input.** From 20 s, a thin bar across the
      top empties over the last 10 s and a line says "Closing soon"; any
      touch resets it. The same 30 s covers the screens opened from
      settings (change the code, the delete confirmation) and the
      new-code screen.
  - *Why:* the timeout protects against a parent handing the phone back
    with settings open; 30 s is long enough to read one screen and short
    enough that a child rarely finds it open. A visible warning keeps a
    reading parent from losing their place. "How far it is" tells the
    parent what deleting will cost.
  - **[spec note]** The 30 s value is a tuning value, so it goes to
    `specs/tuning.md` if the user accepts it.
- **Q27 [user]: Changing the code.** The two entries, a mismatch, the
  confirmation that it worked. See `surface-inventory.md` 3.6.
  - **Proposed answer (proposed, pending the user):** the shared "new code"
    component (Q25): "Type a new code", "Type it again", a mismatch shakes,
    says so and starts over. Success returns to settings with a line "Code
    changed" for 3 s. The current code isn't asked again (it opened
    settings).
  - *Why:* the same screen three times (setup, change, reset) is one thing
    for the parent to learn and one thing to build.
- **Q28 [user]: Deleting a level's save.** The second confirmation's form and
  the feedback afterwards. The spec settled what happens to the running
  level and session. See `surface-inventory.md` 3.7.
  - **Proposed answer (proposed, pending the user):** a modal over
    settings: "Delete the progress in <level>?", then "The slimes, baskets
    and opened gates go back to the start. This can't be undone. The
    session timer isn't affected." Two buttons, **Cancel** and **Delete**
    (the error colour), with Delete placed where the "Delete progress"
    button was *not*, so a double tap can't confirm. Afterwards the modal
    closes, the level's row reads "Not started", and a line says "Progress
    deleted" for 3 s. The world behind has already reloaded.
  - *Why:* the one irreversible parent action gets a real pause and a
    plain statement of the loss, including what it doesn't do (it doesn't
    reset bedtime).
- **Q29 [user]: Leave.** Whether anything in the app comes between the
  correct code and Android's unpinning. See `surface-inventory.md` 3.4.
  - **Proposed answer (proposed, pending the user):** nothing. The correct
    code ends pinning and closes the app; Android shows its own unpinned
    message, and on a phone with a screen lock it may lock the phone as it
    unpins [Android-pinning], which setup's pinning step mentions.
  - *Why:* the parent asked to leave and proved it; a further screen is
    friction, and the child is not the one reading it.
- **Q30 [user]: Time left, for the parent.** Would the parent surfaces show
  the time left in the session or the cooldown (P4.G1, P4.G4)? The spec
  neither asks for it nor rules it out. See `surface-inventory.md` 3.1.
  - **Proposed answer (proposed, pending the user):** yes, but only behind
    the code or on the wake-early prompt: settings' header says "Playing:
    8 min left" or "Sleeping: sunrise in 6 min"; the wake-early prompt
    says "The slimes wake on their own in 6 min". Never on the parent
    buttons, which the child reveals.
  - *Why:* a parent deciding whether to wake the slimes early, or whether
    to hand the phone over now, needs the number (P4.G4); a 4-year-old who
    reads digits (P3) shouldn't meet a countdown the spec keeps from the
    child.
  - **[spec note]** It adds to what the parent surfaces show, so it is
    scope: `spec-writer` first, if the user wants it.

## Setup and platform

- **Q31 [user]: The first-launch setup.** One screen or several steps; the
  order of the code, the pinning explanation, the "Ask for PIN before
  unpinning" advice and the no-screen-lock warning; resuming after an
  interruption. The spec settled that pinning is asked right after setup.
  See `surface-inventory.md` 4.1.
  - **Proposed answer (proposed, pending the user):** four short steps,
    full screen, in the parent style, with a step count ("2 of 4"):
    1. **Welcome:** what the game is, that this part is for the grown-up,
       how to reach the parent buttons later (tap the top of the screen),
       with a small drawing, and one line of advice: "The first time,
       show your child once: tap near a sleeping slime." (See Q11's spec
       note on the personas.)
    2. **Your code:** the "new code" component (Q25), typed twice.
    3. **If you forget it:** with a screen lock, one line ("You can reset
       it with your phone's own lock"); without one, the plain warning
       that clearing the app's data is the only way and erases all
       progress, with a suggestion to write the code down.
    4. **Screen pinning:** what it does, that Android will ask every time
       the game opens, the advice to turn on "Ask for PIN before
       unpinning" (with a button to the phone's security settings, Q32),
       and what declining changes (the back gesture then leaves the game;
       the session keeps counting). Its button, "Start", hands on to
       Android's pinning prompt.
    - **The code is saved only when step 4 is left.** An interruption
      before that restarts setup at step 1, so no parent ever skips the
      pinning explanation.
  - *Why:* one idea per screen suits a parent setting up with a child at
    their elbow; the code comes before the explanations because it is the
    one mandatory act, and pinning comes last so its explanation sits
    right before the Android prompt it explains. Android's pinning request
    accepts a tap anywhere around its dialog [Android-pinning], so a child's
    poke at that moment pins the screen, which is harmless.
- **Q32 [tech]: What setup can tailor.** Can the app tell whether the phone
  has a screen lock (to show the warning only when it matters), and can it
  open Android's pinning settings directly? See `surface-inventory.md` 4.1.
  - **Proposed answer (proposed, pending a technical check):** yes for the
    first: Android tells an app whether the phone has a PIN, pattern or
    password [Android-keyguard], and setup's step 3 and the "forgot the
    code?" panel use it. No for the second: there is no public way to open
    the pinning page itself, so setup opens the phone's security settings
    (a call that may not exist on every phone, so the button hides when it
    fails) and names the path: on Samsung, Security and privacy, More
    security settings, Pin app [Samsung]. Android asks to pin even when the
    phone's pinning setting is off, so the parent needn't turn it on first
    [Android-pinning].
  - *To check in the Android chunk:* both calls from Godot's Android
    plugin, the settings path on the reference phone, and the phone's own
    lock prompt: Android's newer prompt can't ask for the phone's PIN alone
    on Android 10 and older, where the older call (deprecated but working)
    is the fallback [Android-biometric].
- **Q33 [user]: Life after pinning is declined.** Any lasting sign in the app,
  a later reminder, a way to read the pinning explanation again (settings?).
  See `surface-inventory.md` 4.2.
  - **Proposed answer (proposed, pending the user):** nothing in the world.
    Settings' "Screen pinning" section says whether the screen is pinned
    now and holds setup's explanation. Android's own confirmation on
    every launch is the reminder.
  - *Why:* the child's world stays clean; the parent finds the matter
    where they already go.
- **Q34 [user]: Opening the app.** Splash and loading while the save loads;
  whether falling back to the backup save is silent. The spec settled what
  reopening lands on and that a level with neither save readable starts
  fresh. See `surface-inventory.md` 4.3.
  - **Proposed answer (proposed, pending the user):** a black splash (the
    ground colour) with no logo, then the world fades in over 0.5 s in the
    state it resumes in. Falling back to the backup, or starting fresh, is
    silent in the world; settings' row for the level then says so
    ("Restored from a backup on <date>" or "Couldn't be read; started
    again on <date>").
  - *Why:* the child sees no text and no error, ever; the parent can still
    find out why progress looks different.
- **Q35 [user]: Parent-facing text.** Tone and amount of the only text in the
  game (setup, prompt, settings), in English and French. See
  `surface-inventory.md` sections 3 and 4.
  - **Proposed answer (proposed, pending the user):** plain, calm and
    direct; sentences of at most about 20 words; at most about 50 words a
    screen; buttons start with a verb ("Change the code", "Delete
    progress"); Android's own names for its features ("screen pinning",
    with Samsung's name where it differs); no exclamation marks, no emoji,
    no jokes. French written directly, not translated word for word, with
    "vous". Body text at least 16 dp in size.
  - *Why:* the parent reads this with a child waiting; short and plain is
    what gets read.

## Sources

Checked on 2026-09-29. Practitioner guidance is marked as such; it isn't
trial evidence.

- **[Vatavu]** Vatavu, Cramariuc, Schipor (2015). Touch interaction for
  children aged 3 to 6 years: experimental findings and relationship to
  motor skills. IJHCS 74. 89 children; tap offsets by age, tap durations
  up to about 5 s at 3, gesture success rates.
  https://mintviz.usv.ro/publications/ijhcs2015.pdf
- **[Anthony]** Anthony, Brown, Nias, Tate, Mohan (2012). Interaction and
  recognition challenges in interpreting children's touch and gesture
  input on mobile devices. ITS '12. Ages 7 to 16, not preschoolers; edge
  misses and hit areas larger than the drawing.
  https://lisa-anthony.com/wp-content/uploads/2012/09/anthony-et-al-tabletop20121.pdf
- **[Nacher15]** Nacher, Jaen, Navarro, Catala, González (2015).
  Multi-touch gestures for pre-kindergarten children. IJHCS 73. Ages 2 to
  3; double tap and long press do worse than tap and drag.
  https://riunet.upv.es/handle/10251/64752
- **[Nacher14]** Nacher, Jaen, Catala (2014). Exploring visual cues for
  intuitive communicability of touch gestures to pre-kindergarten
  children. ITS '14. https://riunet.upv.es/handle/10251/65315
- **[Hiniker15]** Hiniker, Sobel, Hong, Suh, Kim, Kientz (2015).
  Touchscreen prompts for preschoolers. IDC '15. Ages 2 to 5; glow, hand,
  voice and adult demonstration compared.
  http://faculty.washington.edu/alexisr/TouchscreenPrompts.pdf
- **[Hiniker16]** Hiniker, Suh, Cao, Kientz (2016). Screen time tantrums.
  CHI '16. Children aged 1 to 5; endings by the technology versus by a
  parent; warnings. https://faculty.washington.edu/alexisr/ScreenTimeTantrums.pdf
- **[Hiniker18]** Hiniker, Heung, Hong, Kientz (2018). Coco's Videos.
  CHI '18. Ages 3 to 5; a character ending the session.
  https://faculty.washington.edu/alexisr/CocosVideos.pdf
- **[Sesame]** Sesame Workshop (2012). Best practices: designing touch
  tablet experiences for preschoolers. Practitioner guidance.
  https://joanganzcooneycenter.org/wp-content/uploads/2020/02/SesameWorkshop-2012.pdf
- **[NNg]** Liu (2018). Physical development and children's UX. Nielsen
  Norman Group; practitioner guidance.
  https://www.nngroup.com/articles/children-ux-physical-development/
- **[Apple]** App Store Review Guidelines 1.3 and parental gates.
  https://developer.apple.com/app-store/kids-apps/
- **[GooglePlay]** Google Play Families policies.
  https://support.google.com/googleplay/android-developer/answer/9893335
- **[Material]** Google, touch target size (48 × 48 dp, about 9 mm).
  https://support.google.com/accessibility/android/answer/7101858
- **[WCAG]** W3C, WCAG 2.2: 1.4.3 (text 4.5:1), 1.4.11 (non-text 3:1),
  2.5.8 and 2.5.5 (target size). https://www.w3.org/TR/WCAG22/
- **[Android-gesture]** Android gesture navigation and back-gesture
  exclusion; the 200 dp limit and its exemption in sticky immersive mode
  (the `View` documentation and the window manager's source).
  https://developer.android.com/develop/ui/views/touch-and-input/gestures/gesturenav
- **[Android-immersive]** Android immersive mode.
  https://developer.android.com/develop/ui/views/layout/immersive
- **[Android-pinning]** App pinning: Google's help page, and Android's own
  source (the lock-task controller, the pinning request dialog, the
  pinning setting). https://support.google.com/android/answer/9455138
- **[Android-keyguard]** `KeyguardManager.isDeviceSecure`, Android's own
  source and reference.
- **[Android-biometric]** Android biometric and device-credential prompts.
  https://developer.android.com/identity/sign-in/biometric-auth
- **[Samsung]** Samsung support, pinning an app.
  https://www.samsung.com/us/support/answer/ANS10004865/
- **[Godot-theme]** Godot 4's `Theme` class, which can be built and filled
  in code. Not re-checked in this pass.
