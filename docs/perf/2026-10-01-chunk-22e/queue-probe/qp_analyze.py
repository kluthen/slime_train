import csv, sys, statistics as st
from collections import Counter, defaultdict
rows=list(csv.DictReader(open(sys.argv[1])))
for r in rows:
    for k in r:
        if k not in('outcome',): r[k]=float(r[k])
def binq(a):
    a=int(a)
    return '0-2' if a<=2 else '3-7' if a<=7 else '8-14' if a<=14 else '15+'
BINS=['0-2','3-7','8-14','15+']
print('decisions',len(rows))
print('outcomes',Counter(r['outcome'] for r in rows))
# prediction check
mis=[r for r in rows if (r['outcome'] in('start','still'))!=(r['blocked']==1) and r['outcome'] not in('nohop_nohold',)]
print('prediction mismatches',len(mis), Counter(r['outcome'] for r in mis))
tab=defaultdict(Counter)
for r in rows: tab[r['outcome']][binq(r['ahead'])]+=1
print('outcome x queue bin (train slimes ahead within 300px along loop):')
print('%-16s'%'', *['%6s'%b for b in BINS])
for o in sorted(tab): print('%-16s'%o, *['%6d'%tab[o][b] for b in BINS])
def summ(name, rs):
    if not rs: print(name,'n=0'); return
    c=[r['count'] for r in rs]
    tot=sum(c) or 1
    print('%s n=%d count mean=%.1f median=%.0f | split: train_holding=%.0f%% train_awake=%.0f%% other=%.0f%% | behind_on_loop=%.0f%% elsewhere_on_loop(fwd>450)=%.0f%% | mean_dist_to_target=%.0f | jam=%d | count>15:%d >30:%d | ahead mean=%.1f'%(
        name,len(rs),st.mean(c),st.median(c),100*sum(r['n_hold'] for r in rs)/tot,100*sum(r['n_train'] for r in rs)/tot,
        100*sum(r['n_other'] for r in rs)/tot,100*sum(r['n_behind'] for r in rs)/tot,100*sum(r['n_far'] for r in rs)/tot,
        st.mean(r['mean_dist'] for r in rs if r['count']>0) if any(r['count']>0 for r in rs) else 0,
        sum(1 for r in rs if r['jam']), sum(1 for r in rs if r['count']>15), sum(1 for r in rs if r['count']>30), st.mean(r['ahead'] for r in rs)))
for o in sorted(tab):
    summ(o,[r for r in rows if r['outcome']==o])
    for b in BINS:
        rs=[r for r in rows if r['outcome']==o and binq(r['ahead'])==b]
        if rs: summ('   '+b,rs)
# hold starts: why
st_=[r for r in rows if r['outcome']=='start']
print('starts: crowd only',sum(1 for r in st_ if r['count']>30 and not r['jam']),'jam only',sum(1 for r in st_ if r['count']<=30 and r['jam']),'both',sum(1 for r in st_ if r['count']>30 and r['jam']))
stl=[r for r in rows if r['outcome']=='still']
print('failed rechecks: crowd only',sum(1 for r in stl if r['count']>30 and not r['jam']),'jam only',sum(1 for r in stl if r['count']<=30 and r['jam']),'both',sum(1 for r in stl if r['count']>30 and r['jam']))
# flips
def flips(th, f=lambda r:r['count']):
    a=Counter()
    for r in rows:
        if r['outcome']=='nohop_nohold': continue
        old = r['count']>30 or r['jam']
        new = f(r)>th or r['jam']
        if old!=new: a[('pass->fail' if new else 'fail->pass', r['outcome'], binq(r['ahead']))]+=1
    return a
print('flips at HOLD_CROWD 15:',sorted(flips(15).items()))
print('flips at 30 excluding behind-on-loop train slimes:',sorted(flips(30,lambda r:r['count']-r['n_behind']).items()))
print('flips at 15 excluding behind-on-loop:',sorted(flips(15,lambda r:r['count']-r['n_behind']).items()))
print('flips at 30 counting only non-train + train ahead<=300 on loop:',sorted(flips(30,lambda r:r['count']-r['n_behind']-r['n_far']).items()))
# Decisions by elapsed for cap ends: blocked at cap?
cap=[r for r in rows if r['outcome'].startswith('end_cap')]
print('cap ends still blocked at the cap:',sum(1 for r in cap if r['blocked']),'of',len(cap))
# hold durations distribution by bin for ending holds
for o in ('end_pass','end_cap'):
    rs=[r for r in rows if r['outcome']==o]
    if rs: print(o,'elapsed median',st.median(r['elapsed'] for r in rs))
# per-tick time profile: hops by queue bin in first/second half
