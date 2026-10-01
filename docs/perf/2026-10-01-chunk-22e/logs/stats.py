#!/usr/bin/env python3
"""Per-log statistics from the PERF lines (22e perf report). usage: stats.py <label>=<log> ..."""
import sys, statistics as st

COUNTS = ["physics", "on_screen", "in_range", "parked", "resting", "largest_cluster", "bodies"]
PARTS = ["slimes_ms", "eyes_ms", "frontier_ms", "hud_ms", "debug_ms", "main_ms", "setup_ms",
         "render_cpu_ms", "render_gpu_ms", "field_cpu_ms", "field_gpu_ms"]

def lines(path):
    out = []
    for raw in open(path, errors="replace"):
        if not raw.startswith("PERF "):
            continue
        d = {}
        for tok in raw.split()[1:]:
            k, v = tok.split("=", 1)
            d[k] = float(v)
        out.append(d)
    return out

def wmean(ls, key, wkey):
    w = sum(l[wkey] for l in ls)
    return sum(l[key] * l[wkey] for l in ls) / w if w else 0.0

def p95(vals):
    s = sorted(vals)
    return s[max(0, int(round(0.95 * len(s))) - 1)]

def runs_above(ls, key, limit):
    """Longest run of consecutive lines above limit: (lines, real s, game s); and total lines."""
    best = (0, 0.0, 0.0); cur = [0, 0.0, 0.0]; total = 0; prev_t = None
    for l in ls:
        dt = l["t"] - prev_t if prev_t is not None else 2.0
        prev_t = l["t"]
        if l[key] > limit:
            total += 1
            cur = [cur[0] + 1, cur[1] + dt, cur[2] + l["ticks"] / 60.0]
            if cur[0] > best[0]:
                best = tuple(cur)
        else:
            cur = [0, 0.0, 0.0]
    return best, total

for arg in sys.argv[1:]:
    label, path = arg.split("=", 1)
    ls = lines(path)
    n = len(ls)
    ticks = sum(l["ticks"] for l in ls)
    print(f"## {label}  ({path.split('/')[-1]}): {n} lines t={ls[0]['t']}..{ls[-1]['t']} ticks={int(ticks)} game_s={ticks/60:.1f}")
    fps = [l["fps"] for l in ls]
    print(f"  fps p50 {st.median(fps):.1f} min {min(fps):.1f} | frame_ms p50 med {st.median([l['frame_ms_p50'] for l in ls]):.2f}"
          f" p95 med {st.median([l['frame_ms_p95'] for l in ls]):.2f} max {max(l['frame_ms_p95'] for l in ls):.2f}"
          f" | frame max {max(l['frame_ms_max'] for l in ls):.2f}")
    tk = [l["tick_ms_mean"] for l in ls if l["ticks"] > 0]
    print(f"  tick_ms mean {wmean(ls,'tick_ms_mean','ticks'):.2f} (line p95 {p95(tk):.2f} max {max(tk):.2f})"
          f" | tick_ms_frame {wmean(ls,'tick_ms_frame_mean','frames'):.2f} | rest {wmean(ls,'rest_ms_mean','frames'):.2f}"
          f" | process {wmean(ls,'process_ms_mean','frames'):.2f} | ticks/frame {ticks/sum(l['frames'] for l in ls):.2f}")
    for k in COUNTS:
        v = [l[k] for l in ls]
        print(f"  {k:16s} mean {st.mean(v):6.1f}  min {min(v):4.0f}  max {max(v):4.0f}")
    h = sum(l["hops"] for l in ls); s = sum(l["short_hops"] for l in ls)
    print(f"  hops {int(h)} short {int(s)} share {100*s/h if h else 0:.1f} %")
    procx = wmean(ls, "process_ms_mean", "frames") - wmean(ls, "tick_ms_frame_mean", "frames")
    parts = {k: wmean(ls, k, "frames") for k in PARTS}
    print("  parts " + " ".join(f"{k[:-3]} {v:.2f}" for k, v in parts.items()) + f" | procx {procx:.2f}")
    draw = procx + parts["eyes_ms"] + parts["frontier_ms"] + parts["hud_ms"] + parts["render_cpu_ms"]
    print(f"  drawing (procx+eyes+frontier+hud+render_cpu) {draw:.2f}")
    (bl, br, bg), tot = runs_above(ls, "largest_cluster", 20)
    print(f"  cluster>20: longest {bl} lines = {br:.1f} s real, {bg:.1f} s game; lines above {tot}/{n}")
    (bl, br, bg), tot = runs_above(ls, "physics", 20)
    print(f"  physics>20: longest {bl} lines = {br:.1f} s real, {bg:.1f} s game; lines above {tot}/{n}")
    print("  cluster by line: " + " ".join(str(int(l["largest_cluster"])) for l in ls))
