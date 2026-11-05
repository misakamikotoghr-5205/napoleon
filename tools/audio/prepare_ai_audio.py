#!/usr/bin/env python3
# #212-1 离线音频后处理；参照 W2_HANDOFF.md 的 10-18 决定与合同 §11/§12.7。
# AI 目录的 ownership、审核和发行登记依赖 AGY 的 #212-3/#202，本工具不修改登记文件。
r"""Convert a local MP3 to normalized Ogg Vorbis with ffmpeg (no network).

Example (run from any directory):
  python3 tools/audio/prepare_ai_audio.py /tmp/day.mp3 --kind music --id day \
      --tool google-flow --model lyria --date 2026-10-18 --prompt-id day-v1

Output: audio/ai/<kind>/<id>.ogg under --root (defaults to this repository).
Music entries are merged into data/cards/audio/music.json, consumed by C16.
SFX entries use audio/ai/sfx/manifest.json with the same `cues` entry shape;
this tool does not connect SFX playback. Each entry gets `ai` and `_provenance`.
Existing human paths and unrelated metadata/entries are preserved. No overwrite:
remove/move an existing AI output explicitly before replacing it. Run one job per
root at a time. Synthetic verification belongs in a temporary --root, never here.

Two-pass loudnorm targets -16 LUFS, -2 dBTP, LRA 11; output is 48 kHz Vorbis q5.
The encoded output is measured again: reject non-finite loudness (silence/too short),
LUFS error > 0.5 or true peak > -1 dBTP (allows lossy encoder overshoot).
Needs Python standard library and a local ffmpeg with libvorbis/loudnorm.
"""
from __future__ import annotations

import argparse
from datetime import date
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import tempfile

TARGET = 'loudnorm=I=-16:TP=-2:LRA=11'


def ffmpeg(args: list[str]) -> str:
    result = subprocess.run(
        ['ffmpeg', '-hide_banner', '-nostdin', '-nostats', *args],
        text=True, capture_output=True, check=True,
    )
    return result.stderr


def measure(path: Path) -> dict:
    log = ffmpeg([
        '-protocol_whitelist', 'file,pipe', '-i', str(path), '-map', '0:a:0',
        '-af', TARGET + ':print_format=json', '-f', 'null', '-',
    ])
    match = re.search(r'\{\s*"input_i".*?\}', log, re.S)
    if match is None:
        raise ValueError('ffmpeg did not report loudnorm measurements')
    values = json.loads(match.group())
    for key in ('input_i', 'input_tp', 'input_lra', 'input_thresh', 'target_offset'):
        if not math.isfinite(float(values[key])):
            raise ValueError('audio has no measurable loudness (silent or too short)')
    return values


def token(value: str) -> str:
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', value):
        raise argparse.ArgumentTypeError('use ASCII letters/digits with dot, underscore or hyphen')
    return value


def iso_date(value: str) -> str:
    try:
        if date.fromisoformat(value).isoformat() != value:
            raise ValueError()
    except ValueError:
        raise argparse.ArgumentTypeError('use a valid YYYY-MM-DD date') from None
    return value


def convert(args: argparse.Namespace) -> Path:
    source = args.source.resolve(strict=True)
    if not source.is_file() or source.suffix.lower() != '.mp3':
        raise ValueError('source must be a local .mp3 file')
    root = args.root.resolve(strict=True)
    relative = f'audio/ai/{args.kind}/{args.id}.ogg'
    output = root / relative
    manifest = root / ('data/cards/audio/music.json' if args.kind == 'music'
                       else 'audio/ai/sfx/manifest.json')
    # Do not follow output/manifest symlinks out of the selected root.
    for path in (output, manifest):
        if not path.resolve().is_relative_to(root):
            raise ValueError('destination escapes --root')
    if output.exists() or output.is_symlink():
        raise ValueError(f'output already exists: {output}')
    doc = json.loads(manifest.read_text(encoding='utf-8')) if manifest.exists() else {'cues': {}}
    if not isinstance(doc, dict) or not isinstance(doc.get('cues'), dict):
        raise ValueError('manifest must contain a cues object')
    cues = doc['cues']
    entry = cues.get(args.id, {})
    if not isinstance(entry, dict):
        raise ValueError('manifest cue must be an object')
    entry = dict(entry)
    entry.setdefault('human', f'audio/cards/{args.kind}/{args.id}.ogg')
    entry['ai'] = relative
    entry['_provenance'] = f'ai:{args.tool}:{args.model}:{args.date}:{args.prompt_id}'
    entry['source_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
    measured = measure(source)
    normalization = TARGET + (
        ':measured_I={input_i}:measured_TP={input_tp}:measured_LRA={input_lra}'
        ':measured_thresh={input_thresh}:offset={target_offset}:linear=true'
    ).format(**measured)
    # Encode and validate before publishing either the audio or its provenance.
    with tempfile.TemporaryDirectory(prefix='dh-ai-audio-') as temp:
        encoded = Path(temp) / 'normalized.ogg'
        ffmpeg([
            '-v', 'error', '-protocol_whitelist', 'file,pipe', '-i', str(source),
            '-map', '0:a:0', '-vn', '-map_metadata', '-1', '-af', normalization,
            '-ar', '48000', '-c:a', 'libvorbis', '-q:a', '5', str(encoded),
        ])
        verified = measure(encoded)
        lufs, peak = float(verified['input_i']), float(verified['input_tp'])
        if abs(lufs + 16) > 0.5 or peak > -1:
            raise ValueError(f'encoded audio outside loudness limits: {lufs} LUFS, {peak} dBTP')
        entry['normalization'] = {
            'method': 'ffmpeg loudnorm two-pass', 'target_lufs': -16, 'target_dbtp': -2,
            'target_lra': 11, 'sample_rate': 48000, 'measured_lufs': lufs, 'measured_dbtp': peak,
        }
        cues[args.id] = entry
        contents = json.dumps(doc, ensure_ascii=False, indent=2) + '\n'
        output.parent.mkdir(parents=True, exist_ok=True)
        manifest.parent.mkdir(parents=True, exist_ok=True)
        # Exclusive creation prevents accidental replacement of an existing asset.
        with output.open('xb') as dest:
            try:
                dest.write(encoded.read_bytes())
            except BaseException:
                output.unlink()
                raise
        staged: Path | None = None
        try:
            with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=manifest.parent,
                                             prefix='.audio-manifest-', delete=False) as dest:
                staged = Path(dest.name)
                dest.write(contents)
            staged.replace(manifest)
        except BaseException:
            output.unlink()
            raise
        finally:
            if staged is not None:
                staged.unlink(missing_ok=True)
    print(f'PASS: {relative} ({lufs:.2f} LUFS, {peak:.2f} dBTP)')
    print(f'PROVENANCE: {entry["_provenance"]} -> {manifest.relative_to(root)}')
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('source', type=Path)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--kind', choices=('music', 'sfx'), required=True)
    parser.add_argument('--id', type=token, required=True)
    parser.add_argument('--tool', type=token, required=True)
    parser.add_argument('--model', type=token, required=True)
    parser.add_argument('--date', type=iso_date, required=True, help='generation date, not conversion date')
    parser.add_argument('--prompt-id', type=token, required=True)
    args = parser.parse_args()
    try:
        convert(args)
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        detail = exc.stderr if isinstance(exc, subprocess.CalledProcessError) else str(exc)
        parser.exit(1, f'FAIL: {detail}\n')


if __name__ == '__main__':
    main()
