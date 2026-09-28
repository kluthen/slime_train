extends GutTest
## StateHash: canonical JSON of a state dictionary, and its SHA-256.


func test_key_order_does_not_matter() -> void:
	var a := {"b": 1, "a": {"y": 2, "x": [1, 2]}}
	var b := {"a": {"x": [1, 2], "y": 2}, "b": 1}
	assert_eq(StateHash.canonical_json(a), StateHash.canonical_json(b))
	assert_eq(StateHash.of(a), StateHash.of(b))


func test_canonical_json_is_compact_and_sorted() -> void:
	assert_eq(StateHash.canonical_json({"b": 1, "a": "x"}), '{"a":"x","b":1}')


func test_vectors_become_arrays() -> void:
	assert_eq(StateHash.canonical_json({"at": Vector2(1.5, -2.0)}), '{"at":[1.5,-2.0]}')
	assert_eq(StateHash.canonical_json({"at": Vector2i(3, 4)}), '{"at":[3,4]}')


func test_non_string_keys_are_stringified() -> void:
	assert_eq(StateHash.canonical_json({1: true, &"n": null}), '{"1":true,"n":null}')


func test_floats_keep_full_precision() -> void:
	var a := StateHash.of({"v": 0.1 + 0.2})
	var b := StateHash.of({"v": 0.3})
	assert_ne(a, b, "0.1 + 0.2 and 0.3 differ in the last bit and must hash differently")


func test_values_change_the_hash() -> void:
	assert_ne(StateHash.of({"tick": 1}), StateHash.of({"tick": 2}))
	assert_ne(StateHash.of({"list": [1, 2]}), StateHash.of({"list": [2, 1]}))


func test_hash_is_sha256_hex() -> void:
	var h := StateHash.of({})
	assert_eq(h.length(), 64)
	assert_eq(h, "{}".sha256_text())
