#!/usr/bin/env python3
"""Copy a ship-ready tree into a staging directory (CARDS_INTERFACES.md sections 2.3, 11.4, 11.6).

usage: stage_ship.py <staging_dir> [--src=<repo root, default: this repo>]
                     [--variant=ai-disclosure|no-disclosure] [--no-ai]

Starts at scenes/cards/CardGame.tscn, project.godot autoloads, and
scripts/cards/core/validate_main.gd (section 11.6 runs it inside the staging
project; the game scene does not reference it). Then follows .tscn/.tres
ext_resource paths, res:// string literals, and class_name references.
Also copies data/cards/** (except the ship exclusions), art/cards/**,
audio/cards/**, and (in ai-disclosure variant) art/ai/**, audio/ai/**,
data/cards/text_ai/**, the whitelisted legacy files, fonts, project.godot,
export_presets.cfg, and .import sidecars.

Two variants are supported:
- ai-disclosure (default): includes art/ai/**, audio/ai/**, data/cards/text_ai/**
  and preserves string _provenance on text_ai, art/manifest.json, and audio/*.json.
- no-disclosure (--variant=no-disclosure or --no-ai): human-art-only build;
  excludes art/ai/**, audio/ai/**, data/cards/text_ai/** and strips ai keys
  from manifests.

Story packs (packs/<id>/, docs/cards/PLUGINS.md): only packs/<id>/pack.json and
packs/<id>/text/**.json are copied, and only for release packs: id not starting
with "_", manifest readable with id equal to the folder, enabled not false, and
source "human" or "ai". The no-disclosure variant takes source "human" packs only.
_provenance is kept everywhere under packs/ (validate --mode=ship reads it).

JSON is rewritten (key order kept, 2-space indent, UTF-8) with draft keys removed:
brief, _doc, _test, and _provenance. brief is removed at every depth, including
a stage block (stage.brief, cast, props, intro, and after.<key> beats). _provenance
is KEPT on data/cards/text/**, on data/cards/theme/palette.json's _meta, and (in
ai-disclosure mode) on data/cards/text_ai/** and art/audio manifest entries, because
the pack flow runs validate --mode=ship and audit on this same directory
(section 11.6). Skeleton _provenance objects (the AI {by, task, date} blobs) are
stripped.

Prints: STAGED <n> files, <bytes> bytes
Standard library only. Same inputs always produce the same bytes.
"""
import json
import os
import re
import shutil
import sys

SCRIPT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

AI_PREFIXES = (
    "art/ai/",
    "audio/ai/",
    "data/cards/text_ai/",
)
VARIANTS = ("ai-disclosure", "no-disclosure")

# Prefixes are directory prefixes with a trailing slash, or exact files below.
EXCLUDED_PREFIXES = (
    "art/_placeholder/",
    "audio/_placeholder/",
    "data/cards/_examples/",
    "data/cards/_dev/",
    "data/cards/branch/",
    "scripts/tests/",
    "scripts/town/",
    "tools/",
    "docs/",
    "art/bg/",
    "art/portraits/",
    "art/tools/",
    "art/ui/",
    "art/town/",
    "audio/music/",
    "data/town/",
)
EXCLUDED_FILES = {
    "data/cards/theme/palette.dev.json",
    "data/cards/rules/wording.json",
    "data/codebook.json",
}
WHITELIST_EXACT = {
    "data/town/item_templates.json",
    # CardSettings (scripts/cards/ui/shell/card_settings.gd) preloads it for the old settings keys.
    "scripts/town/settings.gd",
}
CARD_DIRS = ("era", "demand", "news", "dossier", "common", "fortune", "guide",
             "items", "minigames", "rules", "tags", "theme", "ui_keys", "art", "audio", "_schema")
CLASS_RE = re.compile(r"(?m)^class_name\s+([A-Za-z_][A-Za-z0-9_]*)")
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def normalize_variant(variant=None, no_ai=False):
    if no_ai:
        return "no-disclosure"
    v = (variant or "ai-disclosure").strip().lower().replace("_", "-")
    if v in ("ai", "ai-disclosure", "with-ai", "disclosure"):
        return "ai-disclosure"
    if v in ("no-ai", "no-disclosure", "human-only", "human"):
        return "no-disclosure"
    raise ValueError("unknown variant %r (expected ai-disclosure or no-disclosure)" % variant)


PACK_SOURCES = ("human", "ai")


def pack_path_excluded(rel):
    """Paths under packs/ that never ship: dev packs (_id), stray files, anything but pack.json and text/**.json."""
    if not (rel == "packs" or rel.startswith("packs/")):
        return False
    parts = rel.split("/")
    if len(parts) < 3 or parts[1].startswith("_") or not parts[1]:
        return True
    if len(parts) == 3 and parts[2] == "pack.json":
        return False
    return not (parts[2] == "text" and len(parts) > 3 and rel.endswith(".json"))


def read_pack_manifest(src, pack_id):
    try:
        with open(os.path.join(src, "packs", pack_id, "pack.json"), encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, UnicodeError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def pack_shippable(manifest, pack_id, variant="ai-disclosure"):
    """A story pack ships when it is a release pack that is switched on and allowed by the variant."""
    if not isinstance(manifest, dict) or pack_id.startswith("_") or manifest.get("id") != pack_id:
        return False
    if manifest.get("enabled", True) is False:
        return False
    source = manifest.get("source")
    if source not in PACK_SOURCES:
        return False
    return normalize_variant(variant) == "ai-disclosure" or source == "human"


def pack_files(src, variant="ai-disclosure"):
    """Repo-relative files of the story packs that ship in this variant."""
    root = os.path.join(src, "packs")
    out = []
    if not os.path.isdir(root):
        return out
    for pack_id in sorted(os.listdir(root)):
        base = os.path.join(root, pack_id)
        if not os.path.isdir(base) or not pack_shippable(read_pack_manifest(src, pack_id), pack_id, variant):
            continue
        out.append("packs/%s/pack.json" % pack_id)
        for dirpath, dirnames, files in os.walk(os.path.join(base, "text")):
            dirnames.sort()
            for name in sorted(files):
                if name.endswith(".json"):
                    out.append(os.path.relpath(os.path.join(dirpath, name), src).replace(os.sep, "/"))
    return out


def excluded(rel, variant="ai-disclosure"):
    rel = rel.replace("\\", "/")
    if rel in WHITELIST_EXACT:
        return False
    if pack_path_excluded(rel):
        return True
    if rel in EXCLUDED_FILES:
        return True
    for pref in EXCLUDED_PREFIXES:
        if rel == pref.rstrip("/") or rel.startswith(pref):
            return True
    if normalize_variant(variant) == "no-disclosure":
        for pref in AI_PREFIXES:
            if rel == pref.rstrip("/") or rel.startswith(pref):
                return True
    if rel.startswith("scenes/") and not rel.startswith("scenes/cards/"):
        return True
    if rel.startswith(".godot/") or rel.startswith(".git/") or rel in (".git", ".godot"):
        return True
    return False


def keep_provenance(rel, parent_parts, variant="ai-disclosure", value=None):
    """Registration the ship validators still have to see. Draft provenance is stripped."""
    if isinstance(value, dict):
        return False
    if rel.startswith("data/cards/text/") or rel.startswith("packs/"):
        return True
    if rel == "data/cards/theme/palette.json" and parent_parts == ["_meta"]:
        return True
    if normalize_variant(variant) == "ai-disclosure":
        if rel.startswith("data/cards/text_ai/"):
            return True
        if rel == "data/cards/art/manifest.json" and (
            parent_parts == ["_meta"] or (len(parent_parts) == 2 and parent_parts[0] == "art")
        ):
            return True
        if (rel.startswith("data/cards/audio/") or rel == "audio/ai/sfx/manifest.json") and (
            parent_parts == ["_meta"] or (len(parent_parts) == 2 and parent_parts[0] in ("cues", "sfx"))
        ):
            return True
    return False


def _is_manifest_entry(rel, parent_parts):
    if rel == "data/cards/art/manifest.json" and len(parent_parts) == 2 and parent_parts[0] == "art":
        return True
    if (rel.startswith("data/cards/audio/") or rel == "audio/ai/sfx/manifest.json") and len(parent_parts) == 2 and parent_parts[0] in ("cues", "sfx"):
        return True
    return False


def strip_drafts(value, rel, parent_parts, variant="ai-disclosure"):
    """Drop draft keys at every object depth. Nested stage briefs go with the rest."""
    norm_variant = normalize_variant(variant)
    if isinstance(value, dict):
        out = {}
        for key, child in value.items():
            if key in ("brief", "_doc", "_test"):
                continue
            if norm_variant == "no-disclosure" and key == "ai" and _is_manifest_entry(rel, parent_parts):
                continue
            if key == "_provenance" and not keep_provenance(rel, parent_parts, norm_variant, child):
                continue
            out[key] = strip_drafts(child, rel, parent_parts + [key], norm_variant)
        return out
    if isinstance(value, list):
        return [strip_drafts(child, rel, parent_parts, norm_variant) for child in value]
    return value


def dump_json(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def scan_gd(text):
    """Return (res:// paths inside string literals, identifier text of code).

    A backslash consumes the next source character before a closer is tested,
    including inside triple quotes. An odd run does not end the literal.
    """
    strings = []
    code_chars = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "#":
            j = text.find("\n", i)
            if j < 0:
                break
            i = j
            continue
        if ch in "\"'":
            triple = text.startswith(ch * 3, i)
            quote = ch * 3 if triple else ch
            j = i + len(quote)
            buf = []
            while j < n:
                if text[j] == "\\":
                    if j + 1 < n:
                        buf.append(text[j + 1])
                        j += 2
                        continue
                if text.startswith(quote, j):
                    j += len(quote)
                    break
                buf.append(text[j])
                j += 1
            strings.append("".join(buf))
            code_chars.append(" ")
            i = j
            continue
        code_chars.append(ch)
        i += 1
    paths = []
    for s in strings:
        if s.startswith("res://"):
            paths.append(s[len("res://"):].split("?")[0])
    return paths, "".join(code_chars)


def res_paths_in_text(text):
    found = []
    for match in re.finditer(r'res://([^"\'\s]+)', text):
        found.append(match.group(1))
    return found


def autoload_paths(project_text):
    found = []
    in_auto = False
    for line in project_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_auto = stripped == "[autoload]"
            continue
        if in_auto:
            found.extend(res_paths_in_text(line))
    return found


def build_class_index(src):
    index = {}
    for dirpath, dirnames, files in os.walk(src):
        dirnames[:] = [d for d in dirnames if d not in (".git", ".godot")]
        for name in files:
            if not name.endswith(".gd"):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, src).replace(os.sep, "/")
            try:
                text = open(full, encoding="utf-8").read()
            except (OSError, UnicodeError):
                continue
            for match in CLASS_RE.finditer(text):
                index.setdefault(match.group(1), rel)
    return index


def discover(src, variant="ai-disclosure"):
    """Return a sorted list of repo-relative paths to copy."""
    norm_variant = normalize_variant(variant)
    class_index = build_class_index(src)
    seeds = ["scenes/cards/CardGame.tscn", "project.godot", "export_presets.cfg",
             "scripts/cards/core/validate_main.gd"]
    project = os.path.join(src, "project.godot")
    if os.path.isfile(project):
        try:
            seeds.extend(autoload_paths(open(project, encoding="utf-8").read()))
        except (OSError, UnicodeError):
            pass
    # Runtime-loaded card data, ship media roots, whitelist, fonts.
    walk_roots = [os.path.join(src, "data", "cards"),
                  os.path.join(src, "art", "cards"),
                  os.path.join(src, "audio", "cards")]
    if norm_variant == "ai-disclosure":
        walk_roots.extend([os.path.join(src, "art", "ai"),
                           os.path.join(src, "audio", "ai")])
    for root in walk_roots:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, files in os.walk(root):
            dirnames.sort()
            for name in sorted(files):
                if name.endswith(".import"):
                    continue
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, src).replace(os.sep, "/")
                if not excluded(rel, norm_variant):
                    seeds.append(rel)
    seeds.extend(pack_files(src, norm_variant))
    for extra in ("data/town/item_templates.json", "data/cast.json"):
        if os.path.isfile(os.path.join(src, extra)):
            seeds.append(extra)
    font_root = os.path.join(src, "fonts")
    if os.path.isdir(font_root):
        for dirpath, dirnames, files in os.walk(font_root):
            dirnames.sort()
            for name in sorted(files):
                rel = os.path.relpath(os.path.join(dirpath, name), src).replace(os.sep, "/")
                seeds.append(rel)

    wanted = set()
    queue = sorted(set(seeds))
    while queue:
        rel = queue.pop(0)
        rel = rel.replace("\\", "/")
        if not rel or rel in wanted or excluded(rel, norm_variant):
            continue
        full = os.path.join(src, rel)
        if not os.path.isfile(full):
            continue
        wanted.add(rel)
        new_deps = []
        if rel.endswith((".tscn", ".tres")):
            try:
                text = open(full, encoding="utf-8").read()
            except (OSError, UnicodeError):
                text = ""
            new_deps.extend(res_paths_in_text(text))
        elif rel.endswith(".gd"):
            try:
                text = open(full, encoding="utf-8").read()
            except (OSError, UnicodeError):
                text = ""
            paths, code = scan_gd(text)
            new_deps.extend(paths)
            own = None
            for match in CLASS_RE.finditer(text):
                own = match.group(1)
                break
            for ident in IDENT_RE.findall(code):
                target = class_index.get(ident)
                if target and target != rel and ident != own:
                    new_deps.append(target)
        for dep in new_deps:
            dep = dep.replace("\\", "/").lstrip("/")
            if dep and dep not in wanted and not excluded(dep, norm_variant):
                queue.append(dep)
        queue.sort()

    sidecars = []
    for rel in wanted:
        side = rel + ".import"
        if os.path.isfile(os.path.join(src, side)) and not excluded(side, norm_variant):
            sidecars.append(side)
    return sorted(wanted.union(sidecars))


SHIP_MAIN_SCENE = "res://scenes/cards/CardGame.tscn"


def rewrite_project_godot(text):
    lines = text.splitlines()
    out = []
    has_app = False
    in_app = False
    wrote_main = False
    wrote_ship = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if in_app:
                if not wrote_main:
                    out.append('run/main_scene="%s"' % SHIP_MAIN_SCENE)
                    wrote_main = True
                if not wrote_ship:
                    out.append('run/main_scene.ship="%s"' % SHIP_MAIN_SCENE)
                    wrote_ship = True
            in_app = stripped == "[application]"
            if in_app:
                has_app = True
            out.append(line)
            continue
        if in_app and stripped.startswith("run/main_scene="):
            out.append('run/main_scene="%s"' % SHIP_MAIN_SCENE)
            wrote_main = True
            continue
        if in_app and stripped.startswith("run/main_scene.ship="):
            out.append('run/main_scene.ship="%s"' % SHIP_MAIN_SCENE)
            wrote_ship = True
            continue
        out.append(line)
    if in_app:
        if not wrote_main:
            out.append('run/main_scene="%s"' % SHIP_MAIN_SCENE)
            wrote_main = True
        if not wrote_ship:
            out.append('run/main_scene.ship="%s"' % SHIP_MAIN_SCENE)
            wrote_ship = True
    if not has_app:
        if out and out[-1].strip() != "":
            out.append("")
        out.append("[application]")
        out.append('run/main_scene="%s"' % SHIP_MAIN_SCENE)
        out.append('run/main_scene.ship="%s"' % SHIP_MAIN_SCENE)
    return "\n".join(out) + "\n"


def write_one(src, dst_root, rel, variant="ai-disclosure"):
    src_path = os.path.join(src, rel)
    dst_path = os.path.join(dst_root, rel)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    if rel == "project.godot":
        try:
            raw = open(src_path, encoding="utf-8").read()
        except (OSError, UnicodeError):
            shutil.copyfile(src_path, dst_path)
            return os.path.getsize(dst_path)
        text = rewrite_project_godot(raw)
        open(dst_path, "w", encoding="utf-8", newline="\n").write(text)
        return len(text.encode("utf-8"))
    if rel.endswith(".json"):
        try:
            data = json.load(open(src_path, encoding="utf-8"))
        except (OSError, UnicodeError, ValueError):
            shutil.copyfile(src_path, dst_path)
        else:
            cleaned = strip_drafts(data, rel, [], variant)
            text = dump_json(cleaned)
            open(dst_path, "w", encoding="utf-8", newline="\n").write(text)
            return len(text.encode("utf-8"))
    shutil.copyfile(src_path, dst_path)
    return os.path.getsize(dst_path)


def _stage_no_disclosure_sfx_manifest(src, dst):
    """When audio/ai/** is stripped in no-disclosure mode, retain stripped SFX cue
    declarations in data/cards/audio/sfx.json so human SFX is required by audit."""
    ai_sfx_path = os.path.join(src, "audio", "ai", "sfx", "manifest.json")
    if not os.path.isfile(ai_sfx_path):
        return 0, 0
    try:
        raw_doc = json.load(open(ai_sfx_path, encoding="utf-8"))
    except (OSError, UnicodeError, ValueError):
        return 0, 0
    if not isinstance(raw_doc, dict):
        return 0, 0
    stripped = strip_drafts(raw_doc, "audio/ai/sfx/manifest.json", [], "no-disclosure")
    has_entries = any(isinstance(stripped.get(sec), dict) and stripped.get(sec) for sec in ("cues", "sfx"))
    if not has_entries:
        return 0, 0
    sfx_rel = "data/cards/audio/sfx.json"
    dst_path = os.path.join(dst, sfx_rel)
    added_files = 0
    old_bytes = 0
    if os.path.isfile(dst_path):
        old_bytes = os.path.getsize(dst_path)
        try:
            merged = json.load(open(dst_path, encoding="utf-8"))
        except (OSError, UnicodeError, ValueError):
            merged = {}
        if not isinstance(merged, dict):
            merged = {}
    else:
        merged = {}
        added_files = 1
    for sec in ("cues", "sfx"):
        sec_map = stripped.get(sec)
        if not isinstance(sec_map, dict):
            continue
        dst_sec = merged.setdefault(sec, {})
        if not isinstance(dst_sec, dict):
            dst_sec = {}
            merged[sec] = dst_sec
        for cue_id, entry in sec_map.items():
            dst_sec.setdefault(cue_id, entry)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    text = dump_json(merged)
    open(dst_path, "w", encoding="utf-8", newline="\n").write(text)
    new_bytes = len(text.encode("utf-8"))
    return added_files, (new_bytes - old_bytes)


def stage(src, dst, variant="ai-disclosure"):
    norm_variant = normalize_variant(variant)
    src = os.path.abspath(src)
    dst = os.path.abspath(dst)
    if dst == src or src.startswith(dst + os.sep):
        raise SystemExit("stage_ship: refusing to stage into the source tree (%s)" % dst)
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    elif os.path.isfile(dst):
        os.remove(dst)
    os.makedirs(dst)
    paths = discover(src, norm_variant)
    total = 0
    for rel in paths:
        total += write_one(src, dst, rel, norm_variant)
    count = len(paths)
    if norm_variant == "no-disclosure":
        extra_files, extra_bytes = _stage_no_disclosure_sfx_manifest(src, dst)
        count += extra_files
        total += extra_bytes
    return count, total


def main(argv):
    args = []
    opts = {}
    flags = set()
    for a in argv:
        if a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            opts[k] = v
        elif a.startswith("--"):
            flags.add(a[2:])
        else:
            args.append(a)
    if len(args) != 1:
        print(__doc__)
        return 2
    no_ai = bool(flags & {"no-ai", "no-disclosure", "human-only"})
    variant_arg = opts.get("variant")
    if not variant_arg and ("ai-disclosure" in flags or "with-ai" in flags):
        variant_arg = "ai-disclosure"
    try:
        variant = normalize_variant(variant_arg, no_ai=no_ai)
    except ValueError as exc:
        print("stage_ship: %s" % exc)
        return 2
    src = os.path.abspath(opts.get("src", SCRIPT_ROOT))
    if not os.path.isdir(src):
        print("stage_ship: source is not a directory: %s" % src)
        return 2
    count, nbytes = stage(src, args[0], variant=variant)
    print("STAGED %d files, %d bytes" % (count, nbytes))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
