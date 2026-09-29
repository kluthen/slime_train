#!/usr/bin/env python3
"""Merge the level-rules checker's JSON with the rules as written today.

Reads the checker's JSON (tools/check_level.gd ... --json; the last line of
its output, the Godot banner above it dropped) from a file or stdin, reads the
rules from specs/level-design.md (never from a copy: the rules change), and
prints, for every rule of the spec, its text as written, the checker's short
title and status, its findings (with a command to look at each and one to
re-check the rule), the checker's "by eye" item and its notes.

A rule of the spec missing from the run is "NOT IN THIS RUN" (a --rule
filter, or a rule newer than the checker: check it by hand); a rule the
checker reports that the spec no longer has is flagged too.

Usage, from the project root:
  godot --headless --path . -s res://tools/check_level.gd -- --level=<id> --json 2>/dev/null \
    | tail -n 1 | python3 .claude/skills/level-review/scripts/rules_table.py -
  python3 .claude/skills/level-review/scripts/rules_table.py check.json [--spec specs/level-design.md]

Exit code: 0 no FAIL, 1 the level loads with errors or a rule FAILs (as the
checker's own exit code), 2 the input or the spec can't be read.
"""

import json
import re
import sys

SPEC = "specs/level-design.md"
## One screen in level pixels (LevelData.SCREEN): findings give x in screens,
## test mode's --at=x,y takes level pixels.
SCREEN = 1152
## The rules whose behaviour runs --fast skips: re-check them in full.
BEHAVIOUR_RULES = {1, 2, 7}


def read_spec(path):
    """(status line, [(number, group heading, text)]): the numbered items under
    the spec's `##` headings, each item's continuation lines joined."""
    status = ""
    rules = []
    group = None
    current = None
    with open(path, encoding="utf-8") as spec:
        for raw in spec:
            line = raw.rstrip("\n")
            if not status and line.startswith("Status:"):
                status = line.strip()
            heading = re.match(r"^##\s+(.*)$", line)
            item = re.match(r"^(\d+)\.\s+(.*)$", line)
            if heading:
                current = None
                group = heading.group(1).strip()
            elif item and group is not None:
                current = [int(item.group(1)), group, item.group(2).strip()]
                rules.append(current)
            elif current is not None and line.startswith((" ", "\t")) and line.strip():
                current[2] += " " + line.strip()
            else:
                current = None
    return status, [tuple(rule) for rule in rules]


def main(argv):
    source = "-"
    spec = SPEC
    args = argv[1:]
    while args:
        arg = args.pop(0)
        if arg == "--spec" and args:
            spec = args.pop(0)
        else:
            source = arg
    try:
        text = sys.stdin.read() if source == "-" else open(source, encoding="utf-8").read()
        lines = [line for line in text.splitlines() if line.strip().startswith("{")]
        check = json.loads(lines[-1])
    except (OSError, ValueError, IndexError) as error:
        print("rules_table: no checker JSON in %s (%s). Run check_level.gd without --json to see "
              "why (exit 2: a bad level ID, or a level that doesn't load)." % (source, error),
              file=sys.stderr)
        return 2
    try:
        status_line, rules = read_spec(spec)
    except OSError as error:
        print("rules_table: can't read the rules in %s (%s)" % (spec, error), file=sys.stderr)
        return 2

    level = check.get("level", "?")
    fast = bool(check.get("fast"))
    results = {result["rule"]: result for result in check.get("results", [])}
    counts = check.get("counts", {})
    load = check.get("load", {})
    by_eye = sum(1 for result in results.values() if result.get("manual"))

    print("Level %s (version %s), %s" % (level, check.get("version", "?"),
          "FAST run: behaviour runs skipped, rules 1, 2 and 7 not fully checked: run it again without --fast"
          if fast else "full run (behaviour runs included)"))
    print("Spec: %s, %s (%d rules)" % (spec, status_line or "no status line", len(rules)))
    print("Checker: %s (a MANUAL status: nothing checkable by code; by-eye items, "
          "under any status: %d)" % (", ".join("%d %s" % (counts.get(k, 0), k)
          for k in ("PASS", "FAIL", "MANUAL", "N/A")), by_eye))
    print("load: %s %s" % (load.get("status", "?"), load.get("title", "")))
    for finding in load.get("findings", []):
        print("  FINDING %s" % finding.get("text", ""))

    group = None
    for number, heading, rule_text in rules:
        if heading != group:
            group = heading
            print("\n## %s" % heading)
        result = results.get(number)
        if not result:
            print("\nrule %d [NOT IN THIS RUN]" % number)
            print("  spec: %s" % rule_text)
            print("  not in this checker run (a --rule filter, or a rule newer than the checker): "
                  "check it by hand from the spec's text")
            continue
        print("\nrule %d [%s] %s" % (number, result["status"], result.get("title", "")))
        print("  spec: %s" % rule_text)
        for finding in result.get("findings", []):
            where = finding.get("id", "")
            x = finding.get("x")
            has_x = isinstance(x, (int, float)) and x == x
            place = where + (" (x %.2f screens)" % x if has_x else "")
            print("  FINDING %s: %s" % (place or "level", finding.get("text", "")))
            if where:
                print("    look: godot --path . -- --test-mode --level=%s --seed=1 --at=%s" % (level, where))
            elif has_x:
                print("    look: godot --path . -- --test-mode --level=%s --seed=1 --at=%d,0 "
                      "(x in px; set y to the height to look at)" % (level, round(x * SCREEN)))
        if result.get("findings"):
            print("    re-check: godot --headless --path . -s res://tools/check_level.gd -- --level=%s%s --rule=%d"
                  % (level, "" if number in BEHAVIOUR_RULES else " --fast", number))
        if result.get("manual"):
            print("  by eye: %s" % result["manual"])
        for note in result.get("notes", []):
            print("  note: %s" % note)

    spec_numbers = [number for number, _, _ in rules]
    if spec_numbers != list(range(1, len(spec_numbers) + 1)):
        print("\nThe spec's rule numbers aren't 1 to %d in order (%s): check that every rule was read."
              % (len(spec_numbers), ", ".join(str(n) for n in spec_numbers)))
    extra = sorted(set(results) - set(spec_numbers))
    if extra:
        print("\nThe checker reports rules the spec no longer has: %s. The checker is out of date "
              "(a follow-up for the tools)." % ", ".join(str(n) for n in extra))
    missing = sorted(set(spec_numbers) - set(results))
    if missing:
        print("\nRules of the spec not in this run: %s. Without a --rule filter, the checker doesn't "
              "know them yet: check them by hand, and report it (a follow-up for the tools)."
              % ", ".join(str(n) for n in missing))
    failed = counts.get("FAIL", 0) > 0 or load.get("status") == "FAIL"
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
