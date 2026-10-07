import re, sys, glob, os
d = '/home/bastien/work/slime_train/.claude/worktrees/agent-a994fc5fd516987db/docs/perf/exp-dipjam-p2/out'
tag = sys.argv[1] if len(sys.argv) > 1 else 'm'
def kv(path):
    out = {}
    if not os.path.exists(path): return None
    for line in open(path):
        for k, v in re.findall(r'(\w+)=([-\w.]+)', line):
            key = line.split()[0] + '.' + k
            out[key] = v
    return out
vs = ["base", "g", "h", "g,h", "g,h,v1s", "r", "g,r", "g,r,v1s", "g,h,r"]
print("| variant | arr | x240 | x750 | clu max | clu mean | over 20 (s run) | short | adv med | climb start / bowl px/s | slide (alone) px/s | fus/min | stack/landings | stuck/stall/oob/lost |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for v in vs:
    a = [kv(f"{d}/{tag}_{v}_s3-basket-59of60_s{s}.txt") for s in (1, 2)]
    if None in a: continue
    f = lambda k: " / ".join(x.get(k, "?") for x in a)
    print(f"| {v} | {f('DJ_LATE.arr')} | {f('DJ_LATE.x240')} | {f('DJ_LATE.x750')} | {f('DJ_CLU.max')} | {f('DJ_CLU.mean')} | {f('DJ_CLU.run_s')} | {f('DJ_TOT.short')} | {f('DJ_TOT.adv_med')} | {f('DJ_CLIMB.start')} ; {f('DJ_CLIMB.bowl')} | {f('DJ_CLIMB.slide')} ({f('DJ_CLIMB.alone')}) | {f('DJ_TOT.fus_min')} | {' / '.join(x['DJ_CLIMB.stack']+'/'+x['DJ_CLIMB.landings'] for x in a)} | {' / '.join(x['DJ_TOT.stuck']+'/'+x['DJ_CLIMB.stall']+'/'+x['DJ_CLIMB.oob']+'/'+x['DJ_CLIMB.lost'] for x in a)} |")
print()
print("| variant | speed px/s | slow | short | adv med | fus/min | bumps | gathering | bowl climb px/s | slide (alone) | stack/landings | over taken |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|")
for v in vs:
    x = kv(f"{d}/{tag}_{v}_stress-dense_s1.txt")
    if x is None: continue
    over = ""
    for line in open(f"{d}/{tag}_{v}_stress-dense_s1.txt"):
        if line.startswith("DJ_OVER"):
            m = re.search(r'taken:(\d+)', line); over = m.group(1) if m else "0"
    print(f"| {v} | {x['DJ_TOT.speed']} | {x['DJ_TOT.slow']} | {x['DJ_TOT.short']} | {x['DJ_TOT.adv_med']} | {x['DJ_TOT.fus_min']} | {x['DJ_TOT.bumps']} | {x['DJ_TOT.gather_mean']} | {x['DJ_CLIMB.bowl']} | {x['DJ_CLIMB.slide']} ({x['DJ_CLIMB.alone']}) | {x['DJ_CLIMB.stack']}/{x['DJ_CLIMB.landings']} | {over} |")
print()
for p in sorted(glob.glob(f"{d}/{tag}_*")):
    for line in open(p):
        if line.startswith("STATE") or line.startswith("DJ_OVER"):
            print(os.path.basename(p), line.strip()[:110])
