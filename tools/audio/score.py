"""Score layer: a jianpu-like text notation, pentatonic ladder, 加花 (ornamentation)
generators, rubato time map, and `Ctx`, the object tracks.py uses to place parts.

Jianpu text mini-language (tokens separated by whitespace):

    pitch   : 1..7 scale degree (0 = rest), optional prefix # / b, octave marks
              ' (up) and , (down), e.g.  5,  1'  #4  b7
    length  : default 1 beat; each _ halves; each - adds a beat; . x1.5; :x explicit beats
    marks   : ~ vibrato / long breath-vibrato     & slur (legato) into the next note
              ^ press-bend up a whole tone (按音)  / slide in from below  \\ slide in from above
              * short (staccato)  > accent  @ tremolo / roll (轮指)
    graces  : (2)3  grace note 2 before 3 (倚音); several: (2)(1)3
    bars    : |   (validated: every bar must add up to the time signature)
    Rn      : n bars of rest
    dynamics: !pp !p !mp !mf !f  (apply to the following notes)
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

import numpy as np

from dsp import SR, rng_for
from instruments import PEvent, VNote

MAJOR = [0, 2, 4, 5, 7, 9, 11]
PENTA = [0, 2, 4, 7, 9]            # 宫 商 角 徵 羽  = 1 2 3 5 6
NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
DYN = {"pp": 0.45, "p": 0.6, "mp": 0.75, "mf": 0.9, "f": 1.05}


def tonic_midi(name: str) -> int:
    """'D4' -> 62, 'F#3' -> 54"""
    m = re.match(r"^([A-G])([#b]?)(-?\d)$", name)
    n = NOTE_NAMES[m.group(1)] + (1 if m.group(2) == "#" else -1 if m.group(2) == "b" else 0)
    return 12 * (int(m.group(3)) + 1) + n


@dataclass
class Note:
    b: float                  # start beat (relative to the melody start)
    d: float                  # duration in beats
    midi: float = 0.0
    rest: bool = False
    flags: str = ""
    graces: list = field(default_factory=list)
    dyn: float = 0.9

    def copy(self, **kw):
        n = Note(self.b, self.d, self.midi, self.rest, self.flags, list(self.graces), self.dyn)
        for k, v in kw.items():
            setattr(n, k, v)
        return n


@dataclass
class Mel:
    notes: list
    bars: int
    bpb: int

    @property
    def beats(self):
        return self.bars * self.bpb

    def sub(self, bar0: int, bar1: int) -> "Mel":
        """bars [bar0, bar1) as a new melody starting at beat 0"""
        b0, b1 = bar0 * self.bpb, bar1 * self.bpb
        out = []
        for n in self.notes:
            if n.b >= b0 - 1e-9 and n.b < b1 - 1e-9:
                out.append(n.copy(b=n.b - b0))
        return Mel(out, bar1 - bar0, self.bpb)

    def shift_octave(self, k: int) -> "Mel":
        return Mel([n.copy(midi=n.midi + 12 * k) if not n.rest else n.copy() for n in self.notes], self.bars, self.bpb)

    def concat(self, other: "Mel") -> "Mel":
        off = self.beats
        return Mel(self.notes + [n.copy(b=n.b + off) for n in other.notes], self.bars + other.bars, self.bpb)


_TOK = re.compile(r"""^(?P<g>(?:\([#b]?[1-7][',]*\))*)
                      (?P<acc>[#b]?)(?P<deg>[0-7])(?P<oct>[',]*)
                      (?P<dur>[_\-.]*)(?::(?P<ex>[0-9.]+))?
                      (?P<fl>[~&^/\\*>@]*)$""", re.X)
_GR = re.compile(r"\(([#b]?)([1-7])([',]*)\)")


def _pitch(tonic, acc, deg, octs):
    m = tonic + MAJOR[int(deg) - 1] + (1 if acc == "#" else -1 if acc == "b" else 0)
    return m + 12 * (octs.count("'") - octs.count(","))


def jp(text: str, tonic: int, bpb: int = 4, name: str = "") -> Mel:
    """Parse jianpu text into a Mel."""
    notes = []
    beat = 0.0
    in_bar = 0.0
    bar_no = 1
    dyn = 0.9
    for tok in text.split():
        if tok == "|":
            if abs(in_bar - bpb) > 1e-6:
                raise ValueError(f"[{name}] bar {bar_no} has {in_bar} beats (expected {bpb})")
            in_bar = 0.0
            bar_no += 1
            continue
        if tok.startswith("!") and tok[1:] in DYN:
            dyn = DYN[tok[1:]]
            continue
        m = re.match(r"^R(\d+)$", tok)
        if m:
            if abs(in_bar) > 1e-6:
                raise ValueError(f"[{name}] R{m.group(1)} inside bar {bar_no}")
            nb = int(m.group(1))
            notes.append(Note(beat, nb * bpb, rest=True))
            beat += nb * bpb
            bar_no += nb
            continue
        m = _TOK.match(tok)
        if not m:
            raise ValueError(f"[{name}] bad token {tok!r} in bar {bar_no}")
        dur_s = m.group("dur")
        if m.group("ex"):
            d = float(m.group("ex"))
        else:
            d = 0.5 ** dur_s.count("_") + dur_s.count("-")
            if "." in dur_s:
                d *= 1.5
        graces = [_pitch(tonic, g.group(1), g.group(2), g.group(3)) for g in _GR.finditer(m.group("g"))]
        if m.group("deg") == "0":
            notes.append(Note(beat, d, rest=True))
        else:
            notes.append(Note(beat, d, _pitch(tonic, m.group("acc"), m.group("deg"), m.group("oct")), False,
                              m.group("fl"), graces, dyn))
        beat += d
        in_bar += d
    if abs(in_bar) > 1e-6 and abs(in_bar - bpb) > 1e-6:
        raise ValueError(f"[{name}] last bar has {in_bar} beats")
    bars = int(round(beat / bpb))
    return Mel(notes, bars, bpb)


# ------------------------------------------------------------------ scale ladder
class Scale:
    def __init__(self, tonic: int):
        self.tonic = tonic
        self.ladder = np.array(sorted({tonic + 12 * o + s for o in range(-5, 6) for s in PENTA}), dtype=float)

    def idx(self, m: float) -> int:
        return int(np.argmin(np.abs(self.ladder - m)))

    def step(self, m: float, k: int) -> float:
        i = int(np.clip(self.idx(m) + k, 0, len(self.ladder) - 1))
        return float(self.ladder[i])

    def between(self, a: float, b: float):
        lo, hi = (a, b) if a <= b else (b, a)
        seq = [float(x) for x in self.ladder if lo - 1e-6 <= x <= hi + 1e-6]
        return seq if a <= b else seq[::-1]


# ------------------------------------------------------------------ 加花
def _notes_only(mel_notes):
    return [n for n in mel_notes if not n.rest]


def jiahua(mel: Mel, sc: Scale, rng, density=0.5, style="dizi") -> Mel:
    """Ornamented variant of a melody (heterophony).  Keeps every original onset
    on its beat; extra notes are scale neighbours / approach tones."""
    out = []
    notes = mel.notes
    for i, n in enumerate(notes):
        if n.rest:
            out.append(n.copy())
            continue
        nxt = None
        if i + 1 < len(notes) and not notes[i + 1].rest and abs(notes[i + 1].b - (n.b + n.d)) < 1e-6:
            nxt = notes[i + 1]
        start_idx = len(out)
        up = sc.step(n.midi, 1)
        dn = sc.step(n.midi, -1)
        d = n.d
        r = float(rng.random())

        def add(off, dur, midi, flags="", dyn_mul=1.0):
            out.append(Note(n.b + off, dur, midi, False, flags, [], n.dyn * dyn_mul))

        keep_flags = n.flags
        if "~" in n.flags:            # marked long note (vibrato / trill): leave it alone
            out.append(n.copy())
        elif d >= 2.0 and r < min(1.0, density * 1.3):
            tail = 1.0 if (d >= 3.0 and r < density * 0.6) else 0.5
            toward = None
            if nxt is not None:
                toward = sc.step(n.midi, 1 if nxt.midi > n.midi else -1)
            kind = int(rng.integers(0, 3))
            add(0, d - tail, n.midi, keep_flags)
            if tail == 1.0:
                if kind == 0:
                    add(d - 1.0, 0.25, up, "&", 0.8); add(d - 0.75, 0.25, n.midi, "&", 0.8)
                    add(d - 0.5, 0.25, dn, "&", 0.75); add(d - 0.25, 0.25, n.midi, "", 0.8)
                elif kind == 1:
                    add(d - 1.0, 0.5, up, "", 0.85)
                    add(d - 0.5, 0.5, toward if toward is not None else dn, "", 0.8)
                else:
                    add(d - 1.0, 0.5, dn, "", 0.85)
                    add(d - 0.5, 0.25, n.midi, "", 0.8); add(d - 0.25, 0.25, up, "", 0.8)
            else:
                if kind == 0:
                    add(d - 0.5, 0.25, up, "&", 0.8); add(d - 0.25, 0.25, n.midi, "", 0.8)
                elif kind == 1 and toward is not None:
                    add(d - 0.5, 0.5, toward, "", 0.8)
                else:
                    add(d - 0.5, 0.25, dn, "&", 0.8); add(d - 0.25, 0.25, n.midi, "", 0.8)
        elif 1.0 <= d < 2.0 and r < density:
            kind = int(rng.integers(0, 4))
            if d == 1.0:
                if kind == 0:
                    add(0, 0.5, n.midi, keep_flags); add(0.5, 0.5, up, "", 0.85)
                elif kind == 1:
                    add(0, 0.5, n.midi, keep_flags); add(0.5, 0.25, n.midi, "", 0.8); add(0.75, 0.25, up, "&", 0.8)
                elif kind == 2:
                    add(0, 0.75, n.midi, keep_flags); add(0.75, 0.25, dn, "", 0.75)
                else:
                    add(0, 0.25, up, "&", 0.8); add(0.25, 0.75, n.midi, keep_flags)
            else:  # 1.5
                add(0, 1.0, n.midi, keep_flags)
                add(1.0, 0.25, up if kind % 2 == 0 else dn, "&", 0.8); add(1.25, d - 1.25, n.midi, "", 0.8)
        elif d == 0.5 and r < density * 0.45:
            add(0, 0.25, n.midi, keep_flags); add(0.25, 0.25, up if rng.random() < 0.5 else dn, "", 0.75)
        else:
            out.append(n.copy())
        # dizi-style grace notes
        if style == "dizi" and d >= 0.5 and not n.graces and rng.random() < density * 0.35 and start_idx < len(out):
            out[start_idx].graces = [up if rng.random() < 0.6 else dn]
    return Mel(out, mel.bars, mel.bpb)


# ------------------------------------------------------------------ accompaniment patterns
# steps are pentatonic-ladder offsets from the root (+5 = one octave); None = rest
PATTERNS = {
    # slot (beats), steps, velocities
    "sparse":   dict(slot=1.0, steps=[0, None, 3, 5], vel=[0.62, 0, 0.42, 0.40]),
    "sparse2":  dict(slot=1.0, steps=[0, 3, None, 5, 3, None, 2, None], vel=[0.60, 0.40, 0, 0.42, 0.36, 0, 0.34, 0]),
    "wave":     dict(slot=0.5, steps=[0, 2, 3, 5, 3, 2], vel=[0.60, 0.40, 0.42, 0.46, 0.38, 0.34]),
    "wave8":    dict(slot=0.5, steps=[0, 3, 5, 7, 5, 3], vel=[0.60, 0.40, 0.42, 0.46, 0.38, 0.34]),
    "walk":     dict(slot=1.0, steps=[0, 3, 5, 3], vel=[0.60, 0.42, 0.46, 0.38]),
    "rock":     dict(slot=1.0, steps=[0, None, 3, None], vel=[0.60, 0, 0.42, 0]),
    "lilt":     dict(slot=0.5, steps=[0, None, 3, 5, None, 3, 2, None], vel=[0.58, 0, 0.40, 0.44, 0, 0.36, 0.34, 0]),
    "slow":     dict(slot=2.0, steps=[0, 3], vel=[0.60, 0.40]),
    "brisk":    dict(slot=0.5, steps=[0, 3, 5, 3, 0, 3, 5, 7], vel=[0.62, 0.42, 0.45, 0.40, 0.50, 0.40, 0.45, 0.42]),
}


# ------------------------------------------------------------------ time map
class TimeMap:
    """beat -> seconds with phrase breathing, slow tempo drift, and breath pauses."""

    def __init__(self, bpm, total_beats, rng, phrase_beats=8.0, breath_amt=0.045, drift=0.012,
                 pauses=(), res=96, tail_beats=40):
        self.res = res
        nb = int((total_beats + tail_beats) * res)
        b = np.arange(nb + 1) / res
        spb = 60.0 / bpm
        x = (b % phrase_beats) / phrase_beats
        r1 = breath_amt * (-0.4 + 1.4 * x ** 4)
        # slow drift
        k = np.arange(nb + 1)
        noise = rng.standard_normal(len(k) // res + 4)
        sm = np.convolve(noise, np.hanning(9) / np.hanning(9).sum(), mode="same")
        sm = sm / (np.std(sm) + 1e-9) * drift
        r2 = np.interp(b, np.arange(len(sm)), sm)
        sp = spb * (1.0 + r1 + r2)
        base = np.concatenate([[0.0], np.cumsum(sp[:-1] / res)])
        self.b, self.base = b, base
        self.pauses = sorted(pauses)
        self.total_beats = total_beats

    def _base(self, beat):
        return float(np.interp(beat, self.b, self.base))

    def start(self, beat):
        t = self._base(beat)
        for pb, ps in self.pauses:
            if pb <= beat + 1e-9:
                t += ps
        return t

    def end(self, beat):
        t = self._base(beat)
        for pb, ps in self.pauses:
            if pb < beat - 1e-9:
                t += ps
            elif abs(pb - beat) < 1e-9:
                t += 0.6 * ps
        return t

    def total_seconds(self):
        return self.start(self.total_beats)


# ------------------------------------------------------------------ context
RANGE = {"guzheng": (38, 100), "pipa": (45, 98), "yangqin": (52, 100),
         "erhu": (62, 98), "dizi": (62, 100), "xiao": (55, 86)}


def fit_range(inst: str, m: float) -> float:
    lo, hi = RANGE[inst]
    while m < lo:
        m += 12
    while m > hi:
        m -= 12
    return m


INST_TIMING = {  # (offset s, jitter sigma s)
    "guzheng": (0.004, 0.008), "pipa": (0.008, 0.008), "yangqin": (0.0, 0.007),
    "erhu": (0.010, 0.006), "dizi": (-0.006, 0.006), "xiao": (0.012, 0.010),
}


class Ctx:
    def __init__(self, track_id: str, key: str, bpm: float, bpb: int, bars: int, seed_extra="", pauses_bars=(),
                 phrase_beats=8.0, breath_amt=0.045, drift=0.012):
        self.id = track_id
        self.tonic = tonic_midi(key)
        self.sc = Scale(self.tonic)
        self.bpm, self.bpb, self.bars = bpm, bpb, bars
        self.rng = rng_for(track_id, "score", seed_extra)
        pauses = [(b * bpb, s) for b, s in pauses_bars]
        self.tm = TimeMap(bpm, bars * bpb, rng_for(track_id, "tm"), phrase_beats, breath_amt, drift, pauses)
        self.pl: dict[str, list[PEvent]] = {"guzheng": [], "pipa": [], "yangqin": []}
        self.vo: dict[str, list[VNote]] = {"erhu": [], "dizi": [], "xiao": []}
        self.loop_seconds = self.tm.total_seconds()

    # -- helpers
    def p(self, tok: str) -> float:
        """single pitch token -> midi, e.g. c.p("6,") """
        m = re.match(r"^([#b]?)([1-7])([',]*)$", tok)
        return float(_pitch(self.tonic, m.group(1), m.group(2), m.group(3)))

    def jp(self, text, name="", tonic=None):
        return jp(text, self.tonic if tonic is None else tonic, self.bpb, name or self.id)

    def _t(self, inst, beat, jitter=True):
        off, sig = INST_TIMING[inst]
        t = self.tm.start(beat) + off
        if jitter:
            t += float(np.clip(self.rng.normal(0, sig), -2.5 * sig, 2.5 * sig))
        return max(t, 0.0)

    def _vel_shape(self, beat_in_bar, base, accent=0.07):
        v = base
        if abs(beat_in_bar) < 1e-6:
            v += accent
        elif abs(beat_in_bar - 2.0) < 1e-6 and self.bpb == 4:
            v += accent * 0.5
        elif abs(beat_in_bar % 1.0) > 1e-6:
            v -= 0.04
        return float(np.clip(v + self.rng.normal(0, 0.035), 0.08, 1.0))

    # -- plucked parts -----------------------------------------------------
    def pluck(self, inst, mel: Mel, bar: float, vel=0.62, ring=0.0, octave=0, accent=0.07, tremolo_min=2.5,
              trem_ring=1.4, bend_ok=True, lag=0.0, vel_mul=1.0, bright=1.0):
        b0 = bar * self.bpb
        for n in mel.notes:
            if n.rest:
                continue
            beat = b0 + n.b
            bib = (n.b % self.bpb)
            v = self._vel_shape(bib, vel * n.dyn * vel_mul, accent)
            m = fit_range(inst, n.midi + 12 * octave)
            t = self._t(inst, beat) + lag
            for gi, g in enumerate(n.graces):   # plucked grace: quick pre-note
                self.pl[inst].append(PEvent(t - 0.05 * (len(n.graces) - gi), fit_range(inst, g + 12 * octave), v * 0.6, ring=ring or 0.8,
                                            extra={"bright": bright}))
            kind = "pluck"
            dur = 0.0
            if "@" in n.flags:
                v *= 0.72
                kind = "trem"
                dur = max(0.4, self.tm.end(beat + n.d) - self.tm.start(beat) - 0.05)
            bend = 2.0 if ("^" in n.flags and bend_ok) else 0.0
            if "/" in n.flags and inst in ("pipa", "guzheng"):
                bend = 0.0
            r = ring
            if kind == "trem":
                r = trem_ring
            self.pl[inst].append(PEvent(t, m, v, kind=kind, dur=dur, ring=r, bend=bend,
                                        bend_delay=float(self.rng.uniform(0.06, 0.14)),
                                        bend_time=float(self.rng.uniform(0.16, 0.26)), extra={"bright": bright}))

    def arp(self, inst, roots_text: str, bar: float, pattern="wave", vel=0.55, ring=0.0, octave=0, bass=True,
            bass_oct=-1, name="", vel_mul=1.0, vary=0.08, bright=1.0, bass_vel=0.50):
        """Pentatonic arpeggios from per-bar root tokens.  roots_text: bars separated by '|', each bar's
        tokens share the bar equally, e.g. '6, 3, | 2 | 5, 1'."""
        pat = PATTERNS[pattern]
        bars_txt = [b.strip() for b in roots_text.split("|") if b.strip()]
        for bi, bt in enumerate(bars_txt):
            toks = bt.split()
            U = self.bpb / len(toks)
            for ti, tk in enumerate(toks):
                m = re.match(r"^([#b]?)([1-7])([',]*)$", tk)
                if not m:
                    continue
                root = _pitch(self.tonic, m.group(1), m.group(2), m.group(3)) + 12 * octave
                u0 = (bar + bi) * self.bpb + ti * U
                nslot = int(round(U / pat["slot"]))
                for si in range(nslot):
                    st = pat["steps"][si % len(pat["steps"])]
                    if st is None:
                        continue
                    if vary > 0 and self.rng.random() < vary:
                        st = st + int(self.rng.choice([-1, 1]))
                    midi = fit_range(inst, self.sc.step(root, st))
                    beat = u0 + si * pat["slot"]
                    v = pat["vel"][si % len(pat["vel"])] * (vel / 0.6) * vel_mul
                    v = float(np.clip(v + self.rng.normal(0, 0.03), 0.08, 1.0))
                    t = self._t(inst, beat)
                    self.pl[inst].append(PEvent(t, midi, v, ring=ring, extra={"bright": bright}))
                if bass:
                    # low octave doubling of the root on the unit's first beat
                    t = self._t(inst, u0)
                    self.pl[inst].append(PEvent(t, fit_range(inst, root + 12 * bass_oct), float(np.clip(bass_vel * (vel / 0.6) * vel_mul, 0.1, 1)),
                                                ring=ring * 1.3 if ring else 0.0, extra={"bright": bright}))

    def gliss(self, inst, beat_abs: float, lo: float, hi: float, up=True, t_step=(0.045, 0.02), vel=(0.3, 0.6),
              ring=1.8, offset_s=0.0, end_vel=None):
        """刮奏: rapid run across the pentatonic strings between lo and hi (midi)."""
        seq = self.sc.between(lo, hi)
        if not up:
            seq = seq[::-1]
        n = len(seq)
        t = self.tm.start(beat_abs) + offset_s
        for i, m in enumerate(seq):
            x = i / max(n - 1, 1)
            dt = t_step[0] + (t_step[1] - t_step[0]) * x
            v = vel[0] + (vel[1] - vel[0]) * x if up else vel[1] + (vel[0] - vel[1]) * x
            if end_vel and i == n - 1:
                v = end_vel
            self.pl[inst].append(PEvent(t, fit_range(inst, m), float(np.clip(v + self.rng.normal(0, 0.02), 0.08, 1)), ring=ring))
            t += dt * float(self.rng.uniform(0.9, 1.1))
        return t

    def harm(self, inst, beat_abs: float, midi: float, vel=0.5, ring=3.5, pan=0.0):
        self.pl[inst].append(PEvent(self.tm.start(beat_abs) + float(self.rng.normal(0, 0.01)), midi, vel, kind="harm",
                                    ring=ring, pan=pan))

    # -- voices -------------------------------------------------------------
    def voice(self, inst, mel: Mel, bar: float, dyn=0.7, octave=0, gap=0.035, slide_p=0.0, auto_slur=False,
              grace_t=0.045, vib_all=None, vib_depth=1.0, port=None, swell=0.0, lag=0.0, long_vib=0.7, trill=False):
        b0 = bar * self.bpb
        ns = [n for n in mel.notes if not n.rest]
        # decide slurs
        slur = []
        for i, n in enumerate(ns):
            nxt = ns[i + 1] if i + 1 < len(ns) else None
            s = False
            if nxt is not None and abs(nxt.b - (n.b + n.d)) < 1e-6:
                if "&" in n.flags:
                    s = True
                elif auto_slur and n.d <= 0.5 and nxt.d <= 0.5 and abs(nxt.midi - n.midi) <= 5:
                    s = True
            slur.append(s)
        starts = [self._t(inst, b0 + n.b) + lag for n in ns]
        out = []
        prev_end = -1.0
        for i, n in enumerate(ns):
            t0 = starts[i]
            m = fit_range(inst, n.midi + 12 * octave)
            # graces take their time from the front of the note
            gdur = grace_t
            g_total = 0.0
            for gi, g in enumerate(n.graces):
                gt = t0 + gi * gdur
                out.append(VNote(gt, gdur * 1.05, fit_range(inst, g + 12 * octave), dyn * n.dyn * 0.8, slur=True, grace=True,
                                 vib=False))
                g_total += gdur
            t_note = t0 + g_total
            if slur[i] and i + 1 < len(ns):
                dur = starts[i + 1] - t_note
            else:
                dur = self.tm.end(b0 + n.b + n.d) + INST_TIMING[inst][0] + lag - t_note - (gap if n.d < 2 else 0.02)
                if "*" in n.flags:
                    dur = min(dur, 0.18)
            dur = max(dur, 0.06)
            gin = 0.0
            if "/" in n.flags:
                gin = 1.6
            elif "\\" in n.flags:
                gin = -1.6
            elif slide_p > 0 and not (i > 0 and slur[i - 1]) and i > 0 and self.rng.random() < slide_p and n.d >= 1.0:
                gin = float(self.rng.choice([1.0, 1.6, 2.0]))
            vib = None
            if "~" in n.flags:
                vib = True
            elif vib_all is not None:
                vib = vib_all
            else:
                vib = n.d >= long_vib * self.bpb / 4 * 1.0 and dur >= 0.7
            if trill and "~" in n.flags and n.d >= 2.0 and not slur[i]:
                # 颤音: hold, then alternate with the upper scale neighbour for the last beat
                t_tr = self.tm.start(b0 + n.b + n.d - 1.0) + INST_TIMING[inst][0] + lag
                out.append(VNote(t_note, max(0.1, t_tr - t_note), m, dyn * n.dyn, slur=True, gin=gin, vib=False))
                step = 1.0 / 7.5 / 2.0
                tt = t_tr
                k = 0
                upper = self.sc.step(m, 1)
                t_end = t_note + dur
                while tt < t_end - 0.12:
                    out.append(VNote(tt, step, m if k % 2 == 0 else upper, dyn * n.dyn * 0.92, slur=True, vib=False))
                    tt += step
                    k += 1
                out.append(VNote(tt, max(0.08, t_end - tt), m, dyn * n.dyn * 0.8, vib=False))
                continue
            vn = VNote(t_note, dur, m, dyn * n.dyn * (1.08 if ">" in n.flags else 1.0), slur=slur[i] and i + 1 < len(ns),
                       gin=gin, vib=vib, vib_depth=vib_depth, swell=swell)
            if n.graces:  # last grace slurs into the main note
                out[-1].slur = True
            if port:
                vn.port = port
            out.append(vn)
        self.vo[inst].extend(out)

    def trill(self, inst, beat_abs, midi, upper, dur_beats, rate=7.5, dyn=0.6):
        """Dizi/erhu trill (颤音) as rapidly alternating slurred notes."""
        t0 = self._t(inst, beat_abs)
        t1 = self.tm.end(beat_abs + dur_beats)
        step = 1.0 / rate / 2.0
        k = 0
        t = t0
        out = []
        while t < t1 - 0.05:
            m = midi if k % 2 == 0 else upper
            out.append(VNote(t, step, m, dyn, slur=True, vib=False, grace=False))
            t += step
            k += 1
        if out:
            out[-1].slur = False
            out[-1].dur = max(0.06, t1 - out[-1].t)
        self.vo[inst].extend(out)

    def note(self, inst, beat_abs, dur_beats, midi, dyn=0.6, vib=None, slur=False, gin=0.0, lag=0.0, swell=0.0, vib_depth=1.0):
        """single sustained note at an absolute beat"""
        t0 = self._t(inst, beat_abs) + lag
        t1 = self.tm.end(beat_abs + dur_beats) + lag
        self.vo[inst].append(VNote(t0, max(0.08, t1 - t0 - 0.02), midi, dyn, slur=slur, gin=gin, vib=vib, swell=swell,
                                   vib_depth=vib_depth))

    # -- bookkeeping --------------------------------------------------------
    def counts(self):
        return {k: len(v) for k, v in {**self.pl, **self.vo}.items()}
