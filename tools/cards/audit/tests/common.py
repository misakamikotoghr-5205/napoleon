"""Helpers for the K15 audit tool tests. Not collected by unittest discovery."""
import hashlib
import os
import shutil
import struct
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
AUDIT = os.path.join(ROOT, "tools", "cards", "audit")
FIX = os.path.join(AUDIT, "fixtures")
GOOD = os.path.join(FIX, "good")
PY = sys.executable
MEDIA = (".png", ".jpg", ".jpeg", ".webp", ".svg", ".ogg", ".wav", ".mp3")


def run(cmd, cwd=None, env=None):
    return subprocess.run(cmd, cwd=cwd or ROOT, capture_output=True, text=True, env=env)


def audit_cmd(stage, report, pck=None, godot=None, lint=None, legacy=None, variant=None, env=None):
    cmd = [
        PY, os.path.join(AUDIT, "audit.py"), stage,
        "--report=" + report,
        "--godot=" + (godot or os.path.join(FIX, "fake_godot.py")),
        "--wording-lint=" + (lint or os.path.join(FIX, "wording_ok.py")),
    ]
    if pck:
        cmd.append("--pck=" + pck)
    if legacy:
        cmd.append("--legacy-hashes=" + legacy)
    if variant:
        cmd.append("--variant=" + variant)
    proc_env = os.environ.copy()
    proc_env["GODOT"] = ""
    if env:
        proc_env.update(env)
    return run(cmd, env=proc_env)


def item_lines(output, number):
    prefix = "AUDIT FAIL: item %d:" % number
    return [line for line in output.splitlines() if line.startswith(prefix)]


def build_stage(dst, overlay=None, legacy_candle=False):
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    shutil.copytree(GOOD, dst, symlinks=False)
    proj_path = os.path.join(dst, "project.godot")
    if not os.path.isfile(proj_path):
        with open(proj_path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(
                'config_version=5\n\n[application]\n'
                'config/name="Fixture"\n'
                'run/main_scene="res://scenes/cards/CardGame.tscn"\n'
                'run/main_scene.ship="res://scenes/cards/CardGame.tscn"\n'
            )
    scene_path = os.path.join(dst, "scenes", "cards", "CardGame.tscn")
    if not os.path.isfile(scene_path):
        os.makedirs(os.path.dirname(scene_path), exist_ok=True)
        with open(scene_path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write('[gd_scene format=3]\n\n[node name="CardGame" type="Node"]\n')
    music_json = os.path.join(dst, "data", "cards", "audio", "music.json")
    if not os.path.isfile(music_json):
        os.makedirs(os.path.dirname(music_json), exist_ok=True)
        with open(music_json, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(
                '{\n  "_meta": {\n    "owner": "C16",\n    "schema": 1\n  },\n'
                '  "cues": {\n    "day": {\n      "human": "audio/cards/music/day.ogg"\n    }\n  }\n}\n'
            )
    human_ogg = os.path.join(dst, "audio", "cards", "music", "day.ogg")
    if not os.path.isfile(human_ogg):
        os.makedirs(os.path.dirname(human_ogg), exist_ok=True)
        with open(human_ogg, "wb") as fh:
            fh.write(b"OggS-human-day-audio")
    if overlay and os.path.isdir(overlay):
        for dirpath, _dirs, files in os.walk(overlay):
            for name in files:
                src = os.path.join(dirpath, name)
                rel = os.path.relpath(src, overlay)
                target = os.path.join(dst, rel)
                os.makedirs(os.path.dirname(target), exist_ok=True)
                shutil.copy(src, target)
    if legacy_candle:
        os.makedirs(os.path.join(dst, "art", "cards"), exist_ok=True)
        shutil.copy(os.path.join(ROOT, "art", "tools", "candle.png"), os.path.join(dst, "art", "cards", "candle.png"))
    font_dir = os.path.join(dst, "fonts")
    os.makedirs(font_dir, exist_ok=True)
    for name in ("NotoSerifSC-Regular-subset.otf", "MaShanZheng-Title-subset.ttf"):
        dest = os.path.join(font_dir, name)
        if os.path.lexists(dest):
            os.remove(dest)
        os.symlink(os.path.join(ROOT, "fonts", name), dest)
    rows = ["path,sha256,author,method,source_file,license,license_file,order_no,no_ai_proof,date,reviewer"]
    for dirpath, _dirs, files in os.walk(dst):
        for name in sorted(files):
            if not name.lower().endswith(MEDIA):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, dst).replace(os.sep, "/")
            with open(full, "rb") as fh:
                digest = hashlib.sha256(fh.read()).hexdigest()
            rows.append(",".join([
                rel, digest, "painter-a", "paint", name, "CC-BY-4.0", "LICENSE", "1", "signed", "2026-01-15", "painter-a",
            ]))
    os.makedirs(os.path.join(dst, "legal"), exist_ok=True)
    csv_path = os.path.join(dst, "legal", "ASSET_PROVENANCE.csv")
    with open(csv_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(rows) + "\n")
    return dst


def write_pck(path, files):
    """Minimal Godot 4.7 (format version 4) unencrypted pck. files: [(path, bytes)]."""
    meta = []
    cursor = 0
    for rel, blob in files:
        if rel.startswith("res://"):
            rel = rel[len("res://"):]
        meta.append((rel, cursor, blob))
        cursor += len(blob)
    file_base = 104
    dir_off = file_base + cursor
    out = bytearray()
    out += struct.pack("<IIIIII", 0x43504447, 4, 4, 7, 1, 2)
    out += struct.pack("<Q", file_base)
    out += struct.pack("<Q", dir_off)
    out += b"\x00" * 64
    if len(out) != file_base:
        raise RuntimeError("pck header size drifted: %s" % len(out))
    for _rel, _ofs, blob in meta:
        out += blob
    directory = struct.pack("<I", len(meta))
    for rel, ofs, blob in meta:
        raw = rel.encode("utf-8")
        pad = (4 - (len(raw) % 4)) % 4
        directory += struct.pack("<I", len(raw) + pad)
        directory += raw + (b"\x00" * pad)
        directory += struct.pack("<QQ", ofs, len(blob))
        directory += hashlib.md5(blob).digest()
        directory += struct.pack("<I", 0)
    out += directory
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(out)
