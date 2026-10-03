#!/usr/bin/env python3
"""Means of PERF fields over windows of a perf.log: whole, cold (first N s), warm (last N s)."""
import sys, statistics as st

def lines(path):
    out = []
    for l in open(path):
        i = l.find("PERF ")
        if i < 0 or "PERF_INFO" in l:
            continue
        d = {}
        for kv in l[i + 5:].split():
            if "=" in kv:
                k, v = kv.split("=", 1)
                try:
                    d[k] = float(v)
                except ValueError:
                    d[k] = v
        if "fps" in d:
            out.append(d)
    return out

def pct(xs, p):
    xs = sorted(xs)
    k = (len(xs) - 1) * p
    f = int(k)
    c = min(f + 1, len(xs) - 1)
    return xs[f] + (xs[c] - xs[f]) * (k - f)

def summ(name, L):
    if not L:
        print(name, "no lines"); return
    g = lambda k: [d[k] for d in L if isinstance(d.get(k), float)]
    fr = sum(g("frames")); dur = len(L)
    fps = g("fps")
    hops = sum(g("hops")); sh = sum(g("short_hops"))
    print(f"{name}: n={len(L)} t={L[0]['t']:.0f}..{L[-1]['t']:.0f}")
    print(f"  fps mean {st.mean(fps):.1f} (frames/lines {fr/dur:.1f}) p50 {pct(fps,.5):.1f} p5 {pct(fps,.05):.1f} min {min(fps):.1f}")
    print(f"  frame_ms_p95 median {pct(g('frame_ms_p95'),.5):.1f} mean {st.mean(g('frame_ms_p95')):.1f}  frame_ms_p50 median {pct(g('frame_ms_p50'),.5):.1f}")
    for k in ["tick_ms_mean", "ticks_per_frame_mean", "tick_ms_frame_mean", "rest_ms_mean", "process_ms_mean", "physics", "largest_cluster", "active", "pairs", "render_cpu_ms", "render_gpu_ms", "slimes_ms"]:
        v = g(k)
        if v:
            print(f"  {k} mean {st.mean(v):.2f} max {max(v):.2f}")
    print(f"  hops/line {hops/len(L):.2f} short share {100*sh/hops if hops else float('nan'):.0f}%")

L = lines(sys.argv[1]); n = int(sys.argv[2]) if len(sys.argv) > 2 else 60
t0 = L[0]["t"]; t1 = L[-1]["t"]
summ("session", L)
summ("cold", [d for d in L if d["t"] - t0 < n])
summ("warm", [d for d in L if t1 - d["t"] < n])
