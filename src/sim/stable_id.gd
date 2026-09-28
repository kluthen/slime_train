class_name StableId
extends RefCounted
## Stable IDs (D72): every placed thing in a level (a slime, an object, a
## gate, a route) carries one, so saves survive a minor level update.
##
## Pattern: `<place>.<kind>` or `<place>.<kind>.<name>`, lowercase, no spaces.
## `<place>` is `start` or a section, `s1`, `s2`...; `<kind>` and `<name>` are
## lowercase words joined by hyphens, and numbered items use two digits
## (`s1.sleeper.01`). Examples: `start.split-zone`, `s1.gate`,
## `s1.route-back.tree`. See specs/levels/test/README.md, "Stable IDs".

const _PATTERN := "^(start|s[1-9][0-9]*)\\.[a-z0-9]+(-[a-z0-9]+)*(\\.[a-z0-9]+(-[a-z0-9]+)*)?$"

static var _regex: RegEx


## Whether `id` follows the pattern.
static func is_valid(id: String) -> bool:
	if _regex == null:
		_regex = RegEx.create_from_string(_PATTERN)
	return _regex.search(id) != null
