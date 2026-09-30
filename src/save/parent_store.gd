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
## Every write goes to the file, then to its mirror backup (BACKUP_SUFFIX:
## parent.json.bak, the same content, so never the code in plain text). Each
## goes to a side file (SIDE_SUFFIX) first, is read back, and only then takes
## the old file's place, so a kill mid-write leaves both complete.
##
## Loading (D130, proposed): the file if it reads; else (missing or
## unreadable, e.g. not JSON, another format, a bad field) the backup, with
## its code, tries and wait's end, refused loudly; the next write mends the
## file. Neither there: no code (first launch, setup). Neither readable (or one
## unreadable, the other missing): LOCKED (is_locked()), refused loudly. A
## locked store says a code exists (has_code(), so setup never shows again)
## but no code matches; the tries and the wait apply in memory only, as the
## files are left untouched until a set_code (the forgotten-code route)
## replaces them and unlocks the store.
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
## The mirror backup, next to the file, written after it with the same content.
const BACKUP_SUFFIX := ".bak"

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
## Neither the file nor its backup could be read: no code matches and
## nothing is written until a set_code.
var _locked := false


## A store on the file at `store_path`, loaded if it's there.
func _init(store_path := DEFAULT_PATH) -> void:
	path = store_path
	_load()


## Whether a parent code is set (a locked store counts as having one).
# @spec-link [[req_parent_gate_and_access]]
func has_code() -> bool:
	return _locked or not _hash_hex.is_empty()


## Whether the store is locked: neither its file nor the backup could be read,
## so no code matches until a new one is set.
# @spec-link [[req_denial_and_stepup_behavior]]
func is_locked() -> bool:
	return _locked


## Sets the parent code to `code` (exactly 6 ASCII digits, else refused
## loudly and nothing changes): a fresh salt and hash, the count and the wait
## reset, the file and its backup written (a locked store unlocks). For
## setup, changing the code and the code reset.
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
	_locked = false
	_save()


## Checks `code` against the parent code at wall time `now_wall_ms`: WAITING
## during a wait (nothing checked, nothing counted), else OK (count reset) or
## WRONG (counted; the 5th in a row starts the wait). Needs a code
## (has_code()): without one it is refused loudly and answers WRONG, uncounted.
## A locked store answers WRONG to every code, counted as usual.
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
	if not _locked and _hash(_salt_hex.hex_decode(), code) == _hash_hex:
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


## Reads the file into memory, or its backup when the file is missing or
## unreadable (refused loudly). Neither there: no code. Neither readable:
## locked (refused loudly), the files left as they are.
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[rule_parent_code_not_stored_plaintext]]
func _load() -> void:
	var backup := path + BACKUP_SUFFIX
	var main: Variant = _read(path)
	if main is Dictionary:
		_take(main)
		return
	var spare: Variant = _read(backup)
	if main == null and spare == null:
		return
	var main_why: String = "missing" if main == null else main
	if spare is Dictionary:
		push_error("ParentStore: %s is %s; using its backup %s (the next write replaces the file)."
				% [path, main_why, backup])
		_take(spare)
		return
	_lock("%s is %s and %s is %s" % [path, main_why, backup, "missing" if spare == null else spare])


## The parent file at `file_path`: its data (a Dictionary) if it reads, null
## if it isn't there, or why it's unreadable (a String).
static func _read(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != Error.OK:
		return "unreadable: not JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()]
	var why := _why_bad(json.data)
	if not why.is_empty():
		return "unreadable: " + why
	return json.data


## Takes the state of the readable parent file `data` into memory.
func _take(data: Dictionary) -> void:
	if data["code"] != null:
		_salt_hex = data["code"]["salt"]
		_hash_hex = data["code"]["hash"]
	_wrong_tries = int(data["wrong_tries"])
	_wait_until_ms = int(data["wait_until_ms"])


## Locks the store, loudly, for `why`: no code matches and the files are left
## untouched until a set_code.
# @spec-link [[req_denial_and_stepup_behavior]]
func _lock(why: String) -> void:
	_locked = true
	push_error("ParentStore: %s. The parent code is locked: no code matches until a new code is set; the files are left as they are." % why)


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


## Writes the state to the file, then to its backup; a failure is loud and
## leaves the file not yet swapped as it was. A locked store writes nothing:
## its files wait, untouched, for a set_code (which unlocks it first).
func _save() -> void:
	if _locked:
		return
	var code: Variant = null
	if has_code():
		code = {"salt": _salt_hex, "hash": _hash_hex}
	var text := JSON.stringify({"format": FORMAT, "code": code, "wrong_tries": _wrong_tries,
			"wait_until_ms": _wait_until_ms}, "\t")
	var why := _write(text)
	if not why.is_empty():
		push_error("ParentStore: %s" % why)


## Writes `text` to the file, then the same to its backup, each through its
## side file. Returns "" or why not.
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[rule_parent_code_not_stored_plaintext]]
func _write(text: String) -> String:
	var made := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if made != Error.OK and made != ERR_ALREADY_EXISTS:
		return "can't make %s (%s)" % [path.get_base_dir(), error_string(made)]
	var why := _write_through_side(path, text)
	if why.is_empty():
		why = _write_through_side(path + BACKUP_SUFFIX, text)
	return why


## Writes `text` to `file_path` via its side file, read back before it takes
## the old file's place. Returns "" or why not (the old file is then kept).
static func _write_through_side(file_path: String, text: String) -> String:
	var side := file_path + SIDE_SUFFIX
	var file := FileAccess.open(side, FileAccess.WRITE)
	if file == null:
		return "can't write %s (%s); the old %s is kept" % [side, error_string(FileAccess.get_open_error()), file_path]
	file.store_string(text)
	var failed := file.get_error()
	file.close()
	if failed != Error.OK or FileAccess.get_file_as_string(side) != text:
		return "writing %s failed; the old %s is kept" % [side, file_path]
	var swapped := DirAccess.rename_absolute(side, file_path)
	if swapped != Error.OK:
		return "can't move %s into place (%s); the old %s is kept" % [side, error_string(swapped), file_path]
	return ""
