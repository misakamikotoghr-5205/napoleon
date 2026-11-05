import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import battle_lib as B, try_battle as TB
from cristo_enemies import E
from cristo_templates import T
from cristo_uses import levels_of
ids = sys.argv[1:] or list(T)
for tid in ids:
    t = TB.prep(tid)
    for L in levels_of(tid):
        o = B.simulate_idle(t, E, L, t.get('weather', 'clear'))
        res, _ = TB.run(tid, L, [], TB.PLANS[tid]['roster'], hero=False)
        print(tid, L, 'walk:', o[0], 't%d' % o[1], 'loss%d' % o[2], [x[0] for x in o[3]][:10], '| full:', res['outcome'], 't%d' % res['turn'], 'm%d' % res['morale'], 'leaks', res['leaks'])
