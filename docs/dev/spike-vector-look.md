# Spike: vector look (chunk 2)

Throwaway spike, `spikes/vector-look/`. Godot rasterizes SVGs into a texture
at import time (master-spec.md §11 known gap 5, tech-direction.md
"Engine"), so this spike checked what stays crisp for the game's curved
terrain ("black stone and black plants" as smooth curved silhouettes, plus a
thin coloured outline) across the zoom range the camera can reach.

## Setup

`spikes/vector-look/spike.gd`, run on the scene `spikes/vector-look/spike.tscn`
with:

```
godot --path /home/bastien/work/slime_train spikes/vector-look/spike.tscn
```

A single terrain-like blob (a closed, rounded silhouette with a thin
coloured outline) is drawn two ways from the *same* seven control points
(the SVG's path was generated off those points with a small offline script,
so the two are a fair visual match):

1. **SVG imported as a texture (`Sprite2D`)** — `terrain.svg`, imported by
   Godot's texture importer at `svg/scale = 1.0` (rasterized once, at the
   SVG's own 200×200 size).
2. **Curve2D tessellated into `Polygon2D` + `Line2D`** — a `Curve2D` built in
   code from the control points (Catmull-Rom-style tangents for smooth
   curves through them), baked with `get_baked_points()` into a `Polygon2D`
   fill and a `Line2D` outline (`antialiased = true`,
   `joint_mode = LINE_JOINT_ROUND`, rounded caps). The bake interval is
   tightened with the zoom level (`4.0 / zoom`, clamped to `[0.5, 8.0]`), so
   the shape is retessellated rather than just redrawn at each zoom step.
3. **A vector plugin** — skipped. A few minutes of searching the Godot asset
   library and GitHub found nothing that renders vector shapes at runtime
   for Godot 4.7. The one actively developed, well-known project,
   [GodSVG](https://github.com/MewPurPur/GodSVG) (2.7k stars), is a
   **standalone SVG editor application** (its own Godot project, imported
   and run on its own), not an addon you drop into a game project to render
   vector shapes at runtime — it doesn't apply here. No further time was
   spent on this option, per the spike's ~20-minute budget for it.

The scene stepped through camera zooms 0.5×, 1×, 2× and 4× for each
approach (`Camera2D.zoom` set directly to the factor — in Godot 4, values
above 1 zoom **in**), capturing a screenshot after two frames each time into
`spikes/vector-look/out/` (`get_viewport().get_texture().get_image().save_png()`).
It then measured frame time for 50 terrain pieces on screen (10×5 grid,
vsync disabled, `Engine.max_fps = 0`, averaged over 60 frames) for both
approaches.

## What was seen

At 1× zoom, both approaches look about the same and both curves are smooth
(`out/svg_1.0x.png`, `out/tessellated_1.0x.png`).

At 4× zoom, cropped tight on the silhouette's edge and magnified further for
inspection (`out/svg_4x_edge_zoomed.png`, `out/tessellated_4x_edge_zoomed.png`):

- The **SVG texture is visibly blurred** — a soft, several-pixel-wide
  gradient band along the black/teal/background transitions. This is the
  expected result of upscaling a texture rasterized once at 200×200 to
  roughly 4× that display size, filtered.
- The **tessellated `Polygon2D`/`Line2D` stays crisp** — a clean, narrow
  antialiased edge, no blur band, because it was retessellated at a bake
  interval fine enough for that zoom and drawn as real geometry rather than
  a fixed-resolution raster.

Frame time for 50 pieces (desktop, AMD iGPU, uncapped): SVG sprites
averaged ~0.62–0.67 ms/frame, tessellated `Polygon2D`+`Line2D` averaged
~0.53–0.62 ms/frame. Both are trivially cheap at this scale on desktop —
the numbers are too small and too GPU-dependent to treat as a phone
prediction, but they rule out "the tessellated approach costs meaningfully
more to draw" as a reason to prefer the SVG route. The real per-phone
performance question is chunk 1's (soft slimes at scale), not this spike's.

## Decision

**For terrain, use a `Curve2D`/`Path2D` baked into `Polygon2D` (fill) +
`Line2D` (outline), not an SVG texture.** It stays crisp at every zoom the
game uses, matches the design stance ("simple, curved, high contrast, low
detail" — flat fills and thin outlines, not photographic detail an SVG
raster would suit better), and costs about the same to draw as the SVG
sprite. The vector-plugin option is dropped: nothing viable was found for
Godot 4.7, and the code-drawn approach already meets the need with no added
dependency.

**For level art in general, the same approach**: build shapes (terrain,
plants, rocks, decoration) as one or more `Path2D`/`Curve2D` curves baked
into `Polygon2D`/`Line2D` layers, authored as editor curves rather than
imported raster art. SVG import stays an option only for art that never
gets zoomed by the game camera (if any placeholder parent-facing UI icons
end up wanting it), since that's where its blur-on-zoom weakness doesn't
matter.

**What this means for level authoring:** unchanged from
`specs/tech-direction.md` — terrain is a `Path2D` with a collision polygon,
built in the editor, no per-level scripts. This spike adds a concrete
implementation shape for it: a reusable terrain component that reads a
level's `Path2D` and, at load, bakes its `Curve2D` into the
`CollisionPolygon2D` (for physics) and the `Polygon2D`/`Line2D` pair (for the
visual) from the *same* baked points, so a level author only draws one
curve per terrain piece.

**What this means for chunk 4** (level scaffolding and Meadow greybox):
build that terrain component. Bake once, at load, at an interval fine
enough for the maximum zoom the game reaches (this spike's finest test was
4×; recheck against known gap 4 — the minimum zoom — once it's settled, and
against the idle-camera/screensaver zoom in chunk 13, which can go further
than in-play zoom). Retessellating on every zoom change, as this spike did
to demonstrate the technique, is unlikely to be needed in the shipped game
since terrain doesn't change shape at runtime — revisit only if a fixed
fine bake turns out to draw too many points when the camera is zoomed far
out.

## Files

- `spikes/vector-look/spike.gd`, `spikes/vector-look/spike.tscn` — the spike
  scene and script.
- `spikes/vector-look/terrain.svg` — the SVG comparison asset.
- `spikes/vector-look/out/` — four kept screenshots: `svg_1.0x.png`,
  `tessellated_1.0x.png`, `svg_4x_edge_zoomed.png`,
  `tessellated_4x_edge_zoomed.png` (the last two are edge crops magnified
  with ImageMagick for inspection, not raw captures).
