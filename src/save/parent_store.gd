class_name ParentStore
extends RefCounted
## The parent store: the app's one parent code and the wrong-try state, in
## one file (user://parent.json unless a test gives another path). It is not
## a level save: deleting a level's save erases neither the code nor the count.
##
## The file (JSON), FORMAT 1:
##   {"format": 1,
##    "code": {"salt": <hex>, "hash": <hex>} or null (no code yet),
##    "wrong_tries": int (wrong tries in a row),
##    "wait_until_ms": int (wall clock, Unix ms, when the wait ends; 0 = none)}
## The code itself is never written: only a salted SHA-256 of it, with a fresh
## random salt at every set_code (setup, change, reset).
##
## The tries (specs/tuning.md "Wrong-code wait": 30 s after 5 wrong tries in a
## row): a wrong try counts and is on disk at once; the 5th in a row starts a
## wait, during which nothing is checked or counted; when a wait has ended, the
## count starts again from 0; a right code or a new code resets it. Times are
## the session clock's wall ms, given by the caller, so the wait survives the
## app being killed.
##
## A file that can't be read (not JSON, another format, a bad field) is left
## untouched and the store holds no code in memory, so setup runs again; the
## first set_code then writes over it (chunk 19 hardens persistence).
## Writes go to a side file (SIDE_SUFFIX) first, are read back, and only then
## take the old file's place.
# @spec-link [[rule_parent_code_not_stored_plaintext]]
# @spec-link [[req_denial_and_stepup_behavior]]

const DEFAULT_PATH := "user://parent.json"
const FORMAT := 1
## Wrong tries in a row that start a wait (specs/tuning.md, D83).
const WRONG_TRIES_BEFORE_WAIT := 5
## How long the wait lasts, in ms (specs/tuning.md, D83).
const WAIT_MS := 30000
## The code's length, in ASCII digits.
const CODE_DIGITS := 6
## Random salt bytes per code.
const SALT_BYTES := 16
## The side file a write goes to before it replaces the file.
const SIDE_SUFFIX := ".new"

## The answer to a try.
enum Result {
	OK,       ## the right code
	WRONG,    ## a wrong code (counted)
	WAITING,  ## during a wait: the code wasn't even checked
}

var path := DEFAULT_PATH

## The salt and hash of the code, as hex; both "" when there is no code.
var _salt_hex := ""
var _hash_hex := ""
var _wrong_tries := 0
## Wall ms when the wait ends; 0 = no wait.
var _wait_until_ms := 0


## A store on the file at `store_path`, loaded if it's there.
func _init(store_path := DEFAULT_PATH) -> void:
	path = store_path
	_load()


## Whether a parent code is set.
# @spec-link [[req_parent_gate_and_access]]
func has_code() -> bool:
	return not _hash_hex.is_empty()


## Sets the parent code to `code` (exactly 6 ASCII digits, else refused
## loudly and nothing changes): a fresh salt and hash, the count and the wait
## reset, the file written. For setup, changing the code and the code reset.
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[rule_parent_code_not_stored_plaintext]]
func set_code(code: String) -> void:
	if not is_valid_code(code):
		push_error("ParentStore.set_code: a parent code is exactly %d digits, got '%s'" % [CODE_DIGITS, code])
		return
	var salt := Crypto.new().generate_random_bytes(SALT_BYTES)
	_salt_hex = salt.hex_encode()
	_hash_hex = _hash(salt, code)
	_wrong_tries = 0
	_wait_until_ms = 0
	_save()


## Checks `code` against the parent code at wall time `now_wall_ms`: WAITING
## during a wait (nothing checked, nothing counted), else OK (count reset) or
## WRONG (counted; the 5th in a row starts the wait). Needs a code
## (has_code()): without one it is refused loudly and answers WRONG, uncounted.
# @spec-link [[req_denial_and_stepup_behavior]]
func try_code(code: String, now_wall_ms: int) -> Result:
	if not has_code():
		push_error("ParentStore.try_code: no parent code is set (setup comes first)")
		return Result.WRONG
	if wait_left_ms(now_wall_ms) > 0:
		return Result.WAITING
	if _wait_until_ms != 0:
		_wait_until_ms = 0
		_wrong_tries = 0
	if _hash(_salt_hex.hex_decode(), code) == _hash_hex:
		_wrong_tries = 0
		_save()
		return Result.OK
	_wrong_tries += 1
	if _wrong_tries >= WRONG_TRIES_BEFORE_WAIT:
		_wait_until_ms = now_wall_ms + WAIT_MS
	_save()
	return Result.WRONG


## Ms left of the wait at wall time `now_wall_ms` (0 = no wait), never above
## WAIT_MS. If the clock was moved back so far that more than WAIT_MS would be
## left, the wait's end moves to WAIT_MS from now (and is saved): a wait
## never lasts over 30 s, whatever the clock does.
# @spec-link [[req_denial_and_stepup_behavior]]
func wait_left_ms(now_wall_ms: int) -> int:
	if _wait_until_ms == 0:
		return 0
	if _wait_until_ms - now_wall_ms > WAIT_MS:
		_wait_until_ms = now_wall_ms + WAIT_MS
		_save()
	return clampi(_wait_until_ms - now_wall_ms, 0, WAIT_MS)


## Wrong tries in a row so far (a count left from an ended wait is cleared
## by the next try_code).
func wrong_tries() -> int:
	return _wrong_tries


## Whether `code` has the shape of a parent code: exactly 6 ASCII digits.
static func is_valid_code(code: String) -> bool:
	if code.length() != CODE_DIGITS:
		return false
	for i in code.length():
		var c := code.unicode_at(i)
		if c < 48 or c > 57:
			return false
	return true


## The SHA-256 of `salt` then `code`'s bytes, as hex.
static func _hash(salt: PackedByteArray, code: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	# One update: HashingContext refuses an empty buffer, and an entry may be "".
	context.update(salt + code.to_utf8_buffer())
	return context.finish().hex_encode()


## Reads the file into memory if it's there; an unreadable one is refused
## loudly, left as it is, and read as "no code".
func _load() -> void:
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != Error.OK:
		_unreadable("not JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()])
		return
	var why := _why_bad(json.data)
	if not why.is_empty():
		_unreadable(why)
		return
	var data: Dictionary = json.data
	if data["code"] != null:
		_salt_hex = data["code"]["salt"]
		_hash_hex = data["code"]["hash"]
	_wrong_tries = int(data["wrong_tries"])
	_wait_until_ms = int(data["wait_until_ms"])


## Why `data` isn't a parent file of FORMAT, or "".
static func _why_bad(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "not a parent file (expected a JSON object)"
	if not _is_count(data.get("format")) or int(data["format"]) != FORMAT:
		return "format %s, expected %d" % [data.get("format"), FORMAT]
	if not _is_count(data.get("wrong_tries")):
		return "wrong_tries isn't a whole number of 0 or more"
	if not _is_count(data.get("wait_until_ms")):
		return "wait_until_ms isn't a whole number of 0 or more"
	var code: Variant = data.get("code", "missing")
	if code == null:
		return ""
	if typeof(code) != TYPE_DICTIONARY or not _is_hex(code.get("salt")) or not _is_hex(code.get("hash")):
		return "code isn't null or {\"salt\": <hex>, \"hash\": <hex>}"
	return ""


## Whether `value` is a JSON number that is a whole number of 0 or more.
static func _is_count(value: Variant) -> bool:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return false
	return is_finite(value) and value >= 0 and value == floorf(value)


## Whether `value` is a non-empty string of lowercase hex digit pairs.
static func _is_hex(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() % 2 != 0:
		return false
	for c in value:
		if not c in "0123456789abcdef":
			return false
	return true


## Refuses the file loudly for `why` (the file itself isn't touched).
func _unreadable(why: String) -> void:
	push_error("ParentStore: %s is unreadable: %s. It is left as it is; no parent code is set." % [path, why])


## Writes the state to the file through the side file; a failure is loud and
## leaves the old file.
func _save() -> void:
	var code: Variant = null
	if has_code():
		code = {"salt": _salt_hex, "hash": _hash_hex}
	var text := JSON.stringify({"format": FORMAT, "code": code, "wrong_tries": _wrong_tries,
			"wait_until_ms": _wait_until_ms}, "\t")
	var why := _write(text)
	if not why.is_empty():
		push_error("ParentStore: %s; the old file is kept" % why)


## Writes `text` to the file via the side file. Returns "" or why not.
func _write(text: String) -> String:
	var made := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if made != Error.OK and made != ERR_ALREADY_EXISTS:
		return "can't make %s (%s)" % [path.get_base_dir(), error_string(made)]
	var side := path + SIDE_SUFFIX
	var file := FileAccess.open(side, FileAccess.WRITE)
	if file == null:
		return "can't write %s (%s)" % [side, error_string(FileAccess.get_open_error())]
	file.store_string(text)
	var failed := file.get_error()
	file.close()
	if failed != Error.OK or FileAccess.get_file_as_string(side) != text:
		return "writing %s failed" % side
	var swapped := DirAccess.rename_absolute(side, path)
	if swapped != Error.OK:
		return "can't move %s into place (%s)" % [side, error_string(swapped)]
	return ""
