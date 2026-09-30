#!/usr/bin/env python3
"""Summarises a phone perf session from its log only (tools/android/perf.sh).

    tools/android/perf_summary.py [--cold=S] [--warm=S] [--thermal=FILE] PERF_LOG
    tools/android/perf_summary.py --self-test

PERF_LOG holds the perf log's lines (src/debug/perf_log.gd, whose class doc
lists the PERF line's fields): perf.sh's perf.log, or a whole logcat capture
(any prefix before "PERF" is ignored, so `logcat -v threadtime` works too).
Lines starting with "# " (perf.sh's header: device, launch) are echoed first.

It prints the whole session, then, when asked, the cold window (--cold=S: the
PERF lines within S seconds of the first) and the warm window (--warm=S: the
last S seconds of lines). For each: fps p50, p5 and min over the lines (p5:
95 % of the lines ran at least that fast, the fps side of a p95), frame_ms
p95 (the median and the max of the lines' p95s) and the worst frame, ms per
tick (weighted by ticks), ms per frame in ticks, outside them (the rest) and
in the whole process, ticks per frame (weighted by frames), active bodies and
candidate pairs (weighted by frames), the slime counts (mean and max), the
sections the camera was in (lines in each: seconds at --perf-log=1) and the
zoom range.

--thermal=FILE reads perf.sh's thermal.log (one sample a line:
"<date> elapsed_s=<s> thermal_status=<0..6|unavailable> battery_c=<C|unavailable>")
and prints the thermal status's first, max and last with its timeline (every
change) and the battery temperature's first, max and last.

--self-test runs the summary on a canned log and checks its numbers.
Exit: 0; 1 when the log holds no PERF line; 2 on bad arguments.
"""
# @spec-link [[req_platform_and_performance_targets]]

import argparse
import math
import statistics
import sys

# The PERF line's fields that must be there (src/debug/perf_log.gd).
REQUIRED = ("t", "frames", "fps", "frame_ms_p95", "frame_ms_max", "process_ms_mean", "ticks", "ticks_per_frame_mean",
            "ticks_per_frame_max", "tick_ms_mean", "tick_ms_frame_mean", "rest_ms_mean", "on_screen",
            "simulated", "off_screen", "bodies", "active", "pairs", "zoom")
# The count fields summarised by mean and max; parked and section are newer
# (a log without them just skips them).
COUNTS = ("on_screen", "simulated", "off_screen", "parked", "bodies")
# Android's thermal status names (PowerManager.THERMAL_STATUS_*).
THERMAL_NAMES = {0: "none", 1: "light", 2: "moderate", 3: "severe", 4: "critical", 5: "emergency",
                 6: "shutdown"}


def parse_perf_line(text):
    """The fields of one PERF line as a dict of floats, or None when `text` holds none.

    A malformed field (not key=number) raises ValueError: the line is a contract."""
    at = text.find("PERF t=")
    if at < 0:
        return None
    fields = {}
    for part in text[at:].split()[1:]:
        key, sep, value = part.partition("=")
        if not sep:
            raise ValueError("PERF field without '=': %r in %r" % (part, text.strip()))
        fields[key] = float(value)
    missing = [key for key in REQUIRED if key not in fields]
    if missing:
        raise ValueError("PERF line without %s: %r" % (", ".join(missing), text.strip()))
    return fields


def read_log(lines):
    """(header lines, PERF_INFO line or None, PERF records) of a log's `lines`."""
    header, info, records = [], None, []
    for text in lines:
        text = text.rstrip("\r\n")
        if text.startswith("# "):
            header.append(text)
        elif "PERF_INFO " in text and info is None:
            info = text[text.find("PERF_INFO "):]
        else:
            record = parse_perf_line(text)
            if record is not None:
                records.append(record)
    return header, info, records


def nearest_rank(values, share):
    """The nearest-rank `share` percentile of `values` (not empty), as the perf log's."""
    ordered = sorted(values)
    rank = min(max(1, math.ceil(share * len(ordered))), len(ordered))
    return ordered[rank - 1]


def weighted_mean(records, key, weight):
    """The mean of `key` over `records`, each weighted by its `weight` field (0 when none weigh)."""
    total = sum(r[weight] for r in records)
    if total <= 0:
        return 0.0
    return sum(r[key] * r[weight] for r in records) / total


def cold_window(records, seconds):
    """The records within `seconds` of the first line (by t)."""
    if not records:
        return []
    return [r for r in records if r["t"] - records[0]["t"] < seconds]


def warm_window(records, seconds):
    """The records within the last `seconds` (by t)."""
    if not records:
        return []
    return [r for r in records if records[-1]["t"] - r["t"] < seconds]


def summarise(records):
    """The summary numbers of `records` (at least one) as a dict."""
    fps = [r["fps"] for r in records]
    p95 = [r["frame_ms_p95"] for r in records]
    out = {
        "lines": len(records),
        "t_first": records[0]["t"],
        "t_last": records[-1]["t"],
        "fps_p50": nearest_rank(fps, 0.50),
        "fps_p5": nearest_rank(fps, 0.05),
        "fps_min": min(fps),
        "p95_median": statistics.median(p95),
        "p95_max": max(p95),
        "frame_ms_max": max(r["frame_ms_max"] for r in records),
        "process_ms": weighted_mean(records, "process_ms_mean", "frames"),
        "tick_ms": weighted_mean(records, "tick_ms_mean", "ticks"),
        "tick_ms_frame": weighted_mean(records, "tick_ms_frame_mean", "frames"),
        "rest_ms": weighted_mean(records, "rest_ms_mean", "frames"),
        "ticks_per_frame": weighted_mean(records, "ticks_per_frame_mean", "frames"),
        "ticks_per_frame_max": max(r["ticks_per_frame_max"] for r in records),
        "active": weighted_mean(records, "active", "frames"),
        "pairs": weighted_mean(records, "pairs", "frames"),
        "zoom_min": min(r["zoom"] for r in records),
        "zoom_max": max(r["zoom"] for r in records),
        "counts": {},
        "sections": {},
    }
    for key in COUNTS:
        values = [r[key] for r in records if key in r]
        if values:
            out["counts"][key] = (statistics.fmean(values), max(values))
    for r in records:
        if "section" in r:
            section = int(r["section"])
            out["sections"][section] = out["sections"].get(section, 0) + 1
    return out


def format_summary(title, records):
    """The printed summary of `records` titled `title` (lines of text)."""
    if not records:
        return ["== %s: no PERF line" % title]
    s = summarise(records)
    counts = "  ".join("%s %.0f (max %d)" % (key, mean, most) for key, (mean, most) in s["counts"].items())
    lines = [
        "== %s: %d PERF lines, t=%.1f..%.1f s" % (title, s["lines"], s["t_first"], s["t_last"]),
        "  fps             p50 %.1f  p5 %.1f  min %.1f" % (s["fps_p50"], s["fps_p5"], s["fps_min"]),
        "  frame_ms p95    median %.2f  max %.2f  (worst frame %.2f)" % (
            s["p95_median"], s["p95_max"], s["frame_ms_max"]),
        "  per frame       ticks %.2f (max %d)  in ticks %.2f ms  rest %.2f ms" % (
            s["ticks_per_frame"], s["ticks_per_frame_max"], s["tick_ms_frame"], s["rest_ms"]),
        "  per tick        %.2f ms   process per frame %.2f ms" % (s["tick_ms"], s["process_ms"]),
        "  solver (mean)   active %.1f  pairs %.1f" % (s["active"], s["pairs"]),
        "  slimes (mean)   " + counts,
    ]
    if s["sections"]:
        lines.append("  section (lines) " + "  ".join(
            "s%d %d" % (section, n) for section, n in sorted(s["sections"].items())))
    lines.append("  zoom            %.3f..%.3f" % (s["zoom_min"], s["zoom_max"]))
    return lines


def parse_sample(text):
    """(elapsed s, thermal status int or None, battery C or None) of one thermal.log line, or None."""
    fields = dict(part.split("=", 1) for part in text.split()[1:] if "=" in part)
    if "elapsed_s" not in fields:
        return None
    status = fields.get("thermal_status", "unavailable")
    battery = fields.get("battery_c", "unavailable")
    return (float(fields["elapsed_s"]), int(status) if status.lstrip("-").isdigit() else None,
            float(battery) if battery != "unavailable" else None)


def thermal_name(status):
    """`status` (an int, or None) as "<n> (<name>)" or "unavailable"."""
    if status is None:
        return "unavailable"
    return "%d (%s)" % (status, THERMAL_NAMES.get(status, "?"))


def format_thermal(lines):
    """The printed thermal and battery summary of thermal.log's `lines`."""
    samples = [s for s in (parse_sample(text) for text in lines if text.strip()) if s is not None]
    if not samples:
        return ["== thermal: no sample"]
    out = ["== thermal: %d samples over %.0f s" % (len(samples), samples[-1][0] - samples[0][0])]
    statuses = [(t, status) for t, status, _ in samples if status is not None]
    if statuses:
        out.append("  thermal status  first %s  max %s  last %s" % (
            thermal_name(statuses[0][1]), thermal_name(max(st for _, st in statuses)),
            thermal_name(statuses[-1][1])))
        timeline, previous = [], None
        for t, status in statuses:
            if status != previous:
                timeline.append("%s at +%.0f s" % (thermal_name(status), t))
                previous = status
        out.append("  timeline        " + ", ".join(timeline))
    else:
        out.append("  thermal status  unavailable")
    temps = [c for _, _, c in samples if c is not None]
    if temps:
        out.append("  battery         first %.1f C  max %.1f C  last %.1f C" % (temps[0], max(temps), temps[-1]))
    else:
        out.append("  battery         unavailable")
    return out


def report(log_lines, cold=None, warm=None, thermal_lines=None):
    """The whole printed summary (lines of text), or None when the log holds no PERF line."""
    header, info, records = read_log(log_lines)
    if not records:
        return None
    out = list(header)
    out.append(info if info else "(no PERF_INFO line)")
    out += format_summary("session", records)
    if cold:
        out += format_summary("cold (first %g s)" % cold, cold_window(records, cold))
    if warm:
        out += format_summary("warm (last %g s)" % warm, warm_window(records, warm))
    if thermal_lines is not None:
        out += format_thermal(thermal_lines)
    return out


# The self-test's log: a threadtime logcat prefix on some lines, a header, a
# PERF_INFO line, a noise line, and six PERF lines a second apart.
CANNED_LOG = """# device test: Canned Phone
09-30 17:00:00.000  100  101 I godot   : PERF_INFO seconds=1 model=Canned renderer=mobile
09-30 17:00:00.500  100  101 I godot   : Slime Train booted
PERF t=10.0 frames=30 fps=30.0 frame_ms_p50=33.00 frame_ms_p95=40.00 frame_ms_max=50.00 process_ms_mean=20.00 ticks=60 ticks_per_frame_mean=2.00 ticks_per_frame_max=3 tick_ms_mean=5.00 tick_ms_frame_mean=10.00 rest_ms_mean=23.00 on_screen=10 simulated=5 off_screen=20 parked=21 bodies=35 active=12.0 pairs=40.0 section=1 zoom=1.000
PERF t=11.0 frames=60 fps=60.0 frame_ms_p50=16.00 frame_ms_p95=17.00 frame_ms_max=20.00 process_ms_mean=8.00 ticks=60 ticks_per_frame_mean=1.00 ticks_per_frame_max=1 tick_ms_mean=2.00 tick_ms_frame_mean=2.00 rest_ms_mean=14.00 on_screen=12 simulated=5 off_screen=18 parked=18 bodies=35 active=10.0 pairs=20.0 section=1 zoom=1.000
PERF t=12.0 frames=45 fps=45.0 frame_ms_p50=22.00 frame_ms_p95=30.00 frame_ms_max=35.00 process_ms_mean=10.00 ticks=60 ticks_per_frame_mean=1.33 ticks_per_frame_max=2 tick_ms_mean=3.00 tick_ms_frame_mean=4.00 rest_ms_mean=18.00 on_screen=12 simulated=5 off_screen=18 parked=18 bodies=35 active=10.0 pairs=20.0 section=2 zoom=0.800
09-30 17:00:13.000  100  101 I godot   : PERF t=13.0 frames=20 fps=20.0 frame_ms_p50=50.00 frame_ms_p95=60.00 frame_ms_max=90.00 process_ms_mean=40.00 ticks=60 ticks_per_frame_mean=3.00 ticks_per_frame_max=4 tick_ms_mean=10.00 tick_ms_frame_mean=30.00 rest_ms_mean=20.00 on_screen=30 simulated=0 off_screen=5 parked=5 bodies=35 active=30.0 pairs=100.0 section=2 zoom=0.800
PERF t=14.0 frames=50 fps=50.0 frame_ms_p50=20.00 frame_ms_p95=25.00 frame_ms_max=30.00 process_ms_mean=9.00 ticks=60 ticks_per_frame_mean=1.20 ticks_per_frame_max=2 tick_ms_mean=2.50 tick_ms_frame_mean=3.00 rest_ms_mean=17.00 on_screen=12 simulated=5 off_screen=18 parked=18 bodies=35 active=10.0 pairs=20.0 section=2 zoom=0.800
PERF t=15.0 frames=40 fps=40.0 frame_ms_p50=25.00 frame_ms_p95=28.00 frame_ms_max=40.00 process_ms_mean=11.00 ticks=60 ticks_per_frame_mean=1.50 ticks_per_frame_max=2 tick_ms_mean=3.50 tick_ms_frame_mean=5.25 rest_ms_mean=19.75 on_screen=12 simulated=5 off_screen=18 parked=18 bodies=35 active=10.0 pairs=20.0 section=3 zoom=0.800
"""

CANNED_THERMAL = """2026-09-30T17:00:00+02:00 elapsed_s=0 thermal_status=0 battery_c=31.0
2026-09-30T17:00:15+02:00 elapsed_s=15 thermal_status=1 battery_c=33.5
2026-09-30T17:00:30+02:00 elapsed_s=30 thermal_status=2 battery_c=36.0
2026-09-30T17:00:45+02:00 elapsed_s=45 thermal_status=1 battery_c=35.0
"""


def self_test():
    """Checks the summary on the canned log; prints it and returns 0, or raises AssertionError."""
    header, info, records = read_log(CANNED_LOG.splitlines())
    assert header == ["# device test: Canned Phone"], header
    assert info.startswith("PERF_INFO seconds=1 "), info
    assert len(records) == 6, len(records)
    s = summarise(records)
    assert s["fps_p50"] == 40.0, s["fps_p50"]  # rank 3 of 20, 30, 40, 45, 50, 60
    assert s["fps_p5"] == 20.0 and s["fps_min"] == 20.0, s
    assert s["p95_median"] == 29.0 and s["p95_max"] == 60.0, s  # median of 17 25 28 30 40 60
    assert s["frame_ms_max"] == 90.0, s
    assert abs(s["tick_ms"] - 26.0 / 6.0) < 1e-9, s["tick_ms"]  # 60 ticks each: the plain mean
    frames = 30 + 60 + 45 + 20 + 50 + 40
    rest = (30 * 23 + 60 * 14 + 45 * 18 + 20 * 20 + 50 * 17 + 40 * 19.75) / frames
    assert abs(s["rest_ms"] - rest) < 1e-9, s["rest_ms"]
    assert s["ticks_per_frame_max"] == 4, s
    assert s["counts"]["parked"] == (98 / 6, 21), s["counts"]
    assert s["sections"] == {1: 2, 2: 3, 3: 1}, s["sections"]
    assert (s["zoom_min"], s["zoom_max"]) == (0.8, 1.0), s
    assert [r["t"] for r in cold_window(records, 2)] == [10.0, 11.0]
    assert [r["t"] for r in warm_window(records, 2)] == [14.0, 15.0]
    thermal = format_thermal(CANNED_THERMAL.splitlines())
    assert thermal[1] == "  thermal status  first 0 (none)  max 2 (moderate)  last 1 (light)", thermal
    assert thermal[2] == ("  timeline        0 (none) at +0 s, 1 (light) at +15 s, 2 (moderate) at +30 s, "
                          "1 (light) at +45 s"), thermal
    assert thermal[3] == "  battery         first 31.0 C  max 36.0 C  last 35.0 C", thermal
    assert format_thermal(["2026 elapsed_s=0 thermal_status=unavailable battery_c=unavailable"])[1:] == [
        "  thermal status  unavailable", "  battery         unavailable"]
    try:
        parse_perf_line("PERF t=1 fps=x")
    except ValueError:
        pass
    else:
        raise AssertionError("a malformed PERF line must fail")
    assert report(["no perf here"]) is None
    print("\n".join(report(CANNED_LOG.splitlines(), cold=2, warm=2, thermal_lines=CANNED_THERMAL.splitlines())))
    print("perf_summary self-test: OK")
    return 0


def main(argv):
    """Parses `argv` and prints the summary; returns the exit code."""
    parser = argparse.ArgumentParser(description="Summarises a perf.sh session's PERF log.")
    parser.add_argument("log", nargs="?", help="perf.log, or a logcat capture holding PERF lines")
    parser.add_argument("--cold", type=float, help="also summarise the first COLD seconds")
    parser.add_argument("--warm", type=float, help="also summarise the last WARM seconds")
    parser.add_argument("--thermal", help="perf.sh's thermal.log")
    parser.add_argument("--self-test", action="store_true", help="check the summary on a canned log")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    if args.log is None:
        parser.error("a PERF log is needed (or --self-test)")
    for name in ("cold", "warm"):
        value = getattr(args, name)
        if value is not None and value <= 0:
            parser.error("--%s expects seconds > 0" % name)
    with open(args.log, encoding="utf-8", errors="replace") as log:
        log_lines = log.readlines()
    thermal_lines = None
    if args.thermal:
        with open(args.thermal, encoding="utf-8", errors="replace") as thermal:
            thermal_lines = thermal.readlines()
    lines = report(log_lines, args.cold, args.warm, thermal_lines)
    if lines is None:
        print("perf_summary: no PERF line in %s" % args.log, file=sys.stderr)
        return 1
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
