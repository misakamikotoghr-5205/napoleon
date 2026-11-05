#!/usr/bin/env python3
"""德厚当 / 青溪镇 1938 - procedural background music generator.

Everything is synthesised from code (Karplus-Strong strings, additive/formant bowed and
blown voices, Freeverb-style reverb).  No samples, no existing tunes, no percussion.

    python3 gen_music.py                 # render + encode everything into audio/music/
    python3 gen_music.py title night     # only some tracks
    python3 gen_music.py --jobs 4        # parallel (default: number of CPUs, max 4)
    python3 gen_music.py --analyse       # print per-instrument / per-bar statistics

Needs numpy + scipy and an ffmpeg with libvorbis (falls back to the native vorbis encoder).
If scipy is missing the script builds ./venv and re-runs itself inside it.
Deterministic: all randomness is seeded from track/instrument names.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def _ensure_deps():
    try:
        import numpy  # noqa: F401
        import scipy  # noqa: F401
        return
    except ImportError:
        pass
    venv = os.path.join(HERE, "venv")
    py = os.path.join(venv, "bin", "python")
    if not os.path.exists(py):
        print("[gen_music] creating venv with numpy + scipy ...")
        subprocess.check_call([sys.executable, "-m", "venv", venv])
        subprocess.check_call([py, "-m", "pip", "install", "-q", "numpy", "scipy"])
    os.execv(py, [py] + sys.argv)


_ensure_deps()

import time  # noqa: E402
from concurrent.futures import ProcessPoolExecutor  # noqa: E402

import numpy as np  # noqa: E402
from scipy import signal  # noqa: E402
from scipy.io import wavfile  # noqa: E402

from dsp import SR, db2lin, lin2db, lufs, true_peak  # noqa: E402
from mixer import finish_loop, finish_oneshot, mix_down, render_stems  # noqa: E402
from tracks import TRACKS  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "..", "audio", "music"))  # res://audio/music
REPORTS = os.path.join(HERE, "reports")
FFMPEG = os.environ.get("FFMPEG", "/usr/bin/ffmpeg")


# --------------------------------------------------------------------------- rendering
def stem_stats(stems: dict) -> dict:
    res = {}
    for inst, st in stems.items():
        x = st.mean(axis=1)
        win = int(0.05 * SR)
        n = (len(x) // win) * win
        rms = np.sqrt(np.mean(x[:n].reshape(-1, win) ** 2, axis=1))
        act = rms > (rms.max() * 10 ** (-50 / 20) if rms.max() > 0 else 1)
        if not np.any(act):
            continue
        xa = x[:n].reshape(-1, win)[act].reshape(-1)
        f, p = signal.welch(xa, SR, nperseg=8192)
        mag = np.sqrt(p)
        res[inst] = dict(centroid_hz=float(np.sum(f * mag) / np.sum(mag)),
                         rms_db_active=float(lin2db(np.sqrt(np.mean(xa ** 2)))),
                         active_frac=float(np.mean(act)))
    return res


def density_per_bar(ctx) -> dict:
    out = {}
    edges = np.array([ctx.tm.start(b * ctx.bpb) for b in range(ctx.bars + 1)])
    for inst, evs in {**ctx.pl, **ctx.vo}.items():
        if not evs:
            continue
        ts = np.array([e.t for e in evs])
        h, _ = np.histogram(ts, bins=edges)
        out[inst] = dict(mean=float(h.mean()), max=int(h.max()), per_bar=[int(v) for v in h])
    return out


def render_track(tid: str, want_stats: bool = False):
    meta = TRACKS[tid]
    t0 = time.time()
    ctx = meta["build"]()
    mix = meta["mix"]
    if meta["loop"]:
        loop_n = int(round(ctx.loop_seconds * SR))
        n_long = loop_n + int(mix.tail_s * SR)
    else:
        loop_n = int(round(meta["dur_s"] * SR))
        n_long = loop_n
    stems = render_stems(ctx, n_long, mix)
    long_buf, dry, send = mix_down(stems, mix, n_long)
    if meta["loop"]:
        audio = finish_loop(long_buf, loop_n, int(mix.tail_s * SR), mix, tid)
    else:
        audio = finish_oneshot(long_buf, loop_n, mix, tid)
    info = dict(id=tid, loop_samples=int(loop_n), seconds=loop_n / SR, render_s=time.time() - t0, counts=ctx.counts())
    if want_stats:
        info["stems"] = stem_stats(stems)
        info["density"] = density_per_bar(ctx)
    return audio.astype(np.float32), info


# --------------------------------------------------------------------------- encode / verify
def encode_ogg(audio: np.ndarray, path: str):
    tmp = path + ".tmp.wav"
    wavfile.write(tmp, SR, audio.astype(np.float32))
    cmds = [[FFMPEG, "-y", "-loglevel", "error", "-i", tmp, "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis", "-q:a", "5", "-ar", str(SR), "-ac", "2", path],
            [FFMPEG, "-y", "-loglevel", "error", "-i", tmp, "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "vorbis", "-strict", "-2", "-q:a", "5", "-ar", str(SR),
             "-ac", "2", path]]
    for cmd in cmds:
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode == 0:
            break
    else:
        raise RuntimeError("ffmpeg failed: " + r.stderr)
    os.remove(tmp)


def decode_ogg(path: str) -> np.ndarray:
    r = subprocess.run([FFMPEG, "-loglevel", "error", "-i", path, "-f", "f32le", "-ar", str(SR), "-ac", "2", "pipe:1"],
                       capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode())
    return np.frombuffer(r.stdout, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def seam_metrics(x: np.ndarray) -> dict:
    """Loop-point check: wrap-around jump vs the typical sample-to-sample step near the seam."""
    n20 = int(0.02 * SR)
    seam = np.concatenate([x[-n20:], x[:n20]], axis=0)
    steps = np.abs(np.diff(seam, axis=0))
    jump = float(np.max(np.abs(x[0] - x[-1])))
    ref = float(np.percentile(steps, 99)) + 1e-9
    rms_tail = float(np.sqrt(np.mean(x[-n20:] ** 2)) + 1e-12)
    rms_head = float(np.sqrt(np.mean(x[:n20] ** 2)) + 1e-12)
    return dict(edge_jump=jump, seam_step_p99=ref, seam_ratio=jump / ref,
                tail_rms_db=lin2db(rms_tail), head_rms_db=lin2db(rms_head))


def verify(path: str, loop: bool, expect_samples: int | None = None) -> dict:
    x = decode_ogg(path)
    mono = x.mean(axis=1)
    f, p = signal.welch(mono, SR, nperseg=8192)
    lo = float(np.sum(p[f < 250]))
    tot = float(np.sum(p)) + 1e-18
    m = dict(samples=int(len(x)), seconds=len(x) / SR, peak_dbfs=lin2db(np.max(np.abs(x))), true_peak_dbtp=lin2db(true_peak(x)),
             rms_dbfs=lin2db(np.sqrt(np.mean(x ** 2))), lufs=lufs(x), dc=[float(v) for v in x.mean(axis=0)],
             silent=bool(np.max(np.abs(x)) < 1e-4), clipped_samples=int(np.sum(np.abs(x) >= 0.999)),
             low_freq_energy_ratio_below_250=lo / tot, centroid_hz=float(np.sum(f * np.sqrt(p)) / np.sum(np.sqrt(p))))
    if loop:
        m.update(seam_metrics(x))
    if expect_samples is not None:
        m["length_matches"] = (len(x) == expect_samples)
        m["length_diff_samples"] = int(len(x) - expect_samples)
    return m


# --------------------------------------------------------------------------- main
def _job(args):
    tid, analyse = args
    audio, info = render_track(tid, analyse)
    path = os.path.join(OUT, tid + ".ogg")
    encode_ogg(audio, path)
    ver = verify(path, TRACKS[tid]["loop"], info["loop_samples"])
    if TRACKS[tid]["loop"]:
        info["pre_encode_seam"] = seam_metrics(audio.astype(np.float64))
    info["verify"] = ver
    return info


def main(argv):
    analyse = "--analyse" in argv
    jobs = 4
    ids = []
    skip = False
    for i, a in enumerate(argv):
        if skip:
            skip = False
            continue
        if a == "--jobs":
            jobs = int(argv[i + 1])
            skip = True
        elif not a.startswith("--"):
            ids.append(a)
    ids = ids or list(TRACKS.keys())
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(REPORTS, exist_ok=True)
    t0 = time.time()
    # longest first for better parallel packing
    order = sorted(ids, key=lambda k: -TRACKS[k].get("dur_s", 150 if TRACKS[k]["loop"] else 6))
    jobs = max(1, min(jobs, len(order), os.cpu_count() or 1))
    if jobs == 1:
        results = [_job((i, analyse)) for i in order]
    else:
        with ProcessPoolExecutor(max_workers=jobs) as ex:
            results = list(ex.map(_job, [(i, analyse) for i in order]))
    results = {r["id"]: r for r in results}
    # manifest (merge with an existing one when only some tracks were rebuilt)
    mpath = os.path.join(OUT, "music.json")
    man = {"tracks": {}}
    if os.path.exists(mpath):
        try:
            man = json.load(open(mpath, encoding="utf-8"))
        except Exception:
            man = {"tracks": {}}
    for tid, meta in TRACKS.items():
        if tid in results:
            r = results[tid]
            entry = dict(file=tid + ".ogg", title=meta["title"], loop=meta["loop"],
                         loop_seconds=round(r["loop_samples"] / SR, 6) if meta["loop"] else round(r["seconds"], 3),
                         volume_db=meta["volume_db"], mood=meta["mood"])
            if meta["loop"]:
                entry["loop_samples"] = r["loop_samples"]
                entry["sample_rate"] = SR
            else:
                entry["duration_seconds"] = round(r["seconds"], 3)
            man["tracks"][tid] = entry
    man["tracks"] = {k: man["tracks"][k] for k in TRACKS if k in man["tracks"]}
    with open(mpath, "w", encoding="utf-8") as f:
        json.dump(man, f, ensure_ascii=False, indent=2)
    with open(os.path.join(REPORTS, "report.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=1, default=float)
    print(f"{'track':14s} {'sec':>7s} {'peak':>7s} {'TP':>7s} {'rms':>7s} {'LUFS':>7s} {'seam':>6s} {'DC':>9s} render_s")
    for tid in TRACKS:
        if tid not in results:
            continue
        r = results[tid]
        v = r["verify"]
        seam = f"{v['seam_ratio']:.2f}" if "seam_ratio" in v else "-"
        print(f"{tid:14s} {v['seconds']:7.2f} {v['peak_dbfs']:7.2f} {v['true_peak_dbtp']:7.2f} {v['rms_dbfs']:7.2f} "
              f"{v['lufs']:7.2f} {seam:>6s} {max(abs(d) for d in v['dc']):9.1e} {r['render_s']:.0f}"
              + ("" if v.get("length_matches", True) else f"  LENGTH DIFF {v['length_diff_samples']}")
              + ("  SILENT!" if v["silent"] else ""))
    print(f"total {time.time() - t0:.0f}s")
    if analyse:
        for tid, r in results.items():
            print("==", tid)
            for inst, s in r.get("stems", {}).items():
                d = r["density"].get(inst, {})
                print(f"  {inst:8s} centroid {s['centroid_hz']:6.0f} Hz  rms {s['rms_db_active']:6.1f} dB  active {s['active_frac']*100:4.0f}%"
                      f"  notes/bar mean {d.get('mean', 0):5.1f} max {d.get('max', 0):3d}")


if __name__ == "__main__":
    main(sys.argv[1:])
