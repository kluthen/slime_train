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
since chunk 22e: their mean per line, and the short hops' share of the hops
over the lines, a percentage), the hold (since chunk 22f: its snapshot's
counts by mean, min and max; its per-line counters' totals and shares: how
the holds ended, how they began, front, queue and crowded hops among the
hops, and the share of the touching queues' back slimes held), the sections
the camera was in (lines in each: seconds at --perf-log=1), the
zoom range, and the frame's parts outside the ticks (weighted by frames: each
node's ms, the rendering server's setup and render times, the draw calls,
objects and primitives), when the lines carry them (older logs don't).

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
# The train hops taken and those landed short, per line (since chunk 22e):
# their mean per line over the lines that carry them, and short_hops' share
# of hops summed over those lines, reported on their own line.
HOPS = ("hops", "short_hops")
# The hold (since chunk 22f, D147): the snapshot at each line (Train's
# hold_snapshot), summarised by min, mean and max, and the per-line counters
# (TrainHold.COUNTERS), summed over the lines that carry them all.
# @spec-link [[req_platform_and_performance_targets]]
HOLD_SNAPSHOT = ("holding", "holding_resting", "contact_resting", "queue_back", "queue_back_held")
HOLD_PERIOD = ("hold_ends_clear", "hold_ends_cap", "guard_releases", "hold_ends_other", "front_hops", "queue_hops",
               "holder_holds", "crowd_holds", "crowded_hops")
# How a hold ends, in the order reported, as (field, short name).
HOLD_ENDS = (("hold_ends_clear", "clear"), ("hold_ends_cap", "cap"), ("guard_releases", "guard"),
             ("hold_ends_other", "other"))
# The frame's parts outside the ticks (the perf log's PART_FIELDS), newer
# still: summarised by their frame-weighted mean over the lines that have
# them, in three rows (the nodes' ms, the rendering's ms, the counts).
PART_ROWS = (
    ("  parts ms/frame  ", ("slimes_ms", "eyes_ms", "frontier_ms", "hud_ms", "debug_ms", "main_ms"), "%.2f"),
    ("  render ms/frame ", ("setup_ms", "render_cpu_ms", "render_gpu_ms", "field_cpu_ms", "field_gpu_ms"), "%.2f"),
    ("  render /frame   ", ("draw_calls", "objects", "primitives"), "%.0f"),
)
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
        "parts": {},
        "hops": None,
        "hold": None,
    }
    having = [r for r in records if all(key in r for key in HOPS)]
    if having:
        hops = sum(r["hops"] for r in having)
        short = sum(r["short_hops"] for r in having)
        out["hops"] = {"lines": len(having), "hops_mean": hops / len(having), "short_mean": short / len(having),
                       "hops": hops, "short_hops": short, "short_share": 100.0 * short / hops if hops > 0 else None}
    out["hold"] = summarise_hold(records)
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


def share(part, whole):
    """`part` over `whole` as a percentage, or None when `whole` is 0."""
    return 100.0 * part / whole if whole > 0 else None


def summarise_hold(records):
    """The hold's numbers of `records` (D147 (1), (8)), or None when no line carries them.

    {"snapshot": {field: (min, mean, max)}, "lines", "totals": {field: sum},
    "hops" (the hops of those lines), "ends", "starts", "end_shares" {field: %},
    "holder_share", "front_share", "queue_share", "crowded_share",
    "back_held_share" (sum(queue_back_held) / sum(queue_back)), "back" (those two
    sums)}; a share is None
    when its whole is 0. The snapshot needs its own fields only; the rest
    needs every counter and hops on the line."""
    snapshot = {}
    for key in HOLD_SNAPSHOT:
        values = [r[key] for r in records if key in r]
        if values:
            snapshot[key] = (min(values), statistics.fmean(values), max(values))
    having = [r for r in records if all(key in r for key in HOLD_PERIOD + ("hops",))]
    if not snapshot and not having:
        return None
    totals = {key: sum(r[key] for r in having) for key in HOLD_PERIOD}
    hops = sum(r["hops"] for r in having)
    ends = sum(totals[key] for key, _ in HOLD_ENDS)
    starts = totals["holder_holds"] + totals["crowd_holds"]
    back = [r for r in records if "queue_back" in r and "queue_back_held" in r]
    return {
        "snapshot": snapshot,
        "lines": len(having),
        "totals": totals,
        "hops": hops,
        "ends": ends,
        "starts": starts,
        "end_shares": {key: share(totals[key], ends) for key, _ in HOLD_ENDS},
        "holder_share": share(totals["holder_holds"], starts),
        "front_share": share(totals["front_hops"], hops),
        "queue_share": share(totals["queue_hops"], hops),
        "crowded_share": share(totals["crowded_hops"], hops),
        "back_held_share": share(sum(r["queue_back_held"] for r in back), sum(r["queue_back"] for r in back)),
        "back": (sum(r["queue_back_held"] for r in back), sum(r["queue_back"] for r in back)),
    }


def percent(value):
    """A share (or None) as "12.3 %" or "n/a"."""
    return "n/a" if value is None else "%.1f %%" % value


def format_hold(h):
    """The printed lines of summarise_hold()'s `h`."""
    lines = []
    if h["snapshot"]:
        lines.append("  hold (now)      " + "  ".join(
            "%s %.1f (%d..%d)" % (key, mean, least, most) for key, (least, mean, most) in h["snapshot"].items()))
    if h["lines"]:
        t = h["totals"]
        lines.append("  hold ends       " + "  ".join(
            "%s %d (%s)" % (name, t[key], percent(h["end_shares"][key])) for key, name in HOLD_ENDS)
            + "  of %d" % h["ends"])
        # A hold both checks start (a crowd and a holder) is a crowd start:
        # "holder" is the holder rule's own, below the occupancy threshold.
        lines.append("  hold starts     holder (below threshold) %d  crowd (above, holder or not) %d   holder share %s" % (
            t["holder_holds"], t["crowd_holds"], percent(h["holder_share"])))
        lines.append("  hop kinds       front %d (%s)  queue %d (%s)  crowded %d (%s)  of %d hops" % (
            t["front_hops"], percent(h["front_share"]), t["queue_hops"], percent(h["queue_share"]),
            t["crowded_hops"], percent(h["crowded_share"]), h["hops"]))
    if "queue_back" in h["snapshot"]:
        lines.append("  back held       %s (%d of %d queue_back)" % (
            (percent(h["back_held_share"]),) + h["back"]))
    return lines


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
    if s["hold"] is not None:
        lines += format_hold(s["hold"])
    if s["sections"]:
        lines.append("  section (lines) " + "  ".join(
            "s%d %d" % (section, n) for section, n in sorted(s["sections"].items())))
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
# two with the frame's parts and the hold's fields (the first four have
# none, as an older log's). Hops: 54 in all, 12 short; 20 on the hold's lines.
CANNED_LOG = """# device test: Canned Phone
09-30 17:00:00.000  100  101 I godot   : PERF_INFO seconds=1 model=Canned renderer=mobile
09-30 17:00:00.500  100  101 I godot   : Slime Train booted
PERF t=10.0 frames=30 fps=30.0 frame_ms_p50=33.00 frame_ms_p95=40.00 frame_ms_max=50.00 process_ms_mean=20.00 ticks=60 ticks_per_frame_mean=2.00 ticks_per_frame_max=3 tick_ms_mean=5.00 tick_ms_frame_mean=10.00 rest_ms_mean=23.00 physics=12 on_screen=10 in_range=14 parked=21 resting=2 largest_cluster=6 hops=10 short_hops=2 bodies=35 active=12.0 pairs=40.0 section=1 zoom=1.000
PERF t=11.0 frames=60 fps=60.0 frame_ms_p50=16.00 frame_ms_p95=17.00 frame_ms_max=20.00 process_ms_mean=8.00 ticks=60 ticks_per_frame_mean=1.00 ticks_per_frame_max=1 tick_ms_mean=2.00 tick_ms_frame_mean=2.00 rest_ms_mean=14.00 physics=10 on_screen=12 in_range=17 parked=18 resting=7 largest_cluster=4 hops=12 short_hops=3 bodies=35 active=10.0 pairs=20.0 section=1 zoom=1.000
PERF t=12.0 frames=45 fps=45.0 frame_ms_p50=22.00 frame_ms_p95=30.00 frame_ms_max=35.00 process_ms_mean=10.00 ticks=60 ticks_per_frame_mean=1.33 ticks_per_frame_max=2 tick_ms_mean=3.00 tick_ms_frame_mean=4.00 rest_ms_mean=18.00 physics=10 on_screen=12 in_range=17 parked=18 resting=7 largest_cluster=4 hops=8 short_hops=1 bodies=35 active=10.0 pairs=20.0 section=2 zoom=0.800
09-30 17:00:13.000  100  101 I godot   : PERF t=13.0 frames=20 fps=20.0 frame_ms_p50=50.00 frame_ms_p95=60.00 frame_ms_max=90.00 process_ms_mean=40.00 ticks=60 ticks_per_frame_mean=3.00 ticks_per_frame_max=4 tick_ms_mean=10.00 tick_ms_frame_mean=30.00 rest_ms_mean=20.00 physics=30 on_screen=30 in_range=30 parked=5 resting=0 largest_cluster=22 hops=4 short_hops=4 bodies=35 active=30.0 pairs=100.0 section=2 zoom=0.800
PERF t=14.0 frames=50 fps=50.0 frame_ms_p50=20.00 frame_ms_p95=25.00 frame_ms_max=30.00 process_ms_mean=9.00 ticks=60 ticks_per_frame_mean=1.20 ticks_per_frame_max=2 tick_ms_mean=2.50 tick_ms_frame_mean=3.00 rest_ms_mean=17.00 physics=10 on_screen=12 in_range=17 parked=18 resting=7 largest_cluster=5 hops=9 short_hops=0 holding=4 holding_resting=1 contact_resting=0 queue_back=6 queue_back_held=4 hold_ends_clear=3 hold_ends_cap=1 guard_releases=0 hold_ends_other=0 front_hops=8 queue_hops=1 holder_holds=1 crowd_holds=3 crowded_hops=1 bodies=35 active=10.0 pairs=20.0 section=2 zoom=0.800 slimes_ms=2.00 eyes_ms=0.50 frontier_ms=0.30 hud_ms=0.05 debug_ms=0.00 main_ms=0.10 setup_ms=0.20 render_cpu_ms=3.00 render_gpu_ms=4.00 field_cpu_ms=1.00 field_gpu_ms=2.00 draw_calls=40 objects=30 primitives=900
PERF t=15.0 frames=40 fps=40.0 frame_ms_p50=25.00 frame_ms_p95=28.00 frame_ms_max=40.00 process_ms_mean=11.00 ticks=60 ticks_per_frame_mean=1.50 ticks_per_frame_max=2 tick_ms_mean=3.50 tick_ms_frame_mean=5.25 rest_ms_mean=19.75 physics=10 on_screen=12 in_range=17 parked=18 resting=7 largest_cluster=5 hops=11 short_hops=2 holding=2 holding_resting=2 contact_resting=1 queue_back=4 queue_back_held=4 hold_ends_clear=5 hold_ends_cap=0 guard_releases=0 hold_ends_other=1 front_hops=10 queue_hops=0 holder_holds=0 crowd_holds=2 crowded_hops=0 bodies=35 active=10.0 pairs=20.0 section=3 zoom=0.800 slimes_ms=4.25 eyes_ms=0.50 frontier_ms=0.30 hud_ms=0.05 debug_ms=0.00 main_ms=0.10 setup_ms=0.20 render_cpu_ms=3.00 render_gpu_ms=4.00 field_cpu_ms=1.00 field_gpu_ms=2.00 draw_calls=49 objects=30 primitives=900
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
    h = s["hold"]
    assert h["snapshot"] == {"holding": (2, 3, 4), "holding_resting": (1, 1.5, 2), "contact_resting": (0, 0.5, 1),
                             "queue_back": (4, 5, 6), "queue_back_held": (4, 4, 4)}, h["snapshot"]
    assert h["lines"] == 2 and h["hops"] == 20 and h["ends"] == 10 and h["starts"] == 6, h
    assert h["end_shares"] == {"hold_ends_clear": 80.0, "hold_ends_cap": 10.0, "guard_releases": 0.0,
                               "hold_ends_other": 10.0}, h["end_shares"]
    assert (h["front_share"], h["queue_share"], h["crowded_share"]) == (90.0, 5.0, 5.0), h
    assert abs(h["holder_share"] - 100.0 / 6) < 1e-9 and h["back_held_share"] == 80.0, h
    assert session[9:14] == [
        "  hold (now)      holding 3.0 (2..4)  holding_resting 1.5 (1..2)  contact_resting 0.5 (0..1)  "
        "queue_back 5.0 (4..6)  queue_back_held 4.0 (4..4)",
        "  hold ends       clear 8 (80.0 %)  cap 1 (10.0 %)  guard 0 (0.0 %)  other 1 (10.0 %)  of 10",
        "  hold starts     holder (below threshold) 1  crowd (above, holder or not) 5   holder share 16.7 %",
        "  hop kinds       front 18 (90.0 %)  queue 1 (5.0 %)  crowded 1 (5.0 %)  of 20 hops",
        "  back held       80.0 % (8 of 10 queue_back)"], session
    assert summarise(records[:4])["hold"] is None, "an older log: no hold"
    assert not any(text.startswith("  hold") for text in format_summary("old", records[:4]))
    quiet = summarise([dict(records[4], **{key: 0 for key in HOLD_PERIOD + HOLD_SNAPSHOT})])["hold"]
    assert quiet["end_shares"]["hold_ends_cap"] is None and quiet["back_held_share"] is None, quiet
    assert s["sections"] == {1: 2, 2: 3, 3: 1}, s["sections"]
    assert (s["zoom_min"], s["zoom_max"]) == (0.8, 1.0), s
    # Parts: only the last two lines (50 and 40 frames) carry them.
    assert abs(s["parts"]["slimes_ms"] - (50 * 2.0 + 40 * 4.25) / 90) < 1e-9, s["parts"]
    assert abs(s["parts"]["draw_calls"] - (50 * 40 + 40 * 49) / 90) < 1e-9, s["parts"]
    assert s["parts"]["field_gpu_ms"] == 2.0 and len(s["parts"]) == 14, s["parts"]
    old = format_summary("old", records[:4])
    assert not any(text.startswith(("  parts", "  render")) for text in old), old
    new = format_summary("new", records[4:])
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
    assert not any(text.startswith("  hold") for text in old_log), old_log
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
