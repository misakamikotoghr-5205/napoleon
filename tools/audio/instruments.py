"""Physical-modelling style instrument synthesis: plucked strings (guzheng, pipa,
yangqin) by Karplus-Strong with a pole-based loop filter, bowed/blown monophonic
voices (erhu, dizi, xiao) by additive synthesis + formants + noise.

No samples are used anywhere.  All randomness comes from dsp.rng_for(...).
"""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from scipy import signal

from dsp import (SR, biquad, bandpass_noise, hz2midi, lp_noise, midi2hz, one_pole_lp, pan_gains,
                 resonator_bank, rng_for, smoothstep)


# =========================================================================
#  Plucked strings
# =========================================================================
def _pd(b, a, f, sr=SR):
    """phase delay (samples) of polynomial filter b/a (in z^-1) at frequency f."""
    w = 2 * np.pi * f / sr
    z = np.exp(-1j * w)
    num = np.polyval(np.asarray(b, dtype=np.float64)[::-1], z)
    den = np.polyval(np.asarray(a, dtype=np.float64)[::-1], z)
    return float(-np.angle(num / den) / w)


def _h1(p, f, sr=SR):
    w = 2 * np.pi * f / sr
    return (1 - p) / np.sqrt(1 - 2 * p * np.cos(w) + p * p)


def design_loop(f0, t60, hf_ratio, inharm, sr=SR):
    """Return (N, b, a): integer delay N plus a 4th-order IIR loop filter
    (2-pole low-pass squared, dispersion all-pass, Thiran tuning all-pass)."""
    fh = float(np.clip(8.0 * f0, 1500.0, 5000.0))
    fh = max(fh, 2.2 * f0)
    L0 = 60.0 / (f0 * t60)                # dB lost per round trip at f0
    Lh = 60.0 / (f0 * t60 * hf_ratio)     # dB lost per round trip at fh
    target = Lh - L0
    lo, hi = 0.0, 0.96
    if target <= 0:
        p = 0.0
    else:
        for _ in range(48):
            mid = 0.5 * (lo + hi)
            val = 40 * np.log10(_h1(mid, f0, sr) / _h1(mid, fh, sr))
            if val < target:
                lo = mid
            else:
                hi = mid
        p = 0.5 * (lo + hi)
    g = 10 ** (-(L0 + 40 * np.log10(_h1(p, f0, sr))) / 20.0)
    g = min(g, 0.99995)
    b_lp = [(1 - p) ** 2]
    a_lp = [1.0, -2 * p, p * p]
    ad = -float(inharm)
    b_d, a_d = [ad, 1.0], [1.0, ad]
    tau_other = _pd(b_lp, a_lp, f0, sr) + _pd(b_d, a_d, f0, sr)
    R = sr / f0 - tau_other
    N = int(np.floor(R - 0.8))
    N = max(N, 2)
    D = R - N
    lo, hi = -0.6, 0.6
    for _ in range(50):
        mid = 0.5 * (lo + hi)
        pdv = _pd([mid, 1.0], [1.0, mid], f0, sr)
        if pdv > D:
            lo = mid
        else:
            hi = mid
    at = 0.5 * (lo + hi)
    b = g * b_lp[0] * np.convolve(b_d, [at, 1.0])
    a = np.convolve(np.convolve(a_lp, a_d), [1.0, at])
    return N, np.asarray(b, dtype=np.float64), np.asarray(a, dtype=np.float64)


def ks_string(f0, n_out, t60, hf_ratio, pos, exc_fc, noise, inharm, rng, sr=SR):
    """One plucked string; returns n_out samples of 'bridge force'-like signal."""
    N, b, a = design_loop(f0, t60, hf_ratio, inharm, sr)
    Lx = int(round(sr / f0))
    npls = max(1, int(round(pos * Lx)))
    pulse = np.full(Lx, -pos)
    pulse[:npls] = 1.0 - pos
    pulse /= np.std(pulse) + 1e-12
    nz = rng.standard_normal(Lx)
    nz -= nz.mean()
    nz /= np.std(nz) + 1e-12
    x = (1 - noise) * pulse + noise * nz
    # brightness of the excitation (softer plucks -> darker)
    if exc_fc < sr * 0.4:
        xx = np.concatenate([x[-16:], x, np.zeros(8)])  # periodic-ish warm-up so the pulse edge is not smeared at wrap
        xx = one_pole_lp(one_pole_lp(xx, exc_fc, sr), exc_fc, sr)
        x = xx[16:16 + Lx]
    y = np.zeros(n_out)
    m = min(Lx, n_out)
    y[:m] = x[:m]
    zi = np.zeros(max(len(a), len(b)) - 1)
    prev = None
    for s in range(0, n_out, N):
        blk = y[s:s + N]
        if prev is not None:
            blk += prev[:len(blk)]
        prev, zi = signal.lfilter(b, a, blk, zi=zi)
    return y


@dataclass
class PEvent:
    t: float                 # onset, seconds
    midi: float
    vel: float = 0.7
    kind: str = "pluck"      # pluck | trem | harm | roll
    dur: float = 0.0         # nominal length (needed for trem / roll)
    ring: float = 0.0        # maximum ring time (0 = natural)
    bend: float = 0.0        # semitones pressed up after the pluck (按音)
    bend_delay: float = 0.10
    bend_time: float = 0.22
    pos: float = 0.0         # pluck position override
    pan: float = 0.0         # extra pan offset
    extra: dict = field(default_factory=dict)


# Per-instrument string models ------------------------------------------------
def _string_params(inst: str, midi: float, vel: float):
    v = float(np.clip(vel, 0.05, 1.0))
    if inst == "guzheng":
        t60 = 6.0 * 2 ** (-(midi - 45.0) / 19.0) * (0.75 + 0.5 * v)
        return dict(t60=float(np.clip(t60, 0.9, 7.0)), hf_ratio=0.16, pos=0.17, exc_fc=1500 + 4300 * v ** 1.2,
                    noise=0.10, inharm=0.012, click=0.16, level=1.0)
    if inst == "pipa":
        t60 = 2.2 * 2 ** (-(midi - 57.0) / 22.0) * (0.8 + 0.4 * v)
        return dict(t60=float(np.clip(t60, 0.6, 3.6)), hf_ratio=0.085, pos=0.125, exc_fc=2200 + 5200 * v ** 1.2,
                    noise=0.20, inharm=0.045, click=0.42, level=1.0)
    if inst == "yangqin":
        t60 = 1.5 * 2 ** (-(midi - 62.0) / 26.0) * (0.8 + 0.4 * v)
        return dict(t60=float(np.clip(t60, 0.45, 2.2)), hf_ratio=0.09, pos=0.10, exc_fc=2800 + 6000 * v ** 1.2,
                    noise=0.12, inharm=0.085, click=0.48, level=1.0)
    raise ValueError(inst)


def render_pluck(inst: str, ev: PEvent, rng, sr=SR) -> np.ndarray:
    """Render a single plucked event (mono)."""
    midi = ev.midi
    if ev.kind == "harm":
        return _render_harmonic(ev, rng, sr)
    P = _string_params(inst, midi, ev.vel)
    br = float(ev.extra.get("bright", 1.0)) if ev.extra else 1.0
    P["exc_fc"] *= br
    P["click"] *= br
    f0 = float(midi2hz(midi))
    pos = ev.pos if ev.pos > 0 else P["pos"] * float(rng.uniform(0.93, 1.07))
    ring = ev.ring if ev.ring > 0 else P["t60"]
    ring = min(ring, P["t60"] * 1.05)
    # bending changes the length through varispeed, render a little longer
    n_base = int((ring + 0.1) * sr)
    y = ks_string(f0, n_base, P["t60"], P["hf_ratio"], pos, P["exc_fc"], P["noise"], P["inharm"], rng, sr)
    if inst in ("guzheng",) and ring > 1.2:
        # second polarisation: slightly detuned, longer-lived (two-stage decay)
        y2 = ks_string(f0 * 1.0006, n_base, P["t60"] * 2.2, P["hf_ratio"], pos * 1.15, P["exc_fc"] * 0.8, P["noise"] * 0.5,
                       P["inharm"], rng, sr)
        y = y + 0.20 * y2
    if inst == "yangqin":
        # paired courses, a few cents apart -> bright shimmer
        y2 = ks_string(f0 * 1.0021, n_base, P["t60"] * 0.9, P["hf_ratio"], pos, P["exc_fc"], P["noise"], P["inharm"], rng, sr)
        y = 0.62 * y + 0.5 * y2
    # nail / hammer click
    nc = int(0.006 * sr)
    t = np.arange(nc) / sr
    click = rng.standard_normal(nc) * np.exp(-t / 0.0011)
    b, a = biquad("hp", 1800, 0.7)
    click = signal.lfilter(b, a, click)
    b, a = biquad("lp", 6500, 0.7)
    click = signal.lfilter(b, a, click)
    # normalise on first 180 ms RMS so that velocity maps to loudness
    ref = np.sqrt(np.mean(y[:int(0.18 * sr)] ** 2)) + 1e-12
    y = y / ref
    y[:nc] += P["click"] * (0.4 + 0.6 * ev.vel) * click / (np.std(click) + 1e-12) * 0.6
    amp = 0.11 * (ev.vel ** 1.25) * P["level"]
    y *= amp
    if ev.bend != 0.0:
        y = _varispeed_bend(y, ev.bend, ev.bend_delay, ev.bend_time, sr)
    n = len(y)
    # natural ring then fade
    nfade = int(min(0.25, max(0.04, ring * 0.12)) * sr)
    n_end = int(min(n, ring * sr + (0.0 if ev.bend == 0 else 0.1 * sr)))
    y = y[:n_end].copy()
    if nfade < n_end:
        y[-nfade:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, nfade)))
    nin = int(0.0004 * sr)
    y[:nin] *= np.linspace(0, 1, nin)
    return y


def _varispeed_bend(y, semis, delay_s, time_s, sr=SR):
    n = len(y)
    t = np.arange(n) / sr
    s = semis * smoothstep((t - delay_s) / max(time_s, 1e-3))
    rate = 2.0 ** (s / 12.0)
    tau = np.cumsum(rate) / 1.0  # in source samples
    tau = tau - rate[0]
    keep = tau < (n - 2)
    tau = tau[keep]
    return np.interp(tau, np.arange(n), y)


def _render_harmonic(ev: PEvent, rng, sr=SR):
    """泛音: near-pure bell tone with a very short pluck, slow shimmer."""
    f0 = float(midi2hz(ev.midi))
    ring = ev.ring if ev.ring > 0 else 3.2 * (0.7 + 0.5 * ev.vel)
    n = int(ring * sr)
    t = np.arange(n) / sr
    dec = np.exp(-t / (ring / 6.9))
    ph = rng.uniform(0, 2 * np.pi, 4)
    y = np.sin(2 * np.pi * f0 * t + ph[0])
    y += 0.30 * np.sin(2 * np.pi * f0 * 2.0007 * t + ph[1]) * np.exp(-t / 0.5)
    y += 0.06 * np.sin(2 * np.pi * f0 * 3.0021 * t + ph[2]) * np.exp(-t / 0.25)
    beat = 1.0 + 0.10 * np.sin(2 * np.pi * (0.35 + 0.2 * rng.random()) * t + ph[3])
    y = y * dec * beat
    a_in = int(0.0025 * sr)
    y[:a_in] *= np.linspace(0, 1, a_in)
    nc = int(0.004 * sr)
    c = rng.standard_normal(nc) * np.exp(-np.arange(nc) / sr / 0.0009)
    y[:nc] += 0.10 * c
    y *= 0.17 * ev.vel ** 1.2
    nfade = int(0.3 * sr)
    y[-nfade:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, nfade)))
    return y


# Stream-level rendering ------------------------------------------------------
BODY = {
    # (freq, Q, linear gain) - soundboard / box resonances
    "guzheng": [(190, 6.0, 0.55), (430, 5.0, 0.38), (900, 4.0, 0.22), (2200, 3.0, 0.08)],
    "pipa": [(230, 6.0, 0.50), (520, 5.0, 0.30), (1250, 3.5, 0.30), (1900, 3.0, 0.18)],
    "yangqin": [(310, 5.0, 0.35), (780, 4.0, 0.30), (1700, 3.5, 0.15)],
}
PAN_BASE = {"guzheng": 0.05, "pipa": -0.38, "yangqin": 0.45}
PAN_SPREAD = {"guzheng": 0.32, "pipa": 0.10, "yangqin": 0.18}
PAN_CENTER_MIDI = {"guzheng": 62.0, "pipa": 60.0, "yangqin": 70.0}


def render_plucked_stream(inst: str, events: list[PEvent], n_total: int, seed_key: str, sr=SR):
    """Mix a list of PEvent into a stereo (n,2) array (body resonance applied)."""
    out = np.zeros((n_total, 2))
    rng = rng_for(seed_key, inst, "pluck")
    for ev in sorted(events, key=lambda e: e.t):
        i0 = int(round(ev.t * sr))
        if i0 >= n_total or i0 < 0:
            continue
        if ev.kind == "trem":
            sig = _render_tremolo(inst, ev, rng, sr)
        elif ev.kind == "roll":
            sig = _render_tremolo(inst, ev, rng, sr, rate=(18.0, 24.0))
        else:
            sig = render_pluck(inst, ev, rng, sr)
        n = min(len(sig), n_total - i0)
        base = PAN_BASE.get(inst, 0.0) + ev.pan
        spr = PAN_SPREAD.get(inst, 0.0)
        p = base + spr * float(np.clip((ev.midi - PAN_CENTER_MIDI.get(inst, 60.0)) / 18.0, -1.2, 1.2))
        gl, gr = pan_gains(p)
        out[i0:i0 + n, 0] += gl * sig[:n]
        out[i0:i0 + n, 1] += gr * sig[:n]
    for ch in range(2):
        out[:, ch] = resonator_bank(out[:, ch], BODY[inst], sr)
    return out


def _render_tremolo(inst, ev: PEvent, rng, sr=SR, rate=(11.0, 15.0)):
    """轮指 (pipa) / 竹击 roll (yangqin): rapid repeated plucks with a swelling envelope."""
    dur = max(ev.dur, 0.3)
    br = float(ev.extra.get("bright", 1.0)) if ev.extra else 1.0
    tail = ev.ring if ev.ring > 0 else 1.2
    n_total = int((dur + tail) * sr)
    out = np.zeros(n_total)
    t = 0.0
    r0 = rate[0] + (rate[1] - rate[0]) * float(rng.random())
    k = 0
    while t < dur:
        x = t / dur
        env = (0.55 + 0.45 * np.sin(np.pi * min(1.0, x * 0.9 + 0.05))) if dur > 0.8 else 0.8
        v = ev.vel * (0.6 + 0.4 * env) * float(rng.uniform(0.82, 1.1))
        if k == 0:
            v = ev.vel * 1.0
        last = (t + 1.0 / r0) >= dur
        sub = PEvent(t=0.0, midi=ev.midi, vel=min(1.0, v), kind="pluck", ring=(tail if last else 0.55),
                     pos=(0.10 if (k % 2) else 0.14) * float(rng.uniform(0.95, 1.05)), extra={"bright": 0.7 * br})
        sig = render_pluck(inst, sub, rng, sr)
        i0 = int(t * sr)
        m = min(len(sig), n_total - i0)
        gain = 0.34 if not last else 0.5
        out[i0:i0 + m] += gain * sig[:m]
        t += (1.0 / r0) * float(rng.uniform(0.9, 1.1))
        k += 1
    return out


# =========================================================================
#  Monophonic voices (erhu, dizi, xiao)
# =========================================================================
@dataclass
class VNote:
    t: float
    dur: float
    midi: float
    dyn: float = 0.7
    slur: bool = False       # slurred into the next note (portamento / legato)
    gin: float = 0.0         # glide in from (midi - gin) semitones (non-slurred notes)
    vib: bool | None = None  # None = automatic (long notes)
    vib_depth: float = 1.0   # multiplier
    swell: float = 0.0       # extra bow/breath swell
    grace: bool = False
    port: float = 0.0        # portamento time override into the NEXT note


VOICES = {
    "erhu": dict(attack=0.075, release=0.11, port=(0.07, 0.15), vib_rate=5.7, vib_cents=34, vib_delay=0.17,
                 vib_ramp=0.28, jitter=3.2, K=44, fmax=6500, a0=1.45, a1=0.55, noise=(1500, 4200, 0.014),
                 onset_noise=0.07, amp_vib=0.08, ref=0.2, nstages=2, amp_sync=0.10),
    "dizi": dict(attack=0.035, release=0.07, port=(0.03, 0.06), vib_rate=5.0, vib_cents=7, vib_delay=0.35,
                 vib_ramp=0.4, jitter=1.5, K=16, fmax=9000, a0=2.7, a1=1.0, noise=(2400, 4200, 0.016),
                 onset_noise=0.16, amp_vib=0.14, ref=0.2, nstages=2),
    "xiao": dict(attack=0.14, release=0.22, port=(0.10, 0.2), vib_rate=4.4, vib_cents=9, vib_delay=0.5,
                 vib_ramp=0.6, jitter=2.0, K=8, fmax=5000, a0=3.2, a1=1.0, noise=(700, 2300, 0.05),
                 onset_noise=0.30, amp_vib=0.06, ref=0.2, nstages=2),
}


def _interp_knots(knots, n, sr):
    ts = np.array([k[0] for k in knots])
    vs = np.array([k[1] for k in knots])
    # enforce strictly increasing
    keep = np.concatenate([[True], np.diff(ts) > 1e-6])
    ts, vs = ts[keep], vs[keep]
    return np.interp(np.arange(n) / sr, ts, vs)


def _build_contours(notes: list[VNote], P: dict, n_total: int, rng, kind: str, sr=SR):
    """Return (pitch in midi semitones, amplitude, onset-noise envelope, vibrato track), all [n_total]."""
    notes = sorted(notes, key=lambda x: x.t)
    knots = []
    for i, nt in enumerate(notes):
        prev = notes[i - 1] if i > 0 else None
        slurred_in = prev is not None and prev.slur and abs((prev.t + prev.dur) - nt.t) < 0.08
        gin = nt.gin if not slurred_in else 0.0
        p_start = nt.midi - gin
        if slurred_in:
            dd = prev.port if prev.port > 0 else float(rng.uniform(*P["port"]))
            dd = min(dd, 0.6 * prev.dur, 0.6 * nt.dur) if nt.dur > 0 else dd
            dd = max(dd, 0.012)
            a0, a1 = nt.t - 0.3 * dd, nt.t + 0.7 * dd
            knots.append((a0, prev.midi))
            for k in range(1, 12):
                x = k / 12.0
                knots.append((a0 + x * (a1 - a0), prev.midi + (p_start - prev.midi) * (3 * x * x - 2 * x ** 3)))
            knots.append((a1, p_start))
        else:
            if prev is not None:
                knots.append((nt.t - 0.014, prev.midi))
            knots.append((nt.t - 0.004, p_start))
        if gin != 0.0:
            tg = float(rng.uniform(0.07, 0.12))
            for k in range(1, 8):
                x = k / 8.0
                knots.append((nt.t + x * tg, p_start + (nt.midi - p_start) * (3 * x * x - 2 * x ** 3)))
            knots.append((nt.t + tg + 0.001, nt.midi))
        elif not slurred_in:
            knots.append((nt.t + 0.003, nt.midi))
        # hold until end of note
        knots.append((nt.t + max(nt.dur - 0.002, 0.004), nt.midi))
    # remove knots that violate monotonic time by stable sort
    knots.sort(key=lambda k: k[0])
    knots.insert(0, (0.0, knots[0][1]))
    knots.append((n_total / sr, knots[-1][1]))
    pitch = _interp_knots(knots, n_total, sr)

    # vibrato / jitter
    jit = lp_noise(n_total, 7.0, rng, sr) * (P["jitter"] / 100.0)
    pitch += jit
    amp = np.zeros(n_total)
    onset = np.zeros(n_total)
    vibtrack = np.zeros(n_total)
    vr = lp_noise(n_total, 1.5, rng, sr)
    vd = lp_noise(n_total, 1.2, rng, sr)
    for i, nt in enumerate(notes):
        prev = notes[i - 1] if i > 0 else None
        nxt = notes[i + 1] if i + 1 < len(notes) else None
        slurred_in = prev is not None and prev.slur and abs((prev.t + prev.dur) - nt.t) < 0.08
        i0 = int(nt.t * sr)
        n_note = int(nt.dur * sr)
        h = 0.035
        att = P["attack"] * (0.55 if nt.grace else 1.0)
        rel = P["release"] * (0.6 if nt.grace else 1.0)
        tail = int((rel + 0.05) * sr) if not nt.slur else int(0.1 * sr)
        lo = max(0, i0 - int(0.06 * sr))
        hi = min(n_total, i0 + n_note + tail)
        if hi <= lo:
            continue
        tt = (np.arange(lo, hi) / sr) - nt.t
        end = nt.dur
        # rise
        if slurred_in:
            rise = smoothstep((tt + h) / (2 * h))
        else:
            rise = smoothstep(tt / att)
        # fall
        if nt.slur and nxt is not None:
            fall = 1.0 - smoothstep((tt - end + h) / (2 * h))
        else:
            fall = 1.0 - smoothstep((tt - (end - 0.01)) / rel)
        # body: slight swell
        x = np.clip(tt / max(nt.dur, 1e-3), 0, 1)
        body = 1.0 + (0.07 + nt.swell) * np.sin(np.pi * x) if nt.dur > 0.5 else 1.0 + 0.0 * x
        env = rise * fall * body * nt.dyn
        amp[lo:hi] += env
        # onset noise burst envelope (bow change / breath chiff)
        if not slurred_in:
            ob = np.exp(-np.clip(tt, 0, None) / (0.035 if kind != "xiao" else 0.09)) * (tt >= -0.005)
            onset[lo:hi] += ob * nt.dyn
        # vibrato (rate and depth wander a little, like a real hand)
        use_vib = nt.vib if nt.vib is not None else (nt.dur >= 0.7)
        if use_vib and nt.dur > 0.3:
            rate = P["vib_rate"] * float(rng.uniform(0.94, 1.06))
            delay = P["vib_delay"]
            ramp = P["vib_ramp"]
            depth = P["vib_cents"] / 100.0 * nt.vib_depth * float(rng.uniform(0.85, 1.1))
            tpos = np.clip(tt, 0, nt.dur)
            vdepth = smoothstep((tpos - delay) / ramp) * (1.0 - smoothstep((tpos - (nt.dur - 0.06)) / 0.06 if not nt.slur else 0.0))
            r_t = rate * (1.0 + 0.07 * vr[lo:hi])
            ph = 2 * np.pi * np.cumsum(np.where(tt >= delay, r_t, 0.0)) / sr + float(rng.uniform(0, 6.28))
            seg = depth * (1.0 + 0.18 * vd[lo:hi]) * vdepth * np.sin(ph)
            seg = seg * ((tt >= 0) & (tt <= nt.dur + 0.02))
            pitch[lo:hi] += seg
            vibtrack[lo:hi] += seg
    return pitch, amp, onset, vibtrack


def render_voice(kind: str, notes: list[VNote], n_total: int, seed_key: str, sr=SR):
    """Render a monophonic expressive line.  Returns mono array."""
    P = VOICES[kind]
    rng = rng_for(seed_key, kind, "voice")
    if not notes:
        return np.zeros(n_total)
    pitch, amp, onset, vibtrack = _build_contours(notes, P, n_total, rng, kind, sr)
    # dizi/xiao: blown onsets overshoot a touch sharp, xiao scoops up from flat
    if kind in ("dizi", "xiao"):
        for nt in notes:
            i0 = int(nt.t * sr)
            n = int(0.25 * sr)
            tt = np.arange(n) / sr
            if kind == "dizi":
                bump = (0.28 * np.exp(-tt / 0.03)) if not nt.grace else np.zeros(n)
            else:
                bump = -0.28 * np.exp(-tt / 0.09)
            sl = slice(i0, min(n_total, i0 + n))
            pitch[sl] += bump[:sl.stop - sl.start] * (amp[sl] > 0.01)
    f = midi2hz(pitch)
    # amplitude micro-variation (breath / bow pressure)
    if kind == "dizi":
        av = 1.0 + P["amp_vib"] * lp_noise(n_total, 5.5, rng, sr) * 0.5 + 0.06 * np.sin(2 * np.pi * 5.2 * np.arange(n_total) / sr)
    elif kind == "xiao":
        av = 1.0 + 0.10 * lp_noise(n_total, 2.5, rng, sr)
    else:
        av = 1.0 + 0.05 * lp_noise(n_total, 6.0, rng, sr)
    E = amp * av * (1.0 + P.get("amp_sync", 0.0) * vibtrack / (P["vib_cents"] / 100.0))
    # active regions
    act = E > 2e-4
    idx = np.flatnonzero(act)
    out = np.zeros(n_total)
    if len(idx) == 0:
        return out
    gaps = np.flatnonzero(np.diff(idx) > int(0.12 * sr))
    starts = np.concatenate([[idx[0]], idx[gaps + 1]])
    ends = np.concatenate([idx[gaps], [idx[-1]]]) + 1
    phase_all = np.cumsum(2 * np.pi * f / sr)
    for s0, e0 in zip(starts, ends):
        s0 = max(0, s0 - 64)
        e0 = min(n_total, e0 + 64)
        for c0 in range(s0, e0, sr * 2):
            c1 = min(e0, c0 + sr * 2)
            out[c0:c1] = _harmonic_block(kind, P, phase_all[c0:c1], f[c0:c1], E[c0:c1], sr)
    # stream-level noise
    ln, hn, lvl = P["noise"]
    nz = bandpass_noise(n_total, ln, hn, rng, sr, stages=P.get('nstages', 1))
    env_n = lvl * (0.25 * E + 0.9 * P["onset_noise"] * onset)
    if kind == "erhu":
        env_n = env_n * (1.0 + 0.5 * np.clip(E, 0, 1))
    out = out * 1.0 + nz * env_n
    if kind == "dizi":
        # membrane (笛膜) buzz: odd-harmonic sizzle above 3 kHz, only when blowing hard
        lowband = signal.lfilter(*biquad("lp", 2600, 0.7), out)
        buzz = np.tanh(5.0 * lowband)
        buzz = signal.lfilter(*biquad("hp", 3200, 0.7), buzz)
        buzz = signal.lfilter(*biquad("lp", 9000, 0.7), buzz)
        mod = 0.7 + 0.3 * np.clip(lp_noise(n_total, 40.0, rng, sr), -1.5, 1.5)
        out = out + 0.06 * buzz * mod * np.clip(E, 0, 1) ** 1.3 * 1.0
    # fixed body / formants
    if kind == "erhu":
        for fc, q, g in [(260, 1.2, 3.0), (700, 3.0, 9.0), (1600, 3.5, 6.5), (3300, 3.0, 2.0)]:
            out = signal.lfilter(*biquad("peak", fc, q, g, sr), out)
        out = signal.lfilter(*biquad("lp", 5200, 0.6, sr=sr), out)
        out = signal.lfilter(*biquad("hp", 160, 0.7, sr=sr), out)
    elif kind == "dizi":
        out = signal.lfilter(*biquad("peak", 1500, 1.6, 3.0, sr), out)
        out = signal.lfilter(*biquad("peak", 3400, 1.5, 2.0, sr), out)
        out = signal.lfilter(*biquad("lp", 9500, 0.6, sr=sr), out)
        out = signal.lfilter(*biquad("hp", 300, 0.7, sr=sr), out)
    else:  # xiao
        out = signal.lfilter(*biquad("peak", 420, 1.3, 3.0, sr), out)
        out = signal.lfilter(*biquad("lp", 4200, 0.6, sr=sr), out)
        out = signal.lfilter(*biquad("hp", 90, 0.7, sr=sr), out)
    out *= _voice_gain(kind, pitch)
    return out


def _harmonic_block(kind, P, phase, f, E, sr):
    """Sum of harmonics via the Chebyshev recurrence, RMS-normalised."""
    Ec = np.clip(E, 0, 1.3)
    alpha = P["a0"] - P["a1"] * np.clip(Ec, 0, 1)
    c = np.cos(phase)
    s1 = np.sin(phase)
    sm1 = np.zeros_like(phase)
    sk = s1
    fm = P["fmax"]
    K = int(min(P["K"], np.ceil(fm / max(30.0, float(np.min(f))))))
    acc = np.zeros_like(phase)
    p2 = np.zeros_like(phase)
    for k in range(1, K + 1):
        w = np.exp(-alpha * np.log(k))
        w *= np.clip((fm - k * f) / (0.25 * fm), 0.0, 1.0)
        acc += w * sk
        p2 += w * w
        nxt = 2.0 * c * sk - sm1
        sm1, sk = sk, nxt
    norm = 1.0 / np.sqrt(0.5 * p2 + 1e-9)
    return acc * norm * E * P["ref"] * 0.5


_CAL: dict = {}
_CAL_RANGE = {"erhu": (60, 100), "dizi": (60, 102), "xiao": (52, 88)}


def _voice_gain(kind: str, pitch):
    """Per-pitch loudness equalisation (the formant filters make some registers louder):
    a gain curve measured once per process from a sweep of single notes, so that a sustained
    note at dyn 0.7 always has the same RMS (0.05 = -26 dBFS) whatever its pitch."""
    tab = _CAL.get(kind)
    if tab == "busy":
        return 1.0
    if tab is None:
        _CAL[kind] = "busy"
        lo, hi = _CAL_RANGE[kind]
        midis = np.arange(lo, hi + 1, 1.5)
        gains = []
        for m in midis:
            y = render_voice(kind, [VNote(t=0.1, dur=1.3, midi=float(m), dyn=0.7, vib=False)], int(1.7 * SR), "cal")
            seg = y[int(0.5 * SR):int(1.2 * SR)]
            gains.append(0.05 / (float(np.sqrt(np.mean(seg ** 2))) + 1e-12))
        g = np.array(gains)
        gs = np.convolve(np.pad(g, 1, mode="edge"), np.ones(3) / 3.0, mode="valid")
        tab = (midis, gs)
        _CAL[kind] = tab
    return np.interp(pitch, tab[0], tab[1])
