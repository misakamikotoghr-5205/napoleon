"""Town + pawnshop maps. Tile ids match build_all.py's atlas layout.

Run from repo root: python3 tools/art/town/gen_maps.py
"""
import json
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
MAP_DIR = os.path.join(ROOT, "data", "town", "maps")
BLD = os.path.join(ROOT, "art", "town", "buildings")
MANIFEST = os.path.join(ROOT, "art", "town", "manifest.json")
TILE = 16
# door.building (schedule / shop id) -> building object id in the manifest
DOOR_BUILDING = {"market": "market_stall", "dock": "dock_shed"}

W, H = 60, 34
# North street occupies y=12..15. Building sprites sit with their bottom tile on y=11.
STREET_Y0, STREET_Y1 = 12, 15
FRONT_Y = 11  # last tile row of north facades


def rows_of(grid):
    return [" ".join(r) for r in grid]


def fill(grid, x, y, w, h, tid):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if 0 <= xx < len(grid[0]) and 0 <= yy < len(grid):
                grid[yy][xx] = tid


def load_manifest():
    with open(MANIFEST, encoding="utf-8") as f:
        return json.load(f)


def door_tile(manifest, building_id, obj_at):
    """Tile where the door of a placed building sprite is drawn.

    manifest.buildings.<id>.door is [x, y, w, h] in sprite pixels. The door tile is the
    column under the door's centre and the row holding the door's bottom edge.
    """
    spec = manifest["buildings"][building_id]
    dx, dy, dw, dh = spec["door"]
    cx = obj_at[0] * TILE + dx + dw / 2.0
    bottom = obj_at[1] * TILE + dy + dh - 1
    return [int(cx // TILE), int(bottom // TILE)]


def tile_span(png):
    im = Image.open(png)
    return (im.width + 15) // 16, (im.height + 15) // 16


def build_town():
    g = [["grass_0" for _ in range(W)] for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if (x + y) % 5 == 0:
                g[y][x] = "grass_1"
            elif (x * 3 + y) % 7 == 0:
                g[y][x] = "grass_2"
    # dirt yards under the north facades
    fill(g, 0, 5, W, 7, "dirt_0")
    for y in range(5, 12):
        for x in range(W):
            if (x + y) % 4 == 0:
                g[y][x] = "dirt_1"
    # bridge-head street, full width so 镇外 is reachable without crossing water
    for y in range(STREET_Y0, STREET_Y1 + 1):
        for x in range(W):
            g[y][x] = ["road_0", "road_1", "road_2", "road_4", "road_5"][(x + y) % 5]
            if (x * 5 + y) % 17 == 0:
                g[y][x] = "road_3"
    # canal
    fill(g, 0, 16, W, 1, "bank_n")
    for y in range(17, 23):
        for x in range(W):
            g[y][x] = "water_0" if (x + y) % 2 == 0 else "water_1"
    fill(g, 0, 23, W, 1, "bank_s")
    # stone arch bridge, 3 tiles wide, connects the two banks
    for y in range(16, 24):
        for x in (28, 29, 30):
            g[y][x] = "bridge_deck"
    g[16][28] = "bridge_rail"
    g[16][30] = "bridge_rail"
    g[23][28] = "bridge_rail"
    g[23][30] = "bridge_rail"
    # south bank street and market ground
    for y in range(24, 28):
        for x in range(W):
            g[y][x] = "dirt_0" if (x + y) % 3 else "dirt_1"
            if 8 <= x <= 52 and y in (25, 26):
                g[y][x] = "road_1" if x % 2 == 0 else "road_2"
    # dock steps into the canal's south edge
    fill(g, 4, 27, 10, 3, "dock_0")
    for y in range(27, 30):
        for x in range(4, 14):
            if (x + y) % 2:
                g[y][x] = "dock_1"
    # east gate stays on the north street (already road)

    north = [
        # id, door_x, png
        ("pawnshop", 8, "pawnshop.png"),
        ("teahouse", 16, "teahouse.png"),
        ("ricehall", 24, "ricehall.png"),
        ("pharmacy", 32, "pharmacy.png"),
        ("baogong", 40, "baogong.png"),
        ("post", 48, "post.png"),
        ("sunfu", 55, "sunfu.png"),
    ]
    objects = []
    for bid, door_x, png in north:
        path = os.path.join(BLD, png)
        tw, th = tile_span(path) if os.path.exists(path) else (6, 6)
        at_x = max(0, min(W - tw, door_x - tw // 2))
        at_y = max(0, FRONT_Y - th + 1)
        objects.append({"kind": "building", "id": bid, "at": [at_x, at_y]})

    south = [
        ("market_stall", 20, 27, "market_stall.png"),
        ("police", 44, 27, "police_locked.png"),
        ("dock_shed", 6, 30, "dock_shed.png"),
    ]
    for bid, door_x, bottom_y, png in south:
        path = os.path.join(BLD, png)
        tw, th = tile_span(path) if os.path.exists(path) else (4, 3)
        at_x = max(0, min(W - tw, door_x - max(tw // 2, 1)))
        at_y = max(0, min(H - th, bottom_y - th + 1))
        objects.append({"kind": "building", "id": bid if bid != "police" else "police", "at": [at_x, at_y]})

    props = [
        ("willow", 3, 14),
        ("willow", 26, 14),
        ("lantern_post", 12, 15),
        ("lantern_post", 36, 15),
        ("lantern_post", 50, 15),
        ("notice_wall", 11, 14),
        ("laundry", 21, 10),
        ("rice_sacks", 22, 14),
        ("barrel", 33, 15),
        ("bench", 18, 15),
        ("bench", 42, 26),
        ("boat", 18, 20),
        ("cat", 9, 15),
        ("chicken", 52, 26),
        ("duck", 16, 21),
        ("cat_sleep", 57, 14),
    ]
    for pid, x, y in props:
        objects.append({"kind": "prop", "id": pid, "at": [x, y]})

    # Door tiles come from the art: building object `at` + manifest door rect, so the
    # door in the data is where the door is drawn (the sprite's door is not centred).
    manifest = load_manifest()
    placed = {o["id"]: o["at"] for o in objects if o["kind"] == "building"}
    door_rows = [
        ("pawnshop", {"to_map": "pawnshop", "to_spawn": "front_door"}),
        ("teahouse", {"closeup": "teahouse"}),
        ("ricehall", {"closeup": "ricehall"}),
        ("pharmacy", {"closeup": "pharmacy"}),
        ("baogong", {"closeup": "baogong"}),
        ("post", {"closeup": "post"}),
        ("market", {"closeup": "market"}),
        ("sunfu", {"locked": True}),
        ("police", {"locked": True}),
        ("dock", {"locked": True}),
    ]
    doors = []
    for bid, extra in door_rows:
        obj_id = DOOR_BUILDING.get(bid, bid)
        row = {"building": bid, "at": door_tile(manifest, obj_id, placed[obj_id])}
        row.update(extra)
        doors.append(row)
    pawn_door = doors[0]["at"]
    # Standing just outside the pawnshop door: the tile right below the door tile.
    from_pawnshop = [pawn_door[0], pawn_door[1] + 1]
    _check_town_doors(g, doors, from_pawnshop)
    nodes = {
        "p_door": [8, 12],
        "p_home": [4, 13],
        "street_w": [8, 14],
        "street_tea": [16, 13],
        "street_rice": [24, 13],
        "street_pharm": [32, 13],
        "street_bao": [40, 13],
        "street_post": [48, 13],
        "street_sun": [55, 13],
        "street_e": [58, 14],
        "bridge_n": [29, 15],
        "bridge_s": [29, 24],
        "market": [20, 26],
        "dock": [8, 28],
        "police": [44, 26],
    }
    chain = ["p_home", "p_door", "street_w", "street_tea", "street_rice", "street_pharm",
             "street_bao", "street_post", "street_sun", "street_e"]
    edges = [[chain[i], chain[i + 1]] for i in range(len(chain) - 1)]
    edges += [["street_rice", "bridge_n"], ["bridge_n", "bridge_s"],
              ["bridge_s", "market"], ["bridge_s", "dock"], ["market", "police"],
              ["street_w", "bridge_n"]]
    return {
        "id": "town",
        "size": [W, H],
        "tile": 16,
        "tileset": "town",
        "layers": {"ground": rows_of(g), "deco": [" ".join(["."] * W) for _ in range(H)]},
        "objects": objects,
        "doors": doors,
        "spawns": {"wake": [8, 14], "from_pawnshop": from_pawnshop, "edge_east": [58, 14], "dock": [8, 28]},
        "waypoints": {"nodes": nodes, "edges": edges},
        "places": {
            "德厚当": ["p_door"],
            "桥头街": ["street_w", "street_tea", "street_rice"],
            "茶馆": ["street_tea"],
            "米行": ["street_rice"],
            "济生堂": ["street_pharm"],
            "保公所": ["street_bao"],
            "邮电局": ["street_post"],
            "码头": ["dock"],
            "孙府": ["street_sun"],
            "集市": ["market"],
            "镇外": ["street_e"],
            "家": ["p_home"],
        },
        "hints": [{"at": [11, 13], "text": "告示墙", "once": True}],
    }


def _check_town_doors(g, doors, from_pawnshop):
    for d in doors:
        x, y = d["at"]
        assert _walk_tile(g[y][x]), ("door tile is not walkable ground", d, g[y][x])
    fx, fy = from_pawnshop
    assert _walk_tile(g[fy][fx]), ("from_pawnshop is not walkable", from_pawnshop, g[fy][fx])


def build_pawnshop():
    """20×12 room after mockup A2.

    y 0–2  back wall, three tiles tall (cap / plaster / wainscot)
    y 3     shelf plinth and storeroom
    y 4     staff floor; counter_spot in the middle
    y 5     high counter, one gate tile
    y 6–10  customer floor, benches, three waiting spots
    y 11    front wall and the street door
    """
    IW, IH = 20, 12
    g = [["floor_0" for _ in range(IW)] for _ in range(IH)]
    for y in range(IH):
        g[y][0] = "wall_wood"
        g[y][IW - 1] = "wall_wood"
    for x in range(IW):
        g[0][x] = "wall_2"
        g[1][x] = "wall_0"
        g[2][x] = "wall_1"
        g[IH - 1][x] = "wall_1"
    # quiet floors: dark staff platform, one worn path, no speckle
    fill(g, 1, 3, IW - 2, 1, "block_0")
    fill(g, 1, 4, IW - 2, 1, "floor_2")
    fill(g, 1, 5, IW - 2, 1, "counter_face")
    fill(g, 1, 6, IW - 2, 5, "floor_0")
    for y in range(6, 11):
        g[y][9] = "floor_1"
        g[y][10] = "floor_1"
    # left bay stays staff floor behind the bed; the counter starts at x=3
    g[3][1] = "floor_2"
    g[3][2] = "floor_2"
    g[5][1] = "block_0"
    g[5][2] = "block_0"
    g[5][15] = "floor_2"  # 腰门
    # east passage beside the storeroom, closed at the counter line
    g[3][18] = "floor_2"
    g[5][18] = "block_0"
    # street door and the back door
    g[IH - 1][9] = "floor_1"
    g[IH - 1][10] = "floor_1"
    g[4][IW - 1] = "floor_2"
    objects = [
        {"kind": "prop", "id": "calendar", "at": [2, 2]},
        {"kind": "prop", "id": "shelf", "at": [3, 3]},
        {"kind": "prop", "id": "storeroom_door", "at": [16, 3]},
        {"kind": "prop", "id": "stairs", "at": [1, 3]},
        {"kind": "prop", "id": "bed", "at": [1, 4]},
        {"kind": "prop", "id": "trunk", "at": [2, 5]},
        {"kind": "prop", "id": "counter", "at": [3, 6]},
        {"kind": "prop", "id": "counter_mid", "at": [7, 6]},
        {"kind": "prop", "id": "counter_lamp", "at": [11, 6]},
        {"kind": "prop", "id": "counter_gate", "at": [15, 6]},
        {"kind": "prop", "id": "pawn_bench", "at": [3, 8]},
        {"kind": "prop", "id": "pawn_bench", "at": [11, 8]},
        {"kind": "prop", "id": "clothes_rack", "at": [17, 8]},
        {"kind": "prop", "id": "plant", "at": [1, 9]},
        {"kind": "prop", "id": "broom", "at": [18, 9]},
        {"kind": "prop", "id": "back_door", "at": [19, 4]},
    ]
    # Customers wait on row 9: the counter sprites (props at y=6, 44px tall) end at pixel 140
    # (inside tile row 8), so row 9 is the first floor row fully in front of the counter.
    # Every edge below runs along walkable floor only (a straight line between node
    # centres): the customer side is joined to the staff side through the waist gate at
    # (15, 5) by walking down column 15, never diagonally across the counter.
    nodes = {
        "counter": [10, 4],
        "customers": [10, 9],
        "gate_front": [15, 9],
        "gate": [15, 5],
        "gate_in": [15, 4],
        "bed": [3, 4],
        "back": [18, 4],
        "exit": [10, 10],
        "lamp": [12, 4],
        "telegraph": [17, 4],
    }
    edges = [
        ["exit", "customers"],
        ["customers", "gate_front"],
        ["gate_front", "gate"],
        ["gate", "gate_in"],
        ["gate_in", "counter"],
        ["counter", "bed"],
        ["counter", "lamp"],
        ["counter", "back"],
        ["back", "telegraph"],
    ]
    shop = {
        "id": "pawnshop",
        "size": [IW, IH],
        "tile": 16,
        "tileset": "interior",
        "layers": {"ground": rows_of(g), "deco": [" ".join(["."] * IW) for _ in range(IH)]},
        "objects": objects,
        "doors": [{"building": "town", "at": [10, 11], "to_map": "town", "to_spawn": "from_pawnshop"}],
        "spawns": {"wake": [10, 4], "front_door": [10, 10]},
        "waypoints": {"nodes": nodes, "edges": edges},
        "places": {"柜台": ["counter"], "床": ["bed"], "后门": ["back"]},
        "counter_spot": [10, 4],
        "customer_spot": [[6, 9], [10, 9], [14, 9]],
        "shelf": [4, 4, 12, 1],
        "bed": [3, 4],
        "backdoor": [19, 4],
        "lamp": [12, 4],
        "telegraph": [17, 4],
        "exit": [10, 11],
        # 交互点（像素）：stand = 主角站在哪里算“在它旁边”（脚点），radius = 多远以内出提示，anchor = 提示指向的物件位置。
        # 数字都取自贴图：蜡烛在 counter_lamp 的 x≈190，电报箱（带铜键）在 counter_gate 右半的 x≈275、柜面 y≈100，
        # 床靠左墙 x 17–47（床体不可走，所以站在它右边），后门在最右一格墙里（门洞不可走，站在它左边）。
        # 货架是一整面墙：只给矩形，优先级最低（站在别的物件旁边时让位）。
        "interact": {
            "counter": {"stand": [168, 72], "radius": 18, "anchor": [168, 100]},
            "bed": {"stand": [58, 72], "radius": 14, "anchor": [32, 78]},
            "lamp": {"stand": [191, 72], "radius": 9, "anchor": [191, 96]},
            "telegraph": {"stand": [275, 72], "radius": 12, "anchor": [275, 98]},
            "backdoor": {"stand": [297, 72], "radius": 9, "anchor": [312, 90]},
            "shelf": {"rect": [64, 64, 192, 16], "anchor": [160, 60]},
        },
        "hints": [{"at": [10, 6], "text": "柜台", "once": True}],
    }
    _check_pawnshop(shop)
    return shop


def _walk_tile(tid):
    return not (tid.startswith("wall") or tid.startswith("counter") or tid.startswith("block"))


def _check_pawnshop(shop):
    ground = [row.split(" ") for row in shop["layers"]["ground"]]
    h, w = len(ground), len(ground[0])
    assert (w, h) == (20, 12), (w, h)
    for y in range(3):
        for x in range(w):
            assert ground[y][x].startswith("wall"), (x, y, ground[y][x])
    row = ground[5]
    assert all(row[x] == "counter_face" for x in list(range(3, 15)) + [16, 17]), row
    assert row[15] == "floor_2"
    sx, sy = shop["spawns"]["wake"]
    from collections import deque
    q = deque([(sx, sy)])
    seen = set()
    while q:
        x, y = q.popleft()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h) or not _walk_tile(ground[y][x]):
            continue
        seen.add((x, y))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q.append((x + dx, y + dy))
    goals = [shop["doors"][0]["at"], shop["counter_spot"], shop["bed"], shop["backdoor"], shop["exit"]]
    goals += shop["customer_spot"]
    goals += [shop["waypoints"]["nodes"]["telegraph"], shop["waypoints"]["nodes"]["lamp"]]
    for goal in goals:
        assert tuple(goal) in seen, goal
    assert shop["counter_spot"][1] < min(s[1] for s in shop["customer_spot"])
    assert shop["shelf"][2] >= 8
    _check_edges(ground, shop["waypoints"])
    _check_spots_in_front(shop)
    _check_collision(shop)


def _check_edges(ground, wp):
    """Every waypoint edge, drawn as a straight line between tile centres, stays on walkable tiles."""
    nodes = wp["nodes"]
    for a, b in wp["edges"]:
        (ax, ay), (bx, by) = nodes[a], nodes[b]
        steps = max(1, int(max(abs(bx - ax), abs(by - ay)) * 20))
        for i in range(steps + 1):
            t = i / steps
            x = ax + 0.5 + (bx - ax) * t
            y = ay + 0.5 + (by - ay) * t
            tid = ground[int(y)][int(x)]
            assert _walk_tile(tid), ("edge crosses blocked tile", a, b, (int(x), int(y)), tid)


def _blockers(shop):
    """Same rectangles the frontend builds: non-walkable tiles (merged per row) + every prop's manifest footprint."""
    manifest = load_manifest()
    ground = [row.split(" ") for row in shop["layers"]["ground"]]
    out = []
    for y, row in enumerate(ground):
        for x, tid in enumerate(row):
            if not _walk_tile(tid):
                out.append((x * TILE, y * TILE, TILE, TILE))
    for o in shop["objects"]:
        spec = manifest["props"][o["id"]]
        fp = spec.get("footprint")
        if fp:
            out.append((o["at"][0] * TILE + fp[0], o["at"][1] * TILE + fp[1], fp[2], fp[3]))
    return out


def _foot_free(blockers, fx, fy):
    """Player foot box is 10×6 with its bottom-centre at (fx, fy)."""
    l, t, r, b = fx - 5.0, fy - 6.0, fx + 5.0, fy
    for (bx, by, bw, bh) in blockers:
        if l < bx + bw and r > bx and t < by + bh and b > by:
            return False
    return True


def _check_collision(shop):
    """Counter, benches, bed… are solid; the waist gate is the only way across; every use-point can be reached on foot."""
    blockers = _blockers(shop)
    # the counter band (art y 100–140) is solid for the whole counter run except the one-tile gate lane
    gate_x0, gate_x1 = 15 * TILE, 16 * TILE
    for fx in range(48 + 5, 288 - 5):
        for fy in range(106, 140, 2):
            inside_lane = gate_x0 + 5 <= fx <= gate_x1 - 5
            free = _foot_free(blockers, fx, fy)
            assert free == inside_lane, ("counter band must be solid except the gate lane", fx, fy, free)
    # gate lane is walkable all the way from the customer floor to the staff row
    for fy in range(80, 148, 2):
        assert _foot_free(blockers, 15 * TILE + 8, fy), ("gate lane blocked", fy)
    # use-points and waiting spots are standable
    points = {"counter_spot": shop["counter_spot"], "wake": shop["spawns"]["wake"], "front_door": shop["spawns"]["front_door"]}
    pts = {k: (v[0] * TILE + TILE / 2.0, v[1] * TILE + TILE / 2.0) for k, v in points.items()}
    for i, v in enumerate(shop["customer_spot"]):
        pts["customer_spot[%d]" % i] = (v[0] * TILE + TILE / 2.0, v[1] * TILE + TILE / 2.0)
    for key, spec in shop["interact"].items():
        if "stand" in spec:
            pts["interact." + key] = tuple(spec["stand"])
    for key, (fx, fy) in pts.items():
        assert _foot_free(blockers, fx, fy), ("use-point stands inside furniture", key, fx, fy)
    # flood fill on a 2 px grid from the wake spot: everything above must be reachable
    start = pts["wake"]
    seen = set()
    stack = [(int(start[0]), int(start[1]))]
    W, H = shop["size"][0] * TILE, shop["size"][1] * TILE
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < W and 0 <= y < H) or not _foot_free(blockers, x, y):
            continue
        seen.add((x, y))
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            stack.append((x + dx, y + dy))
    for key, (fx, fy) in pts.items():
        assert (int(fx) // 2 * 2, int(fy) // 2 * 2) in seen or (int(fx), int(fy)) in seen, ("not reachable on foot", key, fx, fy)
    ex = shop["doors"][0]["at"]
    assert (ex[0] * TILE + 8, ex[1] * TILE + 8) in seen or (ex[0] * TILE + 8, ex[1] * TILE + 8 - 2) in seen, "street door not reachable on foot"


def _check_spots_in_front(shop):
    """Standing spots are in front of every prop sprite they overlap (foot line below the prop's foot).

    The frontend y-sorts props by their foot line (position + manifest anchor). A wall unit whose
    foot sits below the staff row (the shelf used to end at y=96) would be drawn over whoever
    stands at the counter, so wall furniture anchors sit on the back-wall base line instead.
    """
    manifest = load_manifest()
    props = manifest["props"]
    nodes = shop["waypoints"]["nodes"]
    standing = {"counter_spot": [shop["counter_spot"]], "customer_spot": shop["customer_spot"],
                "wake": [shop["spawns"]["wake"]], "front_door": [shop["spawns"]["front_door"]],
                "lamp": [shop["lamp"]], "telegraph": [shop["telegraph"]], "gate_in": [nodes["gate_in"]]}
    for key, spots in standing.items():
        for sx, sy in spots:
            foot_x, foot_y = sx * TILE + TILE / 2.0, sy * TILE + TILE / 2.0
            body = (foot_x - 6, foot_y - 28, foot_x + 6, foot_y)
            for o in shop["objects"]:
                if o["kind"] != "prop":
                    continue
                spec = props[o["id"]]
                w, h = Image.open(os.path.join(ROOT, spec["image"])).size
                px, py = o["at"][0] * TILE, o["at"][1] * TILE
                overlap = body[0] < px + w and body[2] > px and body[1] < py + h and body[3] > py
                prop_foot = py + spec["anchor"][1]
                assert not overlap or prop_foot < foot_y, (key, [sx, sy], "is behind prop", o["id"], prop_foot, foot_y)


def main():
    os.makedirs(MAP_DIR, exist_ok=True)
    town = build_town()
    shop = build_pawnshop()
    for name, data in (("town.json", town), ("pawnshop.json", shop)):
        path = os.path.join(MAP_DIR, name)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print("wrote", path)
    # sanity: every door is on a non-empty ground id
    for data in (town, shop):
        ground = [r.split(" ") for r in data["layers"]["ground"]]
        for d in data["doors"]:
            x, y = d["at"]
            assert ground[y][x] != ".", (data["id"], d, ground[y][x])
        sx, sy = data["spawns"]["wake"]
        assert ground[sy][sx] not in (".",)
    print("MAPS_OK")


if __name__ == "__main__":
    main()
