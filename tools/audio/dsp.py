"""Low-level DSP helpers for the 德厚当 music synthesiser (numpy + scipy only).

Everything here is deterministic: random numbers always come from
``rng_for(...)`` which derives a seed from string keys (crc32, not hash()).
"""
from __future__ import annotations

import zlib

import numpy as np
from scipy import ndimage, signal

SR = 44100


# ----------------------------------------------------------------- basics
def db2lin(db: float) -> float:
    return float(10.0 ** (db / 20.0))


def lin2db(x: float) -> float:
    return float(20.0 * np.log10(max(float(x), 1e-12)))


def rng_for(*keys) -> np.random.Generator:
    seed = zlib.crc32("|".join(str(k) for k in keys).encode("utf-8")) & 0xFFFFFFFF
    return np.random.default_rng(seed)


def midi2hz(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=np.float64) - 69.0) / 12.0)


def hz2midi(f):
    return 69.0 + 12.0 * np.log2(np.asarray(f, dtype=np.float64) / 440.0)


def pan_gains(p: float) -> tuple[float, float]:
    """Equal-power pan, p in [-1, 1] (left .. right)."""
    p = float(np.clip(p, -1.0, 1.0))
    th = (p + 1.0) * np.pi / 4.0
    return float(np.cos(th)), float(np.sin(th))


def smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


# ----------------------------------------------------------------- filters
def biquad(kind: str, f0: float, q: float = 0.7071, gain_db: float = 0.0, sr: int = SR):
    """RBJ cookbook biquad -> (b, a). kinds: lp hp bp peak lowshelf highshelf notch."""
    f0 = float(np.clip(f0, 5.0, sr * 0.49))
    w0 = 2.0 * np.pi * f0 / sr
    cw, sw = np.cos(w0), np.sin(w0)
    alpha = sw / (2.0 * q)
    A = 10.0 ** (gain_db / 40.0)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bp":  # constant 0 dB peak gain
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "notch":
        b = [1.0, -2 * cw, 1.0]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "peak":
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
        a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    elif kind == "lowshelf":
        sq = 2 * np.sqrt(A) * alpha
        b = [A * ((A + 1) - (A - 1) * cw + sq), 2 * A * ((A - 1) - (A + 1) * cw), A * ((A + 1) - (A - 1) * cw - sq)]
        a = [(A + 1) + (A - 1) * cw + sq, -2 * ((A - 1) + (A + 1) * cw), (A + 1) + (A - 1) * cw - sq]
    elif kind == "highshelf":
        sq = 2 * np.sqrt(A) * alpha
        b = [A * ((A + 1) + (A - 1) * cw + sq), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sq)]
        a = [(A + 1) - (A - 1) * cw + sq, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sq]
    else:
        raise ValueError(kind)
    b = np.asarray(b, dtype=np.float64)
    a = np.asarray(a, dtype=np.float64)
    return b / a[0], a / a[0]


def filt(x, kind, f0, q=0.7071, gain_db=0.0, sr=SR):
    b, a = biquad(kind, f0, q, gain_db, sr)
    return signal.lfilter(b, a, x, axis=0)


def one_pole_lp(x, fc, sr=SR):
    p = float(np.exp(-2.0 * np.pi * fc / sr))
    return signal.lfilter([1.0 - p], [1.0, -p], x, axis=0)


def lp_noise(n: int, fc: float, rng, sr=SR):
    """Unit-std low-pass noise (2 cascaded one-poles)."""
    x = rng.standard_normal(n + 2000)
    x = one_pole_lp(one_pole_lp(x, fc, sr), fc, sr)[1000:1000 + n]
    return x / (np.std(x) + 1e-12)


def bandpass_noise(n: int, f_lo: float, f_hi: float, rng, sr=SR, stages=1):
    x = rng.standard_normal(n)
    fc = np.sqrt(f_lo * f_hi)
    q = fc / (f_hi - f_lo)
    b, a = biquad("bp", fc, q, sr=sr)
    y = x
    for _ in range(stages):
        y = signal.lfilter(b, a, y)
    return y / (np.std(y) + 1e-12)


def resonator_bank(x, bands, sr=SR):
    """Parallel bank of resonant band-passes: x + sum(g_i * BP_i(x)).
    bands = [(freq, Q, gain_linear), ...]"""
    y = x.copy()
    for f, q, g in bands:
        b, a = biquad("bp", f, q, sr=sr)
        y += g * signal.lfilter(b, a, x, axis=0)
    return y


def delay(x, n: int):
    if n <= 0:
        return x
    out = np.zeros_like(x)
    out[n:] = x[:-n]
    return out


# ----------------------------------------------------------------- reverb
def _comb(x, D, fb, damp):
    y = x.copy()
    n = len(y)
    b = [1.0 - damp]
    a = [1.0, -damp]
    zi = np.zeros(1)
    prev = None
    for s in range(0, n, D):
        blk = y[s:s + D]
        if prev is not None:
            blk += fb * prev[:len(blk)]
        prev, zi = signal.lfilter(b, a, blk, zi=zi)
    return y


def _allpass(x, D, g=0.5):
    n = len(x)
    y = np.zeros(n)
    for s in range(0, n, D):
        e = min(s + D, n)
        yb = -g * x[s:e]
        if s > 0:
            yb = yb + x[s - D:e - D] + g * y[s - D:e - D]
        y[s:e] = yb
    return y


_COMBS = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
_APS = [556, 441, 341, 225]


class Reverb:
    """Freeverb-style stereo reverb (8 damped combs + 4 allpasses per channel) plus a few early
    reflections and a pre-delay.  ``rt60`` is the mid-band decay time in seconds (small hall: 1.2-1.9 s);
    ``damp`` darkens the tail (high frequencies decay faster)."""

    def __init__(self, rt60=1.5, damp=0.35, predelay_ms=14.0, spread=23, er_gain=0.5, scale=1.15):
        self.rt60, self.damp = rt60, damp
        self.pre = int(predelay_ms * SR / 1000.0)
        self.spread = spread
        self.er_gain = er_gain
        self.scale = scale

    def _chan(self, x, offset):
        acc = np.zeros(len(x))
        for d in _COMBS:
            D = int(d * self.scale) + offset
            fb = 10.0 ** (-3.0 * D / (SR * self.rt60))
            acc += _comb(x, D, fb, self.damp)
        acc *= 1.0 / len(_COMBS)
        for d in _APS:
            acc = _allpass(acc, d + offset, 0.5)
        return acc

    def process(self, sl, sr_):
        sl = delay(sl, self.pre)
        sr_ = delay(sr_, self.pre)
        wl = self._chan(sl, 0)
        wr = self._chan(sr_, self.spread)
        # early reflections (small hall, alternating sides)
        taps = [(7.3, 0.55, -0.6), (11.9, 0.45, 0.7), (17.1, 0.38, -0.3), (23.7, 0.32, 0.5),
                (31.3, 0.25, -0.8), (41.9, 0.2, 0.4)]
        er_l = np.zeros(len(sl))
        er_r = np.zeros(len(sl))
        mono = 0.5 * (sl + sr_)
        for ms, g, p in taps:
            n = int(ms * SR / 1000.0)
            gl, gr = pan_gains(p)
            d = delay(mono, n)
            er_l += g * gl * d
            er_r += g * gr * d
        wl = wl * 3.0 + self.er_gain * 0.35 * er_l
        wr = wr * 3.0 + self.er_gain * 0.35 * er_r
        # air absorption / rumble removal on the wet signal
        b, a = biquad("lp", 6500, 0.6)
        wl = signal.lfilter(b, a, wl)
        wr = signal.lfilter(b, a, wr)
        b, a = biquad("hp", 180, 0.7)
        wl = signal.lfilter(b, a, wl)
        wr = signal.lfilter(b, a, wr)
        return wl, wr


# ----------------------------------------------------------------- loudness / peaks
def _k_weight(x, sr=SR):
    # BS.1770 K-weighting (shelf + RLB high-pass), coefficients for arbitrary fs
    G, Q, fc = 3.999843853973347, 0.7071752369554196, 1681.9744509555319
    A = 10.0 ** (G / 40.0)
    w0 = 2 * np.pi * fc / sr
    alpha = np.sin(w0) / (2 * Q)
    cw = np.cos(w0)
    sq = 2 * np.sqrt(A) * alpha
    b = np.array([A * ((A + 1) + (A - 1) * cw + sq), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sq)])
    a = np.array([(A + 1) - (A - 1) * cw + sq, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sq])
    y = signal.lfilter(b / a[0], a / a[0], x, axis=0)
    fc2, Q2 = 38.13547087613982, 0.5003270373253953
    K = np.tan(np.pi * fc2 / sr)
    den = 1 + K / Q2 + K * K
    a2 = np.array([1.0, 2 * (K * K - 1) / den, (1 - K / Q2 + K * K) / den])
    b2 = np.array([1.0, -2.0, 1.0])
    return signal.lfilter(b2, a2, y, axis=0)


def lufs(x, sr=SR):
    """Integrated loudness (BS.1770-4 with gating) of stereo/mono array (n,) or (n,2)."""
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        x = x[:, None]
    y = _k_weight(x, sr)
    n = len(y)
    blk, hop = int(0.4 * sr), int(0.1 * sr)
    if n < blk:
        z = np.mean(y ** 2, axis=0).sum()
        return -0.691 + 10 * np.log10(z + 1e-20)
    cs = np.cumsum(np.concatenate([np.zeros((1, y.shape[1])), y ** 2], axis=0), axis=0)
    starts = np.arange(0, n - blk + 1, hop)
    z = (cs[starts + blk] - cs[starts]) / blk  # (nblk, ch)
    zs = z.sum(axis=1)
    l = -0.691 + 10 * np.log10(zs + 1e-20)
    keep = l > -70.0
    if not np.any(keep):
        return -70.0
    gamma = -0.691 + 10 * np.log10(np.mean(zs[keep])) - 10.0
    keep2 = l > gamma
    if not np.any(keep2):
        return float(-0.691 + 10 * np.log10(np.mean(zs[keep])))
    return float(-0.691 + 10 * np.log10(np.mean(zs[keep2])))


def true_peak(x):
    up = signal.resample_poly(np.asarray(x, dtype=np.float64), 4, 1, axis=0)
    return float(np.max(np.abs(up)))


def circular_limit(x, ceiling=0.85, attack_ms=3.0, release_ms=120.0, sr=SR):
    """Look-ahead peak limiter that treats the signal as circular (seamless loops)."""
    pk = np.max(np.abs(x), axis=1)
    need = np.minimum(1.0, ceiling / np.maximum(pk, 1e-9))
    if np.all(need >= 1.0):
        return x
    na = max(1, int(attack_ms * sr / 1000.0))
    nr = max(1, int(release_ms * sr / 1000.0))
    g = ndimage.minimum_filter1d(need, size=2 * na + 1, mode="wrap")
    g = ndimage.uniform_filter1d(g, size=2 * na + 1, mode="wrap")
    # release smoothing: take the running min over a window then smooth (circular)
    g2 = ndimage.minimum_filter1d(g, size=nr, origin=-(nr // 2), mode="wrap")
    g2 = ndimage.uniform_filter1d(g2, size=max(3, nr // 2), mode="wrap")
    g = np.minimum(g, g2)
    return x * g[:, None]


def soft_clip(x, drive_at=0.8):
    """Gentle tanh knee above drive_at (memoryless, so loop-safe)."""
    ax = np.abs(x)
    over = ax > drive_at
    if not np.any(over):
        return x
    y = x.copy()
    k = 1.0 - drive_at
    y[over] = np.sign(x[over]) * (drive_at + k * np.tanh((ax[over] - drive_at) / k))
    return y


def circular_filter_fft(x, b, a=None, n_imp=65536):
    """Apply an IIR filter as a circular (periodic) filter via its truncated impulse response."""
    imp = np.zeros(n_imp)
    imp[0] = 1.0
    h = signal.lfilter(b, a if a is not None else [1.0], imp)
    n = len(x)
    H = np.fft.rfft(h, n)  # h is truncated/wrapped to n
    if n < n_imp:
        hh = h.copy()
        w = np.zeros(n)
        for s in range(0, n_imp, n):
            seg = hh[s:s + n]
            w[:len(seg)] += seg
        H = np.fft.rfft(w)
    return np.fft.irfft(np.fft.rfft(x) * H, n)


def spectral_centroid(x, sr=SR):
    x = np.asarray(x, dtype=np.float64)
    if x.ndim > 1:
        x = x.mean(axis=1)
    if np.max(np.abs(x)) < 1e-9:
        return 0.0
    n = 1 << int(np.ceil(np.log2(min(len(x), 1 << 20))))
    sp = np.abs(np.fft.rfft(x[:n] * np.hanning(min(len(x), n)), n))
    fr = np.fft.rfftfreq(n, 1.0 / sr)
    return float(np.sum(fr * sp) / (np.sum(sp) + 1e-12))
