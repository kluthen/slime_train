#!/usr/bin/env python3
"""The numbers of docs/perf/2026-10-06-5n-s20fe-session.md, from the PERF lines.

    python3 docs/perf/2026-10-06-5n-s20fe-session/tables.py [RUN_DIR...]

Default: every run folder next to this script. The windows are
tools/android/perf_summary.py's (cold: within 60 s of the first line; warm:
the last 60 s), and so are the weighted means (tick ms and phases weighted by
ticks). Printed per window: the fps mean (the plain mean of the lines' fps=,
which the summary doesn't print), the summary's p50 / p5 / min, tick ms,
ticks a frame, the physics count, the largest cluster, and the step split
into the solver (the GDScript passes or the one native lap) and the
behaviour. s3-basket-59of60 also gets its section 3 and section 1 lines.

The device-speed probe: split_zones + auto_hops + free_follow, us per tick
over 30..60 s after the first line, and over the last 60 s. They are
GDScript behaviour on both ticks; comparing a run with the same fixture's
run of 2026-10-03 (docs/perf/2026-10-03-s20fe-phases/) shows the phone's
own speed.
"""
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools", "android"))
import perf_summary as ps  # noqa: E402

PROBE = ("split_zones", "auto_hops", "free_follow")


def records(run):
    with open(os.path.join(run, "perf.log")) as f:
        lines = f.read().splitlines()
    return ps.read_log(lines)[2]


def window_line(name, recs):
    if not recs:
        return "  %-6s no line" % name
    s = ps.summarise(recs)
    p = s["phases"]
    means = p["means"]
    gd = sum(us for k, us in means.items() if k in ps.SOLVER_PHASES and k != "native")
    phys = s["counts"]["physics"]
    cluster = s["counts"][ps.CLUSTER]
    fps_mean = statistics.fmean(r["fps"] for r in recs)
    top = sorted(((us, k) for k, us in means.items() if k not in ps.SOLVER_PHASES), reverse=True)[:6]
    return ("  %-6s %3d lines  fps mean %5.1f p50 %5.1f p5 %5.1f min %5.1f | tick %5.2f ms, %.2f a frame"
            " | physics %5.1f (%d..%d), cluster %5.1f / %d | step %5.0f: solver %5.0f (GDScript passes %5.0f,"
            " native %4.0f), behaviour %5.0f\n           behaviour's largest: %s"
            % (name, s["lines"], fps_mean, s["fps_p50"], s["fps_p5"], s["fps_min"], s["tick_ms"],
               s["ticks_per_frame"], phys[1], phys[0], phys[2], cluster[1], cluster[2],
               sum(means.values()), p["solver"], gd, means.get("native", 0.0), p["behaviour"],
               ", ".join("%s %.0f" % (k, us) for us, k in top)))


def probe(recs, start=30.0, end=60.0):
    t0 = recs[0]["t"]
    w = [r for r in recs if start <= r["t"] - t0 < end and ps.PHASES in r]
    ticks = sum(r["ticks"] for r in w)
    return sum(sum(r[ps.PHASES].get(k, 0.0) for k in PROBE) * r["ticks"] for r in w) / ticks


def main(argv):
    runs = argv or sorted(os.path.join(HERE, d) for d in os.listdir(HERE)
                          if os.path.isfile(os.path.join(HERE, d, "perf.log")))
    for run in runs:
        recs = records(run)
        print("## %s" % os.path.basename(run.rstrip("/")))
        print(window_line("whole", recs))
        print(window_line("cold", ps.cold_window(recs, 60)))
        print(window_line("warm", ps.warm_window(recs, 60)))
        if "s3-basket" in run:
            for section in (3, 1):
                print(window_line("s%d" % section, [r for r in recs if r.get("section") == section]))
        last = recs[-1]["t"] - recs[0]["t"]
        print("  probe  %.0f us/tick at 30..60 s, %.0f over the last 60 s (split_zones + auto_hops + free_follow)"
              % (probe(recs), probe(recs, last - 60.0, last + 1.0)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
