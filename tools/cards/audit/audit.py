#!/usr/bin/env python3
"""Ship audit (CARDS_INTERFACES.md section 11.4). Any failed item is a non-zero exit.

usage:
  audit.py <staging_dir> [--report=<path>] [--pck=<file.pck>] [--godot=<binary>]
           [--wording-lint=<script>] [--src=<repo>] [--legacy-hashes=<json>]
           [--variant=ai-disclosure|no-disclosure] [--no-ai]
  audit.py --build-legacy-hashes [--src=<repo>] [--legacy-hashes=<json>]

Fails closed: a check that cannot be run (missing tool, missing file, unreadable
pack) is a failure, not a skip. Item 9 runs only when --pck= is given (the export
step); without it the report says the re-check was not requested.

Story packs (packs/<id>/, docs/cards/PLUGINS.md) are carried like text: only
pack.json and text/**.json of enabled release packs may ship (no "_" dev packs);
the no-disclosure variant may carry source "human" packs only; source "ai" packs
are counted as AI text in the disclosure summary.

Standard library only.
"""
import datetime
import hashlib
import json
import os
import re
import struct
import subprocess
import sys

SCRIPT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

AI_PREFIXES = (
    "art/ai/",
    "audio/ai/",
    "data/cards/text_ai/",
)
AI_DISCLOSURE_LABEL = "AI 生成、需声明"
VARIANTS = ("ai-disclosure", "no-disclosure")

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
# scripts/town/settings.gd: CardSettings preloads it for the old settings keys (contract §2.3).
WHITELIST_EXACT = {"data/town/item_templates.json", "scripts/town/settings.gd"}
MEDIA_EXT = (".png", ".jpg", ".jpeg", ".webp", ".svg", ".ogg", ".wav", ".mp3")
LEGACY_DIRS = (
    "art/bg", "art/items", "art/portraits", "art/tools", "art/ui", "art/town", "audio/music",
)
HUMAN_PROV = re.compile(r"^human:(A|B):\d{4}-\d{2}-\d{2}$")
PALETTE_PROV = re.compile(r"^human:A:\d{4}-\d{2}-\d{2}$")
AI_PROV = re.compile(r"^ai:([^:\s]+?)(?::([^:\s]+?))?:(\d{4}-\d{2}-\d{2}):(\S+)$")
AI_TEXT_PROV = re.compile(r"^ai:([^:\s]+):([^:\s]+):(\d{4}-\d{2}-\d{2}):(\S+)$")
CJK_RE = re.compile(
    "["
    "\u3000-\u303f"
    "\u3040-\u30ff"
    "\u31f0-\u31ff"
    "\u3400-\u4dbf"
    "\u4e00-\u9fff"
    "\uac00-\ud7af"
    "\uff00-\uffef"
    "]"
)
PACK_MAGIC = 0x43504447
PACK_REL_FILEBASE = 1 << 1
PACK_FILE_ENCRYPTED = 1 << 0
PACK_FILE_REMOVAL = 1 << 1
AI_METHODS = {"ai", "ml", "machine", "generated", "generative", "midjourney", "stable-diffusion", "sd", "novelai"}
COLOR_CALL_RE = re.compile(r"Color8\s*\(|Color\s*\.\s*html\s*\(|Color\s*\(")
COLOR_DOT_RE = re.compile(r"Color\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)")
# Contract §11.4 item 5: the one exception to "no color literals in UI scripts". The palette
# loader turns palette.json hex strings into colors; only that call, only in that file.
COLOR_PARSE_EXCEPTIONS = {"scripts/cards/ui/common/card_theme.gd": ("Color.html(",)}
VERDICT_FIELDS = {
    "fortune_lot": ("verse", "gloss"),
    "cezi": ("has", "none"),
}
PRINT_CAP = 80


def normalize_variant(opts_or_variant=None):
    if isinstance(opts_or_variant, dict):
        if any(opts_or_variant.get(k) for k in ("no-ai", "no-disclosure", "human-only")):
            return "no-disclosure"
        if any(opts_or_variant.get(k) for k in ("ai-disclosure", "with-ai")):
            return "ai-disclosure"
        raw = opts_or_variant.get("variant") or "ai-disclosure"
    else:
        raw = opts_or_variant or "ai-disclosure"
    v = str(raw).strip().lower().replace("_", "-")
    if v in ("ai", "ai-disclosure", "with-ai", "disclosure"):
        return "ai-disclosure"
    if v in ("no-ai", "no-disclosure", "human-only", "human"):
        return "no-disclosure"
    raise ValueError("unknown variant %r (expected ai-disclosure or no-disclosure)" % raw)


def parse_ai_source(prov):
    m = AI_PROV.match(str(prov or "").strip())
    if not m:
        return ""
    tool, model = m.group(1), m.group(2)
    return ("ai:%s:%s" % (tool, model)) if model else ("ai:%s" % tool)


def pack_path_forbidden(rel):
    """Same rule as stage_ship.pack_path_excluded: only packs/<id>/pack.json and packs/<id>/text/**.json, no _ packs."""
    if not (rel == "packs" or rel.startswith("packs/")):
        return False
    parts = rel.split("/")
    if len(parts) < 3 or parts[1].startswith("_") or not parts[1]:
        return True
    if len(parts) == 3 and parts[2] == "pack.json":
        return False
    return not (parts[2] == "text" and len(parts) > 3 and rel.endswith(".json"))


def stage_packs(stage):
    """{pack id: manifest dict or None (unreadable)} for packs/<id>/pack.json in the staging tree."""
    out = {}
    root = os.path.join(stage, "packs")
    if not os.path.isdir(root):
        return out
    for pack_id in sorted(os.listdir(root)):
        path = os.path.join(root, pack_id, "pack.json")
        if not os.path.isdir(os.path.join(root, pack_id)):
            continue
        try:
            data = load_json(path)
        except (OSError, UnicodeError, ValueError):
            data = None
        out[pack_id] = data if isinstance(data, dict) else None
    return out


def pack_text_files(stage, pack_id):
    out = []
    base = os.path.join(stage, "packs", pack_id, "text")
    for dirpath, dirnames, files in os.walk(base):
        dirnames.sort()
        for name in sorted(files):
            if name.endswith(".json"):
                out.append(os.path.join(dirpath, name))
    return out


def pack_text_roots(stage, variant="ai-disclosure", sources=("human", "ai")):
    """Text roots of the story packs whose text counts in this variant (no-disclosure: human packs only)."""
    roots = []
    for pack_id, manifest in stage_packs(stage).items():
        if not isinstance(manifest, dict) or manifest.get("source") not in sources:
            continue
        if normalize_variant(variant) == "no-disclosure" and manifest.get("source") != "human":
            continue
        base = os.path.join(stage, "packs", pack_id, "text")
        if os.path.isdir(base):
            roots.append(base)
    return roots


def is_ai_path(rel):
    rel = rel.replace("\\", "/")
    if rel.startswith("res://"):
        rel = rel[len("res://"):]
    rel = rel.lstrip("./")
    for pref in AI_PREFIXES:
        if rel == pref.rstrip("/") or rel.startswith(pref):
            return True
    return False


def path_forbidden(rel, variant="ai-disclosure"):
    rel = rel.replace("\\", "/")
    if rel.startswith("res://"):
        rel = rel[len("res://"):]
    rel = rel.lstrip("./")
    if rel in WHITELIST_EXACT:
        return False
    if rel in EXCLUDED_FILES:
        return True
    if pack_path_forbidden(rel):
        return True
    for pref in EXCLUDED_PREFIXES:
        if rel == pref.rstrip("/") or rel.startswith(pref):
            return True
    if normalize_variant(variant) == "no-disclosure" and is_ai_path(rel):
        return True
    if rel.startswith("scenes/") and not rel.startswith("scenes/cards/"):
        return True
    return False


def provenance_allowed(rel, parent, variant="ai-disclosure"):
    if rel.startswith("data/cards/text/") or rel.startswith("packs/"):
        return True
    if rel == "data/cards/theme/palette.json" and parent in ("_meta", ["_meta"]):
        return True
    if normalize_variant(variant) == "ai-disclosure":
        if rel.startswith("data/cards/text_ai/"):
            return True
        if rel == "data/cards/art/manifest.json":
            if parent in ("_meta", ["_meta"]):
                return True
            if isinstance(parent, list) and len(parent) == 2 and parent[0] == "art":
                return True
            if isinstance(parent, str) and parent.startswith("art."):
                return True
        if rel.startswith("data/cards/audio/") or rel == "audio/ai/sfx/manifest.json":
            if parent in ("_meta", ["_meta"]):
                return True
            if isinstance(parent, list) and len(parent) == 2 and parent[0] in ("cues", "sfx"):
                return True
            if isinstance(parent, str) and (parent.startswith("cues.") or parent.startswith("sfx.")):
                return True
    return False


def walk_files(root):
    out = []
    if not os.path.isdir(root):
        return out
    skip = {".godot", ".git", ".import"}
    for dirpath, dirnames, files in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in skip)
        for name in sorted(files):
            full = os.path.join(dirpath, name)
            if not os.path.isfile(full):
                continue
            out.append(os.path.relpath(full, root).replace(os.sep, "/"))
    return out


def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def sha256_bytes(blob):
    return hashlib.sha256(blob).hexdigest()


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def load_humans(path):
    humans = set()
    if not path or not os.path.isfile(path):
        return humans
    data = load_json(path)
    rows = data.get("humans", data) if isinstance(data, dict) else data
    for row in rows:
        humans.add(row["login"] if isinstance(row, dict) else str(row))
    return humans


def find_legal(staging, src, name):
    for base in (staging, src, SCRIPT_ROOT):
        path = os.path.join(base, "legal", name)
        if os.path.isfile(path):
            return path
    return None


def method_is_ai(method):
    m = (method or "").strip().lower()
    if not m:
        return True
    if m in AI_METHODS:
        return True
    return re.search(r"\bai\b", m) is not None


def parse_options(argv):
    opts = {}
    pos = []
    for a in argv:
        if a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            opts[k] = v
        elif a.startswith("--"):
            opts[a[2:]] = "1"
        else:
            pos.append(a)
    return pos, opts


# ---------- font cmap (format 4 and 12), standard library only ----------

def _cmap_format4(cmap, so):
    chars = set()
    _length, _lang, segx2 = struct.unpack_from(">HHH", cmap, so + 2)
    seg = segx2 // 2
    p = so + 14
    ends = struct.unpack_from(">%dH" % seg, cmap, p)
    p += 2 * seg + 2
    starts = struct.unpack_from(">%dH" % seg, cmap, p)
    p += 2 * seg
    deltas = struct.unpack_from(">%dh" % seg, cmap, p)
    p += 2 * seg
    idoff_pos = p
    idoff = struct.unpack_from(">%dH" % seg, cmap, p)
    for i in range(seg):
        sc, ec = starts[i], ends[i]
        if sc == 0xFFFF:
            continue
        for c in range(sc, ec + 1):
            if idoff[i] == 0:
                gid = (deltas[i] + c) & 0xFFFF
            else:
                pos = idoff_pos + i * 2 + idoff[i] + 2 * (c - sc)
                if pos + 2 > len(cmap):
                    gid = 0
                else:
                    gid = struct.unpack_from(">H", cmap, pos)[0]
                    if gid:
                        gid = (gid + deltas[i]) & 0xFFFF
            if gid:
                chars.add(c)
    return chars


def _cmap_format12(cmap, so):
    chars = set()
    _length, _lang, ngroups = struct.unpack_from(">III", cmap, so + 4)
    p = so + 16
    for _ in range(ngroups):
        start, end, glyph0 = struct.unpack_from(">III", cmap, p)
        p += 12
        span = end - start + 1
        if span <= 0 or span > 500000:
            continue
        for c in range(start, end + 1):
            if glyph0 + (c - start):
                chars.add(c)
    return chars


def font_chars(path):
    data = open(path, "rb").read()
    if len(data) < 12 or data[:4] not in (b"\x00\x01\x00\x00", b"OTTO", b"true", b"typ1"):
        raise ValueError("not an OpenType font: %s" % path)
    num = struct.unpack_from(">H", data, 4)[0]
    cmap_off = cmap_len = None
    for i in range(num):
        tag, _cs, off, length = struct.unpack_from(">4sIII", data, 12 + i * 16)
        if tag == b"cmap":
            cmap_off, cmap_len = off, length
            break
    if cmap_off is None:
        raise ValueError("font has no cmap: %s" % path)
    cmap = data[cmap_off:cmap_off + cmap_len]
    _ver, nsub = struct.unpack_from(">HH", cmap, 0)
    chars = set()
    seen_fmt = False
    for i in range(nsub):
        plat, enc, so = struct.unpack_from(">HHI", cmap, 4 + i * 8)
        if plat not in (0, 3):
            continue
        if plat == 3 and enc not in (1, 10, 0):
            continue
        fmt = struct.unpack_from(">H", cmap, so)[0]
        if fmt == 4:
            chars |= _cmap_format4(cmap, so)
            seen_fmt = True
        elif fmt == 12:
            chars |= _cmap_format12(cmap, so)
            seen_fmt = True
    if not seen_fmt:
        raise ValueError("font cmap has no format 4 or 12: %s" % path)
    return chars


# ---------- gd scan ----------

def gd_strings_and_mask(text):
    """String literals (with 1-based line numbers) and a code mask (strings/comments blanked).

    GDScript (Godot 4.7 tokenizer): a backslash consumes the next source character
    before a closer is considered, including inside triple quotes. An escaped
    quote is text, not a terminator. Consecutive backslashes pair off — an even
    run leaves the following quotes free to close, an odd run escapes the first
    quote. That is the same closer span for raw strings: raw literals only
    special-case a backslash before a quote or another backslash, which are
    exactly the characters that can change the closer.

    Returns (strings, mask, reliable). reliable is False when a literal has no
    closer before EOF. The tail is left in the mask in that case. Blanking it
    would be a clean mask over code the scan does not actually understand.
    """
    chars = list(text)
    strings = []  # (line, content)
    i = 0
    n = len(text)
    line = 1
    reliable = True
    while i < n:
        ch = text[i]
        if ch == "\n":
            line += 1
            i += 1
            continue
        if ch == "#":
            j = text.find("\n", i)
            if j < 0:
                j = n
            for k in range(i, j):
                chars[k] = " "
            i = j
            continue
        if ch in "\"'":
            triple = text.startswith(ch * 3, i)
            quote = ch * 3 if triple else ch
            start_line = line
            j = i + len(quote)
            buf = []
            closed = False
            while j < n:
                if text[j] == "\\":
                    if j + 1 >= n:
                        break
                    nxt = text[j + 1]
                    buf.append(nxt)
                    if nxt == "\n":
                        line += 1
                    j += 2
                    continue
                if text.startswith(quote, j):
                    j += len(quote)
                    closed = True
                    break
                if text[j] == "\n":
                    line += 1
                buf.append(text[j])
                j += 1
            if not closed:
                # Do not blank [i, n). A confused or unclosed literal must not
                # hide the following source under a clean mask.
                reliable = False
                i += len(quote)
                continue
            strings.append((start_line, "".join(buf)))
            for k in range(i, min(j, n)):
                if chars[k] != "\n":
                    chars[k] = " "
            i = j
            continue
        i += 1
    return strings, "".join(chars), reliable


def split_args(src):
    parts = []
    buf = []
    depth = 0
    for ch in src:
        if ch == "," and depth == 0:
            parts.append("".join(buf).strip())
            buf = []
            continue
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        buf.append(ch)
    parts.append("".join(buf).strip())
    return [p for p in parts if p != ""]


def color_call_allowed(call):
    if call.startswith("Color8") or ".html" in call.split("(")[0]:
        return False
    open_at = call.find("(")
    close_at = call.rfind(")")
    if open_at < 0 or close_at < open_at:
        return False
    args = split_args(call[open_at + 1:close_at])
    if len(args) < 3:
        return False

    def is_one(p):
        return p.strip() in {"1", "1.0", "1.00"}

    return is_one(args[0]) and is_one(args[1]) and is_one(args[2])


def iter_functions(text):
    lines = text.splitlines()
    starts = [i for i, line in enumerate(lines) if re.match(r"^(static\s+)?func\s+", line)]
    spans = []
    if not starts:
        return [(None, lines)]
    if starts[0] > 0:
        spans.append((None, lines[:starts[0]]))
    for n, start in enumerate(starts):
        end = starts[n + 1] if n + 1 < len(starts) else len(lines)
        spans.append((lines[start], lines[start:end]))
    return spans


def line_indent(line):
    width = 0
    for ch in line:
        if ch == " ":
            width += 1
        elif ch == "\t":
            width += 4
        else:
            break
    return width


def line_is_guarded(func_lines, hit):
    """hit is an index into func_lines. Class-body references are not guarded.

    The walk always re-applies the lexical mask: string literals and comments
    are blanked, newlines stay. Callers may pass raw source lines or an
    already-masked slice. A quote cannot invent a ship if, an else, or an
    early return — including a column-0 if/else inside a multiline string.
    A reference is guarded when an earlier `if CardShip.is_ship(): return` makes
    the rest of the function dead in a ship build, or when it sits in
    `if not CardShip.is_ship():`, or in the `else` of `if CardShip.is_ship():`.
    The else is the same indent as its if, so the if has to be remembered while
    it is closed — popping it first made every else look unguarded.
    A blank or comment-only line does not close a block. A same-indent comment
    between the if and the else used to pop the ship if and false-flag the else.
    """
    if not func_lines or hit < 0 or hit >= len(func_lines):
        return False
    # Mask the joined function so a multiline string is one literal, not a
    # stack of statements. Splitting on the newline character keeps a trailing
    # empty line that splitlines() would drop, so indexes stay aligned.
    _strings, mask, reliable = gd_strings_and_mask("\n".join(func_lines))
    if not reliable:
        return False
    func_lines = mask.split("\n")
    if hit >= len(func_lines):
        return False
    raw = func_lines[hit]
    if re.search(r"if\s+not\s+CardShip\.is_ship\(\)\s*:", raw):
        return True
    before = "\n".join(func_lines[:hit])
    if re.search(r"if\s+CardShip\.is_ship\(\)\s*:\s*return\b", before):
        return True
    if re.search(r"if\s+CardShip\.is_ship\(\)\s*:\s*\n\s+return\b", before):
        return True
    stack = []  # (indent, kind)
    for i, line in enumerate(func_lines[:hit + 1]):
        if not line.strip():
            continue
        head = line.strip().split("#", 1)[0].strip()
        if head == "":
            continue
        ind = line_indent(line)
        while stack and ind < stack[-1][0]:
            stack.pop()
        closing = None
        if stack and ind == stack[-1][0]:
            closing = stack.pop()
        ship_else = bool(re.match(r"else\s*:", head) and closing and closing[1] == "ship_if")
        if i == hit:
            if ship_else:
                return True
            return any(kind == "not_ship" for _ind, kind in stack)
        kind = None
        if re.match(r"if\s+not\s+CardShip\.is_ship\(\)\s*:", head):
            kind = "not_ship"
        elif re.match(r"if\s+CardShip\.is_ship\(\)\s*:", head):
            kind = "ship_if"
        elif ship_else:
            kind = "not_ship"
        elif head.endswith(":"):
            kind = "other"
        if kind:
            stack.append((ind, kind))
    return False


def audio_hits(text):
    """Return 1-based line numbers of unguarded placeholder-audio / legacy-music references.

    Guards are decided on the code mask (strings and comments blanked, line
    numbers kept). Quoted text can supply a legacy path, but it cannot open
    a ship if, an else, or an early return.
    """
    strings, mask, reliable = gd_strings_and_mask(text)
    hits = []
    spans = iter_functions(mask)
    abs_spans = []
    cursor = 0
    for _sig, flines in spans:
        abs_spans.append((cursor, cursor + len(flines), flines))
        cursor += len(flines)

    def guarded_at(line_no):
        if not reliable:
            return False
        idx = line_no - 1
        for start, end, flines in abs_spans:
            if start <= idx < end:
                if flines and re.match(r"^(static\s+)?func\s+", flines[0]):
                    return line_is_guarded(flines, idx - start)
                return False
        return False

    # String literals that point at legacy music.
    for line_no, content in strings:
        if "res://audio/music/" in content and not guarded_at(line_no):
            hits.append((line_no, "legacy music %s" % content.strip()))
    # AudioStreamGenerator tokens in code (not in strings or comments).
    for i, line in enumerate(mask.splitlines()):
        if "AudioStreamGenerator" in line and not guarded_at(i + 1):
            hits.append((i + 1, "AudioStreamGenerator"))
    if not reliable:
        # The mask is not a proof of cleanliness. Report whatever the raw
        # source still shows, even if a later quote blanked it again.
        for i, line in enumerate(text.splitlines()):
            if "AudioStreamGenerator" in line:
                hits.append((i + 1, "AudioStreamGenerator"))
            if "res://audio/music/" in line:
                hits.append((i + 1, "legacy music %s" % line.strip()))
    # Dedup by line+message
    seen = set()
    out = []
    for hit in hits:
        if hit not in seen:
            seen.add(hit)
            out.append(hit)
    return out


# ---------- pck (Godot 4 format versions 2, 3 and 4) ----------

def read_pck(path):
    with open(path, "rb") as fh:
        data = fh.read()
    if len(data) < 4 or struct.unpack_from("<I", data, 0)[0] != PACK_MAGIC:
        raise ValueError("not a Godot 4 pck (missing GDPC magic)")
    version, _maj, _min, _pat = struct.unpack_from("<IIII", data, 4)
    if version not in (2, 3, 4):
        raise ValueError("unsupported pck version %s" % version)
    flags = struct.unpack_from("<I", data, 20)[0]
    file_base = struct.unpack_from("<Q", data, 24)[0]
    rel = bool(flags & PACK_REL_FILEBASE)
    if version in (3, 4) or (version == 2 and rel):
        file_base += 0  # standalone pck; embedded packs add the header start
    if version in (3, 4):
        pos = struct.unpack_from("<Q", data, 32)[0]
    else:
        pos = 24 + 8 + 64  # after file_base and 16 reserved uint32s
    if pos + 4 > len(data):
        raise ValueError("pck directory offset is outside the file")
    count = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    files = []
    for _ in range(count):
        if pos + 4 > len(data):
            raise ValueError("truncated pck directory")
        slen = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        raw = data[pos:pos + slen]
        pos += slen
        rel_path = raw.split(b"\x00", 1)[0].decode("utf-8", "replace")
        ofs, size = struct.unpack_from("<QQ", data, pos)
        pos += 16
        pos += 16  # md5, not required for the path/hash re-check
        fflags = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        removal = bool(fflags & PACK_FILE_REMOVAL)
        encrypted = bool(fflags & PACK_FILE_ENCRYPTED)
        blob = b""
        if not removal and not encrypted:
            start = file_base + ofs
            blob = data[start:start + size]
            if len(blob) != size:
                raise ValueError("pck file %s is truncated" % rel_path)
        files.append({
            "path": rel_path,
            "blob": blob,
            "encrypted": encrypted,
            "removal": removal,
        })
    return files


# ---------- provenance csv / blacklist ----------

def load_csv(path):
    import csv
    rows = {}
    with open(path, encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        if not reader.fieldnames or "path" not in reader.fieldnames:
            raise ValueError("ASSET_PROVENANCE.csv needs a path column")
        for row in reader:
            key = (row.get("path") or "").replace("\\", "/")
            if key.startswith("res://"):
                key = key[len("res://"):]
            if key:
                rows[key] = row
    return rows


def load_blacklist(path):
    if not path or not os.path.isfile(path):
        return None
    data = load_json(path)
    if isinstance(data, dict) and data.get("hashes"):
        return set(data["hashes"])
    if isinstance(data, dict) and isinstance(data.get("files"), dict):
        return set(data["files"].values())
    if isinstance(data, list):
        return set(data)
    return set()


def build_legacy_hashes(src, dest):
    files = {}
    for folder in LEGACY_DIRS:
        base = os.path.join(src, folder)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, names in os.walk(base):
            dirnames.sort()
            for name in sorted(names):
                if not name.lower().endswith(MEDIA_EXT):
                    continue
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, src).replace(os.sep, "/")
                files[rel] = sha256_file(full)
    payload = {
        "algo": "sha256",
        "source": "v0.4.2 legacy media under art/{bg,items,portraits,tools,ui,town} and audio/music",
        "count": len(files),
        "files": files,
        "hashes": sorted(set(files.values())),
    }
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    open(dest, "w", encoding="utf-8", newline="\n").write(text)
    print("LEGACY HASHES %d files -> %s" % (len(files), dest))
    return 0


# ---------- the ten checks ----------

class Report(object):
    def __init__(self):
        self.items = {i: [] for i in range(1, 11)}

    def add(self, n, msg):
        self.items[n].append(msg)

    def count(self):
        return sum(len(v) for v in self.items.values())


def _is_manifest_entry(rel, parent_parts):
    if rel == "data/cards/art/manifest.json" and len(parent_parts) == 2 and parent_parts[0] == "art":
        return True
    if (rel.startswith("data/cards/audio/") or rel == "audio/ai/sfx/manifest.json") and len(parent_parts) == 2 and parent_parts[0] in ("cues", "sfx"):
        return True
    return False


def _audio_manifest_paths(stage, src=None, norm_variant="ai-disclosure"):
    """Return [(rel, full_path), ...] for audio manifests in stage (data/cards/audio/*.json
    plus audio/ai/sfx/manifest.json; in no-disclosure mode also fall back to src's
    audio/ai/sfx/manifest.json if neither sfx.json nor audio/ai/sfx/manifest.json is in stage;
    src is None unless --src was passed)."""
    out = []
    audio_cfg_dir = os.path.join(stage, "data", "cards", "audio")
    has_stage_sfx = False
    if os.path.isdir(audio_cfg_dir):
        for name in sorted(os.listdir(audio_cfg_dir)):
            if not name.endswith(".json"):
                continue
            if name == "sfx.json":
                has_stage_sfx = True
            full = os.path.join(audio_cfg_dir, name)
            rel = os.path.relpath(full, stage).replace(os.sep, "/")
            out.append((rel, full))
    ai_sfx_rel = "audio/ai/sfx/manifest.json"
    ai_sfx_full = os.path.join(stage, "audio", "ai", "sfx", "manifest.json")
    if os.path.isfile(ai_sfx_full):
        out.append((ai_sfx_rel, ai_sfx_full))
        has_stage_sfx = True
    elif norm_variant == "no-disclosure" and not has_stage_sfx and src:
        src_ai_sfx = os.path.join(src, "audio", "ai", "sfx", "manifest.json")
        if os.path.isfile(src_ai_sfx):
            out.append((ai_sfx_rel, src_ai_sfx))
    return out


def check_draft_keys(data, rel, out, limit_path="", variant="ai-disclosure"):
    norm_variant = normalize_variant(variant)

    def walk(value, parent_parts):
        if isinstance(value, dict):
            for key, child in value.items():
                path_str = ".".join(parent_parts + [key])
                shown = ("%s.%s" % (limit_path, path_str)) if limit_path else path_str
                if key in ("brief", "_doc", "_test"):
                    out.append("%s key %s" % (rel, shown))
                elif norm_variant == "no-disclosure" and key == "ai" and _is_manifest_entry(rel, parent_parts):
                    out.append("%s key %s" % (rel, shown))
                elif key == "_provenance" and (isinstance(child, dict) or not provenance_allowed(rel, parent_parts, norm_variant)):
                    out.append("%s key %s" % (rel, shown))
                else:
                    walk(child, parent_parts + [key])
        elif isinstance(value, list):
            for child in value:
                walk(child, parent_parts)
    walk(data, [])


def _csv_ai_prov(row):
    if not isinstance(row, dict):
        return ""
    for col in ("no_ai_proof", "method", "source_file", "author"):
        val = (row.get(col) or "").strip()
        if AI_PROV.match(val):
            return val
    return ""


def leaf_string_fields(entry, prefix=""):
    out = {}
    if not isinstance(entry, dict):
        return out
    for key, val in sorted(entry.items()):
        if str(key).startswith("_"):
            continue
        path = ("%s.%s" % (prefix, key)) if prefix else str(key)
        if isinstance(val, dict):
            out.update(leaf_string_fields(val, path))
        elif isinstance(val, str) and val.strip() != "":
            out[path] = val
    return out


def parse_project_main_scenes(text):
    main_scene = ""
    main_scene_ship = ""
    in_app = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_app = stripped == "[application]"
            continue
        if not in_app or "=" not in stripped:
            continue
        k, v = stripped.split("=", 1)
        k = k.strip()
        v = v.strip().strip('"')
        if k == "run/main_scene":
            main_scene = v
        elif k == "run/main_scene.ship":
            main_scene_ship = v
    return main_scene, main_scene_ship


def collect_ai_assets(stage, csv_rows=None):
    """Scan art/ai/**, audio/ai/**, data/cards/text_ai/** and count AI assets by category and provenance."""
    records = []
    file_provenance = {}
    overridden = {"art": [], "audio": [], "text": []}
    partially_overridden = {"text": []}
    missing_files = []
    unregistered = []
    text_field_stats = {"total": 0, "active_ai": 0, "overridden_by_human": 0, "partial_entries": 0}

    # 1. Art manifest mapping for art/ai/**
    art_by_path = {}
    manifest_path = os.path.join(stage, "data", "cards", "art", "manifest.json")
    if os.path.isfile(manifest_path):
        try:
            manifest = load_json(manifest_path)
        except (OSError, ValueError):
            manifest = {}
        if isinstance(manifest, dict):
            meta_prov = str((manifest.get("_meta") or {}).get("_provenance") or "") if isinstance(manifest.get("_meta"), dict) else ""
            art_map = manifest.get("art")
            if isinstance(art_map, dict):
                for art_id, entry in sorted(art_map.items()):
                    if not isinstance(entry, dict):
                        continue
                    ai_rel = str(entry.get("ai") or "").replace("\\", "/")
                    if not ai_rel:
                        continue
                    prov = str(entry.get("_provenance") or meta_prov).strip()
                    human_rel = str(entry.get("human") or "").replace("\\", "/")
                    human_ok = (
                        human_rel.startswith("art/cards/")
                        and not bool(entry.get("legacy", False))
                        and os.path.isfile(os.path.join(stage, human_rel))
                    )
                    art_by_path[ai_rel] = (str(art_id), prov, human_ok)
                    if not os.path.isfile(os.path.join(stage, ai_rel)):
                        missing_files.append("art id %s ai file is missing: %s" % (art_id, ai_rel))

    # 2. Audio manifest mapping for audio/ai/** (data/cards/audio/*.json + audio/ai/sfx/manifest.json)
    audio_by_path = {}
    for _rel, full in _audio_manifest_paths(stage):
        try:
            doc = load_json(full)
        except (OSError, ValueError):
            continue
        if not isinstance(doc, dict):
            continue
        meta_prov = str((doc.get("_meta") or {}).get("_provenance") or "") if isinstance(doc.get("_meta"), dict) else ""
        for section in ("cues", "sfx"):
            sec_map = doc.get(section)
            if not isinstance(sec_map, dict):
                continue
            for cue_id, entry in sorted(sec_map.items()):
                if not isinstance(entry, dict):
                    continue
                ai_rel = str(entry.get("ai") or "").replace("\\", "/")
                if not ai_rel:
                    continue
                prov = str(entry.get("_provenance") or meta_prov).strip()
                human_rel = str(entry.get("human") or "").replace("\\", "/")
                human_ok = (
                    human_rel.startswith("audio/cards/")
                    and os.path.isfile(os.path.join(stage, human_rel))
                )
                audio_by_path[ai_rel] = (str(cue_id), prov, human_ok)
                if not os.path.isfile(os.path.join(stage, ai_rel)):
                    missing_files.append("audio %s %s ai file is missing: %s" % (section[:-1] if section.endswith("s") else section, cue_id, ai_rel))

    # 3. Walk art/ai/** and audio/ai/** files in stage
    for rel in walk_files(stage):
        if rel.startswith("art/ai/") and rel.lower().endswith(MEDIA_EXT):
            art_id, prov, human_ok = art_by_path.get(rel, (rel, "", False))
            if not prov and isinstance(csv_rows, dict):
                prov = _csv_ai_prov(csv_rows.get(rel))
            source = parse_ai_source(prov)
            if not source:
                unregistered.append("%s (%s) has no valid ai:... _provenance" % (rel, AI_DISCLOSURE_LABEL))
                source = "unregistered"
            file_provenance[rel] = prov
            if human_ok:
                overridden["art"].append(art_id)
            records.append({
                "category": "art",
                "id": art_id,
                "path": rel,
                "provenance": prov,
                "source": source,
                "status": AI_DISCLOSURE_LABEL,
                "overridden_by_human": human_ok,
            })
        elif rel.startswith("audio/ai/") and rel.lower().endswith(MEDIA_EXT):
            cue_id, prov, human_ok = audio_by_path.get(rel, (rel, "", False))
            if not prov and isinstance(csv_rows, dict):
                prov = _csv_ai_prov(csv_rows.get(rel))
            source = parse_ai_source(prov)
            if not source:
                unregistered.append("%s (%s) has no valid ai:... _provenance" % (rel, AI_DISCLOSURE_LABEL))
                source = "unregistered"
            file_provenance[rel] = prov
            if human_ok:
                overridden["audio"].append(cue_id)
            records.append({
                "category": "audio",
                "id": cue_id,
                "path": rel,
                "provenance": prov,
                "source": source,
                "status": AI_DISCLOSURE_LABEL,
                "overridden_by_human": human_ok,
            })

    # 4. Human text leaf fields (field-level fallback human -> ai per #213)
    human_text_fields = {}
    text_root = os.path.join(stage, "data", "cards", "text")
    if os.path.isdir(text_root):
        for dirpath, _dirs, files in os.walk(text_root):
            for name in sorted(files):
                if not name.endswith(".json"):
                    continue
                try:
                    data = load_json(os.path.join(dirpath, name))
                except (OSError, ValueError):
                    continue
                if not isinstance(data, dict):
                    continue
                for key, entry in data.items():
                    if str(key).startswith("_") or not isinstance(entry, dict):
                        continue
                    fields = set(leaf_string_fields(entry).keys())
                    if fields:
                        human_text_fields.setdefault(str(key), set()).update(fields)

    # 4b. Story packs sit above every layer: human pack fields hide AI fields below them.
    packs = stage_packs(stage)
    for pack_id, manifest in packs.items():
        if not isinstance(manifest, dict) or manifest.get("source") != "human":
            continue
        for full in pack_text_files(stage, pack_id):
            try:
                data = load_json(full)
            except (OSError, ValueError):
                continue
            if not isinstance(data, dict):
                continue
            for key, entry in data.items():
                if str(key).startswith("_") or not isinstance(entry, dict):
                    continue
                fields = set(leaf_string_fields(entry).keys())
                if fields:
                    human_text_fields.setdefault(str(key), set()).update(fields)

    # 5. Walk data/cards/text_ai/** (strict 5-segment file-level _meta._provenance per #213)
    text_ai_root = os.path.join(stage, "data", "cards", "text_ai")
    if os.path.isdir(text_ai_root):
        for dirpath, _dirs, files in os.walk(text_ai_root):
            for name in sorted(files):
                if not name.endswith(".json"):
                    continue
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, stage).replace(os.sep, "/")
                try:
                    data = load_json(full)
                except (OSError, ValueError):
                    unregistered.append("%s is not valid JSON" % rel)
                    continue
                if not isinstance(data, dict):
                    continue
                meta = data.get("_meta") if isinstance(data.get("_meta"), dict) else {}
                file_prov = str(meta.get("_provenance") or "").strip()
                file_prov_ok = bool(AI_TEXT_PROV.match(file_prov))
                if not file_prov_ok:
                    unregistered.append(
                        "%s: _meta _provenance is not ai:<tool>:<model>:YYYY-MM-DD:<id>" % rel
                    )
                for key, entry in sorted(data.items()):
                    if str(key).startswith("_"):
                        continue
                    entry_prov = str(entry.get("_provenance") or "").strip() if isinstance(entry, dict) and "_provenance" in entry else ""
                    entry_conflict = bool(isinstance(entry, dict) and "_provenance" in entry and entry_prov != file_prov)
                    prov = file_prov if (file_prov_ok and not entry_conflict) else ""
                    source = parse_ai_source(prov)
                    if not source:
                        unregistered.append(
                            "%s: %s _provenance is not ai:<tool>:<model>:YYYY-MM-DD:<id>" % (rel, key)
                        )
                        source = "unregistered"
                    ai_fields = set(leaf_string_fields(entry).keys()) if isinstance(entry, dict) else set()
                    h_fields = human_text_fields.get(str(key), set())
                    overridden_fields = sorted(ai_fields & h_fields)
                    active_ai_fields = sorted(ai_fields - h_fields)
                    fully_overridden = bool(ai_fields) and len(active_ai_fields) == 0
                    partial = len(overridden_fields) > 0 and len(active_ai_fields) > 0
                    override_state = "full" if fully_overridden else ("partial" if partial else "none")
                    text_field_stats["total"] += len(ai_fields)
                    text_field_stats["active_ai"] += len(active_ai_fields)
                    text_field_stats["overridden_by_human"] += len(overridden_fields)
                    if fully_overridden:
                        overridden["text"].append(str(key))
                    elif partial:
                        partially_overridden["text"].append(str(key))
                        text_field_stats["partial_entries"] += 1
                    records.append({
                        "category": "text",
                        "id": str(key),
                        "path": rel,
                        "provenance": prov,
                        "source": source,
                        "status": AI_DISCLOSURE_LABEL,
                        "overridden_by_human": fully_overridden,
                        "partially_overridden_by_human": partial,
                        "override_state": override_state,
                        "ai_fields": sorted(ai_fields),
                        "overridden_fields": overridden_fields,
                        "active_ai_fields": active_ai_fields,
                    })

    # 6. Story packs with source "ai" are AI text (pack.json _provenance, same 5-segment rule).
    #    A human pack stacked higher (order, then id) hides their fields.
    def pack_rank(item):
        man = item[1]
        order = man.get("order", 100) if isinstance(man.get("order", 100), int) else 100
        return (order, item[0])
    ranked = sorted([(pid, man) for pid, man in packs.items() if isinstance(man, dict)], key=pack_rank)
    for index, (pack_id, manifest) in enumerate(ranked):
        if manifest.get("source") != "ai":
            continue
        prov = str(manifest.get("_provenance") or "").strip()
        prov_ok = bool(AI_TEXT_PROV.match(prov))
        above = {}
        for higher_id, higher in ranked[index + 1:]:
            if higher.get("source") != "human":
                continue
            for full in pack_text_files(stage, higher_id):
                try:
                    hdata = load_json(full)
                except (OSError, ValueError):
                    continue
                if isinstance(hdata, dict):
                    for hkey, hentry in hdata.items():
                        if not str(hkey).startswith("_") and isinstance(hentry, dict):
                            above.setdefault(str(hkey), set()).update(leaf_string_fields(hentry).keys())
        for full in pack_text_files(stage, pack_id):
            rel = os.path.relpath(full, stage).replace(os.sep, "/")
            try:
                data = load_json(full)
            except (OSError, ValueError):
                unregistered.append("%s is not valid JSON" % rel)
                continue
            if not isinstance(data, dict):
                continue
            for key, entry in sorted(data.items()):
                if str(key).startswith("_") or not isinstance(entry, dict):
                    continue
                source = parse_ai_source(prov) if prov_ok else ""
                if not source:
                    unregistered.append("%s: %s pack _provenance is not ai:<tool>:<model>:YYYY-MM-DD:<id>" % (rel, key))
                    source = "unregistered"
                ai_fields = set(leaf_string_fields(entry).keys())
                hidden = sorted(ai_fields & above.get(str(key), set()))
                active = sorted(ai_fields - above.get(str(key), set()))
                full_hidden = bool(ai_fields) and not active
                partial = bool(hidden) and bool(active)
                text_field_stats["total"] += len(ai_fields)
                text_field_stats["active_ai"] += len(active)
                text_field_stats["overridden_by_human"] += len(hidden)
                if full_hidden:
                    overridden["text"].append(str(key))
                elif partial:
                    partially_overridden["text"].append(str(key))
                    text_field_stats["partial_entries"] += 1
                records.append({
                    "category": "text",
                    "id": str(key),
                    "path": rel,
                    "pack": pack_id,
                    "provenance": prov if prov_ok else "",
                    "source": source,
                    "status": AI_DISCLOSURE_LABEL,
                    "overridden_by_human": full_hidden,
                    "partially_overridden_by_human": partial,
                    "override_state": "full" if full_hidden else ("partial" if partial else "none"),
                    "ai_fields": sorted(ai_fields),
                    "overridden_fields": hidden,
                    "active_ai_fields": active,
                })

    by_category = {"art": 0, "audio": 0, "text": 0}
    by_source = {}
    by_category_source = {"art": {}, "audio": {}, "text": {}}
    by_provenance = {}
    for rec in records:
        cat = rec["category"]
        src_name = rec["source"]
        prov = rec["provenance"] or "unregistered"
        by_category[cat] = by_category.get(cat, 0) + 1
        by_source[src_name] = by_source.get(src_name, 0) + 1
        cat_map = by_category_source.setdefault(cat, {})
        cat_map[src_name] = cat_map.get(src_name, 0) + 1
        by_provenance[prov] = by_provenance.get(prov, 0) + 1

    return {
        "disclosure_label": AI_DISCLOSURE_LABEL,
        "requires_disclosure": len(records) > 0,
        "total": len(records),
        "by_category": by_category,
        "by_source": by_source,
        "by_category_source": by_category_source,
        "by_provenance": by_provenance,
        "overridden_by_human": overridden,
        "partially_overridden_by_human": partially_overridden,
        "text_fields": text_field_stats,
        "missing_files": missing_files,
        "file_provenance": file_provenance,
        "unregistered": unregistered,
        "records": records,
    }


def collect_art_refs(data, into):
    if isinstance(data, dict):
        for key, child in data.items():
            if key in ("art", "bg") and isinstance(child, str) and child:
                into.append(child)
            else:
                collect_art_refs(child, into)
    elif isinstance(data, list):
        for child in data:
            collect_art_refs(child, into)


def player_strings(value):
    found = []
    if isinstance(value, dict):
        for key, child in value.items():
            if str(key).startswith("_"):
                continue
            found.extend(player_strings(child))
    elif isinstance(value, list):
        for child in value:
            found.extend(player_strings(child))
    elif isinstance(value, str):
        found.append(value)
    return found


def dig(value, field):
    cur = value
    for part in field.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def load_card_types(stage):
    types = {}
    root = os.path.join(stage, "data", "cards")
    if not os.path.isdir(root):
        return types
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if not name.endswith(".json"):
                continue
            rel = os.path.relpath(os.path.join(dirpath, name), stage).replace(os.sep, "/")
            if rel.startswith("data/cards/text/") or rel.startswith("data/cards/text_ai/") or path_forbidden(rel):
                continue
            try:
                data = load_json(os.path.join(stage, rel))
            except (OSError, ValueError):
                continue
            if not isinstance(data, dict):
                continue
            for card in data.get("cards") or []:
                if isinstance(card, dict) and card.get("id") and card.get("type"):
                    types[str(card["id"])] = str(card["type"])
    return types


def check_item_1(stage, report, variant="ai-disclosure"):
    norm_variant = normalize_variant(variant)
    if not os.path.isdir(stage):
        report.add(1, "staging directory does not exist")
        return
    project_path = os.path.join(stage, "project.godot")
    card_scene_path = os.path.join(stage, "scenes", "cards", "CardGame.tscn")
    if not os.path.isfile(project_path):
        report.add(1, "project.godot is missing from staging")
    else:
        try:
            proj_text = open(project_path, encoding="utf-8").read()
        except (OSError, UnicodeError) as exc:
            report.add(1, "project.godot is not readable: %s" % exc)
        else:
            main_scene, main_scene_ship = parse_project_main_scenes(proj_text)
            effective_scene = main_scene_ship or main_scene
            if effective_scene != "res://scenes/cards/CardGame.tscn" or main_scene == "res://scenes/Main.tscn":
                report.add(
                    1,
                    "project.godot main_scene must resolve to res://scenes/cards/CardGame.tscn "
                    "(got main_scene=%r, main_scene.ship=%r)" % (main_scene, main_scene_ship),
                )
    if not os.path.isfile(card_scene_path):
        report.add(1, "scenes/cards/CardGame.tscn is missing from staging")
    for pack_id, manifest in stage_packs(stage).items():
        if not isinstance(manifest, dict):
            continue
        if manifest.get("enabled", True) is False:
            report.add(1, "packs/%s is disabled and must not be shipped" % pack_id)
        if norm_variant == "no-disclosure" and manifest.get("source") != "human":
            report.add(1, "packs/%s is not a human story pack and must not be shipped in no-disclosure build" % pack_id)
    for rel in walk_files(stage):
        if path_forbidden(rel, norm_variant):
            report.add(1, "%s must not be shipped" % rel)
        if not rel.endswith(".json"):
            continue
        try:
            data = load_json(os.path.join(stage, rel))
        except (OSError, UnicodeError, ValueError):
            report.add(1, "%s is not valid JSON" % rel)
            continue
        found = []
        check_draft_keys(data, rel, found, variant=norm_variant)
        for msg in found:
            report.add(1, "%s must be stripped" % msg)


def check_item_2(stage, report, godot, variant="ai-disclosure"):
    norm_variant = normalize_variant(variant)
    text_root = os.path.join(stage, "data", "cards", "text")
    text_ai_root = os.path.join(stage, "data", "cards", "text_ai")
    if os.path.isdir(text_root):
        for dirpath, _dirs, files in os.walk(text_root):
            for name in sorted(files):
                if not name.endswith(".json"):
                    continue
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, stage).replace(os.sep, "/")
                try:
                    data = load_json(full)
                except (OSError, ValueError):
                    report.add(2, "%s text file is not valid JSON" % rel)
                    continue
                if not isinstance(data, dict):
                    continue
                for key, entry in data.items():
                    if str(key).startswith("_"):
                        continue
                    prov = entry.get("_provenance", "") if isinstance(entry, dict) else ""
                    if not HUMAN_PROV.match(str(prov)):
                        report.add(2, "%s: %s _provenance is not human:(A|B):YYYY-MM-DD" % (rel, key))
    elif norm_variant == "no-disclosure" or not os.path.isdir(text_ai_root):
        report.add(2, "data/cards/text is missing; human provenance cannot be checked")
    if os.path.isdir(text_ai_root):
        if norm_variant == "no-disclosure":
            report.add(2, "data/cards/text_ai must not be present in no-disclosure build")
        else:
            for dirpath, _dirs, files in os.walk(text_ai_root):
                for name in sorted(files):
                    if not name.endswith(".json"):
                        continue
                    full = os.path.join(dirpath, name)
                    rel = os.path.relpath(full, stage).replace(os.sep, "/")
                    try:
                        data = load_json(full)
                    except (OSError, ValueError):
                        report.add(2, "%s AI text file is not valid JSON" % rel)
                        continue
                    if not isinstance(data, dict):
                        continue
                    meta = data.get("_meta") if isinstance(data.get("_meta"), dict) else {}
                    file_prov = str(meta.get("_provenance") or "").strip()
                    file_prov_ok = bool(AI_TEXT_PROV.match(file_prov))
                    if not file_prov_ok:
                        report.add(
                            2,
                            "%s: _meta _provenance is not ai:<tool>:<model>:YYYY-MM-DD:<id>" % rel,
                        )
                    for key, entry in sorted(data.items()):
                        if str(key).startswith("_"):
                            continue
                        if isinstance(entry, dict) and "_provenance" in entry:
                            entry_prov = str(entry.get("_provenance") or "").strip()
                            if not file_prov_ok or entry_prov != file_prov:
                                report.add(
                                    2,
                                    "%s: %s _provenance must come from file _meta._provenance (got %r vs _meta %r)"
                                    % (rel, key, entry_prov, file_prov),
                                )
                        if not file_prov_ok:
                            report.add(
                                2,
                                "%s: %s _provenance is not ai:<tool>:<model>:YYYY-MM-DD:<id>" % (rel, key),
                            )
    check_packs_provenance(stage, report)
    if not godot:
        report.add(2, "GODOT is not set and --godot= was not given; validate --mode=ship cannot run")
        return
    if godot.endswith(".py") and not os.path.isfile(godot):
        report.add(2, "godot stand-in does not exist: %s" % godot)
        return
    cmd = [godot, "--headless", "--path", stage, "-s", "res://scripts/cards/core/validate_main.gd",
           "--", "--mode=ship", "--variant=" + norm_variant, "--name=audit_ship"]
    if godot.endswith(".py"):
        cmd = [sys.executable] + cmd
    else:
        # class_name is invisible until the project has been imported.
        try:
            subprocess.run(
                [godot, "--headless", "--path", stage, "--import"],
                capture_output=True, text=True, timeout=180)
        except (OSError, subprocess.TimeoutExpired) as exc:
            report.add(2, "godot --import could not finish: %s" % exc)
            return
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    except (OSError, subprocess.TimeoutExpired) as exc:
        report.add(2, "validate --mode=ship could not run: %s" % exc)
        return
    # Script prints go to stdout (banner, then DATA ERROR / CARDS TEST PASS).
    # Editor diagnostics go to stderr and must not hide the last script line.
    stdout_lines = [ln for ln in (proc.stdout or "").splitlines() if ln.strip()]
    last = stdout_lines[-1] if stdout_lines else ""
    combined = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
    for ln in combined.splitlines():
        if ln.startswith("DATA ERROR:"):
            report.add(2, ln)
    if proc.returncode != 0 or last != "CARDS TEST PASS audit_ship":
        report.add(2, "validate --mode=ship failed (exit %s, last line %r)" % (proc.returncode, last))


def check_packs_provenance(stage, report):
    """Item 2 for story packs: readable manifest, id = folder, source human|ai, _provenance of that kind,
    and text files whose _meta / entry _provenance (when present) match the pack source."""
    for pack_id, manifest in stage_packs(stage).items():
        base = "packs/%s" % pack_id
        if not isinstance(manifest, dict):
            report.add(2, "%s/pack.json is missing or not valid JSON" % base)
            continue
        if manifest.get("id") != pack_id:
            report.add(2, "%s/pack.json id %r must equal the folder name" % (base, manifest.get("id")))
        source = manifest.get("source")
        if source not in ("human", "ai"):
            report.add(2, "%s/pack.json source must be human or ai (got %r)" % (base, source))
            continue
        pattern = HUMAN_PROV if source == "human" else AI_TEXT_PROV
        want = "human:(A|B):YYYY-MM-DD" if source == "human" else "ai:<tool>:<model>:YYYY-MM-DD:<id>"
        if not pattern.match(str(manifest.get("_provenance") or "")):
            report.add(2, "%s/pack.json _provenance is not %s" % (base, want))
        for full in pack_text_files(stage, pack_id):
            rel = os.path.relpath(full, stage).replace(os.sep, "/")
            try:
                data = load_json(full)
            except (OSError, ValueError):
                report.add(2, "%s pack text file is not valid JSON" % rel)
                continue
            if not isinstance(data, dict):
                report.add(2, "%s pack text file is not an object" % rel)
                continue
            meta = data.get("_meta") if isinstance(data.get("_meta"), dict) else {}
            if "_provenance" in meta and not pattern.match(str(meta.get("_provenance") or "")):
                report.add(2, "%s: _meta _provenance is not %s (pack source %s)" % (rel, want, source))
            for key, entry in sorted(data.items()):
                if str(key).startswith("_"):
                    continue
                if isinstance(entry, dict) and "_provenance" in entry and not pattern.match(str(entry.get("_provenance") or "")):
                    report.add(2, "%s: %s _provenance is not %s (pack source %s)" % (rel, key, want, source))


def check_audio_manifests(stage, report, csv_rows, humans, norm_variant, src=None):
    audio_dir = os.path.join(stage, "data", "cards", "audio")
    music_path = os.path.join(audio_dir, "music.json")
    if not os.path.isfile(music_path):
        report.add(3, "data/cards/audio/music.json is missing")
        return
    for rel, full in _audio_manifest_paths(stage, src=src, norm_variant=norm_variant):
        name = os.path.basename(full)
        try:
            doc = load_json(full)
        except (OSError, ValueError) as exc:
            report.add(3, "%s is not readable: %s" % (rel, exc))
            continue
        if not isinstance(doc, dict):
            report.add(3, "%s is not a JSON object" % rel)
            continue
        meta_prov = ""
        if isinstance(doc.get("_meta"), dict):
            meta_prov = str(doc["_meta"].get("_provenance") or "").strip()
        if rel == "data/cards/audio/music.json":
            cues_obj = doc.get("cues")
            if not isinstance(cues_obj, dict) or not cues_obj:
                report.add(3, "data/cards/audio/music.json has no cues")
                continue
        for section in ("cues", "sfx"):
            sec_map = doc.get(section)
            if sec_map is None:
                continue
            if not isinstance(sec_map, dict):
                report.add(3, "%s %s is not an object" % (rel, section))
                continue
            singular = section[:-1] if section.endswith("s") else section
            for cue_id, entry in sorted(sec_map.items()):
                label = "audio %s %s" % (singular, cue_id)
                if not isinstance(entry, dict):
                    report.add(3, "%s is not an object" % label)
                    continue
                if entry.get("legacy") is True:
                    report.add(3, "%s is legacy: true" % label)
                    continue
                human = str(entry.get("human") or "").replace("\\", "/")
                ai_rel = str(entry.get("ai") or "").replace("\\", "/")
                human_full = os.path.join(stage, human) if human else ""
                if norm_variant == "ai-disclosure" and ai_rel:
                    if not ai_rel.startswith("audio/ai/"):
                        report.add(3, "%s ai path is not under audio/ai/: %s" % (label, ai_rel))
                        continue
                    ai_full = os.path.join(stage, ai_rel)
                    if not os.path.isfile(ai_full):
                        report.add(3, "%s ai file is missing: %s" % (label, ai_rel))
                        continue
                    prov = str(entry.get("_provenance") or meta_prov).strip()
                    if not prov and isinstance(csv_rows, dict):
                        prov = _csv_ai_prov(csv_rows.get(ai_rel))
                    if not AI_PROV.match(prov):
                        report.add(
                            3,
                            "%s ai file %s _provenance is not ai:<tool>[:<model>]:YYYY-MM-DD:<id>"
                            % (label, ai_rel),
                        )
                    if not human or not os.path.isfile(human_full):
                        if human and not human.startswith("audio/cards/"):
                            report.add(3, "%s human path is not under audio/cards/: %s" % (label, human))
                        continue
                if not human.startswith("audio/cards/"):
                    report.add(3, "%s human path is not under audio/cards/: %s" % (label, human or "<empty>"))
                    continue
                if not os.path.isfile(human_full):
                    report.add(3, "%s file is missing: %s" % (label, human))
                    continue
                digest = sha256_file(human_full)
                row = csv_rows.get(human)
                if row is None:
                    report.add(3, "%s file %s is not in ASSET_PROVENANCE.csv" % (label, human))
                    continue
                if (row.get("sha256") or "").strip().lower() != digest:
                    report.add(3, "%s sha256 does not match ASSET_PROVENANCE.csv" % label)
                author = (row.get("author") or "").strip()
                if author not in humans:
                    report.add(3, "%s author %r is not in human_authors.json" % (label, author))
                if method_is_ai(row.get("method") or ""):
                    report.add(3, "%s method is AI (%r)" % (label, row.get("method")))


def check_item_3(stage, report, csv_rows, humans, variant="ai-disclosure", src=None):
    norm_variant = normalize_variant(variant)
    manifest_path = os.path.join(stage, "data", "cards", "art", "manifest.json")
    if not os.path.isfile(manifest_path):
        report.add(3, "data/cards/art/manifest.json is missing")
        return
    try:
        manifest = load_json(manifest_path)
    except (OSError, ValueError) as exc:
        report.add(3, "manifest.json is not readable: %s" % exc)
        return
    art = manifest.get("art") if isinstance(manifest, dict) else None
    if not isinstance(art, dict):
        report.add(3, "manifest.json has no art object")
        return
    meta_prov = ""
    if isinstance(manifest, dict) and isinstance(manifest.get("_meta"), dict):
        meta_prov = str(manifest["_meta"].get("_provenance") or "").strip()
    if csv_rows is None:
        report.add(3, "legal/ASSET_PROVENANCE.csv is missing")
        return
    if not humans:
        report.add(3, "legal/human_authors.json is missing or empty")
    refs = []
    for rel in walk_files(stage):
        if (
            not rel.endswith(".json")
            or rel.startswith("legal/")
            or rel == "data/cards/art/manifest.json"
            or rel == "audio/ai/sfx/manifest.json"
            or rel.startswith("data/cards/audio/")
            or rel.startswith("data/cards/text/")
            or rel.startswith("data/cards/text_ai/")
            or rel.startswith("packs/")
        ):
            continue
        try:
            data = load_json(os.path.join(stage, rel))
        except (OSError, ValueError):
            continue
        collect_art_refs(data, refs)
    seen = []
    for art_id in refs:
        if art_id not in seen:
            seen.append(art_id)
    if not seen:
        report.add(3, "no art id is referenced; nothing to prove against the manifest")
        return
    for art_id in seen:
        entry = art.get(art_id)
        if not isinstance(entry, dict):
            report.add(3, "art id %s is not in the manifest" % art_id)
            continue
        if entry.get("legacy") is True:
            report.add(3, "art id %s is legacy: true" % art_id)
            continue
        human = str(entry.get("human") or "")
        ai_rel = str(entry.get("ai") or "")
        human_full = os.path.join(stage, human) if human else ""
        # Human art always takes precedence over AI art when present; in no-disclosure
        # mode, human art is mandatory for every referenced art id.
        if norm_variant == "ai-disclosure" and ai_rel:
            if not ai_rel.startswith("art/ai/"):
                report.add(3, "art id %s ai path is not under art/ai/: %s" % (art_id, ai_rel))
                continue
            ai_full = os.path.join(stage, ai_rel)
            if not os.path.isfile(ai_full):
                report.add(3, "art id %s ai file is missing: %s" % (art_id, ai_rel))
                continue
            prov = str(entry.get("_provenance") or meta_prov).strip()
            if not prov and isinstance(csv_rows, dict):
                prov = _csv_ai_prov(csv_rows.get(ai_rel))
            if not AI_PROV.match(prov):
                report.add(
                    3,
                    "art id %s ai file %s _provenance is not ai:<tool>[:<model>]:YYYY-MM-DD:<id>"
                    % (art_id, ai_rel),
                )
            if not human or not os.path.isfile(human_full):
                if human and not human.startswith("art/cards/"):
                    report.add(3, "art id %s human path is not under art/cards/: %s" % (art_id, human))
                continue
        if not human.startswith("art/cards/"):
            report.add(3, "art id %s human path is not under art/cards/: %s" % (art_id, human or "<empty>"))
            continue
        if not os.path.isfile(human_full):
            report.add(3, "art id %s file is missing: %s" % (art_id, human))
            continue
        digest = sha256_file(human_full)
        row = csv_rows.get(human)
        if row is None:
            report.add(3, "art id %s file %s is not in ASSET_PROVENANCE.csv" % (art_id, human))
            continue
        if (row.get("sha256") or "").strip().lower() != digest:
            report.add(3, "art id %s sha256 does not match ASSET_PROVENANCE.csv" % art_id)
        author = (row.get("author") or "").strip()
        if author not in humans:
            report.add(3, "art id %s author %r is not in human_authors.json" % (art_id, author))
        if method_is_ai(row.get("method") or ""):
            report.add(3, "art id %s method is AI (%r)" % (art_id, row.get("method")))
    check_audio_manifests(stage, report, csv_rows, humans, norm_variant, src=src)


def check_media_blob(rel, digest, csv_rows, blacklist, report, item, variant="ai-disclosure", ai_summary=None):
    norm_variant = normalize_variant(variant)
    clean_rel = rel.replace("\\", "/")
    if clean_rel.startswith("res://"):
        clean_rel = clean_rel[len("res://"):]
    clean_rel = clean_rel.lstrip("./")
    if clean_rel.startswith("art/ai/") or clean_rel.startswith("audio/ai/"):
        if blacklist is None:
            report.add(item, "legacy hash blacklist is missing; %s cannot be cleared" % clean_rel)
        elif digest in blacklist:
            report.add(item, "%s sha256 is on the v0.4.2 legacy blacklist" % clean_rel)
        if norm_variant == "no-disclosure":
            report.add(
                item,
                "%s is an AI asset (%s) and must not be shipped in no-disclosure mode"
                % (clean_rel, AI_DISCLOSURE_LABEL),
            )
            return
        prov = ""
        if isinstance(ai_summary, dict):
            prov = str((ai_summary.get("file_provenance") or {}).get(clean_rel) or "").strip()
        if not prov and isinstance(csv_rows, dict):
            prov = _csv_ai_prov(csv_rows.get(clean_rel))
        if not AI_PROV.match(prov):
            report.add(item, "%s (%s) is missing valid ai:... _provenance" % (clean_rel, AI_DISCLOSURE_LABEL))
        if isinstance(csv_rows, dict) and clean_rel in csv_rows:
            expected = (csv_rows[clean_rel].get("sha256") or "").strip().lower()
            if expected and expected != digest:
                report.add(item, "%s sha256 does not match ASSET_PROVENANCE.csv" % clean_rel)
        return
    if csv_rows is None:
        report.add(item, "%s cannot be checked; ASSET_PROVENANCE.csv is missing" % rel)
        return
    row = csv_rows.get(rel)
    if row is None:
        report.add(item, "%s is not in ASSET_PROVENANCE.csv" % rel)
    elif (row.get("sha256") or "").strip().lower() != digest:
        report.add(item, "%s sha256 does not match ASSET_PROVENANCE.csv" % rel)
    if blacklist is None:
        report.add(item, "legacy hash blacklist is missing; %s cannot be cleared" % rel)
    elif digest in blacklist:
        report.add(item, "%s sha256 is on the v0.4.2 legacy blacklist" % rel)


def check_item_4(stage, report, csv_rows, blacklist, variant="ai-disclosure", ai_summary=None):
    found = False
    for rel in walk_files(stage):
        if not rel.lower().endswith(MEDIA_EXT):
            continue
        found = True
        digest = sha256_file(os.path.join(stage, rel))
        check_media_blob(rel, digest, csv_rows, blacklist, report, 4, variant=variant, ai_summary=ai_summary)
    if not found:
        report.add(4, "staging has no image or audio file to whitelist")


def check_item_5(stage, report, allow):
    if allow is None:
        report.add(5, "cjk_allowlist.json is missing; CJK scan cannot run")
        allow = {}
    for rel in walk_files(stage):
        full = os.path.join(stage, rel)
        if rel.endswith(".gd"):
            try:
                text = open(full, encoding="utf-8").read()
            except (OSError, UnicodeError):
                report.add(5, "%s is not valid UTF-8" % rel)
                continue
            strings, mask, reliable = gd_strings_and_mask(text)
            if not reliable:
                report.add(5, "%s: string literal is unclosed; scan is not reliable" % rel)
            if rel not in allow and not rel.startswith("data/cards/text/") and not rel.startswith("data/cards/text_ai/"):
                for line_no, content in strings:
                    if CJK_RE.search(content):
                        report.add(5, "%s:%d CJK in a string literal" % (rel, line_no))
                        break
            if rel.startswith("scripts/cards/ui/") or rel.startswith("scripts/cards/minigames/"):
                for match in COLOR_DOT_RE.finditer(mask):
                    name = match.group(1)
                    if name in ("WHITE", "TRANSPARENT"):
                        continue
                    # Color.html(...) is a call, reported once by COLOR_CALL_RE.
                    if mask[match.end():].lstrip().startswith("("):
                        continue
                    line_no = mask[:match.start()].count("\n") + 1
                    report.add(5, "%s:%d color literal Color.%s" % (rel, line_no, name))
                for match in COLOR_CALL_RE.finditer(mask):
                    if re.sub(r"\s+", "", match.group(0)) in COLOR_PARSE_EXCEPTIONS.get(rel, ()):
                        continue
                    line_start = mask[:match.start()].rfind("\n") + 1
                    line_end = mask.find("\n", match.start())
                    if line_end < 0:
                        line_end = len(mask)
                    # recover the call from the original line, the mask has strings blanked
                    orig_line = text.splitlines()[mask[:match.start()].count("\n")]
                    call_match = COLOR_CALL_RE.search(orig_line)
                    call = orig_line[call_match.start():] if call_match else orig_line
                    # trim at the matching paren roughly
                    if not color_call_allowed(call if call.rstrip().endswith(")") else call):
                        # Color(1, 1, 1, ...) is allowed; re-parse the original call span
                        depth = 0
                        started = False
                        end = call_match.start() if call_match else 0
                        begin = end
                        for k in range(begin, len(orig_line)):
                            if orig_line[k] == "(":
                                depth += 1
                                started = True
                            elif orig_line[k] == ")":
                                depth -= 1
                                if started and depth == 0:
                                    end = k + 1
                                    break
                        snippet = orig_line[begin:end] if end > begin else orig_line.strip()
                        if not color_call_allowed(snippet):
                            line_no = mask[:match.start()].count("\n") + 1
                            report.add(5, "%s:%d color literal %s" % (rel, line_no, snippet.strip()))
            for line_no, why in audio_hits(text):
                report.add(5, "%s:%d unguarded placeholder audio (%s)" % (rel, line_no, why))
        elif rel.endswith((".json", ".tscn", ".tres")):
            if rel.startswith("data/cards/text/") or rel.startswith("data/cards/text_ai/") or rel in allow:
                continue
            if rel.startswith("packs/") and rel.endswith(".json"):
                continue
            try:
                text = open(full, encoding="utf-8").read()
            except (OSError, UnicodeError):
                report.add(5, "%s is not valid UTF-8" % rel)
                continue
            if CJK_RE.search(text):
                report.add(5, "%s contains CJK and is not in cjk_allowlist.json" % rel)


def load_verdict_words():
    path = os.path.join(SCRIPT_ROOT, "tools", "cards", "audit", "verdict_words.json")
    if not os.path.isfile(path):
        return None
    data = load_json(path)
    words = data.get("words") if isinstance(data, dict) else data
    words = [w for w in words if isinstance(w, str) and w and w != "伪"]
    words.sort(key=len, reverse=True)
    return words


def check_item_6(stage, report, lint, variant="ai-disclosure"):
    norm_variant = normalize_variant(variant)
    words = load_verdict_words()
    if not words:
        report.add(6, "verdict_words.json is missing")
        words = []
    types = load_card_types(stage)
    text_root = os.path.join(stage, "data", "cards", "text")
    text_ai_root = os.path.join(stage, "data", "cards", "text_ai")
    roots = []
    if norm_variant == "no-disclosure":
        if os.path.isdir(text_root):
            roots.append(text_root)
        else:
            report.add(6, "data/cards/text is missing; verdict and percent checks cannot run")
    else:
        if os.path.isdir(text_root):
            roots.append(text_root)
        if os.path.isdir(text_ai_root):
            roots.append(text_ai_root)
        if not roots:
            report.add(6, "data/cards/text is missing; verdict and percent checks cannot run")
    roots.extend(pack_text_roots(stage, norm_variant))
    for cur_root in roots:
        for dirpath, _dirs, files in os.walk(cur_root):
            for name in sorted(files):
                if not name.endswith(".json"):
                    continue
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, stage).replace(os.sep, "/")
                try:
                    data = load_json(full)
                except (OSError, ValueError):
                    report.add(6, "%s is not valid JSON" % rel)
                    continue
                if not isinstance(data, dict):
                    continue
                is_obs = "/minigames/obs/" in ("/" + rel)
                for key, entry in data.items():
                    if str(key).startswith("_") or not isinstance(entry, dict):
                        continue
                    for s in player_strings(entry):
                        if "%" in s:
                            report.add(6, "%s: %s contains '%%'" % (rel, key))
                            break
                    targets = []
                    if is_obs:
                        targets = player_strings(entry)
                    else:
                        kind = types.get(str(key))
                        if kind in VERDICT_FIELDS:
                            for field in VERDICT_FIELDS[kind]:
                                value = dig(entry, field)
                                if isinstance(value, str):
                                    targets.append(value)
                    for s in targets:
                        for word in words:
                            if word in s:
                                report.add(6, "%s: %s contains verdict word %s" % (rel, key, word))
                                break
    if not lint or not os.path.isfile(lint):
        report.add(6, "wording_lint.py not found (%s); K13 check cannot run" % (lint or "<unset>"))
        return
    for cur_root in roots:
        cmd = [sys.executable, lint, cur_root, "--scope=text", "--fail-on=must"]
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        except (OSError, subprocess.TimeoutExpired) as exc:
            report.add(6, "wording_lint.py could not run: %s" % exc)
            return
        if proc.returncode != 0:
            tail = (proc.stdout or proc.stderr or "").strip().splitlines()
            detail = tail[-1] if tail else "exit %s" % proc.returncode
            report.add(6, "wording_lint.py --fail-on=must failed: %s" % detail)


def check_item_7(stage, report, variant="ai-disclosure"):
    norm_variant = normalize_variant(variant)
    fonts = [
        ("fonts/NotoSerifSC-Regular-subset.otf", "Noto Serif SC"),
        ("fonts/MaShanZheng-Title-subset.ttf", "Ma Shan Zheng"),
    ]
    covered = []
    for rel, label in fonts:
        full = os.path.join(stage, rel)
        if not os.path.isfile(full):
            report.add(7, "%s is missing from staging" % rel)
            covered.append(None)
            continue
        try:
            covered.append(font_chars(full))
        except (OSError, ValueError, struct.error) as exc:
            report.add(7, "%s cmap could not be read: %s" % (rel, exc))
            covered.append(None)
    if any(c is None for c in covered):
        return
    text_root = os.path.join(stage, "data", "cards", "text")
    text_ai_root = os.path.join(stage, "data", "cards", "text_ai")
    roots = []
    if norm_variant == "no-disclosure":
        if not os.path.isdir(text_root):
            report.add(7, "data/cards/text is missing; font coverage cannot be checked")
            return
        roots = [text_root]
    else:
        if os.path.isdir(text_root):
            roots.append(text_root)
        if os.path.isdir(text_ai_root):
            roots.append(text_ai_root)
        if not roots:
            report.add(7, "data/cards/text is missing; font coverage cannot be checked")
            return
    roots.extend(pack_text_roots(stage, norm_variant))
    missing = {}
    for cur_root in roots:
        for dirpath, _dirs, files in os.walk(cur_root):
            for name in sorted(files):
                if not name.endswith(".json"):
                    continue
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, stage).replace(os.sep, "/")
                try:
                    data = load_json(full)
                except (OSError, ValueError):
                    continue
                for s in player_strings(data):
                    for ch in s:
                        if ord(ch) < 32:
                            continue
                        cp = ord(ch)
                        for (font_rel, _label), chars in zip(fonts, covered):
                            if cp not in chars:
                                missing.setdefault((ch, font_rel), rel)
    for (ch, font_rel), rel in sorted(missing.items(), key=lambda kv: (kv[0][1], ord(kv[0][0]))):
        report.add(7, "U+%04X %s missing from %s (used in %s)" % (ord(ch), ch, font_rel, rel))


def check_item_8(stage, report):
    path = os.path.join(stage, "data", "cards", "theme", "palette.json")
    if not os.path.isfile(path):
        report.add(8, "data/cards/theme/palette.json is missing")
        return
    try:
        data = load_json(path)
    except (OSError, ValueError):
        report.add(8, "palette.json is not valid JSON")
        return
    prov = ""
    if isinstance(data, dict):
        prov = str(data.get("_meta", {}).get("_provenance", ""))
    if not PALETTE_PROV.match(prov):
        report.add(8, "palette.json _meta._provenance is not human:A:YYYY-MM-DD")


def check_item_9(pck_path, report, csv_rows, blacklist, variant="ai-disclosure", ai_summary=None):
    norm_variant = normalize_variant(variant)
    if not pck_path:
        return
    if not os.path.isfile(pck_path):
        report.add(9, "pck does not exist: %s" % pck_path)
        return
    try:
        files = read_pck(pck_path)
    except (OSError, ValueError, struct.error) as exc:
        report.add(9, "pck could not be read: %s" % exc)
        return
    media = False
    for entry in files:
        if entry["removal"]:
            continue
        rel = entry["path"]
        clean_rel = rel[len("res://"):] if rel.startswith("res://") else rel
        if path_forbidden(rel, norm_variant):
            report.add(9, "pck path %s must not be shipped" % rel)
        pack_match = re.match(r"^packs/([^/]+)/pack\.json$", clean_rel)
        if pack_match and not entry["encrypted"]:
            try:
                manifest = json.loads(entry["blob"].decode("utf-8"))
            except (UnicodeError, ValueError):
                manifest = None
            if not isinstance(manifest, dict):
                report.add(9, "pck %s is not valid JSON" % rel)
            else:
                if manifest.get("enabled", True) is False:
                    report.add(9, "pck story pack %s is disabled and must not be shipped" % pack_match.group(1))
                if norm_variant == "no-disclosure" and manifest.get("source") != "human":
                    report.add(9, "pck story pack %s is not human-written and must not be shipped in no-disclosure mode"
                               % pack_match.group(1))
        if clean_rel in ("project.godot", "project.binary") and not entry["encrypted"]:
            blob = entry["blob"]
            if clean_rel == "project.godot":
                main_scene, main_scene_ship = parse_project_main_scenes(blob.decode("utf-8", "replace"))
                effective = main_scene_ship or main_scene
                if effective != "res://scenes/cards/CardGame.tscn" or main_scene == "res://scenes/Main.tscn":
                    report.add(
                        9,
                        "pck project.godot main_scene must resolve to res://scenes/cards/CardGame.tscn "
                        "(got main_scene=%r, main_scene.ship=%r)" % (main_scene, main_scene_ship),
                    )
            elif b"res://scenes/Main.tscn" in blob and b"res://scenes/cards/CardGame.tscn" not in blob:
                report.add(
                    9,
                    "pck project.binary points main_scene at excluded res://scenes/Main.tscn "
                    "instead of res://scenes/cards/CardGame.tscn",
                )
        if not rel.lower().endswith(MEDIA_EXT):
            continue
        media = True
        if entry["encrypted"]:
            report.add(9, "pck file %s is encrypted; sha256 cannot be checked" % rel)
            continue
        check_media_blob(
            rel,
            sha256_bytes(entry["blob"]),
            csv_rows,
            blacklist,
            report,
            9,
            variant=norm_variant,
            ai_summary=ai_summary,
        )
    if not media:
        # A docs-only bad pack still needs the path check above. No media is OK
        # only when the caller is re-checking paths; item 4's "no media" rule is
        # for the staging tree. A pck with no media is not itself a failure.
        pass


def git_head(root):
    try:
        proc = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return "unknown"
    if proc.returncode != 0:
        return "unknown"
    return proc.stdout.strip() or "unknown"


def write_report(path, stage, report, when, commit, variant="ai-disclosure", ai_summary=None):
    norm_variant = normalize_variant(variant)
    ai_summary = ai_summary or collect_ai_assets(stage)
    labels = {
        1: "草稿键与不该进包的路径",
        2: "validate --mode=ship 与正文来源",
        3: "被引用的美术 id",
        4: "图片音频白名单与旧素材哈希",
        5: "中日韩、颜色字面量、占位音频守卫",
        6: "判词、百分号、措辞检查",
        7: "字体覆盖",
        8: "正式配色来源",
        9: ".pck 复查",
        10: "报告",
    }
    disclosure_state = (
        "%s (%d 项)" % (AI_DISCLOSURE_LABEL, ai_summary["total"])
        if ai_summary["total"] > 0
        else "无 AI 资产（无需 AI 声明）"
    )
    lines = [
        "# 发行审核",
        "",
        "- time: %s" % when,
        "- commit: %s" % commit,
        "- staging: %s" % stage,
        "- variant: %s" % norm_variant,
        "- ai_disclosure: %s" % disclosure_state,
        "",
    ]
    for n in range(1, 11):
        problems = report.items[n]
        status = "OK" if not problems else "FAIL"
        lines.append("## %d. %s" % (n, labels[n]))
        lines.append("")
        lines.append(status)
        if problems:
            shown = problems[:PRINT_CAP]
            for msg in shown:
                lines.append("- %s" % msg)
            extra = len(problems) - len(shown)
            if extra:
                lines.append("- … and %d more" % extra)
        lines.append("")
    lines.append("## AI 资产统计与来源声明")
    lines.append("")
    by_cat = ai_summary["by_category"]
    overridden = ai_summary["overridden_by_human"]
    tf = ai_summary.get("text_fields") or {"total": 0, "active_ai": 0, "overridden_by_human": 0, "partial_entries": 0}
    lines.append("- 状态: %s" % disclosure_state)
    lines.append(
        "- 分类统计: total=%d, art=%d, audio=%d, text=%d"
        % (ai_summary["total"], by_cat.get("art", 0), by_cat.get("audio", 0), by_cat.get("text", 0))
    )
    lines.append(
        "- 已被人工资产覆盖: art=%d, audio=%d, text=%d"
        % (len(overridden.get("art", [])), len(overridden.get("audio", [])), len(overridden.get("text", [])))
    )
    lines.append(
        "- 台词字段级统计: total_fields=%d, active_ai_fields=%d, overridden_fields=%d, partial_entries=%d"
        % (tf.get("total", 0), tf.get("active_ai", 0), tf.get("overridden_by_human", 0), tf.get("partial_entries", 0))
    )
    if ai_summary["by_source"]:
        lines.append("- 按工具/模型来源统计:")
        for src_name, cnt in sorted(ai_summary["by_source"].items()):
            lines.append("  - %s: %d (%s)" % (src_name, cnt, AI_DISCLOSURE_LABEL))
    if ai_summary["by_provenance"]:
        lines.append("- 按完整 _provenance 统计:")
        for prov, cnt in sorted(ai_summary["by_provenance"].items()):
            lines.append("  - %s: %d" % (prov, cnt))
    lines.append("")
    lines.append("AUDIT %s" % ("OK" if report.count() == 0 else "FAILED: %d problems" % report.count()))
    lines.append("")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))


def run_audit(stage, opts):
    try:
        variant = normalize_variant(opts)
    except ValueError as exc:
        print("audit: %s" % exc)
        return 2
    src = os.path.abspath(opts.get("src", SCRIPT_ROOT))
    report = Report()
    csv_path = find_legal(stage, src, "ASSET_PROVENANCE.csv")
    humans_path = find_legal(stage, src, "human_authors.json")
    try:
        csv_rows = load_csv(csv_path) if csv_path else None
    except (OSError, ValueError, UnicodeError) as exc:
        csv_rows = None
        report.add(3, "ASSET_PROVENANCE.csv could not be read: %s" % exc)
        report.add(4, "ASSET_PROVENANCE.csv could not be read: %s" % exc)
    humans = load_humans(humans_path)
    blacklist_path = opts.get("legacy-hashes", os.path.join(SCRIPT_ROOT, "docs", "cards", "audit", "legacy_hashes.json"))
    blacklist = load_blacklist(blacklist_path)
    allow_path = os.path.join(SCRIPT_ROOT, "tools", "cards", "audit", "cjk_allowlist.json")
    allow = None
    if os.path.isfile(allow_path):
        try:
            allow = load_json(allow_path).get("files") or {}
        except (OSError, ValueError):
            allow = None
    godot = opts.get("godot") or os.environ.get("GODOT", "")
    lint = opts.get("wording-lint") or os.path.join(SCRIPT_ROOT, "tools", "cards", "review", "wording_lint.py")
    ai_summary = collect_ai_assets(stage, csv_rows=csv_rows)
    check_item_1(stage, report, variant=variant)
    check_item_2(stage, report, godot, variant=variant)
    # The no-disclosure fallback to src's audio/ai/sfx/manifest.json only applies when --src is given
    # (package_steam.sh always passes it); a bare audit of a fixture stage must not read this repo's manifest.
    check_item_3(stage, report, csv_rows, humans, variant=variant, src=src if "src" in opts else None)
    check_item_4(stage, report, csv_rows, blacklist, variant=variant, ai_summary=ai_summary)
    check_item_5(stage, report, allow)
    check_item_6(stage, report, lint, variant=variant)
    check_item_7(stage, report, variant=variant)
    check_item_8(stage, report)
    if opts.get("pck"):
        check_item_9(opts.get("pck"), report, csv_rows, blacklist, variant=variant, ai_summary=ai_summary)
    # Item 10: the report itself. A missing destination is a failure.
    when = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    commit = git_head(src if os.path.isdir(os.path.join(src, ".git")) else SCRIPT_ROOT)
    report_path = opts.get("report", os.path.join(SCRIPT_ROOT, "docs", "cards", "audit", "last_audit.md"))
    try:
        write_report(report_path, stage, report, when, commit, variant=variant, ai_summary=ai_summary)
    except OSError as exc:
        report.add(10, "could not write report: %s" % exc)
        # try once more only if the failure was the first write; don't loop
    n = report.count()
    for item in range(1, 11):
        shown = 0
        for msg in report.items[item]:
            if shown >= PRINT_CAP:
                break
            print("AUDIT FAIL: item %d: %s" % (item, msg))
            shown += 1
        extra = len(report.items[item]) - shown
        if extra:
            print("AUDIT FAIL: item %d: … and %d more" % (item, extra))
    if n == 0:
        print("AUDIT OK")
        return 0
    print("AUDIT FAILED: %d problems" % n)
    return 1


def main(argv):
    pos, opts = parse_options(argv)
    if opts.get("build-legacy-hashes"):
        src = os.path.abspath(opts.get("src", SCRIPT_ROOT))
        dest = opts.get("legacy-hashes", os.path.join(SCRIPT_ROOT, "docs", "cards", "audit", "legacy_hashes.json"))
        return build_legacy_hashes(src, dest)
    if len(pos) != 1:
        print(__doc__)
        return 2
    return run_audit(os.path.abspath(pos[0]), opts)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
