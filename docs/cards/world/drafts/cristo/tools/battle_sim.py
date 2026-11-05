# Simplified, deterministic re-implementation of the Battle v2 core loop (scripts/cards/campaign/battle/battle_rules.gd)
# extended with the ARCH §3/§4 rules (level table, terrain table, step costs, LOS, top tier, darkness, weather,
# pierce/post/boat/short/sniper/rally tags) and the three objective types this draft proposes (escape / extract / protect).
# It exists to *reason about* the cristo templates: "doing nothing loses", "hero alone loses", and "a sensible
# reference plan wins" — without Godot. It is weaker than a real player on purpose: no military cards, no skills,
# no square, no withdraws, no barricades, no bonds. So a plan that wins here is conservative evidence of solvability.
# Deviations from the engine are listed in SIM_NOTES and in CRISTO.md §6.
import battle_lib as B

SIM_NOTES = [
    "skills fire automatically when charged (mark_target 8 dmg, bayonet_charge 5 + knockback, raise_flag +2 row, fortify = barricade, pay_chest +3 CP +1 morale)",
    "cards: a fixed cycle of the default deck, 3 in hand; requisition, volley, bayonet, bugler and the emperor's order are auto-played; feint / barrage / fallback never",
    "no square / formations / withdraws / bonds",
    "enemy ranged targets are chosen at step d instead of locked at turn start",
    "alt wave compositions: always the first option (seed-independent)",
    "decapitation order only when the hero is on the field (L>=7, not skirmish)",
]

HERO = "hero"
CLASSES = {
    "line": {"hp": 14, "atk": 4, "def": 1, "block": 2, "cost": 4, "place": "ground"},
    "grenadier": {"hp": 20, "atk": 4, "def": 3, "block": 3, "cost": 6, "place": "ground"},
    "jager": {"hp": 8, "atk": 4, "def": 0, "block": 0, "cost": 3, "place": "high"},
    "hussar": {"hp": 10, "atk": 5, "def": 1, "block": 1, "cost": 3, "place": "ground"},
    "artillery": {"hp": 8, "atk": 6, "def": 0, "block": 0, "cost": 7, "place": "high"},
    "medic": {"hp": 10, "atk": 0, "def": 1, "block": 0, "cost": 3, "place": "any"},
    "engineer": {"hp": 14, "atk": 3, "def": 2, "block": 1, "cost": 3, "place": "ground"},
    "drummer": {"hp": 8, "atk": 1, "def": 0, "block": 1, "cost": 3, "place": "ground"},
    "hero": {"hp": 12, "atk": 2, "def": 1, "block": 1, "cost": 0, "place": "any"},
}
MELEE = {"line", "grenadier", "hussar", "engineer", "drummer", "hero"}
DIRS = {"right": (1, 0), "left": (-1, 0), "up": (0, -1), "down": (0, 1)}
LATERAL = {"right": (0, 1), "left": (0, -1), "up": (1, 0), "down": (-1, 0)}
# ARCH §4.2 "防+" column (both sides where a side can stand there)
TERRAIN_DEF = {"village": 2, "rubble": 1, "building": 2, "cell": 1}
TERRAIN_RDEF = {"woods": 2, "cave": 2}
DARK = {"corridor", "catacomb"}
KILL_OUR = {"elite": 1, "leader": 2}
SKILL_CHARGE = {"bayonet_charge": 3, "fortify": 2, "mark_target": 3, "raise_flag": 3, "pay_chest": 4}
CLASS_SKILL = {"grenadier": "bayonet_charge", "engineer": "fortify", "hero": "pay_chest"}
DECK = ["volley", "bayonet", "feint", "bugler", "barrage", "fallback", "requisition", "emperor"]


def caps(scale, L):
    """ARCH §3.3 BattleRules.caps(scale, L) -> (field, companions)"""
    old = {"skirmish": ([5] * 6, [2] * 6), "elite": ([6] * 6, [3] * 6), "major": ([7, 7, 8, 8, 9, 9], [4, 4, 4, 5, 5, 5])}
    if L <= 11 and scale in old:
        i = (L + 1) // 2 - 1
        return old[scale][0][i], old[scale][1][i]
    if scale == "skirmish":
        return (6 if L >= 13 else 5), 2
    if scale == "elite":
        return (7 if L >= 13 else 6), 3
    if scale == "major":
        return 9, 5
    if scale == "grand":
        return (11, 6) if L >= 19 else (10, 5)
    if scale == "epic":
        return (12, 6) if L >= 19 else (11, 6)
    raise ValueError(scale)


def hero_stats(L, hp_max=24):
    s = dict(CLASSES["hero"])
    s["hp"] = min(hp_max, 12 + (L - 1))
    return s


class Sim:
    def __init__(self, tpl, enemies, L, roster, plan, weather=None, cp_bonus=0, hero_enabled=True, boss_mod=None, trace=False, cp_extra=0):
        self.t = tpl
        self.E = enemies
        self.L = L
        self.weather = weather or tpl.get("weather", "clear")
        self.cols, self.rows = tpl.get("size", [len(tpl["map"][0]), len(tpl["map"])])
        self.base = [list(r) for r in tpl["map"]]
        self.grid = [row[:] for row in self.base]
        self.routes = {k: [B.parse_label(x) for x in v] for k, v in tpl["_routes"].items()}
        self.trace = trace
        self.log = []
        # stand-in for what the sim does not model: the hero's pay-chest skill, the requisition card and CP bonds
        # (about +1 CP a turn in practice); only while somebody of ours is on the field
        self.cp_extra = cp_extra
        bm = boss_mod or {}
        row = B.LEVELS[L]
        self.enemy_morale = max(1, (int(tpl["enemy_morale"]) + int(bm.get("enemy_morale", 0))) * row[1] // 100)
        self.enemy_morale_start = self.enemy_morale
        self.limit = int(tpl["turn_limit"]) + int(bm.get("turns", 0))
        self.field_cap, self.comp_cap = caps(tpl["scale"], L)
        self.cp = min(20, 6 + min(7, cp_bonus + int(bm.get("cp_bonus", 0))))
        self.morale = 10
        self.units = {}
        for uid, src in roster.items():
            u = dict(src)
            u.update({"uid": uid, "status": "bar", "col": -1, "row": -1, "facing": "right", "reload": 0, "acted": False, "charged": False,
                      "max_hp": src["hp"], "charge": 0, "skill": src.get("skill") or CLASS_SKILL.get(src["cls"], "")})
            self.units[uid] = u
        if hero_enabled:
            h = hero_stats(L)
            h.update({"uid": HERO, "cls": "hero", "kind": "hero", "status": "bar", "col": -1, "row": -1, "facing": "right", "reload": 0,
                      "acted": False, "charged": False, "max_hp": h["hp"], "tags": [], "charge": 0, "skill": "pay_chest"})
            self.units[HERO] = h
        self.hero_rally_used = False
        self.plan = sorted([p for p in plan if p.get("slots") is None], key=lambda p: p["t"])
        self.enemies = []
        self.next_uid = 1
        self.waves = []
        col_id = 0
        for w in tpl["waves"]:
            units = B.wave_units(tpl, w, L)
            if not units:
                continue
            col_id += 1
            ww = dict(w)
            ww["_units"] = units
            ww["column"] = col_id
            ww["spawned"] = False
            ww["first_fire"] = int(w.get("first_fire", int(w["turn"]) + 1))
            self.waves.append(ww)
        self.leaks = 0
        self.kills = 0
        self.fallen = []
        self.deployed_ever = []
        self.extract_count = 0
        self.decap_used = False
        self.decap_turn = -1
        self.outcome = None
        self.kind = ""
        self.turn = 0
        self.on_kill = [ev for ev in tpl.get("events", []) if "on_kill" in ev]
        self.carried = []
        self.cancelled = []
        self.auto_carry_on = True
        self.lenient = True
        self.flags = []          # [row, until] raise_flag / volley rows
        self.volley_rows = []
        self.bayonet = []
        self.bugled = {}         # row -> until
        self.deck = [c for c in DECK if c not in ("feint", "barrage", "fallback") and not (c == "emperor" and tpl["scale"] == "skirmish")]
        self.deck_i = (L * 3) % len(self.deck)
        self.hand = []
        self.use_cards = True
        self.use_skills = True
        self.skipped = []
        self.slots = []
        for p in plan:
            if p.get("slots") is not None:
                self.slots = p["slots"]

    # ------------------------------------------------------------ helpers
    def say(self, s):
        if self.trace:
            self.log.append("T%d %s" % (self.turn, s))

    def terr(self, c, r):
        return B.TERRAIN[self.grid[r][c]][0]

    def tinfo(self, c, r):
        return B.TERRAIN[self.grid[r][c]]

    def inside(self, c, r):
        return 0 <= c < self.cols and 0 <= r < self.rows

    def unit_at(self, c, r, ok_only):
        for u in self.units.values():
            if u["col"] == c and u["row"] == r and (u["status"] == "ok" or (not ok_only and u["status"] == "dying")):
                return u
        return None

    def enemies_at(self, c, r):
        return [e for e in self.enemies if e["col"] == c and e["row"] == r and e["hp"] > 0]

    def remaining(self, e):
        if e["route"]:
            return len(self.routes[e["route"]]) - 1 - e["step"]
        best = 999
        for r in range(self.rows):
            for c in range(self.cols):
                if self.terr(c, r) == "eagle":
                    best = min(best, abs(c - e["col"]) + abs(r - e["row"]))
        return best

    def hero_on(self):
        h = self.units.get(HERO)
        return h if h and h["status"] == "ok" else None

    def can_stand(self, u, c, r):
        st = self.tinfo(c, r)[1]
        place = CLASSES[u["cls"]]["place"]
        if st == "top":
            return u["cls"] == "jager"
        if place == "ground":
            return st == "ground"
        if place == "high":
            return st == "high"
        return st in ("ground", "high")

    def reserved(self, c, r):
        for w in self.waves:
            if not w["spawned"] and "at" in w and B.parse_label(w["at"]) == (c, r):
                return True
        return False

    def unit_def(self, u, kind):
        d = u["def"] + TERRAIN_DEF.get(self.terr(u["col"], u["row"]), 0) if u["col"] >= 0 else u["def"]
        if kind != "melee" and u["col"] >= 0:
            d += TERRAIN_RDEF.get(self.terr(u["col"], u["row"]), 0)
        return d

    def enemy_def(self, e, ranged):
        d = e["def"] + TERRAIN_DEF.get(self.terr(e["col"], e["row"]), 0)
        if ranged:
            d += TERRAIN_RDEF.get(self.terr(e["col"], e["row"]), 0)
        return d

    def unit_atk(self, u):
        a = u["atk"]
        if a <= 0:
            return 0
        if self.morale >= 12:
            a += 1
        for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            v = self.unit_at(u["col"] + dc, u["row"] + dr, True)
            if v is not None and v["cls"] == "drummer":
                a += 1
                break
        if any(f[0] == u["row"] and f[1] >= self.turn for f in self.flags):
            a += 2
        return a

    def enemy_atk(self, e):
        a = e["atk"]
        if a <= 0:
            return 0
        a -= e["atk_down"]
        if self.bugled.get(e["row"], -1) >= self.turn:
            a -= 2
        if e["type"] != "leader":
            for o in self.enemies:
                if o["type"] == "leader" and o["column"] == e["column"] and o["hp"] > 0:
                    a += 2 if "rally" in o["tags"] else 1
                    break
        return max(0, a)

    def los(self, a, b):
        return B.los_clear(self.grid, a, b)

    def shooter_range_mod(self, u):
        m = 0
        if self.tinfo(u["col"], u["row"])[1] == "top":
            m += 1
        if self.terr(u["col"], u["row"]) in DARK or self.weather == "night":
            m -= 1
        return m

    def pattern(self, u):
        out = []
        f, l = DIRS[u["facing"]], LATERAL[u["facing"]]
        cls = u["cls"]
        if cls in ("line", "jager"):
            n = (2 if cls == "line" else 3) + self.shooter_range_mod(u)
            spec = [(k, 0) for k in range(1, max(1, n) + 1)]
        elif cls == "artillery":
            spec = [(dx, dy) for dx in range(2, 6) for dy in (-1, 0, 1)]
        else:
            spec = [(1, 0)]
        for dx, dy in spec:
            c = u["col"] + f[0] * dx + l[0] * dy
            r = u["row"] + f[1] * dx + l[1] * dy
            if self.inside(c, r) and self.terr(c, r) != "void":
                if cls in ("line", "jager") and not self.los((u["col"], u["row"]), (c, r)):
                    break  # straight pattern: everything past the first blocking cell is cut
                out.append((c, r))
        return out

    def pick_default(self, cands):
        return min(cands, key=lambda e: (self.remaining(e), e["hp"], e["uid"]))

    def field_count(self, companions_only):
        n = 0
        for u in self.units.values():
            if u["status"] in ("ok", "dying") and (not companions_only or u["kind"] == "companion"):
                n += 1
        return n

    # ------------------------------------------------------------ turn structure
    def begin_turn(self, t):
        self.turn = t
        for ev in self.t.get("events", []):
            if "turn" in ev and int(ev["turn"]) == t:
                self.change_terrain(ev)
        for w in self.waves:
            if not w["spawned"] and int(w["turn"]) == t:
                self.spawn(w)
        if t > 1:
            g = 3 + (1 if self.hero_on() else 0) + (self.cp_extra if any(u["status"] == "ok" for u in self.units.values()) else 0)
            if self.weather == "snow":
                g -= 1
            self.cp = min(20, self.cp + g)
        for u in self.units.values():
            u["acted"] = False
            u["charged"] = False
        # decapitation (ARCH: L>=7, not skirmish), first turn the hero is on the field, from turn 3
        if not self.decap_used and self.L >= 7 and self.t["scale"] != "skirmish" and t >= 3 and self.hero_on() and t < self.limit:
            self.decap_used = True
            self.decap_turn = t + 1
        # guns pick their aim one turn ahead
        for e in self.enemies:
            if e["type"] != "gun" or e["aim"] or e["fire_turn"] > t + 1:
                continue
            cell = self.gun_pick(e)
            if cell:
                e["aim"] = cell
                e["fire_turn"] = t + 1

    def change_terrain(self, ev):
        c, r = B.parse_label(ev["cell"])
        self.grid[r][c] = B.ID2CHAR[ev["terrain"]]
        self.say("terrain %s -> %s" % (ev["cell"], ev["terrain"]))
        u = self.unit_at(c, r, False)
        if u is not None and not self.can_stand(u, c, r):
            u["status"], u["col"], u["row"] = "bar", -1, -1
            self.say("unit %s pushed back to the bar" % u["uid"])
        for e in list(self.enemies):
            if e["col"] == c and e["row"] == r and self.tinfo(c, r)[2] not in (True, "through", "start", "end", "boat"):
                self.kill(e, "fell")

    def spawn(self, w):
        w["spawned"] = True
        if "route" in w:
            c0, r0 = self.routes[w["route"]][0]
            if self.terr(c0, r0) not in ("gate", "hatch", "door", "plank") and B.label(c0, r0) not in self.t.get("spawns", []):
                self.say("wave on %s cancelled: its start %s is now %s" % (w["route"], B.label(c0, r0), self.terr(c0, r0)))
                self.cancelled.append(w["route"])
                return
        for s in w["_units"]:
            base = self.E[s["kind"]]
            hp, atk, df = B.scaled(base, self.L)
            tags = list(base["tags"]) + [x for x in s["tags"] if x not in base["tags"]]
            e = {"uid": self.next_uid, "kind": s["kind"], "type": base["type"], "hp": hp, "max_hp": hp, "atk": atk, "def": df,
                 "spd": base["spd"], "range": base["range"], "tags": tags, "route": w.get("route", ""), "step": 0,
                 "column": w["column"], "blocked_by": "", "aim": None, "fire_turn": w["first_fire"] if base["type"] == "gun" else -1,
                 "hunting": False, "retreat_turn": -1, "atk_down": 0}
            if "at" in w:
                e["col"], e["row"] = B.parse_label(w["at"])
            else:
                e["col"], e["row"] = self.routes[w["route"]][0]
            self.next_uid += 1
            self.enemies.append(e)

    def gun_pick(self, e):
        h = self.hero_on()
        if h and ("hunter" in e["tags"] or self.decap_turn == self.turn + 1):
            return (h["col"], h["row"])
        best, bk = None, None
        for i, u in enumerate(self.units.values()):
            if u["status"] != "ok" or self.terr(u["col"], u["row"]) == "cave":
                continue
            if "short" in e["tags"] and abs(u["col"] - e["col"]) > 4:
                continue
            on_high = 1 if self.tinfo(u["col"], u["row"])[1] in ("high", "top") else 0
            k = (on_high, abs(u["col"] - e["col"]) + abs(u["row"] - e["row"]), u["hp"], i)
            if bk is None or k < bk:
                best, bk = u, k
        return (best["col"], best["row"]) if best else None

    def auto_carry(self):
        """a sane player carries a dying companion off (2 CP, needs an adjacent unit of ours; free next to a medic)"""
        for u in self.units.values():
            if u["status"] != "dying":
                continue
            nbs = [self.unit_at(u["col"] + dc, u["row"] + dr, True) for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            nbs = [v for v in nbs if v is not None]
            if not nbs:
                continue
            cost = 0 if any(v["cls"] == "medic" for v in nbs) else 2
            if self.cp < cost:
                continue
            self.cp -= cost
            u["status"], u["col"], u["row"] = "carried", -1, -1
            self.carried.append(u["uid"])
            self.say("carried off %s" % u["uid"])

    def actions(self, t):
        """auto-use charged skills and the cards in hand (after deployment)"""
        self.volley_rows, self.bayonet = [], []
        if self.use_skills:
            for u in list(self.units.values()):
                sk = u.get("skill", "")
                if u["status"] != "ok" or not sk or u.get("charge", 0) < SKILL_CHARGE.get(sk, 99):
                    continue
                used = False
                if sk == "pay_chest":
                    self.cp = min(20, self.cp + 3)
                    self.add_morale(1)
                    used = True
                elif sk == "mark_target":
                    cells = self.pattern(u) if u["cls"] in ("line", "jager", "artillery") else self.pattern(dict(u, cls="line"))
                    cands = [e for (c, r) in cells for e in self.enemies_at(c, r)]
                    if cands:
                        e = min(cands, key=lambda x: (x["hp"] > 8, self.remaining(x), -x["hp"], x["uid"]))
                        e["hp"] -= 8
                        used = True
                        self.sweep()
                elif sk == "bayonet_charge":
                    mine = [e for e in self.enemies if e["blocked_by"] == u["uid"]]
                    if mine:
                        for e in mine:
                            e["hp"] -= 5
                            if e["hp"] > 0:
                                e["blocked_by"] = ""
                                self.knockback(e)
                        used = True
                        self.sweep()
                elif sk == "raise_flag":
                    foes = sum(1 for e in self.enemies if e["row"] == u["row"])
                    ours = sum(1 for v in self.units.values() if v["status"] == "ok" and v["row"] == u["row"] and self.unit_atk(v) > 0)
                    if foes and ours >= 2:
                        self.flags.append([u["row"], t + 1])
                        used = True
                elif sk == "fortify":
                    for rid, cells in self.routes.items():
                        for i, (c, r) in enumerate(cells[1:-1], 1):
                            if abs(c - u["col"]) + abs(r - u["row"]) == 1 and not self.unit_at(c, r, False) and not self.enemies_at(c, r) \
                                    and self.tinfo(c, r)[1] == "ground":
                                uid = "barricade_%d" % len(self.units)
                                self.units[uid] = {"uid": uid, "cls": "barricade", "kind": "barricade", "status": "ok", "col": c, "row": r, "facing": "right",
                                                   "hp": 8, "max_hp": 8, "atk": 0, "def": 0, "block": 2, "cost": 0, "reload": 0, "acted": False, "charged": False,
                                                   "charge": 0, "skill": "", "tags": []}
                                used = True
                                break
                        if used:
                            break
                if used:
                    u["charge"] = 0
        if not self.use_cards:
            return
        while len(self.hand) < 3:
            self.hand.append(self.deck[self.deck_i % len(self.deck)])
            self.deck_i += 1
        for card in list(self.hand):
            played = False
            if card == "requisition":
                self.cp = min(20, self.cp + 2)
                played = True
            elif card == "emperor":
                self.add_morale(3)
                played = True
            elif card == "volley" and self.cp >= 2:
                rows = {}
                for u in self.units.values():
                    if u["status"] == "ok" and u["cls"] in ("line", "jager") and any(self.enemies_at(c, r) for (c, r) in self.pattern(u)):
                        rows[u["row"]] = rows.get(u["row"], 0) + 1
                if rows:
                    self.volley_rows = [max(rows, key=lambda k: (rows[k], -k))]
                    self.cp -= 2
                    played = True
            elif card == "bayonet" and self.cp >= 1:
                best = max((u for u in self.units.values() if u["status"] == "ok" and u["cls"] in MELEE),
                           key=lambda u: sum(1 for e in self.enemies if e["blocked_by"] == u["uid"]), default=None)
                if best is not None and any(e["blocked_by"] == best["uid"] for e in self.enemies):
                    self.bayonet = [best["uid"]]
                    self.cp -= 1
                    played = True
            elif card == "bugler" and self.cp >= 2 and self.enemies:
                rows = {}
                for e in self.enemies:
                    if e["type"] != "gun":
                        rows[e["row"]] = rows.get(e["row"], 0) + 1
                if rows:
                    self.bugled[max(rows, key=lambda k: (rows[k], -k))] = t + 1
                    self.cp -= 2
                    played = True
            if played:
                self.hand.remove(card)
        if len(self.hand) >= 3:
            self.hand.pop(0)   # redraw once a turn: cycle the oldest card away

    def fill(self, t):
        """slots: priority list of [cell, facing, [unit ids or classes]]; from turn `from`, keep them manned while CP allows"""
        for spec in self.slots:
            cell, face, wants = spec[0], spec[1], spec[2]
            frm = spec[3] if len(spec) > 3 else 1
            if t < frm:
                continue
            c, r = B.parse_label(cell)
            if self.unit_at(c, r, False) or self.enemies_at(c, r) or self.reserved(c, r):
                continue
            for want in wants:
                cands = [u for u in self.units.values() if u["status"] == "bar" and (u["uid"] == want or u["cls"] == want)]
                cands = [u for u in cands if u.get("cooldown", 0) <= 0 and self.can_stand(u, c, r) and self.cp >= u["cost"]
                         and self.field_count(False) < self.field_cap and not (u["kind"] == "companion" and self.field_count(True) >= self.comp_cap)]
                if cands:
                    u = cands[0]
                    self.cp -= u["cost"]
                    u.update({"status": "ok", "col": c, "row": r, "facing": face})
                    if u["uid"] not in self.deployed_ever:
                        self.deployed_ever.append(u["uid"])
                    if u["uid"] == HERO:
                        self.add_morale(3)
                    if u["cls"] == "hussar":
                        self.charge(u)
                    break

    def do_plan(self, t):
        if self.auto_carry_on:
            self.auto_carry()
        for p in self.plan:
            if p.get("slots") is not None:
                continue
            if p["t"] != t:
                continue
            u = self.units[p["deploy"]]
            c, r = B.parse_label(p["at"])
            why = None
            if u["status"] != "bar":
                why = "not in bar"
            elif self.cp < u["cost"]:
                why = "no cp (%d < %d)" % (self.cp, u["cost"])
            elif self.field_count(False) >= self.field_cap:
                why = "field full"
            elif u["kind"] == "companion" and self.field_count(True) >= self.comp_cap:
                why = "companions full"
            elif not self.can_stand(u, c, r):
                why = "cannot stand on %s" % self.terr(c, r)
            elif self.unit_at(c, r, False) or self.enemies_at(c, r):
                why = "occupied"
            elif self.reserved(c, r):
                why = "reserved gun cell"
            if why:
                if p.get("soft"):
                    self.say("soft deploy %s at %s skipped: %s" % (p["deploy"], p["at"], why))
                    continue
                if self.lenient:
                    self.skipped.append("T%d %s@%s: %s" % (t, p["deploy"], p["at"], why))
                    continue
                raise ValueError("plan T%d deploy %s at %s: %s" % (t, p["deploy"], p["at"], why))
            self.cp -= u["cost"]
            u.update({"status": "ok", "col": c, "row": r, "facing": p.get("face", "right")})
            if u["uid"] not in self.deployed_ever:
                self.deployed_ever.append(u["uid"])
            if u["uid"] == HERO:
                self.add_morale(3)
            if u["cls"] == "hussar":
                self.charge(u)

    def charge(self, u):
        f = DIRS[u["facing"]]
        stop, target = 0, None
        for k in range(1, 4):
            c, r = u["col"] + f[0] * k, u["row"] + f[1] * k
            if not self.inside(c, r):
                break
            if self.enemies_at(c, r):
                target = (c, r)
                break
            if not self.can_stand(u, c, r) or self.unit_at(c, r, False) or self.terr(c, r) == "mud":
                break
            stop = k
        if target is None:
            return
        u["col"] += f[0] * stop
        u["row"] += f[1] * stop
        atk = self.unit_atk(u) * 2
        for e in self.enemies_at(*target):
            e["hp"] -= max(1, atk - self.enemy_def(e, False))
            if e["hp"] > 0:
                self.knockback(e)
        u["charged"] = True
        self.sweep()

    def knockback(self, e):
        if not e["route"] or e["step"] <= 0:
            return
        pc, pr = self.routes[e["route"]][e["step"] - 1]
        if self.unit_at(pc, pr, False) is not None:
            return
        e["step"] -= 1
        e["col"], e["row"] = pc, pr
        e["blocked_by"] = ""

    # ------------------------------------------------------------ fight
    def fight(self):
        acted = False
        if self.enemy_morale > 0:
            self.step_a()
        if self.enemy_morale > 0:
            acted = True
            self.step_b()
            self.step_c()
            if self.enemy_morale > 0:
                self.step_d()
        self.step_e(acted)

    def small_arms_atk(self, u):
        a = self.unit_atk(u) + (2 if u["row"] in self.volley_rows else 0)
        if self.weather == "rain":
            a -= 1
        return a

    def step_a(self):
        for cls in ("artillery", "jager", "line"):
            for u in list(self.units.values()):
                if u["status"] != "ok" or u["cls"] != cls or u["charged"] or self.unit_atk(u) <= 0:
                    continue
                if cls == "artillery":
                    if u["reload"] > 0:
                        continue
                    cells = self.pattern(u)
                    cands = [e for (c, r) in cells for e in self.enemies_at(c, r)]
                    if not cands:
                        continue
                    best = self.pick_default(cands)
                    cell = (best["col"], best["row"])
                    atk = self.unit_atk(u)
                    for e in self.enemies_at(*cell):
                        e["hp"] -= max(1, atk - self.enemy_def(e, True))
                    f = DIRS[u["facing"]]
                    c2 = (cell[0] + f[0], cell[1] + f[1])
                    if self.inside(*c2):
                        for e in self.enemies_at(*c2):
                            e["hp"] -= max(1, atk - self.enemy_def(e, True)) // 2
                    u["reload"] = 2
                    u["acted"] = True
                    self.sweep()
                else:
                    cands = [e for (c, r) in self.pattern(u) for e in self.enemies_at(c, r)]
                    if not cands:
                        continue
                    if cls == "jager":
                        pref = [e for e in cands if e["type"] in ("elite", "leader") or "officer" in e["tags"]]
                        e = self.pick_default(pref or cands)
                    else:
                        e = self.pick_default(cands)
                    atk = self.small_arms_atk(u)
                    if self.tinfo(u["col"], u["row"])[1] == "top" and self.tinfo(e["col"], e["row"])[7] <= 1:
                        atk += 1
                    e["hp"] -= max(1, atk - self.enemy_def(e, True))
                    u["acted"] = True
                    self.sweep()

    def block_of(self, u):
        return u["block"] if u["status"] == "ok" else 0

    def block_used(self, u):
        return sum(2 if "heavy" in e["tags"] else 1 for e in self.enemies if e["blocked_by"] == u["uid"])

    def need(self, e):
        return (2 if "heavy" in e["tags"] else 1) + (1 if "pierce" in e["tags"] else 0)

    def chain(self, e):
        cells = self.routes[e["route"]]
        out, i = [], e["step"] + 1
        while i < len(cells) - 1:
            u = self.unit_at(cells[i][0], cells[i][1], False)
            if u is None:
                break
            out.append(u)
            i += 1
        return out

    def halts(self, e, hero):
        if self.unit_at(e["col"], e["row"], False) is not None:
            return False
        if hero is not None and abs(e["col"] - hero["col"]) + abs(e["row"] - hero["row"]) == 1:
            e["hunting"] = True
            return True
        ch = self.chain(e)
        if not ch:
            return False
        for u in ch:
            if self.block_of(u) - self.block_used(u) >= self.need(e):
                e["blocked_by"] = u["uid"]
                return True
        return False

    def step_b(self):
        for e in self.enemies:
            e["hunting"] = False
            if e["blocked_by"]:
                b = self.units.get(e["blocked_by"])
                if b is None or b["status"] != "ok":
                    e["blocked_by"] = ""
        movers = sorted(self.enemies, key=lambda x: (self.remaining(x), x["uid"]))
        for e in movers:
            if e not in self.enemies or e["type"] == "gun" or not e["route"] or e["spd"] <= 0:
                continue
            if e["retreat_turn"] == self.turn:
                e["blocked_by"] = ""
                self.knockback(e)
                continue
            if e["blocked_by"]:
                continue
            self.move(e)

    def move(self, e):
        cells = self.routes[e["route"]]
        hero = self.hero_on() if "hunter" in e["tags"] else None
        # step costs (ARCH §4.2): movement points left over when the next cell costs more than what is left
        # carry to the next turn (proposal: otherwise a speed-1 unit could never enter a cost-2 cell)
        e["budget"] = e.get("budget", 0) + max(0, e["spd"] - (1 if self.bugled.get(e["row"], -1) >= self.turn else 0))
        while True:
            if self.halts(e, hero):
                e["budget"] = 0
                return
            if e["step"] >= len(cells) - 1:
                break
            nc, nr = cells[e["step"] + 1]
            cost = self.tinfo(nc, nr)[3] or 1
            if self.weather == "mud" and e["type"] == "cavalry":
                cost += 1
            if e["budget"] < cost:
                e["budget"] = min(e["budget"], cost - 1)
                break
            e["budget"] -= cost
            budget = e["budget"]
            e["step"] += 1
            e["col"], e["row"] = cells[e["step"]]
            if e["step"] == len(cells) - 1:
                self.reach_eagle(e)
                return
        while self.unit_at(e["col"], e["row"], False) is not None and e["step"] < len(cells) - 1:
            e["step"] += 1
            e["col"], e["row"] = cells[e["step"]]
            if e["step"] == len(cells) - 1:
                self.reach_eagle(e)
                return
        self.halts(e, hero)

    def reach_eagle(self, e):
        self.enemies.remove(e)
        self.leaks += 1
        self.say("%s reaches the eagle" % e["kind"])
        self.add_morale(-(3 if e["type"] in ("elite", "leader") else 2))

    def step_c(self):
        hits = []
        for u in self.units.values():
            if u["status"] != "ok" or u["acted"] or u["charged"] or u["cls"] not in MELEE:
                continue
            atk = self.unit_atk(u)
            if atk <= 0:
                continue
            mine = [e for e in self.enemies if e["blocked_by"] == u["uid"]]
            target = None
            if mine:
                target = min(mine, key=lambda e: (e["hp"], e["uid"]))
            else:
                f = DIRS[u["facing"]]
                front = self.enemies_at(u["col"] + f[0], u["row"] + f[1])
                if front:
                    target = min(front, key=lambda e: (e["hp"], e["uid"]))
            if target is None:
                continue
            for _ in range(2 if u["uid"] in self.bayonet else 1):
                hits.append(("e", target, max(1, atk - self.enemy_def(target, False))))
            u["acted"] = True
        for e in self.enemies:
            if e["type"] == "gun" or e["range"] > 0:
                continue
            tgt = HERO if e["hunting"] else e["blocked_by"]
            if not tgt or self.enemy_atk(e) <= 0:
                continue
            tu = self.units[tgt]
            hits.append(("u", tu, max(1, self.enemy_atk(e) - self.unit_def(tu, "melee"))))
        for kind, x, d in hits:
            if kind == "e":
                x["hp"] -= d
            elif x["status"] == "ok":
                x["hp"] -= d
        self.sweep()

    def ranged_target(self, e):
        rng = e["range"] - (1 if (self.terr(e["col"], e["row"]) in DARK or self.weather == "night") else 0)
        rng = max(1, rng)
        h = self.hero_on()
        cands = []
        for i, u in enumerate(self.units.values()):
            if u["status"] != "ok":
                continue
            d = abs(u["col"] - e["col"]) + abs(u["row"] - e["row"])
            if d > rng or not self.los((e["col"], e["row"]), (u["col"], u["row"])):
                continue
            pri = 0
            if "sniper" in e["tags"]:
                pri = 0 if u["kind"] in ("hero", "companion") else 1
            cands.append((pri, d, u["hp"], i, u))
        if h and ("hunter" in e["tags"] or self.decap_turn == self.turn) and any(c[4] is h for c in cands):
            return h
        return min(cands, key=lambda c: c[:4])[4] if cands else None

    def step_d(self):
        for e in list(self.enemies):
            if e["type"] == "gun":
                if e["fire_turn"] == self.turn and e["aim"]:
                    tu = self.unit_at(e["aim"][0], e["aim"][1], True)
                    if tu is not None:
                        tu["hp"] -= max(1, self.enemy_atk(e) - self.unit_def(tu, "gun"))
                    e["aim"] = None
                    e["fire_turn"] = self.turn + (3 if ("boat" in e["tags"] and self.weather == "storm") else 2)
                continue
            if e["range"] <= 0 or self.enemy_atk(e) <= 0:
                continue
            tu = self.units[e["blocked_by"]] if e["blocked_by"] else self.ranged_target(e)
            if tu is not None and tu["status"] == "ok":
                a = self.enemy_atk(e) - (1 if self.weather == "rain" else 0)
                tu["hp"] -= max(1, a - self.unit_def(tu, "ranged"))
        self.sweep()

    def step_e(self, acted):
        t = self.turn
        for u in self.units.values():
            if u["status"] != "ok" or u["hp"] > 0:
                continue
            if u["kind"] == "barricade":
                u["status"] = "routed"
                u["col"] = u["row"] = -1
            elif u["kind"] == "troop":
                u["status"] = "routed"
                u["col"] = u["row"] = -1
                self.add_morale(-1)
            elif u["kind"] == "hero":
                u["status"] = "down"
                u["col"] = u["row"] = -1
                self.fallen.append(HERO)
                self.add_morale(-5)
            else:
                u["status"] = "dying"
                u["hp"] = 0
                self.fallen.append(u["uid"])
                for e in self.enemies:
                    if e["blocked_by"] == u["uid"]:
                        e["blocked_by"] = ""
                self.add_morale(-2)
        for m in self.units.values():
            if m["status"] == "ok" and m["cls"] == "medic":
                best = None
                for v in self.units.values():
                    if v["status"] == "ok" and v["hp"] < v["max_hp"] and abs(v["col"] - m["col"]) + abs(v["row"] - m["row"]) <= 2:
                        if best is None or v["hp"] < best["hp"]:
                            best = v
                if best:
                    best["hp"] = min(best["max_hp"], best["hp"] + 3 - (1 if self.weather == "snow" else 0))
        for u in self.units.values():
            if u["status"] == "ok":
                u["reload"] = max(0, u["reload"] - 1)
                u["charge"] = min(SKILL_CHARGE.get(u.get("skill", ""), 99), u.get("charge", 0) + 1)
        if self.weather == "desert" and t % 3 == 0:
            pass  # no desert maps in this branch
        if self.weather == "storm":
            for u in self.units.values():
                if u["status"] == "ok" and self.terr(u["col"], u["row"]) == "rigging":
                    u["hp"] = max(1, u["hp"] - 1)
        od = self.t.get("order", {})
        if od.get("type") == "extract":
            c, r = B.parse_label(od["cell"])
            u = self.unit_at(c, r, True)
            if u is not None:
                self.extract_count += 1
        if self.morale <= 0:
            return self.finish("defeat", "")
        if self.enemy_morale <= 0:
            return self.finish("victory", "rout")
        future = any(not w["spawned"] for w in self.waves)
        if not future and not self.enemies:
            return self.finish("victory", "cleared" if self.leaks == 0 else "spent")
        if t >= self.limit:
            return self.finish("victory", "hold")

    def add_morale(self, d):
        m = min(self.morale + d, max(15, self.morale))
        h = self.hero_on()
        if d < 0 and m < 3 and h and not self.hero_rally_used:
            self.hero_rally_used = True
            m = 3
            h["hp"] = max(1, h["hp"] - 4)
        self.morale = max(0, m)

    def sweep(self):
        for e in [x for x in self.enemies if x["hp"] <= 0]:
            if e in self.enemies:
                self.kill(e, "killed")

    def kill(self, e, why):
        self.enemies.remove(e)
        self.kills += 1
        self.enemy_morale = max(0, self.enemy_morale - B.KILL_MORALE[e["type"]])
        if KILL_OUR.get(e["type"]):
            self.add_morale(KILL_OUR[e["type"]])
        if e["type"] == "wagon":
            for o in self.enemies:
                if abs(o["col"] - e["col"]) + abs(o["row"] - e["row"]) <= 1:
                    o["hp"] -= 6
        if e["type"] == "leader":
            for o in self.enemies:
                if o["column"] == e["column"]:
                    o["retreat_turn"] = self.turn + 1
                    o["atk_down"] += 1
        for ev in self.on_kill:
            if ev["on_kill"] == e["kind"] and not ev.get("_done"):
                ev["_done"] = True
                self.change_terrain(ev)
        self.say("%s %s" % (e["kind"], why))

    def finish(self, outcome, kind):
        self.outcome, self.kind = outcome, kind
        return True

    def order_done(self):
        od = self.t.get("order", {})
        if self.outcome != "victory" or not od:
            return False
        ty = od["type"]
        if ty == "hold":
            c, r = B.parse_label(od["cell"])
            u = self.unit_at(c, r, True)
            return u is not None and (self.turn >= int(od["turn"]) or self.kind != "hold")
        if ty == "no_leak":
            return self.leaks == 0
        if ty == "escape":
            u = self.units.get(od["unit"])
            cells = [B.parse_label(x) for x in od["cells"]]
            return u is not None and u["status"] == "ok" and (u["col"], u["row"]) in cells and (self.turn >= int(od.get("turn", 0)) or self.kind != "hold")
        if ty == "extract":
            return self.extract_count >= int(od["turns"])
        if ty == "protect":
            return od["unit"] in self.deployed_ever and od["unit"] not in self.fallen
        return False

    def run(self):
        for t in range(1, self.limit + 1):
            self.begin_turn(t)
            self.do_plan(t)
            self.fill(t)
            self.actions(t)
            self.fight()
            if self.trace:
                us = ["%s@%s:%d" % (u["uid"], B.label(u["col"], u["row"]), u["hp"]) for u in self.units.values() if u["status"] in ("ok", "dying")]
                es = ["%s@%s:%d" % (e["kind"][:6], B.label(e["col"], e["row"]), e["hp"]) for e in self.enemies]
                self.log.append("T%d end: cp=%d morale=%d em=%d leaks=%d | ours %s | foes %s" % (t, self.cp, self.morale, self.enemy_morale, self.leaks, " ".join(us), " ".join(es)))
            if self.outcome:
                break
        if not self.outcome:
            self.finish("victory", "hold")
        return {"outcome": self.outcome, "kind": self.kind, "turn": self.turn, "morale": self.morale, "leaks": self.leaks,
                "kills": self.kills, "enemy_morale": "%d/%d" % (self.enemy_morale, self.enemy_morale_start),
                "fallen": list(self.fallen), "carried": list(self.carried), "order_done": self.order_done(),
                "cp_left": self.cp, "skipped": list(self.skipped), "cancelled_waves": list(self.cancelled)}


def ref_roster(L, companions, troops):
    """ARCH §3.6 reference roster: troops at class stats, companions scaled by (100+5(L-1))/100."""
    out = {}
    pct = 100 + 5 * (L - 1)
    for cid, c in companions.items():
        out[cid] = {"cls": c["cls"], "kind": "companion", "hp": c["hp"] * pct // 100, "atk": c["atk"] * pct // 100,
                    "def": c["def"], "block": c["block"], "cost": c["cost"], "tags": [], "skill": c.get("skill", "")}
    for i, cls in enumerate(troops):
        s = CLASSES[cls]
        out["%s_%d" % (cls, i + 1)] = {"cls": cls, "kind": "troop", "hp": s["hp"], "atk": s["atk"], "def": s["def"], "block": s["block"], "cost": s["cost"], "tags": []}
    return out
