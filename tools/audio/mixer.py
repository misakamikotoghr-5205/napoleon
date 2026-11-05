"""Stem rendering, bus mixing, reverb, loop folding and mastering."""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from scipy import signal

from dsp import (SR, Reverb, biquad, circular_limit, db2lin, lin2db, lufs, pan_gains, rng_for, soft_clip,
                 spectral_centroid, true_peak)
from instruments import render_plucked_stream, render_voice

VOICE_PAN = {"erhu": -0.14, "dizi": 0.20, "xiao": 0.04}


@dataclass
class Mix:
    gain_db: dict = field(default_factory=dict)      # per instrument level
    send_db: dict = field(default_factory=dict)      # per instrument reverb send (relative to its dry level)
    pan: dict = field(default_factory=dict)          # per-voice pan override
    wet_db: float = -3.0
    rt60: float = 1.5
    damp: float = 0.35
    predelay_ms: float = 14.0
    dry_lp: float = 0.0          # >0: low-pass the dry bus (distant room)
    dry_shelf_db: float = 0.0    # high-shelf (6 kHz) on dry bus, negative = darker
    noise_db: float = -54.0      # room tone relative to music RMS
    target_lufs: float = -18.0
    tail_s: float = 8.0
    ceiling_db: float = -2.0
    fade_s: float = 1.2          # one-shots: closing fade


def render_stems(ctx, n_long: int, mix: Mix):
    stems = {}
    for inst, evs in ctx.pl.items():
        if evs:
            stems[inst] = render_plucked_stream(inst, evs, n_long, ctx.id)
    for inst, ns in ctx.vo.items():
        if ns:
            mono = render_voice(inst, ns, n_long, ctx.id)
            gl, gr = pan_gains(mix.pan.get(inst, VOICE_PAN[inst]))
            stems[inst] = np.stack([mono * gl, mono * gr], axis=1)
    return stems


def mix_down(stems: dict, mix: Mix, n_long: int):
    dry = np.zeros((n_long, 2))
    send = np.zeros((n_long, 2))
    for inst, st in stems.items():
        g = db2lin(mix.gain_db.get(inst, 0.0))
        dry += g * st
        send += g * db2lin(mix.send_db.get(inst, -6.0)) * st
    if mix.dry_lp > 0:
        b, a = biquad("lp", mix.dry_lp, 0.6)
        dry = signal.lfilter(b, a, dry, axis=0)
    if mix.dry_shelf_db != 0:
        b, a = biquad("highshelf", 6000, 0.7, mix.dry_shelf_db)
        dry = signal.lfilter(b, a, dry, axis=0)
    rv = Reverb(rt60=mix.rt60, damp=mix.damp, predelay_ms=mix.predelay_ms)
    wl, wr = rv.process(send[:, 0], send[:, 1])
    out = dry + db2lin(mix.wet_db) * np.stack([wl, wr], axis=1)
    # soft low-cut at 50 Hz (applied before folding: LTI, so folding stays exact)
    b, a = biquad("hp", 50.0, 0.7071)
    out = signal.lfilter(b, a, out, axis=0)
    return out, dry, send


def room_tone(n: int, key: str, level_rms: float):
    """Circular (loop-safe) quiet room noise: shaped in the frequency domain."""
    rng = rng_for(key, "room")
    out = np.zeros((n, 2))
    fr = np.fft.rfftfreq(n, 1.0 / SR)
    shape = np.zeros_like(fr)
    ok = fr > 40
    shape[ok] = 1.0 / np.sqrt(fr[ok] / 200.0 + 1.0)         # pinkish
    shape *= 1.0 / (1.0 + (fr / 2500.0) ** 2)                 # air
    shape *= 1.0 - np.exp(-(fr / 90.0) ** 2)                  # rumble out
    for ch in range(2):
        spec = (rng.standard_normal(len(fr)) + 1j * rng.standard_normal(len(fr))) * shape
        x = np.fft.irfft(spec, n)
        x *= level_rms / (np.sqrt(np.mean(x ** 2)) + 1e-12)
        out[:, ch] = x
    return out


def finish_loop(long_buf: np.ndarray, loop_n: int, tail_n: int, mix: Mix, key: str):
    """Fold the tail onto the head, add room tone, normalise loudness, limit (circularly)."""
    tail_n = min(tail_n, len(long_buf) - loop_n)
    loop = long_buf[:loop_n].copy()
    loop[:tail_n] += long_buf[loop_n:loop_n + tail_n]
    rms = np.sqrt(np.mean(loop ** 2)) + 1e-12
    loop += room_tone(loop_n, key, rms * db2lin(mix.noise_db))
    return normalise(loop, mix.target_lufs, mix.ceiling_db, circular=True)


def finish_oneshot(long_buf: np.ndarray, n_out: int, mix: Mix, key: str):
    buf = long_buf[:n_out].copy()
    nf = int(mix.fade_s * SR)
    buf[-nf:] *= (0.5 * (1 + np.cos(np.linspace(0, np.pi, nf))))[:, None]
    nin = int(0.004 * SR)
    buf[:nin] *= np.linspace(0, 1, nin)[:, None]
    return normalise(buf, mix.target_lufs, mix.ceiling_db, circular=False)


def normalise(x: np.ndarray, target_lufs: float, ceiling_db: float, circular: bool):
    x = x - np.mean(x, axis=0, keepdims=True)   # remove DC
    for _ in range(3):
        L = lufs(x)
        x = x * db2lin(target_lufs - L)
        ceil = db2lin(ceiling_db)
        tp = true_peak(x)
        if tp > ceil:
            if circular:
                x = circular_limit(x, ceiling=ceil * 0.97, attack_ms=4.0, release_ms=180.0)
            else:
                x = circular_limit(x, ceiling=ceil * 0.97, attack_ms=4.0, release_ms=180.0)
            x = soft_clip(x, 0.9 * ceil)
        else:
            break
    return x
