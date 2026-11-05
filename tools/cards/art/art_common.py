# Shared helpers for the K12 placeholder art tools (stdlib only).
# Contract: docs/cards/CARDS_INTERFACES.md section 4.8, section 11.2, section 12.4.
# Colors come from data/cards/theme/palette.dev.json. Never read palette.json.

import json
import os
import struct
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

PLACEHOLDER_MANIFEST = "art/_placeholder/cards/manifest.json"
DATA_MANIFEST = "data/cards/art/manifest.json"
PALETTE_DEV = "data/cards/theme/palette.dev.json"
GENERATOR_NAME = "tools/cards/art/gen_placeholders.py"
SEED_RULE = "sha256(art_id)"
GENERATOR_VERSION = 2
MISSING_SIZE = (32, 32)
LIMIT_BYTES = 20 * 1024 * 1024

# Commands that look like wheel.<id> but are not art ids (CardIds.CMD_WHEEL_*).
NOT_ART = {
    "wheel.offer",
    "wheel.withdraw",
    "wheel.stake",
    "wheel.spin",
}

# Card frames the table actually draws (section 1.2 / K12), plus gold.
FRAME_TYPES = (
    "person",
    "self",
    "contact",
    "event",
    "fate",
    "big_fate",
    "demand",
    "life",
    "news",
    "kept",
    "estate",
    "night",
    "street",
    "prison",
)

# Guide row the first PR must already cover (handoff, "新手指引").
GUIDE_IDS = (
    "portrait.brother",
    "portrait.zhouma",
    "portrait.hu2",
    "portrait.suanming",
    "portrait.postman",
    "icon.obj.notice",
    "icon.obj.almanac",
    "icon.obj.brother_ledger",
    "frame.guide_bubble",
)

# Fixed draft stamp. "#" = paper glyph, "." = seal ground.
# U+7A3F traced once into a bitmap. Not drawn with FreeType at runtime
# (different machines' font rasterizers would change the PNG bytes).
# Pictures whose shorter side is >= 24 get the 16px stamp; 16px icons get the 8px one.
BADGE_16 = (
    "..........#.....",
    "...##......#....",
    "##.#..##########",
    "...#............",
    "...#....#######.",
    "#######.#....#..",
    "..##....#....#..",
    "..###...#....#..",
    "..##.###########",
    ".#.#.##.......#.",
    ".#.#..#..######.",
    "...#..#..#..#.#.",
    "...#..#..#..#.#.",
    "...#..#..#..#.#.",
    "...#..#.......#.",
    "...#..#.......#.",
)
BADGE_8 = (
    ".#...#..",
    ".#......",
    "###...#.",
    ".#....#.",
    "###.....",
    ".#..#...",
    ".#..#...",
    ".#......",
)


def parse_hex(h):
    s = h.lstrip("#")
    if len(s) == 6:
        return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)
    if len(s) == 8:
        return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), int(s[6:8], 16))
    raise ValueError("bad color %r" % h)


def load_palette():
    with open(os.path.join(ROOT, PALETTE_DEV), encoding="utf-8") as f:
        data = json.load(f)
    return {k: parse_hex(v) for k, v in data["colors"].items()}


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def badge_side(width, height):
    return 16 if min(width, height) >= 24 else 8


def badge_rows(side):
    return BADGE_16 if side >= 16 else BADGE_8


def badge_pixels(pal, side=8):
    """Return `side` rows of `side` RGBA tuples."""
    paper = pal["paper"]
    seal = pal.get("placeholder_seal", pal["seal"])   # draft stamp keeps its own red; the UI seal may change
    rows = []
    for bits in badge_rows(side):
        rows.append(tuple(paper if ch == "#" else seal for ch in bits))
    return rows


def png_ihdr(path):
    """Return (w, h, bit_depth, color_type) or None if not a PNG."""
    with open(path, "rb") as f:
        sig = f.read(8)
        if sig != b"\x89PNG\r\n\x1a\n":
            return None
        ln = int.from_bytes(f.read(4), "big")
        typ = f.read(4)
        if typ != b"IHDR" or ln < 13:
            return None
        w, h, bit, color = struct.unpack(">IIBB", f.read(10))
        return w, h, bit, color


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png_rgba(path):
    """Decode an 8-bit RGBA PNG. Returns (w, h, rows of bytes) or raises ValueError."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a png")
    pos = 8
    w = h = bit = color = None
    idat = b""
    while pos + 8 <= len(data):
        ln = int.from_bytes(data[pos:pos + 4], "big")
        typ = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if typ == b"IHDR":
            w, h = struct.unpack(">II", chunk[:8])
            bit, color = chunk[8], chunk[9]
        elif typ == b"IDAT":
            idat += chunk
        elif typ == b"IEND":
            break
    if bit != 8 or color != 6:
        raise ValueError("not 8-bit RGBA")
    raw = zlib.decompress(idat)
    stride = w * 4
    rows = []
    i = 0
    prev = bytearray(stride)
    for _y in range(h):
        filt = raw[i]
        i += 1
        row = bytearray(raw[i:i + stride])
        i += stride
        recon = bytearray(stride)
        for x in range(stride):
            a = recon[x - 4] if x >= 4 else 0
            b = prev[x]
            c = prev[x - 4] if x >= 4 else 0
            if filt == 0:
                v = row[x]
            elif filt == 1:
                v = (row[x] + a) & 255
            elif filt == 2:
                v = (row[x] + b) & 255
            elif filt == 3:
                v = (row[x] + ((a + b) // 2)) & 255
            elif filt == 4:
                v = (row[x] + _paeth(a, b, c)) & 255
            else:
                raise ValueError("bad filter")
            recon[x] = v
        prev = recon
        rows.append(bytes(recon))
    return w, h, rows


def sha256_file(path):
    import hashlib
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(65536), b""):
            h.update(block)
    return h.hexdigest()


def expected_nine(art_id):
    """Nine-slice margins [left, top, right, bottom], or None if this id is not a frame.

    Card frames, frame.hero, frame.guide_bubble and frame.guide_note are 6.
    frame.dialog is 7 (contract section 4.8).
    """
    if not str(art_id).startswith("frame."):
        return None
    if art_id == "frame.dialog":
        return [7, 7, 7, 7]
    return [6, 6, 6, 6]


def is_generated_placeholder(rel):
    rel = rel.replace("\\", "/")
    return rel.startswith("art/_placeholder/")


# Godot 4.7.1 ResourceUID alphabet: ('z' - 'a') = 25 letters + ('9' - '0') = 9 digits (34 base chars).
GODOT_UID_ALPHABET = "abcdefghijklmnopqrstuvwxy012345678"

_PNG_IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="res://.godot/imported/{base}-{md5}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://{rel}"
dest_files=["res://.godot/imported/{base}-{md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def godot_uid_to_id(uid):
    if not isinstance(uid, str) or not uid.startswith("uid://"):
        return -1
    body = uid[6:]
    if not body:
        return -1
    val = 0
    for ch in body:
        idx = GODOT_UID_ALPHABET.find(ch)
        if idx < 0:
            return -1
        val = val * 34 + idx
    if val <= 0 or val >= (1 << 63):
        return -1
    return val


def godot_id_to_uid(val):
    if val <= 0 or val >= (1 << 63):
        raise ValueError("invalid Godot ResourceUID int %r" % val)
    out = []
    while val > 0:
        out.append(GODOT_UID_ALPHABET[val % 34])
        val //= 34
    return "uid://" + "".join(reversed(out))


def valid_godot_uid(uid):
    nid = godot_uid_to_id(uid)
    return nid > 0 and godot_id_to_uid(nid) == uid


def deterministic_godot_uid(rel):
    import hashlib
    rel = rel.replace("\\", "/")
    digest = hashlib.sha256(("godot-uid:" + rel).encode("utf-8")).digest()
    val = int.from_bytes(digest[:8], "big") & ((1 << 63) - 1)
    if val <= 0:
        val = 1
    return godot_id_to_uid(val)


def read_import_uid(path):
    if not os.path.isfile(path):
        return ""
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith('uid="') and line.endswith('"'):
                    uid = line[5:-1]
                    if valid_godot_uid(uid):
                        return uid
    except OSError:
        return ""
    return ""


def render_png_import(rel, uid=""):
    import hashlib
    rel = rel.replace("\\", "/")
    if not valid_godot_uid(uid):
        uid = deterministic_godot_uid(rel)
    md5 = hashlib.md5(("res://" + rel).encode("utf-8")).hexdigest()
    return _PNG_IMPORT_TEMPLATE.format(uid=uid, base=os.path.basename(rel), md5=md5, rel=rel)

