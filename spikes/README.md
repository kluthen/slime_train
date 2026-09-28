# Spikes

Throwaway prototypes (build plan chunks 1 and 2). Nothing in `src/`,
`levels/` or `tests/` may depend on this folder, and it will be left out of
exports. Avoid `class_name` here so spike classes don't leak into the
project's global class list. The outcome of a spike (numbers, the approach
chosen) goes into `docs/dev/`, not into code comments.
