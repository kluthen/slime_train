class_name StateHash
extends RefCounted
## Deterministic serialisation of a simulation state, for comparisons: a
## canonical JSON string (keys sorted at every level, no whitespace, floats at
## full precision) and its SHA-256. Two states are the same when their hashes
## are.
##
## Accepted values: null, bool, int, float, String, StringName, Vector2,
## Vector2i, arrays (packed or not) and dictionaries. Vectors become [x, y];
## dictionary keys become strings.


## The canonical JSON text of `value`.
static func canonical_json(value: Variant) -> String:
	return JSON.stringify(_canonical(value), "", true, true)


## The SHA-256 of the canonical JSON of `value`, as 64 hex digits.
static func of(value: Variant) -> String:
	return canonical_json(value).sha256_text()


static func _canonical(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return String(value)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			var by_text := {}
			for key in keys:
				by_text[str(key)] = key
			var texts := by_text.keys()
			texts.sort()
			var out := {}
			for text in texts:
				out[text] = _canonical(value[by_text[text]])
			return out
		_:
			if value is Array or typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
				var out := []
				for item in value:
					out.append(_canonical(item))
				return out
	push_error("StateHash: unsupported value type %s" % type_string(typeof(value)))
	return null
