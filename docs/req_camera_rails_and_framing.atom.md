---
id: req_camera_rails_and_framing
status: DRAFT
type: REQUIREMENT
layer: BUSINESS
tags: [camera]
dependents:
  - [[req_camera_shows_gate_opening]]
  - [[req_idle_camera_and_screensaver_zoom]]
version: 1.1
priority: 4
human_name: Camera rails and automatic framing
parents:
  - [[req_controls_tap_zones]]
---

# Camera rails and automatic framing

## INTENT
Define how the camera moves and frames the world without the child ever controlling zoom.

## THE RULE / LOGIC
The game is a landscape, locked side view. The camera moves along the loop, return routes included, driven by the edge buttons: the right button always moves it forward along the loop and the left one backward, whatever the direction looks like on screen; on a return route, forward carries the camera round the turn at the frontier and back toward the start; at a fork it follows the main stream by default. A press moves the camera at least one fixed step; while the finger stays down it keeps moving at a steady pace, and it eases to a stop when the finger lifts. A call pulls the camera toward the call point at a slow, steady pace (call drag): this is how the child looks off the loop, since there is no joystick; when and how the camera returns to the rails afterward is a tuning value. If the call point is already inside a box centred on the screen, 20% of the screen's width by 20% of its height (measured on the screen, whatever the zoom), the call happens as usual but the camera doesn't move, and such a call made during a drag stops the drag where it is. The child never controls the zoom: the camera's place decides the zoom, and sometimes the position. Framing zones are a level component: when the camera reaches one, it gently moves and zooms to that zone's framing. Leaving a framing zone through the edge buttons takes a slightly longer push than a normal move: holding the button about 1 s; a short press stays inside the zone.

## TECHNICAL INTERFACE
Parented to req_controls_tap_zones (zone 2, edge buttons). Shares its zoom rule with req_idle_camera_and_screensaver_zoom; req_camera_shows_gate_opening adds the one camera move made on the game's own initiative when a gate opens.

## EXPECTATION
The edge buttons move the camera along the loop; the child can never change the zoom; entering a framing zone reframes the camera smoothly; a press moves at least one fixed step, holding keeps the camera moving, and leaving a framing zone takes about 1 s of holding (definition of done item 18). A call whose point is inside the central box (20% by 20% of the screen, at any zoom) calls the slimes in range but leaves the camera where it is, and a call inside the box during a drag stops the drag; a call just outside the box drags the camera as before.
