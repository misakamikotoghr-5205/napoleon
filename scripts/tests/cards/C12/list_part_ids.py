# List part ids for the spot catalog.
# Sources: data/town/item_templates.json appraise.sprites (every key except pool)
# and any parts[].id in that file plus data/cards/items/templates_extra.json
# and data/cards/_examples/items/templates_extra.json.
# Prints one id per line. --check compares them to data/cards/minigames/obs/spot.json.
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
SUFFIXES = ("differs", "wear", "plain", "unclear")


def _load(path: Path):
    if not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def _from_sprites(doc, ids: set) -> None:
    sprites = {}
    if isinstance(doc, dict):
        sprites = doc.get("appraise", {}).get("sprites", {})
    if not isinstance(sprites, dict):
        return
    for body in sprites.values():
        if not isinstance(body, dict):
            continue
        for key in body.keys():
            if key == "pool" or str(key).startswith("_"):
                continue
            ids.add(str(key))


def _from_parts(node, ids: set) -> None:
    if isinstance(node, dict):
        parts = node.get("parts")
        if isinstance(parts, list):
            for part in parts:
                if isinstance(part, dict) and "id" in part:
                    ids.add(str(part["id"]))
        for value in node.values():
            _from_parts(value, ids)
    elif isinstance(node, list):
        for value in node:
            _from_parts(value, ids)


def collect() -> list:
    ids = set()
    town = _load(ROOT / "data/town/item_templates.json")
    _from_sprites(town, ids)
    _from_parts(town, ids)
    for rel in (
        "data/cards/items/templates_extra.json",
        "data/cards/_examples/items/templates_extra.json",
    ):
        extra = _load(ROOT / rel)
        if extra is None:
            continue
        _from_sprites(extra, ids)
        _from_parts(extra, ids)
    return sorted(ids)


def main() -> int:
    ids = collect()
    if "--check" in sys.argv:
        cat = _load(ROOT / "data/cards/minigames/obs/spot.json")
        obs = cat.get("obs", {}) if isinstance(cat, dict) else {}
        missing = []
        for pid in ids:
            for suffix in SUFFIXES:
                key = "obs.spot.%s.%s" % (pid, suffix)
                if key not in obs:
                    missing.append(key)
        if missing:
            print("MISSING")
            for key in missing:
                print(key)
            return 1
        print("OK %d parts" % len(ids))
        return 0
    for pid in ids:
        print(pid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
