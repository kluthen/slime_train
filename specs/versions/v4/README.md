# v4 — First store release (probably)

Status: themes only (D137); no spec yet

- **The first store release, probably** (D137): it ships one true, fully
  implemented level, and is probably the largest step on the roadmap.
  D31's price (about $3–5, no in-app purchases) belongs to it.
- v2's level work (chunk L01, the tools, the reusable mechanics) builds
  toward that level; whether it is L01 itself is O104.

Assigned so far:

- **The app ships** (D149): from this first store release on, every
  save-format change ships with its migration, and a save a build can't
  use is kept untouched rather than set aside. The code's "shipped"
  switch is turned on as part of this release (proposed).
- Option to turn the parent code off (D58): the code is then never asked for,
  and waking early takes just a tap. It can be changed in the settings.
