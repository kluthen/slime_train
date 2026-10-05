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
in the whole process, ticks per frame (weighted by frames), active slimes
(those that cost physics) and candidate pairs (weighted by frames), the slime
counts (mean, min and max over the lines: physics, on_screen, in_range,
parked, resting, bodies, and an older log's simulated and off_screen), the
largest awake cluster's max (and mean), the train hops (hops and short_hops,
since chunk 22l: their mean per line, and the short hops' share of the hops
over the lines, a percentage), the sections the camera was in (lines in each: seconds at --perf-log=1), the
zoom range, and the frame's parts outside the ticks (weighted by frames: each
node's ms, the rendering server's setup and render times, the draw calls,
objects and primitives), when the lines carry them (older logs don't). With
the game's --phase-timers (chunk 5N U0a), the lines' `phases` field (mean us
per tick by phase) is summarised too, weighted by ticks: the whole step, the
solver's part (SOLVER_PHASES) and the behaviour's, then every phase.

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
            "ticks_per_frame_max", "tick_ms_mean", "tick_ms_frame_mean", "rest_ms_mean", "bodies", "active",
            "pairs", "zoom")
# The slime count fields summarised by min, mean and max, each only when the
# lines carry it: the perf log's since chunk 22d (physics, on_screen,
# in_range, parked, resting, bodies), and an older log's simulated and
# off_screen (before 22d; parked and section older still, a log may lack
# them). A log from before 22d parses and reports its own counts.
COUNTS = ("physics", "on_screen", "in_range", "parked", "resting", "bodies", "simulated", "off_screen")
# The largest awake cluster (since chunk 22d), summarised as the counts but
# reported on its own line, its max first.
CLUSTER = "largest_cluster"
# The train hops taken and those landed short, per line (since chunk 22l):
# their mean per line over the lines that carry them, and short_hops' share
# of hops summed over those lines, reported on their own line.
HOPS = ("hops", "short_hops")
# The frame's parts outside the ticks (the perf log's PART_FIELDS), newer
# still: summarised by their frame-weighted mean over the lines that have
# them, in three rows (the nodes' ms, the rendering's ms, the counts).
PART_ROWS = (
    ("  parts ms/frame  ", ("slimes_ms", "eyes_ms", "frontier_ms", "hud_ms", "debug_ms", "main_ms"), "%.2f"),
    ("  render ms/frame ", ("setup_ms", "render_cpu_ms", "render_gpu_ms", "field_cpu_ms", "field_gpu_ms"), "%.2f"),
    ("  render /frame   ", ("draw_calls", "objects", "primitives"), "%.0f"),
)
# The phase timers' field (src/debug/phase_timers.gd, the game's
# --phase-timers): "name:us,name:us,..." mean us per tick by phase, in tick
# order; the only PERF field that isn't a number.
PHASES = "phases"
# The solver's phases (PhaseTimers.SOLVER_PHASES): what chunk 5N moves to
# native code, and the native step() that runs it all in one call; every
# other phase is behaviour.
SOLVER_PHASES = ("integrate", "pairs", "contacts", "rings", "terrain", "doors", "rest", "native")
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
        fields[key] = parse_phases(value, text) if key == PHASES else float(value)
    missing = [key for key in REQUIRED if key not in fields]
    if missing:
        raise ValueError("PERF line without %s: %r" % (", ".join(missing), text.strip()))
    return fields


def parse_phases(value, text):
    """The phases field's `value` ("name:us,...") as an ordered dict of floats.

    A malformed entry (not name:number) raises ValueError, as a malformed field does."""
    phases = {}
    for item in value.split(","):
        name, sep, us = item.partition(":")
        if not sep or not name:
            raise ValueError("phases entry without 'name:us': %r in %r" % (item, text.strip()))
        phases[name] = float(us)
    return phases


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
        "parts": {},
        "hops": None,
        "phases": None,
    }
    having = [r for r in records if PHASES in r]
    ticks = sum(r["ticks"] for r in having)
    if having and ticks > 0:
        names = []
        for r in having:
            names += [name for name in r[PHASES] if name not in names]
        means = {name: sum(r[PHASES].get(name, 0.0) * r["ticks"] for r in having) / ticks for name in names}
        solver = sum(us for name, us in means.items() if name in SOLVER_PHASES)
        out["phases"] = {"lines": len(having), "means": means, "solver": solver,
                         "behaviour": sum(means.values()) - solver}
    having = [r for r in records if all(key in r for key in HOPS)]
    if having:
        hops = sum(r["hops"] for r in having)
        short = sum(r["short_hops"] for r in having)
        out["hops"] = {"lines": len(having), "hops_mean": hops / len(having), "short_mean": short / len(having),
                       "hops": hops, "short_hops": short, "short_share": 100.0 * short / hops if hops > 0 else None}
    for key in COUNTS + (CLUSTER,):
        values = [r[key] for r in records if key in r]
        if values:
            out["counts"][key] = (min(values), statistics.fmean(values), max(values))
    for r in records:
        if "section" in r:
            section = int(r["section"])
            out["sections"][section] = out["sections"].get(section, 0) + 1
    for _, keys, _ in PART_ROWS:
        for key in keys:
            having = [r for r in records if key in r]
            if having:
                out["parts"][key] = weighted_mean(having, key, "frames")
    return out


def format_summary(title, records):
    """The printed summary of `records` titled `title` (lines of text)."""
    if not records:
        return ["== %s: no PERF line" % title]
    s = summarise(records)
    counts = "  ".join("%s %.1f (%d..%d)" % (key, mean, least, most)
                       for key, (least, mean, most) in s["counts"].items() if key != CLUSTER)
    lines = [
        "== %s: %d PERF lines, t=%.1f..%.1f s" % (title, s["lines"], s["t_first"], s["t_last"]),
        "  fps             p50 %.1f  p5 %.1f  min %.1f" % (s["fps_p50"], s["fps_p5"], s["fps_min"]),
        "  frame_ms p95    median %.2f  max %.2f  (worst frame %.2f)" % (
            s["p95_median"], s["p95_max"], s["frame_ms_max"]),
        "  per frame       ticks %.2f (max %d)  in ticks %.2f ms  rest %.2f ms" % (
            s["ticks_per_frame"], s["ticks_per_frame_max"], s["tick_ms_frame"], s["rest_ms"]),
        "  per tick        %.2f ms   process per frame %.2f ms" % (s["tick_ms"], s["process_ms"]),
        "  solver (mean)   active %.1f  pairs %.1f" % (s["active"], s["pairs"]),
        "  slimes          " + counts,
    ]
    if CLUSTER in s["counts"]:
        _, mean, most = s["counts"][CLUSTER]
        lines.append("  largest cluster max %d (mean %.1f)" % (most, mean))
    if s["hops"] is not None:
        h = s["hops"]
        share = "n/a (no hop)"
        if h["short_share"] is not None:
            share = "%.1f %% (%d of %d)" % (h["short_share"], h["short_hops"], h["hops"])
        lines.append("  train hops      per line: hops %.1f  short_hops %.1f   short share %s" % (
            h["hops_mean"], h["short_mean"], share))
    if s["sections"]:
        lines.append("  section (lines) " + "  ".join(
            "s%d %d" % (section, n) for section, n in sorted(s["sections"].items())))
    if s["phases"] is not None:
        p = s["phases"]
        step = p["solver"] + p["behaviour"]
        lines.append("  phases us/tick  step %.0f  solver %.0f (%.1f %%)  behaviour %.0f  (%d lines)" % (
            step, p["solver"], 100.0 * p["solver"] / step if step > 0 else 0.0, p["behaviour"], p["lines"]))
        lines.append("  phases          " + "  ".join("%s %.0f" % item for item in p["means"].items()))
    lines.append("  zoom            %.3f..%.3f" % (s["zoom_min"], s["zoom_max"]))
    for title, keys, number in PART_ROWS:
        present = [key for key in keys if key in s["parts"]]
        if present:
            lines.append(title + "  ".join(
                ("%s " + number) % (key.removesuffix("_ms"), s["parts"][key]) for key in present))
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
# PERF_INFO line, a noise line, and six PERF lines a second apart, the last
# two with the frame's parts and the phase timers' field (the first four
# have neither, as an older log's).
# Hops: 54 in all, 12 short.
CANNED_LOG = """# device test: Canned Phone
09-30 17:00:00.000  100  101 I godot   : PERF_INFO seconds=1 model=Canned renderer=mobile
09-30 17:00:00.500  100  101 I godot   : Slime Train booted
PERF t=10.0 frames=30 fps=30.0 frame_ms_p50=33.00 frame_ms_p95=40.00 frame_ms_max=50.00 process_ms_mean=20.00 ticks=60 ticks_per_frame_mean=2.00 ticks_per_frame_max=3 tick_ms_mean=5.00 tick_ms_frame_mean=10.00 rest_ms_mean=23.00 physics=12 on_screen=10 in_range=14 parked=21 resting=2 largest_cluster=6 hops=10 short_hops=2 bodies=35 active=12.0 pairs=40.0 section=1 zoom=1.000
PERF t=11.0 frames=60 fps=60.0 frame_ms_p50=16.00 frame_ms_p95=17.00 frame_ms_max=20.00 process_ms_mean=8.00 ticks=60 ticks_per_frame_mean=1.00 ticks_per_frame_max=1 tick_ms_mean=2.00 tick_ms_frame_mean=2.00 rest_ms_mean=14.00 physics=10 on_screen=12 in_range=17 parked=18 resting=7 largest_cluster=4 hops=12 short_hops=3 bodies=35 active=10.0 pairs=20.0 section=1 zoom=1.000
PERF t=12.0 frames=45 fps=45.0 frame_ms_p50=22.00 frame_ms_p95=30.00 frame_ms_max=35.00 process_ms_mean=10.00 ticks=60 ticks_per_frame_mean=1.33 ticks_per_frame_max=2 tick_ms_mean=3.00 tick_ms_frame_mean=4.00 rest_ms_mean=18.00 physics=10 on_screen=12 in_range=17 parked=18 resting=7 largest_cluster=4 hops=8 short_hops=1 bodies=35 active=10.0 pairs=20.0 section=2 zoom=0.800
09-30 17:00:13.000  100  101 I godot   : PERF t=13.0 frames=20 fps=20.0 frame_ms_p50=50.00 frame_ms_p95=60.00 frame_ms_max=90.00 process_ms_mean=40.00 ticks=60 ticks_per_frame_mean=3.00 ticks_per_frame_max=4 tick_ms_mean=10.00 tick_ms_frame_mean=30.00 rest_ms_mean=20.00 physics=30 on_screen=30 in_range=30 parked=5 resting=0 largest_cluster=22 hops=4 short_hops=4 bodies=35 active=30.0 pairs=100.0 section=2 zoom=0.800
PERF t=14.0 frames=50 fps=50.0 frame_ms_p50=20.00 frame_ms_p95=25.00 frame_ms_max=30.00 process_ms_mean=9.00 ticks=60 ticks_per_frame_mean=1.20 ticks_per_frame_max=2 tick_ms_mean=2.50 tick_ms_frame_mean=3.00 rest_ms_mean=17.00 physics=10 on_screen=12 in_range=17 parked=18 resting=7 largest_cluster=5 hops=9 short_hops=0 bodies=35 active=10.0 pairs=20.0 section=2 zoom=0.800 slimes_ms=2.00 eyes_ms=0.50 frontier_ms=0.30 hud_ms=0.05 debug_ms=0.00 main_ms=0.10 setup_ms=0.20 render_cpu_ms=3.00 render_gpu_ms=4.00 field_cpu_ms=1.00 field_gpu_ms=2.00 draw_calls=40 objects=30 primitives=900 phases=input:1,offscreen:500,integrate:300,contacts:700,rest:100,train_follow:400
PERF t=15.0 frames=40 fps=40.0 frame_ms_p50=25.00 frame_ms_p95=28.00 frame_ms_max=40.00 process_ms_mean=11.00 ticks=60 ticks_per_frame_mean=1.50 ticks_per_frame_max=2 tick_ms_mean=3.50 tick_ms_frame_mean=5.25 rest_ms_mean=19.75 physics=10 on_screen=12 in_range=17 parked=18 resting=7 largest_cluster=5 hops=11 short_hops=2 bodies=35 active=10.0 pairs=20.0 section=3 zoom=0.800 slimes_ms=4.25 eyes_ms=0.50 frontier_ms=0.30 hud_ms=0.05 debug_ms=0.00 main_ms=0.10 setup_ms=0.20 render_cpu_ms=3.00 render_gpu_ms=4.00 field_cpu_ms=1.00 field_gpu_ms=2.00 draw_calls=49 objects=30 primitives=900 phases=input:3,offscreen:700,integrate:500,contacts:900,rest:300,train_follow:600
"""

# An older log (before chunk 22d): on_screen, simulated, off_screen and no
# physics, in_range, resting, largest_cluster, hops nor short_hops; its
# second line older still, without parked nor section.
CANNED_OLD_LOG = """PERF t=1.0 frames=30 fps=30.0 frame_ms_p50=33.00 frame_ms_p95=40.00 frame_ms_max=50.00 process_ms_mean=20.00 ticks=60 ticks_per_frame_mean=2.00 ticks_per_frame_max=3 tick_ms_mean=5.00 tick_ms_frame_mean=10.00 rest_ms_mean=23.00 on_screen=10 simulated=5 off_screen=20 parked=21 bodies=35 active=12.0 pairs=40.0 section=1 zoom=1.000
PERF t=2.0 frames=60 fps=60.0 frame_ms_p50=16.00 frame_ms_p95=17.00 frame_ms_max=20.00 process_ms_mean=8.00 ticks=60 ticks_per_frame_mean=1.00 ticks_per_frame_max=1 tick_ms_mean=2.00 tick_ms_frame_mean=2.00 rest_ms_mean=14.00 on_screen=12 simulated=7 off_screen=16 bodies=35 active=10.0 pairs=20.0 zoom=1.000
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
    assert list(s["counts"]) == ["physics", "on_screen", "in_range", "parked", "resting", "bodies",
                                 "largest_cluster"], s["counts"]
    assert s["counts"]["physics"] == (10, 82 / 6, 30), s["counts"]
    assert s["counts"]["in_range"] == (14, 112 / 6, 30), s["counts"]
    assert s["counts"]["parked"] == (5, 98 / 6, 21), s["counts"]
    assert s["counts"]["resting"] == (0, 30 / 6, 7), s["counts"]
    assert s["counts"]["bodies"] == (35, 35, 35), s["counts"]
    assert s["counts"]["largest_cluster"] == (4, 46 / 6, 22), s["counts"]
    session = format_summary("session", records)
    assert session[6] == ("  slimes          physics 13.7 (10..30)  on_screen 14.7 (10..30)  in_range 18.7 (14..30)  "
                          "parked 16.3 (5..21)  resting 5.0 (0..7)  bodies 35.0 (35..35)"), session
    assert session[7] == "  largest cluster max 22 (mean 7.7)", session
    assert s["hops"] == {"lines": 6, "hops_mean": 9.0, "short_mean": 2.0, "hops": 54, "short_hops": 12,
                         "short_share": 100.0 * 12 / 54}, s["hops"]
    assert session[8] == "  train hops      per line: hops 9.0  short_hops 2.0   short share 22.2 % (12 of 54)", session
    no_hop = summarise([dict(records[0], hops=0, short_hops=0)])["hops"]
    assert no_hop["short_share"] is None, no_hop
    assert format_summary("still", [dict(records[0], hops=0, short_hops=0)])[8].endswith(
        "short share n/a (no hop)"), "no hop: no share"
    assert s["sections"] == {1: 2, 2: 3, 3: 1}, s["sections"]
    assert (s["zoom_min"], s["zoom_max"]) == (0.8, 1.0), s
    # Parts: only the last two lines (50 and 40 frames) carry them.
    assert abs(s["parts"]["slimes_ms"] - (50 * 2.0 + 40 * 4.25) / 90) < 1e-9, s["parts"]
    assert abs(s["parts"]["draw_calls"] - (50 * 40 + 40 * 49) / 90) < 1e-9, s["parts"]
    assert s["parts"]["field_gpu_ms"] == 2.0 and len(s["parts"]) == 14, s["parts"]
    old = format_summary("old", records[:4])
    assert not any(text.startswith(("  parts", "  render")) for text in old), old
    assert s["phases"] == {"lines": 2, "means": {"input": 2.0, "offscreen": 600.0, "integrate": 400.0,
                                                 "contacts": 800.0, "rest": 200.0, "train_follow": 500.0},
                           "solver": 1400.0, "behaviour": 1102.0}, s["phases"]
    assert records[4][PHASES] == {"input": 1.0, "offscreen": 500.0, "integrate": 300.0, "contacts": 700.0,
                                  "rest": 100.0, "train_follow": 400.0}, records[4]
    assert not any(text.startswith("  phases") for text in format_summary("old", records[:4]))
    new = format_summary("new", records[4:])
    assert new[-6] == "  phases us/tick  step 2502  solver 1400 (56.0 %)  behaviour 1102  (2 lines)", new
    assert new[-5] == ("  phases          input 2  offscreen 600  integrate 400  contacts 800  rest 200  "
                       "train_follow 500"), new
    assert new[-3] == "  parts ms/frame  slimes 3.00  eyes 0.50  frontier 0.30  hud 0.05  debug 0.00  main 0.10", new
    assert new[-1] == "  render /frame   draw_calls 44  objects 30  primitives 900", new
    _, _, old_records = read_log(CANNED_OLD_LOG.splitlines())
    assert len(old_records) == 2, old_records
    old_counts = summarise(old_records)["counts"]
    assert list(old_counts) == ["on_screen", "parked", "bodies", "simulated", "off_screen"], old_counts
    assert old_counts["simulated"] == (5, 6, 7) and old_counts["parked"] == (21, 21, 21), old_counts
    old_log = format_summary("old log", old_records)
    assert old_log[6] == ("  slimes          on_screen 11.0 (10..12)  parked 21.0 (21..21)  bodies 35.0 (35..35)  "
                          "simulated 6.0 (5..7)  off_screen 18.0 (16..20)"), old_log
    assert not any(text.startswith("  largest cluster") for text in old_log), old_log
    assert not any(text.startswith("  train hops") for text in old_log), old_log
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
    try:
        parse_phases("input:1,rest", "PERF t=1 phases=input:1,rest")
    except ValueError:
        pass
    else:
        raise AssertionError("a malformed phases field must fail")
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
