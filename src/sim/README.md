# Simulation core

Pure game logic: slimes, the train, the loop, weight, saves, the session
clock. Scripts here don't depend on scenes or on the scene tree (no `Node`,
no `get_tree()`), so they can be unit tested directly. Components and levels
use them; they never use components or levels.
