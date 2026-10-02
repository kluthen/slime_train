#!/usr/bin/env python3
"""Chunk 22f diagnostic: reads hold_probe.gd's output for one run and prints
the BEFORE row, readings (a)-(e), hold start/end causes, back-of-queue cap
ends and the hop corridor's distributions by queue position; when the run
has them (diagnostic 2), the loop's load, the holder rule's responsible
holders, the blocked-by graph, hold ends and hops by cause, and the hold
guard's condition over ticks 1200-2400.

usage: hold_analyze.py <base>.csv [more.csv ...]
(reads <base>-snap.csv and <base>-totals.json next to each csv)
"""
import csv
import json
import os
import statistics as st
import sys
from collections import Counter

BINS = ['0-2', '3-7', '8-14', '15+']
CROWD = 30
# String columns (the rest are numbers): the outcome, and since 22f step 4
# the holder's check ('recheck', 'period_end', '' for a due slime).
STR_COLS = {'outcome', 'check'}


def binq(a):
    a = int(a)
    return '0-2' if a <= 2 else '3-7' if a <= 7 else '8-14' if a <= 14 else '15+'


def pct(values, q):
    if not values:
        return float('nan')
    v = sorted(values)
    k = (len(v) - 1) * q
    lo = int(k)
    hi = min(lo + 1, len(v) - 1)
    return v[lo] + (v[hi] - v[lo]) * (k - lo)


def share(n, d):
    return 100.0 * n / d if d else float('nan')


def load(path):
    rows = list(csv.DictReader(open(path)))
    for r in rows:
        for k in r:
            if k not in STR_COLS:
                r[k] = float(r[k])
    base = path[:-4]
    snaps = list(csv.DictReader(open(base + '-snap.csv')))
    for s in snaps:
        for k in s:
            s[k] = float(s[k])
    totals = json.load(open(base + '-totals.json'))
    return rows, snaps, totals


def before_row(snaps, t):
    hops = t['hops'] or 1
    ends = t['hold_ends_clear'] + t['hold_ends_cap'] + t['guard_releases'] + t['hold_ends_other']
    starts = t['holder_holds'] + t['crowd_holds']
    qb = sum(s['queue_back'] for s in snaps)
    qbh = sum(s['queue_back_held'] for s in snaps)
    m = lambda k: st.mean(s[k] for s in snaps) if snaps else 0.0
    mx = lambda k: max(s[k] for s in snaps) if snaps else 0.0
    print('BEFORE %s seed %s (%d ticks, %d snapshots every 120 ticks)' % (t['fixture'], t['seed'], t['ticks'], len(snaps)))
    print('  hops %d  short %.1f%%  | hold ends %d: clear %.1f / cap %.1f / guard %.1f / other %.1f %%'
          % (t['hops'], share(t['short_hops'], hops), ends, share(t['hold_ends_clear'], ends),
             share(t['hold_ends_cap'], ends), share(t['guard_releases'], ends), share(t['hold_ends_other'], ends)))
    print('  hold starts %d: holder (jam) %.1f%% crowd %.1f%% | front %.1f%% queue %.1f%% crowded %.1f%% of hops'
          % (starts, share(t['holder_holds'], starts), share(t['crowd_holds'], starts), share(t['front_hops'], hops),
             share(t['queue_hops'], hops), share(t['crowded_hops'], hops)))
    print('  holding mean/max %.1f/%d  holding_resting mean %.1f  contact_resting mean %.1f  back-held %.1f%% (%d/%d)'
          % (m('holding'), mx('holding'), m('holding_resting'), m('contact_resting'), share(qbh, qb), qbh, qb))
    print('  Physics mean %.1f  cluster mean/max %.1f/%d  stalled %d  hops not covered by a decision %d  hash %s'
          % (m('physics'), m('cluster'), mx('cluster'), t['stalled'], t['uncovered_hops'], t['hash'][:12]))


def readings(rows):
    dec = [r for r in rows if r['outcome'] != 'pending']
    starts = [r for r in dec if r['outcome'].startswith('start_')]
    passes = [r for r in dec if r['outcome'] in ('hop', 'end_clear')]
    back_pass = [r for r in passes if r['ahead'] >= 8]
    still = [r for r in dec if r['outcome'] == 'still']
    caps = [r for r in dec if r['outcome'] == 'end_cap']
    counts = [r['count'] for r in dec]
    print('READINGS (decisions %d, pending %d not counted)' % (len(dec), len(rows) - len(dec)))
    # (a) resting slimes dropped from the count
    flip_a = sum(1 for r in back_pass if r['count'] <= CROWD < r['count_rest'])
    rest_back = [r['n_rest'] for r in back_pass]
    va = 'confirmed' if share(flip_a, len(back_pass)) >= 10 else 'ruled out'
    print('  (a) %-9s back (8+) passes %d: would fail with resting counted %d (%.1f%%); resting in the half disc mean %.1f max %d'
          % (va, len(back_pass), flip_a, share(flip_a, len(back_pass)), st.mean(rest_back) if rest_back else 0,
             max(rest_back) if rest_back else 0))
    # (b) band, not a filled disc: count rarely over 30, holds mostly from the jam
    crowd_st = sum(1 for r in starts if r['crowded'])
    over = sum(1 for c in counts if c > CROWD)
    if pct(counts, 0.9) > CROWD:
        vb = 'ruled out'
    else:
        vb = 'confirmed' if not starts or share(crowd_st, len(starts)) < 25 else 'partly'
    print('  (b) %-9s count p50/p90/max %.0f/%.0f/%d, > 30 at %d of %d decisions (%.1f%%); starts with crowd failing %d of %d'
          % (vb, pct(counts, .5), pct(counts, .9), max(counts) if counts else 0, over, len(dec), share(over, len(dec)),
             crowd_st, len(starts)))
    # (c) the jam reacts only to holders: few jams start
    jam_only = sum(1 for r in starts if r['outcome'] == 'start_jam')
    vc = 'n/a' if not starts else 'confirmed' if share(jam_only, len(starts)) < 25 else 'ruled out'
    print('  (c) %-9s jam-only starts %d of %d (%.1f%%)' % (vc, jam_only, len(starts), share(jam_only, len(starts))))
    # (d) the half-plane vs along the loop
    flips_d = sum(1 for r in dec if (r['count'] > CROWD) != (r['count_loop'] > CROWD))
    nb = st.mean(r['n_behind'] for r in dec) if dec else 0
    nm = st.mean(r['n_missed'] for r in dec) if dec else 0
    behind_share = share(sum(r['n_behind'] for r in dec), sum(r['count'] for r in dec))
    vd = 'confirmed' if share(flips_d, len(dec)) >= 5 else 'ruled out'
    print('  (d) %-9s counted but behind on the loop mean %.2f (%.1f%% of counted), ahead on the loop but missed mean %.2f;'
          ' crowd verdict flips %d of %d (%.1f%%)' % (vd, nb, behind_share, nm, flips_d, len(dec), share(flips_d, len(dec))))
    # (e) the counted crowd is the train itself and never thins
    tot = sum(r['count'] for r in dec) or 1
    train_share = share(sum(r['n_train'] + r['n_hold'] for r in dec), tot)
    hold_share = share(sum(r['n_hold'] for r in dec), tot)
    still_crowd = sum(1 for r in still if r['crowded'])
    still_jam = sum(1 for r in still if r['jam'])
    cap_crowd = sum(1 for r in caps if r['crowded'])
    cap_jam = sum(1 for r in caps if r['jam'])
    if train_share >= 90 and share(still_crowd, len(still) or 1) >= 50:
        ve = 'confirmed'
    elif train_share >= 90:
        ve = 'partly'
    else:
        ve = 'ruled out'
    print('  (e) %-9s counted: train %.1f%% (awake holders %.1f%%); failed re-checks %d: crowd %d jam %d; cap ends %d: crowd %d jam %d'
          % (ve, train_share, hold_share, len(still), still_crowd, still_jam, len(caps), cap_crowd, cap_jam))
    # the coordinator's second option: all not parked/basket/sleeper, ahead along the loop
    all_over = sum(1 for r in dec if r['count_all_loop'] > CROWD)
    print('      (2nd option) disc, resting counted, ahead along the loop: > 30 at %d of %d (%.1f%%), p50/p90 %.0f/%.0f'
          % (all_over, len(dec), share(all_over, len(dec)), pct([r['count_all_loop'] for r in dec], .5),
             pct([r['count_all_loop'] for r in dec], .9)))


def causes(rows):
    oc = Counter(r['outcome'] for r in rows)
    print('OUTCOMES', dict(sorted(oc.items())))
    # 'start_jam': step 2's runs (22e's checks); 'start_holder': since 22f step 3 (the corridor's holder rule).
    print('HOLD STARTS crowd %d jam %d holder %d both %d none %d' % (oc['start_crowd'], oc['start_jam'],
          oc['start_holder'], oc['start_both'], oc['start_none']))
    print('HOLD ENDS (re-check/cap decisions) clear %d cap %d' % (oc['end_clear'], oc['end_cap']))
    print('outcome x queue bin (train slimes ahead within 300 px):')
    print('  %-12s' % '', *['%6s' % b for b in BINS])
    for o in sorted(oc):
        print('  %-12s' % o, *['%6d' % sum(1 for r in rows if r['outcome'] == o and binq(r['ahead']) == b) for b in BINS])
    for lo, label in ((8, '8+'), (15, '15+')):
        hops = [r for r in rows if r['ahead'] >= lo and r['hopped'] and r['outcome'] != 'pending']
        k = Counter(r['outcome'] for r in hops)
        print('BACK HOPS %s: %d hops: fresh (no hold) %d, after a clear end %d, after a cap end %d (cap share %.1f%%)'
              % (label, len(hops), k['hop'], k['end_clear'], k['end_cap'], share(k['end_cap'], len(hops))))
    caps = [r for r in rows if r['outcome'] == 'end_cap']
    if caps:
        print('cap ends still blocked at the cap: %d of %d (crowd %d, jam %d)' % (
            sum(1 for r in caps if r['crowded'] or r['jam']), len(caps), sum(1 for r in caps if r['crowded']),
            sum(1 for r in caps if r['jam'])))


def corridor(rows, label, keep):
    dec = [r for r in rows if r['outcome'] != 'pending' and keep(r)]
    print('CORRIDOR at %s, by queue bin (ahead within 300 px) | and by touching-queue front' % label)
    print('  %-8s %6s %5s %5s %5s %6s %6s %6s %7s %7s %6s' % ('bin', 'n', 'p10', 'p50', 'p90', '>0.4', '>0.5', '>0.6',
                                                           'holder', 'stack', 'n_corr'))
    groups = [(b, [r for r in dec if binq(r['ahead']) == b]) for b in BINS]
    groups += [('front', [r for r in dec if r['front'] == 1]), ('behind', [r for r in dec if r['front'] == 0])]
    for name, rs in groups:
        if not rs:
            print('  %-8s %6d' % (name, 0))
            continue
        o = [r['occ'] for r in rs]
        print('  %-8s %6d %5.2f %5.2f %5.2f %5.0f%% %5.0f%% %5.0f%% %6.0f%% %6.0f%% %6.1f' % (
            name, len(rs), pct(o, .1), pct(o, .5), pct(o, .9), share(sum(1 for x in o if x > .4), len(rs)),
            share(sum(1 for x in o if x > .5), len(rs)), share(sum(1 for x in o if x > .6), len(rs)),
            share(sum(r['holder_corr'] for r in rs), len(rs)), share(sum(r['holder_stack_only'] for r in rs), len(rs)),
            st.mean(r['n_corr'] for r in rs)))
    print('  would hold (occupancy > th, or a holder outside the stack zone), share of decisions:')
    print('  %-6s' % 'th', *['%8s' % g for g, _ in groups], '  | occupancy only:', *['%7s' % g for g, _ in groups])
    for th in (0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.7):
        cells = []
        occ_only = []
        for _, rs in groups:
            cells.append('%7.0f%%' % share(sum(1 for r in rs if r['occ'] > th or r['holder_corr']), len(rs)))
            occ_only.append('%6.0f%%' % share(sum(1 for r in rs if r['occ'] > th), len(rs)))
        print('  %-6.2f' % th, *cells, '  |                 ', *occ_only)


def read_csv(path):
    return list(csv.DictReader(open(path))) if os.path.exists(path) else None


def signed(g, length):
    g %= length
    return g - length if g > length / 2 else g


def gap_bin(g):
    a = abs(g)
    return '<=60' if a <= 60 else '60-200' if a <= 200 else '200-600' if a <= 600 else '>600'


def blocks_report(blocks):
    """(1) The responsible holders of every holder-rule failure."""
    checks = {}
    for b in blocks:
        checks.setdefault((b['tick'], b['checker']), []).append(b)
    print('BLOCKS (holder rule failing, responsible holders: in the corridor outside the stack zone)')
    print("  gap = the holder's record distance minus the checker's, wrapped into (-L/2, L/2]: ahead > 0")
    for label, keep in (('all', lambda r: True), ('due (starts)', lambda r: r['c_holding'] == '0'),
                        ('re-checks', lambda r: r['c_holding'] == '1'), ('front checkers', lambda r: r['c_front'] == '1')):
        groups = [g for g in checks.values() if keep(g[0])]
        if not groups:
            continue
        allb = sum(1 for g in groups if all(float(r['gap']) < 0 for r in g))
        anyb = sum(1 for g in groups if any(float(r['gap']) < 0 for r in g))
        resp = [r for g in groups for r in g]
        behind = [r for r in resp if float(r['gap']) < 0]
        print('  %-14s checks %6d, holders/check %.2f | ALL behind %.1f%%, any behind %.1f%% | holders behind %.1f%%'
              % (label, len(groups), len(resp) / len(groups), share(allb, len(groups)), share(anyb, len(groups)),
                 share(len(behind), len(resp))))
        bins = Counter((('+' if float(r['gap']) > 0 else '-') + gap_bin(float(r['gap']))) for r in resp)
        print('      gap bins', ' '.join('%s:%.0f%%' % (k, share(bins[k], len(resp))) for k in
                                         ['-' + b for b in ('>600', '200-600', '60-200', '<=60')] +
                                         ['+' + b for b in ('<=60', '60-200', '200-600', '>600')]))
        print('      euclid p50 %.0f, along p50 %.0f | |gap| > euclid + 200 (a fold of the loop) %.1f%%'
              % (pct([float(r['euclid']) for r in resp], .5), pct([float(r['along']) for r in resp], .5),
                 share(sum(1 for r in resp if abs(float(r['gap'])) > float(r['euclid']) + 200), len(resp))))
        hc = Counter(r['h_cause'] for r in resp)
        print('      holder held by: %s | holder resting %.0f%%, holder a front %.0f%%'
              % (', '.join('%s %.0f%%' % (k, share(v, len(resp))) for k, v in hc.most_common()),
                 share(sum(1 for r in resp if r['h_resting'] == '1'), len(resp)),
                 share(sum(1 for r in resp if r['h_front'] == '1'), len(resp))))
        hcb = Counter(r['h_cause'] for r in behind)
        print('      behind holders held by: %s' % ', '.join('%s %.0f%%' % (k, share(v, len(behind)))
                                                         for k, v in hcb.most_common()))


def sccs(nodes, edges):
    """Tarjan's strongly connected components, iterative."""
    index, low, on, stack, out, counter = {}, {}, set(), [], [], [0]
    for v0 in nodes:
        if v0 in index:
            continue
        work = [(v0, iter(edges[v0]))]
        index[v0] = low[v0] = counter[0]
        counter[0] += 1
        stack.append(v0)
        on.add(v0)
        while work:
            v, it = work[-1]
            pushed = False
            for w in it:
                if w not in index:
                    index[w] = low[w] = counter[0]
                    counter[0] += 1
                    stack.append(w)
                    on.add(w)
                    work.append((w, iter(edges[w])))
                    pushed = True
                    break
                if w in on:
                    low[v] = min(low[v], index[w])
            if pushed:
                continue
            work.pop()
            if work:
                low[work[-1][0]] = min(low[work[-1][0]], low[v])
            if low[v] == index[v]:
                comp = []
                while True:
                    w = stack.pop()
                    on.discard(w)
                    comp.append(w)
                    if w == v:
                        break
                out.append(comp)
    return out


def shortest_cycle(comp, edges):
    """The shortest cycle inside one strongly connected component (BFS)."""
    inside = set(comp)
    best = None
    for s in comp:
        prev = {s: None}
        frontier = [s]
        found = None
        while frontier and found is None:
            nxt = []
            for v in frontier:
                for w in edges[v]:
                    if w not in inside:
                        continue
                    if w == s:
                        found = v
                        break
                    if w not in prev:
                        prev[w] = v
                        nxt.append(w)
                if found is not None:
                    break
            frontier = nxt
        if found is None:
            continue
        cyc = [found]
        while prev[cyc[-1]] is not None:
            cyc.append(prev[cyc[-1]])
        cyc.reverse()
        if best is None or len(cyc) < len(best):
            best = cyc
    return best


def graph_report(graph, length):
    """(2) The blocked-by graph among holders, every 120 ticks."""
    by_tick = {}
    for g in graph:
        by_tick.setdefault(int(g['tick']), []).append(g)
    print("GRAPH (edge A -> B: B a responsible holder of A's last check, B still holding)")
    print('  %5s %4s %5s %5s %5s %5s %6s %-22s %6s %6s %6s %6s' % ('tick', 'hold', 'crowd', 'stale', 'inher', 'edges',
                                                              'cycles', 'scc sizes (shortest, wind)', '->cyc', '->root',
                                                              'both', 'none'))
    agg = Counter()
    for t in sorted(by_tick):
        rows = by_tick[t]
        nodes = [int(r['id']) for r in rows]
        ns = set(nodes)
        dist = {int(r['id']): float(r['dist']) for r in rows}
        cause = {int(r['id']): r['cause'] for r in rows}
        edges = {int(r['id']): [int(x) for x in r['resp'].split(';') if x and int(x) in ns] for r in rows}
        roots = {v for v in nodes if not edges[v]}
        crowd = sum(1 for v in roots if cause[v] in ('crowd',))
        inher = sum(1 for v in roots if cause[v] == 'inherited')
        stale = len(roots) - crowd - inher
        comps = [c for c in sccs(nodes, edges) if len(c) > 1]
        cyc_nodes = set(v for c in comps for v in c)
        desc = []
        for c in comps:
            cy = shortest_cycle(c, edges)
            wind = sum(signed(dist[cy[(k + 1) % len(cy)]] - dist[cy[k]], length) for k in range(len(cy))) / length
            desc.append('%d(%d,%+.0f)' % (len(c), len(cy), wind))
        reach_c = reach_r = both = none = 0
        for v in nodes:
            seen, todo = {v}, [v]
            while todo:
                x = todo.pop()
                for w in edges[x]:
                    if w not in seen:
                        seen.add(w)
                        todo.append(w)
            c_ = bool(seen & cyc_nodes)
            r_ = bool(seen & roots)
            both += c_ and r_
            reach_c += c_ and not r_
            reach_r += r_ and not c_
            none += not c_ and not r_
        depth = {}
        if not comps:
            def d_of(v):
                stack = [v]
                while stack:
                    x = stack[-1]
                    todo = [w for w in edges[x] if w not in depth]
                    if todo:
                        stack.extend(todo)
                        continue
                    stack.pop()
                    depth[x] = 1 + max((depth[w] for w in edges[x]), default=-1)
            for v in nodes:
                if v not in depth:
                    d_of(v)
        n_edges = sum(len(e) for e in edges.values())
        print('  %5d %4d %5d %5d %5d %5d %6d %-22s %6d %6d %6d %6d' % (t, len(nodes), crowd, stale, inher, n_edges,
                                                                 len(comps), ' '.join(desc)[:22], reach_c, reach_r,
                                                                 both, none))
        if depth:
            agg['depth_max'] = max(agg['depth_max'], max(depth.values()))
        if t >= 1200 and depth:
            agg.update({'depth_sum': sum(depth.values())})
        if t >= 1200:
            agg.update({'n': len(nodes), 'roots': len(roots), 'crowd': crowd, 'stale': stale, 'cyc_nodes': len(cyc_nodes),
                        'reach_c': reach_c, 'reach_r': reach_r, 'both': both, 'snaps': 1, 'comps': len(comps)})
    if agg['n']:
        print('  ticks 1200-2400: holders %d (sum over snapshots): roots %.1f%% (crowd %.1f%%, stale %.1f%%), in a cycle'
              ' %.1f%%; reach only a cycle %.1f%%, only a root %.1f%%, both %.1f%%; cycles per snapshot %.2f'
              % (agg['n'], share(agg['roots'], agg['n']), share(agg['crowd'], agg['n']), share(agg['stale'], agg['n']),
                 share(agg['cyc_nodes'], agg['n']), share(agg['reach_c'], agg['n']), share(agg['reach_r'], agg['n']),
                 share(agg['both'], agg['n']), agg['comps'] / agg['snaps']))
        print('  chain depth (edges to a root, longest): mean %.1f, max %d' % (agg['depth_sum'] / agg['n'],
                                                                             agg['depth_max']))


def roots_report(rows):
    """The crowd-only holders' checks (the graph's roots), ticks 1200-2400: what fills their corridor."""
    if not rows or 'occ_hold' not in rows[0]:
        return
    rs = [r for r in rows if r['tick'] >= 1200 and r['holding'] == 1 and r['crowd_corr'] == 1 and r['holder_corr'] == 0]
    if not rs:
        return
    occ = [r['occ'] for r in rs]
    oh = [r['occ_hold'] for r in rs]
    orest = [r['occ_rest'] for r in rs]
    free = [r['occ'] - r['occ_hold'] - r['occ_rest'] for r in rs]
    print('ROOTS (crowd-only re-checks, ticks 1200-2400): %d checks, occupancy p50 %.2f p90 %.2f; of it, p50:'
          ' holders in the stack zone %.2f, resting non-holders %.2f, awake non-holders %.2f (share %.0f%%)'
          % (len(rs), pct(occ, .5), pct(occ, .9), pct(oh, .5), pct(orest, .5), pct(free, .5),
             share(sum(free), sum(occ))))


def diag2(base, totals):
    """Diagnostic 2: who blocks whom, who hops, who keeps the guard off."""
    load_rows = read_csv(base + '-load.csv')
    if load_rows is None:
        return
    length = float(load_rows[0]['loop_len'])
    print('LOAD (loop %.0f px): tick n_sim/parked/other, sum of diameters sim/all, share of the loop covered (sim),'
          ' holders, guard blockers' % length)
    for r in load_rows:
        if int(r['tick']) % 600 == 0 or int(r['tick']) == 120:
            print('  %5s %4s/%3s/%2s  diam %6s/%6s = %.2f of the loop  covered %s  holders %s  blockers %s (pinned %s)'
                  '  front holder at %s, ahead of it %s within 1500 px, %s beyond'
                  % (r['tick'], r['n_sim'], r['n_parked'], r['n_other_state'], r['diam_sim'], r['diam_all'],
                     float(r['diam_all']) / length, r['coverage_sim'], r['holders'], r['blockers'], r.get('pinned'),
                     r.get('front_holder'), r.get('ahead_of_front'), r.get('far_ahead')))
    blocks_report(read_csv(base + '-blocks.csv'))
    graph_report(read_csv(base + '-graph.csv'), length)
    ends = read_csv(base + '-ends.csv')
    print('HOLD ENDS by cause: all %s' % dict(Counter(e['cause'] for e in ends).most_common()))
    print('  ticks 1200-2400: %s' % dict(Counter(e['cause'] for e in ends if int(e['tick']) >= 1200).most_common()))
    hops = [h for h in read_csv(base + '-hops.csv') if int(h['tick']) >= 1200]
    kinds = Counter(h['kind'] for h in hops)
    print('HOPS ticks 1200-2400: %d (distinct slimes %d, fronts %.0f%%): %s' % (
        len(hops), len(set(h['id'] for h in hops)), share(sum(1 for h in hops if h['front'] == '1'), len(hops)),
        ', '.join('%s %d' % kv for kv in kinds.most_common())))
    gah = [float(h['gap_holder_ahead']) for h in hops]
    print('  gap to the nearest holder ahead: none %d, p50 %.0f, <=300 px %d' % (
        sum(1 for g in gah if g < 0), pct([g for g in gah if g >= 0], .5), sum(1 for g in gah if 0 <= g <= 300)))
    gw = totals.get('guard_window')
    if gw:
        n = gw['ticks'] or 1
        print('GUARD ticks 1200-2400 (%d): no blocker %d, latest start >= 240 old %d, both %d; blockers mean %.1f'
              ' (air %.1f, ground %.1f), latest-start age mean %.0f; distinct blockers %d'
              % (gw['ticks'], gw['no_blockers'], gw['age_ok'], gw['both'], gw['blockers_sum'] / n, gw['air_sum'] / n,
                 gw['ground_sum'] / n, gw['age_sum'] / n, gw['distinct_blockers']))
        print('  blocker-ticks by kind: %s' % ', '.join('%s %.1f%%' % (k, share(v, gw['blockers_sum'])) for k, v in
                                                      sorted(gw['kind_ticks'].items(), key=lambda kv: -kv[1])))
        print('  top blockers [id, ticks, hops in window, ever held, kind]: %s' % gw['top_blockers'][:8])


def main():
    for path in sys.argv[1:]:
        rows, snaps, totals = load(path)
        print('=' * 100)
        print(path)
        before_row(snaps, totals)
        readings(rows)
        causes(rows)
        corridor(rows, 'due hops (not holding: hop or hold start)', lambda r: r['holding'] == 0)
        corridor(rows, 'all decisions (re-checks and cap included)', lambda r: True)
        roots_report(rows)
        diag2(path[:-4], totals)


if __name__ == '__main__':
    main()
