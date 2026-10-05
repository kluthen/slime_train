#!/usr/bin/env python3
"""Reads the slime census back from a log (src/debug/slime_census.gd).

    tools/census.py [--out=DIR] [--rows=N] LOG
    tools/census.py --self-test

LOG is a desktop run's stdout or a phone session's logcat.txt (any prefix
before "CENSUS " is ignored, so `logcat -v threadtime` works). Each census is
a "CENSUS begin" line, one "CENSUS slime" line per slime and a "CENSUS end"
line (the class doc of src/debug/slime_census.gd lists every key).

It writes one CSV per census, census-<NN>-tick<T>.csv, under DIR (default:
a "census" folder next to LOG, the session folder): one row per slime, the
census's own fields first (census, tick, time, reason, fixture, tick_kind),
then every slime key in the order the lines give them; a key a line lacks is
left empty. Then, for each census, it prints a short text table of the train
front first (rank 1: the furthest along the loop): rank, id, state, route
and section, dist and the gap to the slime ahead, the hold (what holds it
back), the dip nudge, the next hop's kind (and * when the speed cap cuts
it), the last hop's kind, advance and whether it landed short, and the
slimes it touches. --rows=N: the first N train slimes (default 20; 0: all).
Before each table, a summary line: the slimes by state, the holds, the next
hop kinds, the train slimes in the air, the landed last hops that were short.

A census without its "CENSUS end" line (a cut log) is reported as cut and
still written. --self-test runs it on a canned log and checks the output.
Exit: 0; 1 when the log holds no census; 2 on bad arguments.
"""
# @spec-link [[req_platform_and_performance_targets]]

import argparse
import collections
import csv
import os
import sys
import tempfile

TAG = "CENSUS "
# The census's own fields, first in every CSV row (from its "begin" line).
CENSUS_FIELDS = ("census", "tick", "time", "reason", "fixture", "tick_kind")


def parse_tokens(text):
    """The key=value tokens of `text` (a census line from its kind on) as a dict, in order."""
    out = {}
    for token in text.split():
        if "=" not in token:
            raise ValueError("not a key=value token: %r" % token)
        key, value = token.split("=", 1)
        out[key] = value
    return out


def read_censuses(lines):
    """The censuses in `lines`, in order: dicts {"index", "begin", "slimes" (list of dicts), "end" (dict or None)}."""
    censuses = []
    current = None
    for raw in lines:
        at = raw.find(TAG)
        if at < 0:
            continue
        rest = raw[at + len(TAG):].strip()
        kind, _, fields = rest.partition(" ")
        if kind == "begin":
            current = {"index": len(censuses) + 1, "begin": parse_tokens(fields), "slimes": [], "end": None}
            censuses.append(current)
        elif kind == "slime" and current is not None and current["end"] is None:
            current["slimes"].append(parse_tokens(fields))
        elif kind == "end" and current is not None and current["end"] is None:
            current["end"] = parse_tokens(fields)
    return censuses


def csv_name(census):
    """The census's CSV file name."""
    return "census-%02d-tick%s.csv" % (census["index"], census["begin"].get("tick", "x"))


def write_csv(census, path):
    """Writes the census's rows to `path` (see the module doc)."""
    keys = []
    for slime in census["slimes"]:
        for key in slime:
            if key not in keys:
                keys.append(key)
    meta = {"census": census["index"]}
    for key in CENSUS_FIELDS[1:]:
        meta[key] = census["begin"].get(key, "")
    with open(path, "w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(list(CENSUS_FIELDS) + keys)
        for slime in census["slimes"]:
            writer.writerow([meta[key] for key in CENSUS_FIELDS] + [slime.get(key, "") for key in keys])


def train_front_first(census):
    """The census's train slimes (those with a rank), rank 1 first."""
    train = [s for s in census["slimes"] if s.get("rank", "0") not in ("", "0", "-")]
    return sorted(train, key=lambda s: int(s["rank"]))


def counted(values):
    """'a 3, b 1' for the values, the most common first (ties by name)."""
    counts = collections.Counter(values)
    return ", ".join("%s %d" % (k, n) for k, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])))


def summary_lines(census):
    """The census's title and summary lines."""
    begin = census["begin"]
    slimes = census["slimes"]
    end = census["end"]
    title = "Census %d: tick %s (%s s), %s, fixture %s, %s tick, %d slime lines" % (
        census["index"], begin.get("tick", "?"), begin.get("time", "?"), begin.get("reason", "?"),
        begin.get("fixture", "?"), begin.get("tick_kind", "?"), len(slimes))
    if end is None:
        title += " (CUT: no end line, %s announced)" % begin.get("slimes", "?")
    else:
        title += ", %s ms" % end.get("ms", "?")
        if end.get("lines") != str(len(slimes)):
            title += " (MISMATCH: the end line says %s)" % end.get("lines")
    out = [title]
    out.append("  states: " + counted(s.get("state", "?") for s in slimes))
    holds = []
    for slime in slimes:
        holds.extend(slime.get("hold", "-").split(","))
    out.append("  holds:  " + counted(holds))
    train = train_front_first(census)
    if train:
        landed = [s for s in train if s.get("last_short") in ("0", "1")]
        short = sum(1 for s in landed if s["last_short"] == "1")
        in_air = sum(1 for s in train if s.get("in_air") == "1")
        capped = sum(1 for s in train if s.get("capped") == "1")
        out.append("  train %d: next hop %s; capped %d; in the air %d; last hop landed short %d of %d" % (
            len(train), counted(s.get("next_kind", "-") for s in train), capped, in_air, short, len(landed)))
        out.append("  nudge: " + counted(s.get("nudge", "-") for s in train))
    return out


def table_lines(census, rows):
    """The census's train table, front first (`rows` rows at most; 0: all)."""
    train = train_front_first(census)
    if rows > 0:
        train = train[:rows]
    head = ("rank", "id", "state", "route/sect", "dist", "gap", "hold", "nudge", "next", "last", "adv", "short",
            "touch")
    table = [head]
    for s in train:
        nxt = s.get("next_kind", "-") + ("*" if s.get("capped") == "1" else "")
        table.append((s.get("rank", ""), s.get("id", ""), s.get("state", ""),
                      "%s/%s" % (s.get("route", "-"), s.get("section", "-")), s.get("dist", ""),
                      s.get("gap_ahead", "-"), s.get("hold", "-"), s.get("nudge", "-"), nxt,
                      s.get("last_kind", "-"), s.get("last_advance", "-"), s.get("last_short", "-"),
                      s.get("touch", "-")))
    widths = [max(len(str(row[k])) for row in table) for k in range(len(head))]
    return ["  " + "  ".join(str(row[k]).ljust(widths[k]) for k in range(len(head))).rstrip() for row in table]


def report(lines, out_dir, rows=20):
    """Writes the CSVs under `out_dir` and returns the text to print, or None without a census."""
    censuses = read_censuses(lines)
    if not censuses:
        return None
    os.makedirs(out_dir, exist_ok=True)
    out = []
    for census in censuses:
        path = os.path.join(out_dir, csv_name(census))
        write_csv(census, path)
        out += summary_lines(census)
        out += table_lines(census, rows)
        out.append("  -> %s" % path)
        out.append("")
    return out


# The self-test's log: logcat prefixes on some lines, noise, two censuses
# (the second cut: no end line), three slimes in the first (two train
# slimes ranked 2 and 1, a sleeper) and one in the second.
CANNED_LOG = """10-05 17:00:00.000  100  101 I godot   : Slime Train booted
10-05 17:00:10.000  100  101 I godot   : CENSUS begin tick=600 time=10.00 slimes=3 tick_kind=native fixture=stress-dense reason=timer open_gates=s1.gate,s2.gate
10-05 17:00:10.001  100  101 I godot   : CENSUS slime id=4 sid=s3.sleeper.01 species=A size=1 state=train hold=dip_gathering touch=7 rank=2 ahead=7 gap_ahead=40.5 route=outgoing section=3 dist=100.0 nudge=gathering next_kind=ahead capped=0 in_air=0 last_kind=ahead last_advance=20.0 last_short=1
CENSUS slime id=7 sid=s3.sleeper.02 species=B size=1 state=train hold=door touch=4 rank=1 ahead=- gap_ahead=- route=outgoing section=3 dist=140.5 nudge=- next_kind=step_foot capped=1 in_air=1 last_kind=step_foot last_advance=90.0 last_short=0
CENSUS slime id=9 sid=s3.sleeper.09 species=C size=1 state=sleeper hold=asleep touch=-
10-05 17:00:10.002  100  101 I godot   : CENSUS end tick=600 lines=3 ms=1.5
noise
CENSUS begin tick=1200 time=20.00 slimes=2 tick_kind=gdscript fixture=none reason=button
CENSUS slime id=4 state=free hold=- phase=answering
"""


def self_test():
    """Checks the extractor on the canned log; prints its output and returns 0, or raises AssertionError."""
    censuses = read_censuses(CANNED_LOG.splitlines())
    assert len(censuses) == 2, censuses
    first, second = censuses
    assert first["begin"]["tick"] == "600" and first["begin"]["open_gates"] == "s1.gate,s2.gate", first["begin"]
    assert [s["id"] for s in first["slimes"]] == ["4", "7", "9"], first["slimes"]
    assert first["end"] == {"tick": "600", "lines": "3", "ms": "1.5"}, first["end"]
    assert second["end"] is None and len(second["slimes"]) == 1, second
    assert [s["id"] for s in train_front_first(first)] == ["7", "4"], "front first"
    summary = summary_lines(first)
    assert summary[0] == ("Census 1: tick 600 (10.00 s), timer, fixture stress-dense, native tick, 3 slime lines, "
                          "1.5 ms"), summary
    assert summary[1] == "  states: train 2, sleeper 1", summary
    assert summary[2] == "  holds:  asleep 1, dip_gathering 1, door 1", summary
    assert summary[3] == ("  train 2: next hop ahead 1, step_foot 1; capped 1; in the air 1; "
                          "last hop landed short 1 of 2"), summary
    assert summary[4] == "  nudge: - 1, gathering 1", summary
    assert summary_lines(second)[0].endswith("(CUT: no end line, 2 announced)"), summary_lines(second)
    table = table_lines(first, 20)
    assert table[0].split() == ["rank", "id", "state", "route/sect", "dist", "gap", "hold", "nudge", "next", "last",
                                "adv", "short", "touch"], table
    assert table[1].split() == ["1", "7", "train", "outgoing/3", "140.5", "-", "door", "-", "step_foot*",
                                "step_foot", "90.0", "0", "4"], table
    assert table[2].split()[:2] == ["2", "4"], table
    assert len(table_lines(first, 1)) == 2, "--rows=1: one row"
    with tempfile.TemporaryDirectory() as out_dir:
        text = report(CANNED_LOG.splitlines(), out_dir)
        names = sorted(os.listdir(out_dir))
        assert names == ["census-01-tick600.csv", "census-02-tick1200.csv"], names
        with open(os.path.join(out_dir, names[0]), newline="") as handle:
            rows = list(csv.reader(handle))
        assert rows[0][:6] == list(CENSUS_FIELDS) and rows[0][6:9] == ["id", "sid", "species"], rows[0]
        assert len(rows) == 4, rows
        assert rows[1][:6] == ["1", "600", "10.00", "timer", "stress-dense", "native"], rows[1]
        assert rows[3][rows[0].index("rank")] == "", "a key a line lacks is empty"
        print("\n".join(text))
    try:
        parse_tokens("id=1 broken")
    except ValueError:
        pass
    else:
        raise AssertionError("a token without '=' must fail")
    assert report(["no census here"], tempfile.gettempdir()) is None
    print("census self-test: OK")
    return 0


def main(argv):
    """Parses `argv`, writes the CSVs and prints the tables; returns the exit code."""
    parser = argparse.ArgumentParser(description="Reads the slime census back from a log.")
    parser.add_argument("log", nargs="?", help="a run's stdout or a session's logcat.txt")
    parser.add_argument("--out", help="where the CSVs go (default: a census folder next to LOG)")
    parser.add_argument("--rows", type=int, default=20, help="train slimes per table (0: all)")
    parser.add_argument("--self-test", action="store_true", help="check the extractor on a canned log")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    if args.log is None:
        parser.error("a log is needed (or --self-test)")
    if args.rows < 0:
        parser.error("--rows expects a whole number >= 0")
    out_dir = args.out or os.path.join(os.path.dirname(os.path.abspath(args.log)), "census")
    with open(args.log, errors="replace") as handle:
        text = report(handle.read().splitlines(), out_dir, args.rows)
    if text is None:
        print("tools/census.py: no census in %s" % args.log, file=sys.stderr)
        return 1
    print("\n".join(text))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
