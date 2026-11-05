"""Second-volume battlefields from the authored campaign and battlefield plans.

The original 53 templates are untouched.  Each new map keeps integer coordinates,
explicit approaches and previewable waves; enemy stats come from the final roster.
"""
from __future__ import annotations

import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENEMIES = json.loads((ROOT / "docs/cards/world/drafts/spec/data/enemies_final.json").read_text())["enemies"]
HP = [100,108,115,122,130,137,145,152,160,170,180,188,196,204,212,220,228,236,244,252,260,270,280,290]


def power(kind: str, level: int) -> int:
    row = ENEMIES[kind]
    hp = max(1, row["hp"] * HP[level - 1] // 100)
    attack = row["atk"] + ((level + 3) // 4 - 1 if row["atk"] else 0)
    defence = row["def"] + (max(0, (level - 9) // 6) if row["def"] else 0)
    factor = attack + 4 if row["type"] == "gun" else attack + defence + 2 * row["spd"] + (2 if row["range"] else 0)
    return hp * factor // 10


def label(x: int, row: int) -> str:
    return chr(65 + x) + str(row)


def lane(width: int, row: int, end: int = 0) -> list[str]:
    return [label(x, row) for x in range(width - 1, end - 1, -1)]


def paint(grid: list[list[str]], cells: list[str], terrain: str):
    for cell in cells:
        grid[int(cell[1:]) - 1][ord(cell[0]) - 65] = terrain


def fill(target: int, kinds: list[str], level: int, preferred: int = 18) -> list[str]:
    """Meet the budget using whole authored units (at most six power above it)."""
    if target < 0:
        raise ValueError("Authored opening force exceeds the power budget")
    dp = {(0, 0): []}
    for count in range(1, 41):
        for amount in range(target + 7):
            candidates = []
            for index, kind in enumerate(kinds):
                p = power(kind, level)
                previous = dp.get((count - 1, amount - p))
                if previous is not None:
                    candidate = previous + [kind]
                    # Prefer mixed ranks, then authored enemy order.
                    candidates.append((sum(candidate.count(k) ** 2 for k in kinds), index, candidate))
            if candidates:
                dp[count, amount] = min(candidates)[2]
    options = [(amount - target, abs(count - preferred), count, units) for (count, amount), units in dp.items() if amount >= target]
    if not options:
        raise ValueError(f"No exact force for power {target}, L{level}, {kinds}")
    return min(options)[3]


def make(id_: str, name: str, segment: str, level: int, scale: str, size: tuple[int,int],
         ground: str, rows: tuple[int,...], scenery: dict[str,list[str]], weather: str,
         target: int, core: list[list[str]], guns: list[tuple[str,str]], fillers: list[str],
         note: str, turns: int = 13, route_terrain: str = "=", extra_routes: dict | None = None,
         order: dict | None = None) -> dict:
    width, height = size
    grid = [[ground for _ in range(width)] for _ in range(height)]
    routes = {f"approach_{i+1}": lane(width, row) for i, row in enumerate(rows)}
    if extra_routes:
        routes.update(copy.deepcopy(extra_routes))
    for route in routes.values():
        paint(grid, route, route_terrain)
    for char, cells in scenery.items():
        paint(grid, cells, char)
    for route in routes.values():
        paint(grid, [route[0]], "G")
        paint(grid, [route[-1]], "E")
    waves = []
    paths = list(routes)
    for i, specs in enumerate(core):
        waves.append({"turn": 1 + i // len(paths), "route": paths[i % len(paths)], "units": specs[:]})
    for cell, kind in guns:
        waves.append({"turn": 1, "at": cell, "units": [kind], "first_fire": 3})
    current = sum(power(u, level) for w in waves for u in w["units"])
    extras = fill(target - current, fillers, level, max(8, 22 - sum(len(w["units"]) for w in waves)))
    for i, unit in enumerate(extras):
        path = paths[i % len(paths)]
        wave_index = i // len(paths)
        # A later campaign battle is a sequence of attacks, not the whole army
        # arriving before the second command-point refill.  The first two
        # reinforcement groups still reach both exits without active defence.
        turn = 2 + wave_index if wave_index < 2 else 4 + (wave_index - 2) % 5
        wave = next((w for w in waves if w.get("route") == path and w["turn"] == turn), None)
        if wave is None:
            wave = {"turn": turn, "route": path, "units": []}
            waves.append(wave)
        wave["units"].append(unit)
    result = {"id": id_, "name": name, "segment": segment, "volume": 2, "scale": scale,
        "size": list(size), "level": level, "turn_limit": turns, "enemy_morale": 20 + level,
        "weather": [weather], "map": ["".join(line) for line in grid], "routes": routes,
        "waves": sorted(waves, key=lambda w: w["turn"]),
        "order": {"type": "no_leak", "desc": "军令：守住各条通道，不让敌军越过鹰旗。"},
        "objective": {"type": "hold", "desc": note}, "notes": note,
        "_provenance": "ai:Codex:2026-11-04:Napoleon-volume2-authored-battle-plans"}
    if order:
        if order["type"] in ["hold", "no_leak"]:
            result["order"] = copy.deepcopy(order)
        else:
            result["order_next"] = copy.deepcopy(order)
            result["order"]["desc"] = "军令：守住撤离通道。"
    return result


def build_templates() -> dict:
    out = {}

    def add(*args, **kwargs):
        template = make(*args, **kwargs)
        out[template["id"]] = template
        return template

    # The three mutually exclusive trunk theatres match their first-volume peers' power.
    add("marengo", "马伦戈·德赛的午后", "trunk", 5, "major", (9,5), ".", (2,4),
        {"w":["C1","E1","C5","E5"], "~":["F1","F3","F5"], "b":["F2","F4"], "^":["B1","D3","H1"], "v":["C2","C4"]},
        "clear", 150, [["dragoon","whitecoat"],["dragoon","whitecoat"],["hungarian"]], [("H1","gun")], ["whitecoat","grenz","piedmontese"],
        "葡萄园遮蔽两翼；守住丰塔诺内溪上的小桥，等德赛的纵队赶到。", turns=11)
    add("eylau", "埃劳·白雪中的墓地", "trunk", 7, "major", (9,5), "s", (2,4),
        {"#":["D1","E1","D3","E3","D5"], "v":["B2","B4"], "i":["F3","G3"], "^":["B1","C3","H1"]},
        "snow", 172, [["cossack","ru_line"],["cossack","ru_line"],["ru_grenadier"]], [("H1","ru_gun")], ["ru_line","ru_jaeger","opolchenie"],
        "墓地墙分割视线，清出的道路仍可行军；在风雪里守住村口与南侧撤离线。", turns=12)
    t = add("wagram", "瓦格拉姆·洛鲍岛浮桥", "trunk", 9, "grand", (10,6), ".", (2,5),
        {"~":["E1","E3","E4","E6"], "b":["E2","E5"], "+":["B1","D1","C3","D4"], "^":["H1","I3","I6"], "v":["C2","C5"]},
        "clear", 200, [["dragoon","whitecoat"],["dragoon","whitecoat"],["hungarian"]], [("H1","gun"),("I6","gun")], ["whitecoat","grenz","tyrolean"],
        "两座浮桥通向洛鲍岛；用胸墙和高地炮位压制对岸炮群，别把全部兵力挤在一座桥上。", turns=12)

    # Optional elites from the authored main campaign map, now with their own terrain.
    elite_specs = [
        ("fort_bard","巴尔德堡·骡道",4,(8,4),".","clear",105,["dragoon","piedmontese"],"gun",["piedmontese","grenz","barbet"],
         {"#":["D1","E1","D3","E3"],"R":["F1"],"^":["B1","C3","G3"]},"堡墙封住峡谷视线，猎兵可从骡道与屋顶掩护炮车。"),
        ("ulm","乌尔姆·多瑙河桥",6,(9,5),"u","rain",135,["dragoon","whitecoat"],"gun",["whitecoat","grenz","piedmontese"],
         {"~":["E1","E3","E5"],"b":["E2","E4"],"#":["F1","F3"],"^":["B1","C3","H5"]},"泥地拖慢侧翼，桥上的两条道路必须同时保持通畅。"),
        ("jena","耶拿·兰德格拉芬山",6,(9,5),".","fog",140,["uhlan","fusilier"],"pr_gun",["fusilier","landwehr","grenz"],
         {"^":["B1","C1","B3","D3","H5"],"v":["D2","D4"],"w":["F1","F5"]},"雾遮住山后的普军，先占山脊炮位，再守住通往村庄的两条斜路。"),
        ("somosierra","索莫谢拉·四座炮台",8,(9,5),".","clear",170,["es_lancer","es_regular"],"british_gun",["es_regular","guerrillero","bandolero"],
         {"^":["B1","C3","G1","G3","H5"],"n":["E1","E5"],"v":["C2"]},"山口火炮覆盖大道；骑兵要等猎兵压制炮位，再轮换冲上山坡。"),
        ("aspern","阿斯佩恩·两座村庄",8,(9,5),".","clear",176,["dragoon","whitecoat"],"gun",["whitecoat","grenz","piedmontese"],
         {"v":["C2","C4"],"B":["D1","D5"],"~":["F1","F3","F5"],"b":["F2","F4"],"^":["B1","C3","H5"]},"村庄与粮仓互相支援；第五回合旁侧浮桥被冲断，拉纳所在的战线必须及时轮换。"),
        ("krasnoi","克拉斯诺耶·后卫",9,(9,5),"s","snow",190,["cossack","ru_line"],"ru_gun",["ru_line","ru_jaeger","opolchenie"],
         {"i":["E1","E3","E5"],"b":["E2","E4"],"^":["B1","C3","H5"],"v":["C2"]},"在结冰的小河旁接住落后的纵队，哥萨克骑兵会绕向最后一面鹰旗。"),
        ("dresden","德累斯顿·雨中的花园",10,(9,5),".","rain",215,["dragoon","whitecoat"],"ru_gun",["whitecoat","ru_line","grenz"],
         {"w":["C1","E1","C5"],"#":["D1","D3","D5"],"^":["B1","C3","H5"],"~":["F3","G3"]},"花园墙割开城郊防线；雨中火枪减弱，炮兵应照顾两侧通道。"),
        ("hanau","哈瑙·金齐希河桥",10,(9,5),"w","clear",220,["chevauleger","whitecoat"],"gun",["whitecoat","grenz","piedmontese"],
         {"~":["E1","E3","E5"],"b":["E2","E4"],"^":["B1","C3","H5"]},"巴伐利亚军封住林间大道；两座桥让后卫与辎重分流，树林能护住炮手。"),
    ]
    for id_, name, lv, size, ground, weather, budget, pair, gun, fillers, scenery, note in elite_specs:
        width,height=size
        gun_cell = label(width - 2, height if height % 2 else height - 1)
        scenery=copy.deepcopy(scenery)
        scenery.setdefault("^",[]).append(gun_cell)
        add(id_,name,"trunk",lv,"elite",size,ground,(2,4),scenery,weather,budget,
            [pair,pair],[(gun_cell,gun)],fillers,note,turns=11)
    out["aspern"]["events"]=[{"turn":5,"cell":"F3","terrain":"river"}]

    # Conquest: complete the five later chapters, including the two 1817 fronts.
    conquest_specs = [
        ("brussels","布鲁塞尔·北门",15,"grand",(10,6),"S",(2,5),"rain",550,
         {"#":["D1","E1","D3","E4"],"B":["B3","F3","G4"],"R":["C3","G1"],"^":["I1","I6"]},
         ["scots_grey","dutch_belgian"],[("I1","british_gun"),("I6","rocket")],["dutch_belgian","redcoat","brunswicker"],"从城门与屋顶两翼接近北方联盟的后卫，街口不能只留一支纵队。"),
        ("rhine_crossing","莱茵之秋·劳特河防线",16,"grand",(10,6),".",(2,5),"fog",590,
         {"~":["E1","E3","E4","E6"],"b":["E2"],"f":["E5"],"+":["B1","D1","B4","D4"],"^":["I1","I6"]},
         ["uhlan","fusilier"],[("I1","pr_gun"),("I6","gun")],["fusilier","landwehr","whitecoat"],"劳特河桥与浅滩各有一股敌军；占住胸墙，让渡船运来的炮队有地方展开。"),
        ("vienna_streets","第三次维也纳·城墙缺口",18,"grand",(11,6),"S",(2,5),"clear",665,
         {"#":["E1","F1","E3","F4","E6"],";": ["E2","E5"],"B":["C3","G3","D6"],"R":["C1","D4"],"^":["J1","J6"]},
         ["dragoon","hungarian"],[("J1","gun"),("J6","rocket")],["whitecoat","grenz","piedmontese"],"从缺口进入帝国旧都，屋顶猎兵与火箭炮会同时威胁街道上的阵列。"),
        ("iberia_return","托雷斯韦德拉什·最后防线",20,"grand",(11,6),".",(2,5),"clear",750,
         {"+":["C1","D1","C3","D4","E4"],"#":["F1","F3","F6"],"w":["D6","E6"],"^":["J1","J6"]},
         ["es_lancer","foot_guards"],[("J1","british_gun"),("J6","rocket")],["es_regular","redcoat","guerrillero"],"山路把阵线分成两层，胸墙能保护炮兵，远处的英国火箭需要优先压制。"),
        ("channel_landing","多佛·白崖下的登陆",20,"grand",(11,6),",",(2,5),"storm",750,
         {"W":["F1","G1","H1","J6","K6"],"p":["E2","E5"],"k":["C2","D2","C5"],"^":["B1","C3","D4","J1"]},
         ["mounted_orderly","marine"],[("J1","coast_gun"),("K6","gunboat")],["marine","redcoat","sailor"],"白崖上的岸炮与海中的炮艇同时开火；沿两座跳板展开，不要把所有部队留在暴露的甲板上。"),
        ("niemen","第二次涅曼河·三座浮桥",22,"grand",(11,6),".",(2,5),"rain",845,
         {"~":["E1","E3","E4","E6"],"b":["E2","E5"],"f":["F3"],"^":["B1","C3","J1","J6"],"+":["B4","D4"]},
         ["cossack","ru_grenadier"],[("J1","ru_gun"),("J6","ru_gun")],["ru_line","ru_jaeger","opolchenie"],"俄军这次守在对岸；两翼浮桥和中央备用渡口必须相互掩护，先压住高地炮位。"),
        ("coalition_final","最后的同盟·欧洲的黄昏",24,"epic",(12,7),".",(2,4,6),"fog",950,
         {"_":["A1","L7"],"v":["D2","E4","D6"],"~":["G1","G3","G5","G7"],"b":["G2","G4","G6"],"^":["B1","C3","D5","K1","K7"],"+":["B5","C5"]},
         ["cuirassier","ru_grenadier"],[("K1","ru_gun"),("K7","rocket")],["ru_line","fusilier","whitecoat"],"三条道路穿过村庄和河桥，俄、普、奥、英各军从不同方向集结。所有旧战区的选择都在这条防线上兑现。"),
    ]
    for id_,name,lv,scale,size,ground,rows,weather,target,scenery,pair,guns,fillers,note in conquest_specs:
        assert all(len(key)==1 for key in scenery)
        add(id_,name,"conquest",lv,scale,size,ground,rows,scenery,weather,target,
            [pair[:] for _ in rows],guns,fillers,note,turns=14)

    # Cristo: turn the original detailed plans into actual traversable boards.
    add("janina_lake","约阿尼纳湖·湖心岛","cristo",15,"elite",(9,5),",",(2,4),
        {"W":["G1","H1","I1","G5","H5","I5"],"k":["B3","C3"],"#":["D1","D3","D5"],"R":["E1"],"^":["B1","C5","F3"]},
        "fog",560,[["mamluk","nizam"],["mamluk","janissary"]],[("F3","ottoman_gun"),("I5","gunboat")],["nizam","bedouin","arnaut"],
        "把总督的妻女与行李送上B3码头的小船；湖上的炮艇和修道院来的枪手夹击两条岸路。",turns=12,
        order={"type":"extract","cell":"B3","turns":3,"desc":"在B3码头累计守住3回合，掩护湖心岛的撤离。"})
    add("tiboulen_swim","蒂布朗岛·暴风雨的黎明","cristo",17,"elite",(9,5),",",(2,4),
        {"W":["E1","F1","G1","H1","I1","E5","F5","G5","H5","I5"],"d":["A3","B2","B3","C3"],"p":["D3","E3","F3"],"^":["B1","C5"],"t":["A1"]},
        "storm",650,[["mounted_gendarme","customs"],["mounted_gendarme","gendarme"]],[("I1","revenue_cutter"),("I5","gunboat")],["customs","gendarme","smuggler"],
        "唐泰斯从H3礁岛出发，经G3—C3的浅滩与跳板逃向少年阿梅莉号；暴风雨中桅盘上的单位会受伤。",turns=12,
        order={"type":"escape","unit":"dantes","start_cell":"H3","cells":["B2","B3"],"turn":12,"desc":"让唐泰斯从H3礁岛撤到B2或B3甲板，守到第12回合。"})
    add("monte_cristo_cave","基督山岛·斯帕达的洞","cristo",18,"grand",(10,6),",",(2,5),
        {"_":["A1","J6"],"c":["B3","C3","D3","B4","C4","D4"],"^":["B1","E1","I1"],"W":["G6","H6","I6"],"p":["F2","F5"],";":["E2","E5"]},
        "clear",710,[["pirate_captain","smuggler"],["pirate_captain","pirate"]],[("I1","coast_gun"),("I6","gunboat")],["smuggler","pirate","customs"],
        "守住藏宝洞内侧与两个登岸跳板，在C3洞口搬出宝箱；洞穴遮蔽炮火，但走私帮会从岩顶小路接近。",turns=14,
        order={"type":"extract","cell":"C3","turns":4,"gold_after":4,"gold_each":1,"desc":"C3洞口累计驻守4回合；此后继续搬运，每回合带出1金币。"})
    add("appian_way","亚壁古道·柏树下的伏兵","cristo",20,"elite",(10,5),"w",(2,4),
        {"K":["F1","F3","F5"],"B":["C1","D3","C5"],"_":["A1","J5"],"^":["B3","I1"]},
        "night",740,[["papal_dragoon","bandit"],["papal_dragoon","papal_carabinier"]],[],["bandit","papal_carabinier","sbirro"],
        "伯爵的马车穿过柏树林与陵墓，伏兵从墓穴入口接近；夜间射程缩短，近身掩护不能缺席。",turns=12)
    t=add("san_sebastiano","圣塞巴斯蒂安·万帕的墓窟","cristo",21,"grand",(11,6),"C",(2,5),
        {"#":["D1","E1","G1","D4","G4","H4","D6","G6"],"_":["A1","K6"],"K":["H1","I3","H6"],"B":["B1","C4","E6"],"^":["F3","J1"]},
        "night",830,[["papal_dragoon","bandit"],["papal_dragoon","assassin"]],[],["bandit","sbirro","convict"],
        "在F3圆厅找到阿尔贝，再护送他沿E3—A3的石廊撤出。不要把部队站满护送通道。",turns=14,
        order={"type":"extract","cell":"F3","turns":2,"escape":{"npc":{"id":"albert_rescue","name":"阿尔贝","hp":13,"cell":"E3"},"path":["E3","D3","C3","B3","A3"]},"desc":"F3搜救2回合后，护送阿尔贝沿中央石廊走到A3出口。"})
    add("auteuil_garden","奥特伊·花园里的木匣","cristo",22,"elite",(10,5),"w",(2,4),
        {"#":["D1","F1","D5","F5"],"B":["C1","C5"],";":["E3"],"S":["G1","H1","I1"],"^":["B3","I5"]},
        "night",860,[["benedetto","convict"],["mounted_gendarme","police_agent"]],[],["convict","police_agent","thug"],
        "贝内代托与便衣各有目的；守住E3梧桐树下的木匣，别让夜色里的同伙先挖到证据。",turns=12,
        order={"type":"hold","cell":"E3","turn":12,"desc":"第12回合结束时守住E3树下的木匣。"})
    add("paris_rooftops","西岱岛·雨中的屋顶","cristo",23,"elite",(10,5),"S",(2,4),
        {"R":["B1","C1","D1","E1","F1","G1"],"B":["B3","C3","F3"],"_":["D3","E3","G3","H3"],"#":["H1"],"^":["I5"]},
        "rain",900,[["mounted_gendarme","municipal_guard"],["mounted_gendarme","assassin"]],[],["assassin","police_agent","national_guard"],
        "刺客从屋顶和下方小巷分别接近附属监狱；猎兵能跨屋顶支援，中央断口不可穿过。",turns=12)
    add("cristo_final","司法宫之夜·证人的牢房","cristo",24,"epic",(12,7),"S",(2,4,6),
        {"_":["A1","L7"],"C":["B3","C3","D3","C5","D5"],"L":["B4"],"D":["J3","J5"],"#":["E1","E3","F5"],"~":["G1","G3","G5","G7"],"b":["G2","G4","G6"],"R":["C1","D7"],"B":["D1","E7"],"^":["K1","K7"]},
        "night",960,[["mounted_gendarme","convict"],["mounted_gendarme","police_agent"],["mounted_gendarme","assassin"]],[],["national_guard","convict","police_agent"],
        "苦役场同伙、检察署便衣与屋顶刺客同时逼近司法宫。守住B4牢房，让证人贝内代托活到天亮。",turns=14,
        order={"type":"protect","npc":{"id":"benedetto_witness","name":"贝内代托（证人）","hp":12,"cell":"B4","place":"cell"},"desc":"保护B4牢房中的证人直到战斗结束，敌军踏入牢房即告失败。"},
        extra_routes={"approach_2":lane(12,4,2)+["C3","B3","A3"]})

    # Five authored regional replacements for the generic Austrian skirmishes.
    encounters=[
        ("skirmish_desert_well","沙漠井·运水纵队",3,"a","desert",90,["mamluk","nizam"],["nizam","bedouin","whitecoat"],{"o":["C2","C4"],"n":["B1","D3","E3"],"^":["F1"]},"守住两口井，提防绕行沙丘的骑兵。"),
        ("skirmish_sierra_village","山村·两条小巷",7,"S","clear",155,["es_lancer","es_regular"],["es_regular","guerrillero","bandolero"],{"B":["C1","E1","D3"],"R":["B3"],"^":["F1"]},"山村两条小巷都通向粮车，房屋能保护守军。"),
        ("skirmish_snow_village","雪村·落后的辎重",8,"s","snow",170,["cossack","ru_line"],["ru_line","ru_jaeger","opolchenie"],{"v":["C2","C4"],"i":["D1","D3"],"^":["F1"]},"道路上的积雪已被清开，沿村庄轮换后卫。"),
        ("skirmish_rhine_ferry","莱茵渡口·夜间摆渡",14,".","fog",420,["uhlan","fusilier"],["fusilier","landwehr","whitecoat"],{"~":["D1","D3"],"b":["D2"],"f":["D4"],"^":["B1","F1"]},"渡桥与浅滩同时受压，雾里不要漏看第二条路。"),
        ("skirmish_danube_mill","多瑙河磨坊·磨盘与渡桥",14,".","rain",430,["dragoon","whitecoat"],["whitecoat","grenz","piedmontese"],{"B":["C1","C3"],"~":["D1","D3"],"b":["D2","D4"],"^":["F1"]},"磨坊挡住视线，两座渡桥仍须各留一支队伍。"),
    ]
    for id_,name,lv,ground,weather,budget,pair,fillers,scenery,note in encounters:
        t=add(id_,name,"trunk" if lv<12 else "conquest",lv,"skirmish",(7,4),ground,(2,4),scenery,weather,budget,[pair,pair],[],fillers,note,turns=10)
        t["base_level"]=t.pop("level")
        t["pad"]={"every":3,"kind":fillers[0]}

    # Every authored field offers friendly gun positions as well as hostile gun
    # platforms.  Rooftops alone are not usable by artillery (jager-only terrain).
    for template in out.values():
        width,height=template["size"]
        grid=[list(row) for row in template["map"]]
        occupied={cell for route in template["routes"].values() for cell in route}
        occupied.update(w["at"] for w in template["waves"] if "at" in w)
        order=template.get("order_next",template["order"])
        occupied.update(order.get("cells",[]))
        occupied.update(order.get("escape",{}).get("path",[]))
        occupied.update([order.get("cell",""),order.get("start_cell",""),order.get("npc",{}).get("cell","")])
        sites=[label(x,y+1) for y in range(height) for x in range(width//2+1)
               if grid[y][x] in ["^","+"] and label(x,y+1) not in occupied]
        candidates=[(width//2,2),(width//2-1,height-2),(2,2),(1,0),(1,height-1),(3,0)]
        for x,y in candidates:
            if len(sites)>=3:break
            if y>=height or x>=width:continue
            cell=label(x,y+1)
            if cell in occupied or cell in sites or grid[y][x] not in [".","S","C","a","s","u",",","w","v"]:continue
            grid[y][x]="^";sites.append(cell)
        template["map"]=["".join(row) for row in grid]
        assert all(len(row)==template["size"][0] for row in template["map"])
    return out


if __name__ == "__main__":
    print(json.dumps(build_templates(),ensure_ascii=False,indent=2))
