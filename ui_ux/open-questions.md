# Open questions

Unresolved UI/UX questions, with stable IDs. Each entry points into the
document that holds the matter. A question leaves this file only when it is
resolved and logged in `decisions.md`.

Tags: **[user]** is a design call for the user; **[tech]** needs a technical
check before it can be decided; **[v2]** is parked for v2 on purpose. A
**[spec note]** is for `spec-writer`: the matter would need the spec to
change or be checked, and isn't ours to settle.

Q1 to Q10 and Q12 to Q35 were answered on 2026-09-29 and are closed in
`decisions.md` (D2 to D7), and Q36 to Q48 were closed by the spec (D1).
Nothing is open for v1 at the moment; new questions will come with the
strategy and design-system passes.

## Parked for v2

v1 keeps the spec's first-play hint as it stands: a wordless pulsing mark
near the first sleeper, on the very first play, after about 10 s with no
call. The user parked the proposal below, and the idea of the parent
showing the first tap, as v2 work (D2).

- **Q11 [user][v2]: The first-play hint.** Its form, where it appears if the
  first sleeper is out of view (screensaver mode starts on the idle camera),
  and how it leaves. See `surface-inventory.md` 1.6.
  - **Proposed answer (parked for v2 by the user, 2026-09-29):** a
    translucent ghost hand, about 12 mm tall, tapping the first sleeper once every 1.5 s,
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
    showing her once, which setup could ask for (parked with this, D2).
    Hint delays in
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

### Sources for Q11

- **[Nacher14]** Nacher, Jaen, Catala (2014). Exploring visual cues for
  intuitive communicability of touch gestures to pre-kindergarten
  children. ITS '14. https://riunet.upv.es/handle/10251/65315
- **[Hiniker15]** Hiniker, Sobel, Hong, Suh, Kim, Kientz (2015).
  Touchscreen prompts for preschoolers. IDC '15. Ages 2 to 5; glow, hand,
  voice and adult demonstration compared.
  http://faculty.washington.edu/alexisr/TouchscreenPrompts.pdf
- **[Sesame]** Sesame Workshop (2012). Best practices: designing touch
  tablet experiences for preschoolers. Practitioner guidance.
  https://joanganzcooneycenter.org/wp-content/uploads/2020/02/SesameWorkshop-2012.pdf
