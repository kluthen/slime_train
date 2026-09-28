---
id: req_camera_rails_and_framing
status: DRAFT
type: REQUIREMENT
layer: BUSINESS
tags: [camera]
dependents:
  - [[req_idle_camera_and_screensaver_zoom]]
version: 1.0
priority: 4
human_name: Camera rails and automatic framing
parents:
  - [[req_controls_tap_zones]]
---

# Camera rails and automatic framing

## INTENT
Define how the camera moves and frames the world without the child ever controlling zoom.

## THE RULE / LOGIC
The game is a landscape, locked side view. The camera moves along the loop, return routes included, driven by the edge buttons: the right button always moves it forward along the loop and the left one backward, whatever the direction looks like on screen; on a return route, forward carries the camera round the turn at the frontier and back toward the start; at a fork it follows the main stream by default. (proposed, D95, pending the user's approval — O70) A press moves the camera at least one fixed step; while the finger stays down it keeps moving at a steady pace, and it eases to a stop on release. A call pulls the camera toward the call point at a slow, steady pace (call drag): this is how the child looks off the loop, since there is no joystick; when and how the camera returns to the rails afterward is a tuning value. The child never controls the zoom: the camera's place decides the zoom, and sometimes the position. Framing zones are a level component: when the camera reaches one, it gently moves and zooms to that zone's framing, and leaving a framing zone through the edge buttons takes a slightly longer push than a normal move. (proposed, D95, pending the user's approval — O70) That push is holding the button about 1 s; a short press stays inside the zone.

## TECHNICAL INTERFACE
Parented to req_controls_tap_zones (zone 2, edge buttons). Shares its zoom rule with req_idle_camera_and_screensaver_zoom.

## EXPECTATION
The edge buttons move the camera along the loop; the child can never change the zoom; entering a framing zone reframes the camera smoothly (definition of done item 18). (proposed, D95, pending the user's approval — O70) A press moves at least one fixed step, holding keeps it moving at a steady pace with an ease to a stop, and leaving a framing zone takes about 1 s of holding.
