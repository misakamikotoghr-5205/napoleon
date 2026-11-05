"""Normalize the authored campaign maps; retain node IDs, geography and routes.

The draft maps are source data. Runtime maps use the final WORLD_MAP_DESIGN
contract, including integer camera centers and explicit recruitment actions.
"""
from __future__ import annotations

import copy
import json
import math
import heapq
from pathlib import Path

SOURCES = {
    "trunk": ("conquest/data/campaigns/napoleon/maps/europe.json", "europe"),
    "conquest": ("conquest/data/campaigns/napoleon/maps/europe_late.json", "europe_late"),
    "ocean": ("ocean/maps/world.json", "world"),
    "cristo": ("cristo/data/campaigns/napoleon/maps/med.json", "med"),
}
SECOND_THEATRES = {"t_alps", "t_prussia", "t_danube"}
SHOP_RECRUITS = {("trunk", "salheyeh"): ["rustam"],
                 ("trunk", "milan_1800"): ["desaix"],
                 ("cristo", "palais_royal_shop"): ["maximilien"]}


def _read(path: Path) -> dict:
    return json.loads(path.read_text())


def _project(geo: list[int], view: dict) -> list[float]:
    lon, lat = (geo[0] / 100, max(-89, min(89, geo[1] / 100)))
    scale = view["scale"]
    y = math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))
    if view["projection"] == "miller":
        y = 1.25 * math.log(math.tan(math.pi / 4 + 0.4 * math.radians(lat)))
    return [scale * (math.radians(lon) - math.radians(view["lon_min"])), scale * (view["y_top"] - y)]


def _volume_condition(cond: dict) -> dict:
    out = copy.deepcopy(cond)
    if SECOND_THEATRES.intersection(out.get("flags", [])):
        out["volume"] = 2
    return out


def _normalize_tree(value):
    if isinstance(value, list):
        return [_normalize_tree(v) for v in value]
    if not isinstance(value, dict):
        return value
    out = {k: _normalize_tree(v) for k, v in value.items()}
    if isinstance(out.get("weather"), str):
        out["weather"] = [out["weather"]]
    if "requires" in out:
        out["requires"] = _volume_condition(out["requires"])
    return out


def _spread_markers(sheet: dict, view: dict, geo_view: dict) -> None:
    """Separate cartographic markers while retaining their authored geo anchors.

    Dense towns contain several transactions at one real place. Their marker
    coordinates are displaced just as draft ``offset`` coordinates were; the
    geographic location remains available for a later art pass.
    """
    nodes = sheet["nodes"]
    points = []
    for node in nodes:
        point = node.get("xy") or _project(node["geo"], geo_view)
        off = node.get("offset", [0, 0])
        points.append([float(point[0] + off[0]), float(point[1] + off[1])])
    minimum = 146 if view.get("proj") == "canvas" else 155
    # Deterministic local repulsion. The soft spring keeps the map geographic.
    for _ in range(600):
        max_push = 0.0
        for i in range(len(points)):
            for j in range(i + 1, len(points)):
                dx, dy = points[j][0] - points[i][0], points[j][1] - points[i][1]
                distance = math.hypot(dx, dy)
                if distance >= minimum:
                    continue
                if distance < 0.01:
                    angle = (i * 17 + j * 31) * 2.399963
                    dx, dy, distance = math.cos(angle), math.sin(angle), 1.0
                push = (minimum - distance) * 0.51
                max_push = max(max_push, push)
                ux, uy = dx / distance * push, dy / distance * push
                points[i][0] -= ux
                points[i][1] -= uy
                points[j][0] += ux
                points[j][1] += uy
        if max_push < 0.1:
            break
    for i, node in enumerate(nodes):
        point = [round(points[i][0]), round(points[i][1])]
        if "xy" in node and node["xy"] != point:
            node["_draft_xy"] = node["xy"]
        node["xy"] = point
        node.pop("offset", None)
        # Draft frame-local xy used a different projection and is superseded by
        # the normalized marker positions shared by renderer and validator.
        if "xy_frames" in node:
            node["_draft_xy_frames"] = node.pop("xy_frames")
    sheet["_marker_layout"] = "Authored geo retained; transaction markers separated for readable selection."


def _frames(sheet: dict, view: dict, geo_view: dict) -> None:
    frames = sheet.get("frames", [])
    if not frames:
        return
    converted = []
    for source in frames:
        frame = {"id": source["id"], "when": _volume_condition(source.get("when", {})), "zoom": 100}
        if view.get("proj") == "canvas":
            points = [n["xy"] for n in sheet["nodes"]]
            frame["center"] = [round((min(p[k] for p in points) + max(p[k] for p in points)) / 2) for k in (0, 1)]
        elif "lon" in source and "lat" in source:
            frame["center"] = [round(sum(source["lon"]) / 2), round(sum(source["lat"]) / 2)]
            frame["_draft_bounds"] = {"lon": source["lon"], "lat": source["lat"]}
        else:
            points = [n["geo"] for n in sheet["nodes"] if "geo" in n]
            frame["center"] = [round((min(p[k] for p in points) + max(p[k] for p in points)) / 2) for k in (0, 1)]
        converted.append(frame)
    sheet["frames"] = converted


def _path(sheet: dict, start: str, end: str) -> tuple[int, list[str]]:
    graph = {}
    for link in sheet["links"]:
        cost = link.get("voyage_days", 0) * 3 or link.get("legs", 1)
        graph.setdefault(link["a"], []).append((link["b"], cost))
        if not link.get("oneway", False):
            graph.setdefault(link["b"], []).append((link["a"], cost))
    todo = [(0, start, [start])]
    done = set()
    while todo:
        cost, node, path = heapq.heappop(todo)
        if node == end:
            return cost, path
        if node in done:
            continue
        done.add(node)
        for dest, extra in graph.get(node, []):
            if dest not in done:
                heapq.heappush(todo, (cost + extra, dest, path + [dest]))
    return -1, []


def _patrols(sheet: dict) -> None:
    # The authors listed patrol stops, not every intermediate road junction.
    # Expand each leg through existing roads, without adding bypass shortcuts.
    for rival in sheet.get("rivals", []):
        stops = rival.get("path", [])
        if len(stops) < 2:
            continue
        path = []
        for index, stop in enumerate(stops):
            _, leg = _path(sheet, stop, stops[(index + 1) % len(stops)])
            if not leg:
                raise ValueError(f"Unreachable patrol {rival['id']}: {stop}")
            path.extend(leg[:-1])
        rival["path"] = path


def _budget(sheet: dict, definition: dict) -> None:
    chapter = next(c for c in definition["chapters"] if c["id"] == sheet["chapter"])
    anchors = []
    for scene in chapter["scene_ids"]:
        anchors.extend(n["id"] for n in sheet["nodes"] if n.get("scene") == scene and n.get("phase", "accumulate") != "campaign")
    musters = sheet.get("muster", [])
    musters = [musters] if isinstance(musters, str) else musters
    waypoints = [sheet["start"]] + anchors + musters[:1]
    mp, visited = 0, set()
    for a, b in zip(waypoints, waypoints[1:]):
        cost, path = _path(sheet, a, b)
        if cost < 0:
            raise ValueError(f"Unreachable anchor: {sheet['chapter']} {a} -> {b}")
        mp += cost
        visited.update(path)
    posts = [n for n in sheet["nodes"] if n.get("pass", {}).get("stamp", 0) > 0]
    stamps = sum(n["pass"]["stamp"] for n in posts if n["id"] in visited)
    base = musters[0] if musters else sheet["start"]
    detours = sorted(2 * max(0, _path(sheet, base, n["id"])[0]) for n in posts if n["id"] not in visited)
    for detour in detours:
        if stamps >= sheet.get("stamps_need", 0):
            break
        mp += detour
        stamps += 1
    minimum = (mp + 2) // 3 + len(anchors)
    sheet["_draft_days_max"] = sheet["days_max"]
    sheet["days_max"] = min(max(sheet["days_max"], minimum + 3), minimum + 9)


def _campaign_structure(sheet: dict, segment: str, closed: bool, volume: int) -> None:
    # These future anchors already carry battles in both book tables. Give them
    # the real scale once their templates exist, even in the gated preview.
    for node in sheet["nodes"]:
        if node.get("scene") == "k_brussels":
            node["type"] = "boss"
        if node.get("scene") in ["c_tiboulen", "c_auteuil"]:
            node["type"] = "elite"
    if closed:
        # A closed chapter is a preview graph, with its authored phase data
        # retained for the second-volume conversion, not an active war front.
        for node in sheet["nodes"]:
            if node.get("phase") == "campaign":
                node["_volume2_phase"] = node.pop("phase")
        return
    for node in sheet["nodes"]:
        if segment == "ocean" and str(node.get("event", "")).startswith("ev_o_council_"):
            node["role"] = "council"
        if node.get("requires", {}).get("volume", 1) > volume:
            node["_volume2_type"] = node["type"]
            node["type"] = "teaser"
            node["teaser"] = "第二卷开放：" + node["label"]
            if node.get("role") == "council":
                node["_volume2_role"] = node.pop("role")
        if sheet["chapter"] == "collapse" and node["id"] in ["erfurt_1813", "mainz_1813"]:
            # These are recovery stops after Leipzig, not the battle's one
            # mandatory camp. Their rest/training actions remain available.
            node["type"] = "story"
        if node["id"] == "borodino_field":
            node["type"] = "boss"  # grand-scale anchor, distinct from chapter boss
        if node.get("scene") == "c_morgiou":
            node["type"] = "elite"
        if node.get("scene") == "k_charleroi":
            node["type"] = "battle"
    if volume == 1 and isinstance(sheet.get("boss"), list):
        bosses = sheet["boss"]
        sheet["_volume2_bosses"] = bosses[1:]
        sheet["boss"] = bosses[0]


def build_volume(root: Path, volume: int) -> dict:
    root = Path(root)
    draft = root / "docs/cards/world/drafts"
    map_dir = root / "data/campaigns/napoleon/maps"
    out_dir = map_dir if volume == 1 else map_dir / "volume2"
    out_dir.mkdir(parents=True, exist_ok=True)
    result = {}
    for segment, (source, name) in SOURCES.items():
        data = _normalize_tree(_read(draft / source))
        data["_doc"] = "Normalized authored map. Source: docs/cards/world/drafts/" + source
        data.pop("_validation", None)
        for view in data["views"].values():
            if view.get("base"):
                view["base"] = Path(view["base"]).stem
            view.pop("lon", None)
            view.pop("lat", None)
        for index, sheet in enumerate(data["sheets"]):
            if sheet.get("interlude") is None:
                sheet["interlude"] = ""
            future = (segment == "conquest" and index >= 1) or (segment == "cristo" and index >= 2)
            closed = future and volume == 1
            for node in sheet["nodes"]:
                if future:
                    node.setdefault("requires", {})["volume"] = 2
                if node.get("role") == "muster":
                    node["phase"] = "accumulate"
                actions = node.get("actions", [])
                if "recruit:companion" in actions:
                    actions.remove("recruit:companion")
                    actions.extend("recruit:" + person for person in SHOP_RECRUITS.get((segment, node["id"]), []))
                if node.get("template") == "janina_lake":
                    node["fallback"] = "elite_a"
                if node.get("template") == "pyramids":
                    node.pop("fallback", None)
                if volume == 2:
                    node.pop("fallback", None)
                    node.pop("_planned", None)
                    if segment == "cristo" and sheet["chapter"] == "paris_1838" and node["id"] == "st_honore":
                        node.update({"type": "event", "event": "ev_noirtier_eyes", "fixed": True, "once": True,
                            "label": "维尔福府·努瓦蒂埃的房间"})
            _campaign_structure(sheet, segment, closed, volume)
            _patrols(sheet)
            definition_path = root / ("data/campaigns/ocean_pawn.json" if segment == "ocean" else f"data/campaigns/napoleon/{segment}.json")
            if definition_path.exists():
                _budget(sheet, _read(definition_path))
            # Required only for closed second-volume content; a missing first-
            # volume battle must be fixed in the template library, never hidden.
            sheet["templates_needed"] = sorted({n["template"] for n in sheet["nodes"]
                if n.get("template") and (closed or n.get("requires", {}).get("volume", 1) > volume)})
            view = data["views"][sheet["view"]]
            geo_view = _read(map_dir / "geo" / (view.get("base", "europe") + ".json"))["view"]
            _spread_markers(sheet, view, geo_view)
            _frames(sheet, view, geo_view)
        (out_dir / (name + ".json")).write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
        result[segment] = {"path": "res://" + str((out_dir / (name + ".json")).relative_to(root)), "sheets": len(data["sheets"])}
    return result


def build(root: Path) -> dict:
    return {"volume1": build_volume(root, 1), "volume2": build_volume(root, 2)}


if __name__ == "__main__":
    print(json.dumps(build(Path(__file__).resolve().parents[2]), ensure_ascii=False, indent=2))
