---
id: req_platform_and_performance_targets
status: DRAFT
tags: [platform,performance]
dependents: []
version: 1.0
type: REQUIREMENT
layer: BUSINESS
priority: 4
human_name: Platform and performance targets
parents:
  - [[req_scope_one_level_four_sections]]
---

# Platform and performance targets

## INTENT
Define the target platform, phones and performance v1 must hit, and where each is tested.

## THE RULE / LOGIC
Platform: Godot 4, targeting Android, with a Linux desktop build for development and tests; v1 is a paid app at about 3 to 5 dollars, with no purchases inside the app. Reference phone: Samsung Galaxy S20 FE. Floor phone: a budget phone of the Galaxy A14 class; if the floor phone can't hold 200 slimes, the floor rises, but the 200-slime cap stays. Performance targets: 60 frames per second on the reference phone in normal play; at least 30 fps on the floor phone with the level's largest realistic pile on one screen (a full basket plus the train, mostly still), measured both cold and after 5 minutes of play. The 200-slime cap stays; measuring 200 slimes moving at once on one screen is a measurement taken along the way, not itself a target. Test environments: the Linux desktop build is used for gameplay, level logic, saves and automated end-to-end tests, but not anything Android-specific; the Android emulator is used for the Android lifecycle, screen pinning, the parent flows, save and restore, and rough tilt, but not performance or touch/tilt feel; real phones (reference and floor) are used for performance, touch and tilt feel, and playtests with children, but not fast iteration; the Google Play pre-launch report (later) is used for smoke tests on many real phones, not detailed performance work.

## TECHNICAL INTERFACE
Parented to req_scope_one_level_four_sections.

## EXPECTATION
At least 60 fps on the reference phone in normal play, and at least 30 fps on the floor phone with the level's largest realistic pile on one screen (a full basket plus the train, mostly still), cold and after 5 minutes of play (definition of done item 30).
