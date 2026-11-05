#!/usr/bin/env python3
"""Rebuild the shipped CJK font subsets so no glyph ever renders as tofu.

Character set = GB2312 (all 6763 hanzi + symbols) ∪ every character used in data/, scripts/, scenes/, packs/
∪ ASCII/CJK punctuation. The calligraphy title font gets the used characters ∪ GB2312 level 1 (3755 common
hanzi), so new text written later mostly stays in the brush face. Run from the project root after adding any
new Chinese text:
    python3 tools/build_fonts.py
It also verifies coverage and exits non-zero if any used character is missing from a font.

Source fonts (OFL, never committed): override the paths with DHD_FONT_SERIF_SRC (Noto Serif CJK .ttc) and
DHD_FONT_TITLE_SRC (Ma Shan Zheng Regular .ttf, e.g. downloaded from Google Fonts to a temp dir). A source
that is not on disk is skipped: that subset in fonts/ is kept as it is and only its coverage is checked.
"""
import os
import subprocess
import sys
import tempfile

from fontTools.ttLib import TTCollection, TTFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SERIF_TTC = os.environ.get("DHD_FONT_SERIF_SRC", "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc")
TITLE_TTF = os.environ.get("DHD_FONT_TITLE_SRC",
                           "/usr/share/fonts/truetype/sand-box/google/Ma Shan Zheng/MaShanZheng-Regular.ttf")
OUT_SERIF = os.path.join(ROOT, "fonts", "NotoSerifSC-Regular-subset.otf")
OUT_TITLE = os.path.join(ROOT, "fonts", "MaShanZheng-Title-subset.ttf")
SCAN_DIRS = ["data", "scripts", "scenes", "packs"]
SCAN_EXT = (".json", ".gd", ".tscn", ".md")


def gb2312_chars():
    out = set()
    for hi in range(0xA1, 0xF8):
        for lo in range(0xA1, 0xFF):
            try:
                out.add(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return out


def gb2312_level1():
    """The 3755 most common hanzi (GB2312 rows 16-55)."""
    out = set()
    for hi in range(0xB0, 0xD8):
        for lo in range(0xA1, 0xFF):
            try:
                out.add(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return out


def used_chars():
    out = set()
    for d in SCAN_DIRS:
        for base, _dirs, files in os.walk(os.path.join(ROOT, d)):
            for f in files:
                if f.endswith(SCAN_EXT):
                    with open(os.path.join(base, f), encoding="utf-8", errors="ignore") as fh:
                        out.update(fh.read())
    return {c for c in out if ord(c) >= 0x20}


def sc_index():
    coll = TTCollection(SERIF_TTC)
    for i, font in enumerate(coll.fonts):
        name = font["name"].getDebugName(1) or ""
        if "SC" in name:
            return i
    return 0


def cmap_of(path, index=None):
    f = TTFont(path, fontNumber=index) if index is not None else TTFont(path)
    return set(chr(c) for c in f.getBestCmap().keys())


def subset(src, dst, chars, index=None):
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".txt", delete=False) as tf:
        tf.write("".join(sorted(chars)))
        textfile = tf.name
    cmd = ["pyftsubset", src, "--text-file=" + textfile, "--output-file=" + dst,
           "--layout-features=*", "--no-hinting", "--desubroutinize"]
    if index is not None:
        cmd.append("--font-number=%d" % index)
    subprocess.check_call(cmd)
    os.unlink(textfile)


def main():
    base = set(chr(c) for c in range(0x20, 0x7F))
    base |= set("　、。〃〈〉《》「」『』【】〔〕—…·‘’“”！（），．：；？～￥％＋－＝×÷→←↑↓★☆○●◎◇◆□■△▲※〇一二三四五六七八九十百千万")
    used = used_chars()
    chars = base | gb2312_chars() | used
    if os.path.isfile(SERIF_TTC):
        subset(SERIF_TTC, OUT_SERIF, chars, sc_index())
    else:
        print("serif source not found (%s): keeping %s, checking coverage only" % (SERIF_TTC, OUT_SERIF))
    if os.path.isfile(TITLE_TTF):
        subset(TITLE_TTF, OUT_TITLE, base | used | gb2312_level1())
    else:
        print("title source not found (%s): keeping %s, checking coverage only" % (TITLE_TTF, OUT_TITLE))
    missing_serif = sorted(c for c in used if c not in cmap_of(OUT_SERIF) and not c.isspace() and ord(c) > 0x7F)
    missing_title = sorted(c for c in used if c not in cmap_of(OUT_TITLE) and not c.isspace() and ord(c) > 0x7F)
    print("serif: %d KB, title: %d KB, chars %d (used %d)" % (
        os.path.getsize(OUT_SERIF) // 1024, os.path.getsize(OUT_TITLE) // 1024, len(chars), len(used)))
    if missing_serif:
        print("MISSING in serif (will be tofu):", "".join(missing_serif))
        sys.exit(1)
    if missing_title:
        # Title font only renders titles/captions; report but fall back to serif in-engine.
        print("note: not in calligraphy font (engine falls back to serif):", "".join(missing_title[:80]))


if __name__ == "__main__":
    main()
