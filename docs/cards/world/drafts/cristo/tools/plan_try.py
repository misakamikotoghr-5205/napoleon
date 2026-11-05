import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import try_battle as TB
def go(tid, L, plan, roster, cp_bonus=0, trace=False, weather=None, boss_mod=None):
    res, sim = TB.run(tid, L, plan, roster, trace=trace, cp_bonus=cp_bonus, weather=weather, boss_mod=boss_mod)
    print(json.dumps(res, ensure_ascii=False))
    if trace: print("\n".join(sim.log))
    return res
