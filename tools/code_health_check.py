#!/usr/bin/env python3
"""Checks the GDScript code against CODING_RULE.md's measurable rules.

    tools/code_health_check.py [--summary] [--no-info] [--root=DIR]

It reads every .gd file under src/ (the checked scope: its errors fail the
run), tools/ and tests/ (for information only: their findings are printed
as INFO and never change the exit code). Addons (addons/gut/) and the
git worktrees under .claude/ are never read.

Checks, per file (rule 6 unless said otherwise):

- size: effective LOC (non-blank lines that are not only a comment);
  WARN above 400, ERROR above 600.
- depth: the nesting depth of every function, the deepest block level of a
  statement counted from the function's body (a statement right in the body
  is depth 0, inside one `if` depth 1, and so on); ERROR above 4.
  Continuation lines (inside open brackets, or after a trailing backslash)
  don't count.
- doc: a `##` doc comment right above every `func` (ATD tags and
  annotations between them are skipped). Missing on a public function (no
  leading underscore): ERROR; on a private one, an engine callback
  (`_ready`, `_init`...) or a test (`test_*` in tests/): WARN.
- atd: the distinct atoms a file links (`# @spec-link [[id]]` in src/ and
  tools/, `# @test-link [[id]]` in tests/; repeats count once). In src/: no
  link at all on a file not listed in TECHNICAL: ERROR (rule 1: every
  business file carries one); more than 5 distinct atoms: WARN; more than
  10: ERROR. Atoms linked only on the file header (a tag not directly
  atop a declaration) and on no function or type: WARN (rule 1: atop the exact
  function or type). In tests/: a file with no @test-link: INFO; a
  @spec-link in a test file: ERROR-as-INFO (tests use @test-link only).
- clock (rule 2), src/sim/ only: no clock or global randomness. Comments
  and string literals are ignored. ERROR on any of: Time., OS.get_ticks_*,
  OS.get_unix_time, OS.get_system_time_*, Engine.get_physics_frames,
  Engine.get_process_frames, Engine.get_frames_drawn, the process deltas,
  the global random functions (randi, randf, randf_range, randi_range,
  randfn, randomize, seed, rand_from_seed), Array.shuffle / pick_random, a
  RandomNumberGenerator made outside src/sim/rng.gd, Timer.new,
  create_timer, Thread.new.

Output: one line per finding, `LEVEL check path:line message`, then a
summary. Exit code: 1 when src/ has an ERROR, else 0.

--summary prints the summary only; --no-info drops tools/ and tests/.
--self-test runs the checker's own small tests and exits.
"""
import argparse
import os
import re
import sys
import tempfile

LOC_WARN = 400
LOC_ERROR = 600
DEPTH_MAX = 4
ATOMS_WARN = 5
ATOMS_ERROR = 10

## Purely technical src/ files that may carry no ATD link (CODING_RULE.md
## rule 1: RNG, fixed step, hashing, test mode, debug tooling, renderers).
## Directories end with "/".
TECHNICAL = (
    "src/debug/",
    "src/test_mode/",
    "src/test_mode_guard.gd",
    "src/sim/rng.gd",
    "src/sim/fixed_step.gd",
    "src/sim/state_hash.gd",
    "src/sim/stable_id.gd",
    "src/sim/polyline.gd",
    "src/sim/terrain_segments.gd",
    "src/slimes/slime_renderer.gd",
    "src/slimes/slime_world.gd",
    "src/slimes/demo.gd",
    "src/components/placeholder_art.gd",
    "src/draw/shape_instances.gd",
    # Picks the native or the GDScript tick: both give the same state.
    "src/sim/tick_choice.gd",
    # Art only: O96 (what decoration may do) is open and has no atom yet.
    # It leaves this list when an atom covers O96's answer.
    "src/components/decoration.gd",
)

## Engine callbacks: private by name, but their intent is the engine's.
CALLBACKS = {
    "_init", "_ready", "_process", "_physics_process", "_draw", "_input",
    "_unhandled_input", "_gui_input", "_notification", "_enter_tree",
    "_exit_tree", "_get_configuration_warnings", "_to_string",
    "_get_property_list", "_get", "_set", "_validate_property",
    "_unhandled_key_input", "_shortcut_input", "_run", "_initialize",
    "_finalize", "_static_init",
}

CLOCK_PATTERNS = [
    (re.compile(r"\bTime\s*\."), "Time singleton"),
    (re.compile(r"\bOS\s*\.\s*get_ticks_(msec|usec)\b"), "OS.get_ticks_*"),
    (re.compile(r"\bOS\s*\.\s*get_unix_time\b"), "OS.get_unix_time"),
    (re.compile(r"\bOS\s*\.\s*get_system_time_(msecs|secs)\b"),
     "OS.get_system_time_*"),
    (re.compile(r"\bEngine\s*\.\s*get_(physics|process)_frames\b"),
     "Engine frame counter"),
    (re.compile(r"\bEngine\s*\.\s*get_frames_drawn\b"), "Engine frame counter"),
    (re.compile(r"\bget_(physics_)?process_delta_time\b"), "process delta"),
    (re.compile(r"(?<![\w.])(randi|randf|randf_range|randi_range|randfn|"
                r"randomize|seed|rand_from_seed)\s*\("), "global randomness"),
    (re.compile(r"\.\s*(shuffle|pick_random)\s*\("), "global randomness"),
    (re.compile(r"\bRandomNumberGenerator\s*\.\s*new\b"),
     "RandomNumberGenerator outside src/sim/rng.gd"),
    (re.compile(r"\bTimer\s*\.\s*new\b"), "ad-hoc timer"),
    (re.compile(r"\bcreate_timer\s*\("), "ad-hoc timer"),
    (re.compile(r"\bThread\s*\.\s*new\b"), "thread"),
]
RNG_FILE = "src/sim/rng.gd"

FUNC_RE = re.compile(r"^(\s*)(?:static\s+)?func\s+(\w+)\s*\(")
DECL_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?"
    r"(func|var|const|signal|enum|class)\b")
TAG_RE = re.compile(r"#\s*@(spec|test)-link\s+\[\[([^\]]+)\]\]")
ANNOTATION_RE = re.compile(r"^\s*@\w+")
STRING_RE = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')


class Finding:
    """One result line: level (ERROR, WARN, INFO), check, place, message."""

    def __init__(self, level, check, path, line, message):
        self.level = level
        self.check = check
        self.path = path
        self.line = line
        self.message = message

    def text(self):
        """The finding as one output line."""
        place = "%s:%d" % (self.path, self.line) if self.line else self.path
        return "%-5s %-5s %s %s" % (self.level, self.check, place, self.message)


def indent_level(line):
    """The indentation level of `line`: a tab or 4 spaces per level."""
    width = 0
    for ch in line:
        if ch == "\t":
            width += 4
        elif ch == " ":
            width += 1
        else:
            break
    return width // 4


def code_part(line):
    """`line` without its string literals and its trailing comment."""
    stripped = STRING_RE.sub('""', line)
    hash_at = stripped.find("#")
    return stripped if hash_at < 0 else stripped[:hash_at]


def is_comment_or_blank(line):
    """Whether `line` holds no code: blank, or only a comment."""
    s = line.strip()
    return s == "" or s.startswith("#")


def logical_starts(lines):
    """For every line, whether it starts a logical line (not a
    continuation inside open brackets or after a trailing backslash)."""
    starts = []
    open_brackets = 0
    continued = False
    for line in lines:
        starts.append(open_brackets == 0 and not continued)
        code = code_part(line)
        open_brackets += code.count("(") + code.count("[") + code.count("{")
        open_brackets -= code.count(")") + code.count("]") + code.count("}")
        open_brackets = max(open_brackets, 0)
        continued = code.rstrip().endswith("\\")
    return starts


def effective_loc(lines):
    """Effective LOC: lines that are neither blank nor only a comment."""
    return sum(1 for line in lines if not is_comment_or_blank(line))


def functions(lines):
    """Every named function as (line index, name, indent level, end index):
    its body runs to the next code line indented at its level or less."""
    starts = logical_starts(lines)
    found = []
    for i, line in enumerate(lines):
        m = FUNC_RE.match(line)
        if not m or not starts[i]:
            continue
        level = indent_level(line)
        end = len(lines)
        for j in range(i + 1, len(lines)):
            if is_comment_or_blank(lines[j]) or not starts[j]:
                continue
            if indent_level(lines[j]) <= level:
                end = j
                break
        found.append((i, m.group(2), level, end))
    return found


def depth_of(lines, start, level, end):
    """The deepest nesting in a function (see the module doc) and its line
    index. Statements of an inner lambda count as nested blocks."""
    starts = logical_starts(lines)
    deepest, where = 0, start
    for j in range(start + 1, end):
        if is_comment_or_blank(lines[j]) or not starts[j]:
            continue
        depth = indent_level(lines[j]) - level - 1
        if depth > deepest:
            deepest, where = depth, j
    return deepest, where


def has_doc(lines, func_index):
    """Whether a `##` comment sits right above the function, skipping ATD
    tag lines and annotations."""
    j = func_index - 1
    while j >= 0:
        s = lines[j].strip()
        if TAG_RE.search(s) or (ANNOTATION_RE.match(s) and not s.startswith("##")):
            j -= 1
            continue
        return s.startswith("##")
    return False


def tags(lines):
    """Every ATD tag as (line index, kind "spec" or "test", atom id)."""
    out = []
    for i, line in enumerate(lines):
        for m in TAG_RE.finditer(line):
            out.append((i, m.group(1), m.group(2).strip()))
    return out


def attached(lines, tag_index):
    """Whether the tag at `tag_index` sits atop a declaration (func, var,
    const, signal, enum, class): only tags, comments and annotations, no
    blank line, between them. A tag that isn't is on the file header."""
    for j in range(tag_index + 1, len(lines)):
        s = lines[j].strip()
        if s == "":
            return False
        if DECL_RE.match(lines[j]):
            return True
        if s.startswith("#") or (ANNOTATION_RE.match(s) and s.endswith(")")):
            continue
        return False
    return False


def is_technical(path):
    """Whether `path` is listed in TECHNICAL."""
    for entry in TECHNICAL:
        if entry.endswith("/") and path.startswith(entry):
            return True
        if path == entry:
            return True
    return False


def check_file(path, text):
    """Every finding on one file (`path` relative to the root, "/"-joined)."""
    lines = text.split("\n")
    scope = path.split("/", 1)[0]
    found = []
    loc = effective_loc(lines)
    if loc > LOC_ERROR:
        found.append(Finding("ERROR", "size", path, 0,
                             "%d effective LOC (error above %d)" % (loc, LOC_ERROR)))
    elif loc > LOC_WARN:
        found.append(Finding("WARN", "size", path, 0,
                             "%d effective LOC (warning above %d)" % (loc, LOC_WARN)))
    for start, name, level, end in functions(lines):
        deepest, where = depth_of(lines, start, level, end)
        if deepest > DEPTH_MAX:
            found.append(Finding("ERROR", "depth", path, where + 1,
                                 "%s(): nesting depth %d (at most %d)"
                                 % (name, deepest, DEPTH_MAX)))
        if not has_doc(lines, start):
            private = name.startswith("_")
            test = scope == "tests" and name.startswith("test_")
            what = "engine callback" if name in CALLBACKS else (
                "private function" if private else
                "test function" if test else "public function")
            found.append(Finding("WARN" if private or test else "ERROR", "doc", path,
                                 start + 1, "%s(): no ## doc comment (%s)"
                                 % (name, what)))
    found.extend(check_atd(path, lines, scope))
    if path.startswith("src/sim/"):
        found.extend(check_clock(path, lines))
    return loc, found


def check_atd(path, lines, scope):
    """The ATD density findings on one file (see the module doc)."""
    found = []
    all_tags = tags(lines)
    atoms = sorted({atom for _, _, atom in all_tags})
    if scope == "tests":
        for i, kind, atom in all_tags:
            if kind == "spec":
                found.append(Finding("ERROR", "atd", path, i + 1,
                                     "@spec-link in a test file: [[%s]]" % atom))
        if not any(kind == "test" for _, kind, _ in all_tags):
            found.append(Finding("INFO", "atd", path, 0, "no @test-link"))
        return found
    if scope == "src" and not atoms and not is_technical(path):
        found.append(Finding("ERROR", "atd", path, 0,
                             "no ATD link on a file not listed as technical"))
    if len(atoms) > ATOMS_ERROR:
        found.append(Finding("ERROR", "atd", path, 0,
                             "%d distinct atoms (at most %d)" % (len(atoms), ATOMS_ERROR)))
    elif len(atoms) > ATOMS_WARN:
        found.append(Finding("WARN", "atd", path, 0,
                             "%d distinct atoms (warning above %d)" % (len(atoms), ATOMS_WARN)))
    on_header = {atom for i, _, atom in all_tags if not attached(lines, i)}
    below = {atom for i, _, atom in all_tags if attached(lines, i)}
    header_only = sorted(on_header - below)
    if header_only:
        found.append(Finding("WARN", "atd", path, 0,
                             "%d atom(s) linked on the file header only: %s"
                             % (len(header_only), ", ".join(header_only))))
    return found


def check_clock(path, lines):
    """The src/sim clock and randomness findings on one file."""
    found = []
    for i, line in enumerate(lines):
        if FUNC_RE.match(line):
            continue  # a definition (Rng.randf()), not a call
        code = code_part(line)
        for pattern, what in CLOCK_PATTERNS:
            if not pattern.search(code):
                continue
            if what.startswith("RandomNumberGenerator") and path == RNG_FILE:
                continue
            found.append(Finding("ERROR", "clock", path, i + 1,
                                 "%s: %s" % (what, line.strip())))
    return found


def gd_files(root, top):
    """Every .gd file under root/top, as "/"-joined paths relative to root,
    sorted."""
    out = []
    base = os.path.join(root, top)
    for directory, subdirs, names in os.walk(base):
        subdirs[:] = sorted(d for d in subdirs if not d.startswith("."))
        for name in names:
            if name.endswith(".gd"):
                full = os.path.join(directory, name)
                out.append(os.path.relpath(full, root).replace(os.sep, "/"))
    return sorted(out)


def run(root, with_info):
    """Checks every file; returns (findings, per-scope stats)."""
    scopes = ["src"] + (["tools", "tests"] if with_info else [])
    findings = []
    stats = {}
    for scope in scopes:
        files = gd_files(root, scope)
        locs = []
        for path in files:
            with open(os.path.join(root, path), encoding="utf-8") as handle:
                loc, found = check_file(path, handle.read())
            locs.append((loc, path))
            if scope != "src":
                for f in found:
                    if f.level != "INFO":
                        f.message = "[%s] %s" % (f.level, f.message)
                        f.level = "INFO"
            findings.extend(found)
        stats[scope] = (len(files), sum(loc for loc, _ in locs), sorted(locs, reverse=True))
    return findings, stats


def summary(findings, stats):
    """The summary lines: per scope and check, the counts by level."""
    out = ["", "Summary"]
    for scope, (count, total, locs) in stats.items():
        out.append("  %s: %d files, %d effective LOC" % (scope, count, total))
        mine = [f for f in findings if f.path.startswith(scope + "/")]
        for check in ("size", "depth", "doc", "atd", "clock"):
            levels = {}
            for f in mine:
                if f.check == check:
                    key = f.level
                    if f.level == "INFO" and f.message.startswith("["):
                        key = "INFO " + f.message[1:f.message.index("]")]
                    levels[key] = levels.get(key, 0) + 1
            if scope == "src" and not levels:
                out.append("    %-5s none" % check)
            elif levels:
                out.append("    %-5s %s" % (check, ", ".join(
                    "%s %d" % (k, v) for k, v in sorted(levels.items()))))
        if scope == "src":
            out.append("    largest: " + ", ".join(
                "%s %d" % (p.split("/")[-1], loc) for loc, p in locs[:6]))
    errors = sum(1 for f in findings if f.level == "ERROR")
    warns = sum(1 for f in findings if f.level == "WARN")
    out.append("  src/ total: %d ERROR, %d WARN -> %s"
               % (errors, warns, "FAIL" if errors else "PASS"))
    return out


def self_test():
    """The checker's own tests, on small made-up files."""
    sample = "\n".join([
        "class_name A",
        "## The class.",
        "# @spec-link [[req_head_only]]",
        "# @spec-link [[req_both]]",
        "",
        "## Doc.",
        "# @spec-link [[req_both]]",
        "func good(x: int) -> int:",
        "\tvar a := [1,",
        "\t\t\t\t\t\t\t2]",
        "\tif x:",
        "\t\tfor i in a:",
        "\t\t\tif i:",
        "\t\t\t\twhile i:",
        "\t\t\t\t\tif i:",
        "\t\t\t\t\t\tpass  # depth 5",
        "\treturn x",
        "",
        "func bare() -> void:",
        "\tvar t = Time.get_ticks_msec()  # Time. in a comment is fine",
        "\tvar r = rng.randf()",
        "\tvar s = randf()",
        "\tvar q = \"Time.\"",
        "func randf() -> float:  # a definition, not a call",
        "\treturn 0.0",
        "",
        "func _ready() -> void:",
        "\tpass",
    ])
    loc, found = check_file("src/sim/a.gd", sample)
    got = sorted((f.level, f.check, f.line) for f in found)
    expect = sorted([
        ("ERROR", "depth", 16),
        ("ERROR", "doc", 19),
        ("ERROR", "doc", 24),
        ("WARN", "doc", 27),
        ("WARN", "atd", 0),
        ("ERROR", "clock", 20),
        ("ERROR", "clock", 22),
    ])
    assert loc == 20, loc
    assert got == expect, got
    header = [f for f in found if f.check == "atd"][0]
    assert "req_head_only" in header.message and "req_both" not in header.message
    _, found = check_file("src/sim/b.gd", "func f() -> void:\n\tpass\n")
    assert [(f.level, f.check) for f in found if f.check == "atd"] == [("ERROR", "atd")]
    _, found = check_file("src/sim/rng.gd", "## D.\nfunc f():\n\tRandomNumberGenerator.new()\n")
    assert not found, [f.text() for f in found]
    _, found = check_file("tests/unit/t.gd", "# @spec-link [[x]]\n## D.\nfunc test_a():\n\tpass\n")
    assert sorted(f.message for f in found) == ["@spec-link in a test file: [[x]]",
                                                "no @test-link"], found
    with tempfile.TemporaryDirectory() as root:
        os.makedirs(os.path.join(root, "src", "sim"))
        with open(os.path.join(root, "src", "sim", "c.gd"), "w") as handle:
            handle.write("## D.\n# @spec-link [[x]]\nfunc f():\n\tpass\n")
        findings, stats = run(root, False)
        assert findings == [] and stats["src"][0] == 1, findings
    print("self-test: ok")


def main():
    """Parses the arguments, runs the checks, prints, sets the exit code."""
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--root", default=os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))))
    parser.add_argument("--summary", action="store_true")
    parser.add_argument("--no-info", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    findings, stats = run(args.root, not args.no_info)
    if not args.summary:
        order = {"ERROR": 0, "WARN": 1, "INFO": 2}
        for f in sorted(findings, key=lambda f: (f.path.split("/")[0] != "src",
                                                  order[f.level], f.path, f.line)):
            print(f.text())
    print("\n".join(summary(findings, stats)))
    return 1 if any(f.level == "ERROR" for f in findings) else 0


if __name__ == "__main__":
    sys.exit(main())
