"""The compositions.  Every melody below is original and written as jianpu text
(see score.py for the notation).  `1=G` means scale degree 1 is G, etc.; the mode
(调式) is given by the degree the tune settles on.

Each build_* function returns a Ctx holding all events; mixer.py renders it.
"""
from __future__ import annotations

from instruments import PEvent, VNote
from mixer import Mix
from score import Ctx, jiahua


# ============================================================================
# 1. title  《德厚当》  1=G  羽调式  ♩=54  4/4   (2 + 4 + 4 + 4 + 4 = 18 bars)
# ============================================================================
def build_title() -> Ctx:
    c = Ctx("title", "G4", 54, 4, 18, pauses_bars=[(6, 0.35), (10, 0.45), (14, 0.35), (18, 0.30)],
            phrase_beats=16, breath_amt=0.04, drift=0.010)
    A = c.jp("""6,-/ 1 2_& 3_ | 3--~ 2_& 1_ | 2- 1 6, | 6,---~""", "A")
    A2 = c.jp("""6,-/ 1 2_& 3_ | 5--~ 3_& 2_ | 3- 2 1 | 2---~""", "A2")
    B = c.jp("""5- 6- | 5_ 6_ 5 3 2 | 3-~ 2_& 1_ 2 | 3--~ 2""", "B")
    A3 = c.jp("""6,-/ 1 2_& 3_ | 3--~ 2_& 1_ | 2- 1 6, | 6,---~""", "A3")
    # erhu: solo line, slides and a long delayed vibrato on the held notes
    c.voice("erhu", A, 2, dyn=0.58, slide_p=0.2, swell=0.06)
    c.voice("erhu", A2, 6, dyn=0.66, slide_p=0.2, swell=0.06)
    c.voice("erhu", B, 10, dyn=0.80, slide_p=0.3, swell=0.10, vib_depth=1.15)
    c.voice("erhu", A3, 14, dyn=0.56, slide_p=0.15, swell=0.05, vib_depth=0.9)
    # guzheng: sparse pentatonic arpeggios, bass note + 5th + octave
    c.arp("guzheng", "6, | 3,", 0, "sparse", vel=0.50, ring=3.2)
    c.arp("guzheng", "6, | 1, 6, | 2, | 6,", 2, "sparse", vel=0.46, ring=3.0)
    c.arp("guzheng", "6, | 1, | 3, 2, | 2,", 6, "sparse2", vel=0.46, ring=3.0)
    c.arp("guzheng", "1 | 6, | 2, | 5, 2,", 10, "wave", vel=0.50, ring=2.4)
    c.arp("guzheng", "6, | 1, 6, | 2, | 6,", 14, "sparse", vel=0.42, ring=3.4)
    c.gliss("guzheng", 10 * 4 - 1.2, c.p("6,"), c.p("6"), up=True, t_step=(0.07, 0.035), vel=(0.22, 0.40), ring=2.2)
    c.harm("guzheng", 5 * 4 + 2.0, c.p("6'"), vel=0.42)
    c.harm("guzheng", 9 * 4 + 2.5, c.p("3'"), vel=0.38)
    c.harm("guzheng", 17 * 4 + 1.5, c.p("6'"), vel=0.34)
    return c


MIX_TITLE = Mix(gain_db={"erhu": 0.0, "guzheng": -2.5}, send_db={"erhu": -5.0, "guzheng": -7.0}, wet_db=-3.5, rt60=1.8,
                damp=0.38, target_lufs=-18.0)


# ============================================================================
# 2. town_day  《桥头街》  1=D  徵调式  ♩=78  4/4  (2+8+8+8+8+8+6 = 48 bars)
# ============================================================================
def build_town_day() -> Ctx:
    c = Ctx("town_day", "D4", 78, 4, 48,
            pauses_bars=[(2, 0.12), (10, 0.18), (18, 0.18), (26, 0.22), (34, 0.18), (42, 0.28), (48, 0.28)], phrase_beats=8,
            breath_amt=0.04, drift=0.012)
    A = c.jp("""0_ 2_ 5- 3_ 2_ | 3 5 6- | 1'_ 6_ 5 3_ 5_ 6 | 6--~ 0 |
                0_ 2_ 5- 3_ 2_ | 3 5 6 1' | 5_ 3_ 2 3 5 | 5---~""", "A")
    A2 = c.jp("""0_ 2_ 5- 3_ 2_ | 3 5 6_ 1'_ 6 | 1'_ 6_ 5 3_ 5_ 6 | 6--~ 0 |
                 0_ 2_ 5- 3_ 2_ | 3 5 6 1' | 5_ 3_ 2 3 5 | 5---~""", "A2")
    B = c.jp("""6 1' 2'- | 3'_ 2'_ 1' 6_ 5_ 6 | 5- 6_ 1'_ 6 | 3- 2- |
                6 1' 2'_ 3'_ 5' | 5'_ 3'_ 2' 1'_ 6_ 5 | 6_ 5_ 3 5 6 | 2-- 0""", "B")
    C = c.jp("""6- 5_ 3_ 5 | 6_ 1'_ 6 5 3 | 2- 3_ 2_ 1 | 2-- 0 |
                2_ 3_ 5 3 2 | 6- 5 3 | 5_ 3_ 2 3_ 2_ 1 | 2-- 0""", "C")
    Z = c.jp("""3 5 6- | 5_ 3_ 2 3 5 | 5--- | R3""", "coda")
    rng = c.rng
    sc = c.sc

    # roots (bass) for the guzheng; 1=D so 5,=A3 2,=E3 1,=D3 6,=B3
    rootsA = "5, | 5, 1, | 6, 5, | 2, | 5, | 5, 1, | 2, | 5,"
    rootsB = "6, | 5, | 2, 5, | 6, 2, | 6, | 1, | 5, 6, | 2,"
    rootsC = "6, | 5, | 1, 2, | 2, | 6, | 1, 2, | 5, | 2,"

    # --- intro (bars 0-1): guzheng wash + a tentative yangqin
    c.arp("guzheng", "5, | 5, 1,", 0, "wave", vel=0.46, ring=2.4)
    c.arp("yangqin", "5 | 1'", 1, "sparse", vel=0.30, ring=0.8, bass=False)

    # --- A (bars 2-9): dizi leads, pipa and guzheng accompany
    Ad = jiahua(A, sc, rng, 0.35, "dizi")
    c.voice("dizi", Ad, 2, dyn=0.64, auto_slur=True, trill=True)
    c.arp("guzheng", rootsA, 2, "walk", vel=0.46, ring=2.3)
    c.arp("pipa", rootsA, 2, "lilt", vel=0.40, ring=1.0, bass=False, octave=0, bright=0.8)

    # --- B (bars 10-17): dizi (call) and pipa (response) dialogue
    c.gliss("guzheng", 10 * 4 - 0.8, c.p("5,"), c.p("5"), up=True, vel=(0.2, 0.4), ring=1.8)
    c.voice("dizi", jiahua(B.sub(0, 2), sc, rng, 0.4, "dizi"), 10, dyn=0.68, auto_slur=True)
    c.pluck("pipa", jiahua(B.sub(2, 4), sc, rng, 0.9, "pipa"), 12, vel=0.55, octave=0, ring=1.6)
    c.voice("dizi", jiahua(B.sub(4, 6), sc, rng, 0.4, "dizi"), 14, dyn=0.70, auto_slur=True)
    c.pluck("pipa", jiahua(B.sub(6, 8), sc, rng, 1.0, "pipa"), 16, vel=0.56, octave=0, ring=1.6)
    c.voice("dizi", B.sub(6, 8).shift_octave(0), 16, dyn=0.52, vib_all=True, gap=0.1)
    c.arp("guzheng", rootsB, 10, "lilt", vel=0.46, ring=2.0)
    c.arp("yangqin", rootsB, 10, "sparse", vel=0.30, ring=0.7, bass=False, octave=1)

    # --- A' (bars 18-25): ornamented variant (heterophony): dizi + pipa + yangqin
    c.voice("dizi", jiahua(A2, sc, rng, 0.55, "dizi"), 18, dyn=0.70, auto_slur=True, trill=True)
    c.pluck("pipa", jiahua(A2, sc, rng, 0.85, "pipa"), 18, vel=0.50, octave=-1, ring=1.5, tremolo_min=2.5)
    c.pluck("yangqin", jiahua(A2, sc, rng, 0.3, "pipa"), 18, vel=0.40, octave=0, ring=0.9)
    c.arp("guzheng", rootsA, 18, "wave", vel=0.46, ring=2.2)

    # --- C (bars 26-33): pipa-led, mid register; dizi answers
    c.pluck("pipa", jiahua(C.sub(0, 4), sc, rng, 0.7, "pipa"), 26, vel=0.55, octave=0, ring=1.6)
    c.voice("dizi", jiahua(C.sub(4, 8), sc, rng, 0.35, "dizi"), 30, dyn=0.58, auto_slur=True)
    c.pluck("pipa", jiahua(C.sub(4, 8), sc, rng, 0.9, "pipa"), 30, vel=0.40, octave=-1, ring=1.4)
    c.arp("guzheng", rootsC, 26, "sparse2", vel=0.46, ring=2.2)
    c.arp("yangqin", rootsC, 30, "lilt", vel=0.30, ring=0.7, bass=False, octave=1)

    # --- A'' (bars 34-41): everyone, fullest, one octave higher on the yangqin
    c.voice("dizi", jiahua(A, sc, rng, 0.6, "dizi"), 34, dyn=0.74, auto_slur=True, trill=True)
    c.pluck("pipa", jiahua(A, sc, rng, 0.9, "pipa"), 34, vel=0.54, octave=-1, ring=1.5)
    c.pluck("yangqin", jiahua(A, sc, rng, 0.5, "pipa"), 34, vel=0.42, octave=1, ring=0.8)
    c.arp("guzheng", rootsA, 34, "brisk", vel=0.48, ring=2.0)

    # --- coda (bars 42-47): winding down, loops back into the intro
    c.voice("dizi", Z, 42, dyn=0.56, auto_slur=True, vib_all=None)
    c.arp("guzheng", "2, | 5, | 5, | 1, | 5, | 5, 1,", 42, "slow", vel=0.42, ring=3.0)
    c.pluck("pipa", c.jp("3_ 5_ 6 5 3 | 2 1 5, 6, | 5,---@ | R3", "pipa-coda"), 42, vel=0.42, octave=-1, ring=2.0)
    c.gliss("guzheng", 46 * 4 + 0.5, c.p("5"), c.p("5,"), up=False, t_step=(0.06, 0.09), vel=(0.18, 0.34), ring=2.4)
    c.harm("guzheng", 47 * 4 + 2.0, c.p("5'"), vel=0.34)
    return c


MIX_DAY = Mix(gain_db={"dizi": 0.0, "pipa": -1.5, "guzheng": -3.0, "yangqin": -3.0},
              send_db={"dizi": -6.0, "pipa": -8.0, "guzheng": -7.0, "yangqin": -6.0}, wet_db=-4.0, rt60=1.9, damp=0.36,
              target_lufs=-18.0)


# ============================================================================
# 3. town_dusk  《傍晚》  1=G  商调式  ♩=56  4/4  (2+6+6+6+4+4 = 28 bars)
# ============================================================================
def build_town_dusk() -> Ctx:
    c = Ctx("town_dusk", "G4", 56, 4, 28,
            pauses_bars=[(2, 0.2), (8, 0.3), (14, 0.3), (20, 0.35), (24, 0.35), (28, 0.35)], phrase_beats=8,
            breath_amt=0.05, drift=0.010)
    A = c.jp("""2- 3. 5_ | 6- 5 3 | 5. 3_ 2 1 | 2-- 0_ 3_ | 3_ 5_ 6 5 3 | 2---""", "A")
    B = c.jp("""6- 1'- | 2'. 1'_ 6 5 | 6- 5_ 3_ 5 | 3- 2- | 5. 6_ 1' 6 | 5- 3-""", "B")
    A2 = c.jp("""2- 3. 5_ | 6- 5 3 | 5. 6_ 5 3 | 2-- 0_ 3_ | 3_ 2_ 1 2 3 | 2---""", "A2")
    B2 = c.jp("""6- 1'- | 2'. 1'_ 6 5 | 3. 5_ 3 2 | 2---""", "B2")
    Z = c.jp("""6,- 1- | 2--- | R2""", "coda")
    c.voice("erhu", A, 2, dyn=0.62, slide_p=0.25, swell=0.07, vib_depth=1.0, auto_slur=False)
    c.voice("erhu", B, 8, dyn=0.76, slide_p=0.30, swell=0.10, vib_depth=1.1)
    c.voice("erhu", A2, 14, dyn=0.64, slide_p=0.25, swell=0.07)
    c.voice("erhu", B2, 20, dyn=0.78, slide_p=0.30, swell=0.10, vib_depth=1.15)
    c.voice("erhu", Z, 24, dyn=0.52, slide_p=0.2, swell=0.06, vib_depth=0.9)
    # guzheng: amber arpeggios under the erhu
    c.arp("guzheng", "2, | 2, 5,", 0, "wave", vel=0.42, ring=2.4)
    c.arp("guzheng", "2, | 6, | 1, 2, | 2, | 5, 6, | 2,", 2, "walk", vel=0.44, ring=2.6)
    c.arp("guzheng", "1 | 1 2 | 6, | 2, | 5, 6, | 1,", 8, "wave", vel=0.44, ring=2.2)
    c.arp("guzheng", "2, | 6, | 1, 2, | 2, | 5, 6, | 2,", 14, "walk", vel=0.44, ring=2.6)
    c.arp("guzheng", "1 | 1 2 | 6, 5, | 2,", 20, "wave", vel=0.44, ring=2.2)
    c.arp("guzheng", "6, | 2, | 2, | 2, 5,", 24, "slow", vel=0.40, ring=3.4)
    # soft xiao pedal underneath the B sections and the coda
    X = c.jp("""5,--- | 5,--- | 6,--- | 6,--- | 5,--- | 2,---""", "xiaoB")
    c.voice("xiao", X, 8, dyn=0.36, gap=0.0, swell=0.12)
    X2 = c.jp("""5,--- | 6,--- | 5,--- | 2,---""", "xiaoB2")
    c.voice("xiao", X2, 20, dyn=0.34, gap=0.0, swell=0.12)
    X3 = c.jp("""2,--- | 2,--- | 2,--- | R1""", "xiaoZ")
    c.voice("xiao", X3, 24, dyn=0.30, gap=0.0, swell=0.12)
    c.gliss("guzheng", 14 * 4 - 1.0, c.p("2,"), c.p("2"), up=True, t_step=(0.08, 0.04), vel=(0.2, 0.36), ring=2.4)
    c.gliss("guzheng", 27 * 4 + 0.2, c.p("2'"), c.p("2,"), up=False, t_step=(0.09, 0.12), vel=(0.14, 0.30), ring=3.0)
    c.harm("guzheng", 7 * 4 + 2.0, c.p("2'"), vel=0.34)
    c.harm("guzheng", 19 * 4 + 2.0, c.p("6'"), vel=0.34)
    return c


MIX_DUSK = Mix(gain_db={"erhu": 0.0, "guzheng": -2.5, "xiao": -2.0}, send_db={"erhu": -5.0, "guzheng": -6.5, "xiao": -4.0},
               wet_db=-3.5, rt60=1.8, damp=0.40, target_lufs=-18.0)


# ============================================================================
# 4. night  《夜·后门》  1=D  角调式  ♩=44  4/4  (22 bars)  sparse, no pulse
# ============================================================================
def build_night() -> Ctx:
    c = Ctx("night", "D4", 44, 4, 22, pauses_bars=[(22, 0.5)], phrase_beats=16, breath_amt=0.02, drift=0.008)
    X = c.jp("""R2 5,--- | 6,-- 0 | 1-- 5, | 5,--- | R2 2-- 1 | 4:1.5 3:2.5 | 1-- 6, | 5,--- |
                R2 3-- 5 | 6-- 5 | 5-- 3 | 3--- | R4""", "xiao")
    c.voice("xiao", X, 0, dyn=0.50, gap=0.0, swell=0.14, long_vib=0.5, port=0.2)
    # low open string D2 - very long ring, plucked softly, irregularly spaced
    for beat, vel in [(0.0, 0.42), (30.0, 0.36), (58.0, 0.38), (76.0, 0.30)]:
        c.pl["guzheng"].append(PEvent(c.tm.start(beat) + 0.01, 38.0, vel, ring=9.0, extra={"bright": 0.7}))
    c.pl["guzheng"].append(PEvent(c.tm.start(44.0), 45.0, 0.30, ring=7.0, extra={"bright": 0.6}))   # A2
    # slow low tremolo (摇指) that swells and fades: the "something is wrong" under bars 13-16
    c.pl["guzheng"].append(PEvent(c.tm.start(52.0), 38.0, 0.30, kind="trem", dur=c.tm.start(63.0) - c.tm.start(52.0),
                                  ring=3.0, extra={"bright": 0.30}))
    # harmonics (泛音): scattered bells, irregular gaps
    for beat, deg, vel in [(25.5, "5'", 0.36), (27.4, "1''", 0.30), (31.0, "3'", 0.28), (40.8, "5'", 0.34),
                           (47.2, "2'", 0.26), (49.0, "6'", 0.30), (66.5, "1''", 0.30), (68.9, "5'", 0.26),
                           (79.0, "3'", 0.24), (82.5, "1'", 0.28), (84.6, "5'", 0.22)]:
        c.harm("guzheng", beat, c.p(deg), vel=vel, ring=4.5, pan=(0.25 if int(beat) % 2 else -0.25))
    c.gliss("guzheng", 54 * 1.0 + 8.0, c.p("5,"), c.p("5"), up=False, t_step=(0.16, 0.22), vel=(0.10, 0.18), ring=3.0)
    return c


MIX_NIGHT = Mix(gain_db={"xiao": 0.0, "guzheng": -2.0}, send_db={"xiao": -2.5, "guzheng": -4.0}, wet_db=-1.5, rt60=2.1,
                damp=0.45, predelay_ms=22.0, noise_db=-47.0, target_lufs=-20.0, tail_s=10.0)


# ============================================================================
# 5. pawnshop  《柜台》  1=D  商调式  ♩=60  4/4  (2+8+8+8+4 = 30 bars)
# ============================================================================
def build_pawnshop() -> Ctx:
    c = Ctx("pawnshop", "D4", 60, 4, 30,
            pauses_bars=[(2, 0.15), (10, 0.25), (18, 0.25), (26, 0.3), (30, 0.4)], phrase_beats=8, breath_amt=0.04,
            drift=0.010)
    A = c.jp("""0_ 2_ 3 2 1_ 2_ | 3_ 5_ 3 2- | 1_ 2_ 3_ 5_ 3 2 | 2---@ |
                5,_ 6,_ 1 2 3 | 5_ 3_ 2 3 5 | 3_ 2_ 1_ 2_ 3 2 | 2---""", "A")
    B = c.jp("""5- 3_ 5_ 6 | 5_ 3_ 2 3 5 | 6- 5 3 | 3--- |
                1_ 2_ 3 5 6 | 1'- 6 5 | 3_ 5_ 3_ 2_ 1_ 2_ 3 | 2---""", "B")
    A2 = c.jp("""0_ 2_ 3 2 1_ 2_ | 3_ 5_ 3 2-^ | 1_ 2_ 3_ 5_ 3 2 | 2---@ |
                 5,_ 6,_ 1 2 3 | 5_ 3_ 2 3 5 | 3_ 2_ 1_ 2_ 3 2^ | 2---@""", "A2")
    Z = c.jp("""5,- 1 2 | 3 2 1 6, | 5,--- | R1""", "coda")
    rng, sc = c.rng, c.sc
    br = 0.62
    # intro: guzheng low arpeggio
    c.arp("guzheng", "2, | 5,", 0, "slow", vel=0.40, ring=3.2, bright=0.7)
    # A
    c.pluck("pipa", A, 2, vel=0.46, ring=1.8, trem_ring=1.6, bright=br)
    c.arp("guzheng", "2, | 5, | 1, 2, | 2, | 5, | 5, | 1, | 2,", 2, "slow", vel=0.36, ring=3.0, bright=0.7)
    # B
    c.pluck("pipa", jiahua(B, sc, rng, 0.35, "pipa"), 10, vel=0.48, ring=1.8, bright=br)
    c.arp("guzheng", "5, | 2, | 6, 5, | 2, | 1, | 1 | 5, | 2,", 10, "sparse", vel=0.36, ring=3.0, bright=0.7)
    # A' with presses (按音) and a guzheng counter-line
    c.pluck("pipa", A2, 18, vel=0.48, ring=1.8, trem_ring=1.6, bright=br)
    c.arp("guzheng", "2, | 5, | 1, 2, | 2, | 5, | 5, | 1, | 2,", 18, "sparse2", vel=0.36, ring=3.0, bright=0.7)
    c.pluck("guzheng", jiahua(A.sub(4, 8), sc, rng, 0.2, "pipa"), 22, vel=0.34, octave=1, ring=2.4, bright=0.7)
    # coda
    c.pluck("pipa", Z, 26, vel=0.42, ring=2.2, bright=br)
    c.arp("guzheng", "5, | 1, | 2, | 2,", 26, "slow", vel=0.32, ring=3.6, bright=0.7)
    c.harm("guzheng", 29 * 4 + 0.5, c.p("2'"), vel=0.26, ring=4.0)
    return c


MIX_PAWN = Mix(gain_db={"pipa": 0.0, "guzheng": -2.5}, send_db={"pipa": -8.0, "guzheng": -8.0}, wet_db=-6.0, rt60=1.5,
               damp=0.45, noise_db=-56.0, target_lufs=-20.0, dry_shelf_db=-2.0)


# ============================================================================
# 6. teahouse  《茶馆》  1=G  宫调式  ♩=104  4/4  (8+8+8+8+8+3 = 43 bars)
# ============================================================================
def build_teahouse() -> Ctx:
    c = Ctx("teahouse", "G4", 104, 4, 43,
            pauses_bars=[(8, 0.10), (16, 0.12), (24, 0.12), (32, 0.12), (40, 0.15), (43, 0.25)], phrase_beats=8,
            breath_amt=0.03, drift=0.012)
    A = c.jp("""0_ 3_ 5_ 6_ 5 3 | 2_ 3_ 5_ 3_ 2 1_ 2_ | 3 5_ 6_ 1'- | 6_ 1'_ 6_ 5_ 3 2 |
                3_ 3_ 5 6_ 5_ 3_ 2_ | 1_ 2_ 3_ 5_ 6- | 5_ 6_ 1'_ 2'_ 1' 6 | 5_ 3_ 2_ 3_ 1-""", "A")
    B = c.jp("""6- 1'- | 2'_ 1'_ 6_ 5_ 6 3 | 5_ 6_ 5_ 3_ 2_ 3_ 5_ 6_ | 1'- 6 5 |
                6_ 1'_ 2'_ 1'_ 2' 1' | 6_ 5_ 6_ 1'_ 6 5 | 3_ 2_ 3_ 5_ 3_ 2_ 1_ 2_ | 2---""", "B")
    Z = c.jp("""5_ 3_ 2_ 3_ 5 3 | 2_ 1_ 2_ 3_ 2 1 | 1---""", "coda")
    rng, sc = c.rng, c.sc
    rootsA = "1 | 6, | 1 | 5, | 1 | 6, | 5, | 1"
    rootsB = "2, | 5, | 6, | 5, | 2, | 6, | 1 | 2,"

    # A (0-7): erhu leads; guzheng + yangqin; dizi joins for the second half
    c.voice("erhu", jiahua(A, sc, rng, 0.25, "erhu"), 0, dyn=0.68, slide_p=0.18, auto_slur=True, swell=0.04)
    c.arp("guzheng", rootsA, 0, "lilt", vel=0.46, ring=1.6, octave=-1, bass=True, bass_oct=-1)
    c.pluck("yangqin", jiahua(A, sc, rng, 0.35, "pipa"), 0, vel=0.38, octave=0, ring=0.7)
    c.voice("dizi", jiahua(A.sub(4, 8), sc, rng, 0.6, "dizi"), 4, dyn=0.58, auto_slur=True)
    c.pluck("pipa", jiahua(A.sub(4, 8), sc, rng, 0.9, "pipa"), 4, vel=0.46, octave=-1, ring=1.2)
    # A' (8-15): dizi leads, erhu varies
    c.voice("dizi", jiahua(A, sc, rng, 0.5, "dizi"), 8, dyn=0.72, auto_slur=True)
    c.voice("erhu", jiahua(A, sc, rng, 0.55, "erhu"), 8, dyn=0.56, slide_p=0.22, auto_slur=True)
    c.pluck("pipa", jiahua(A, sc, rng, 0.9, "pipa"), 8, vel=0.50, octave=-1, ring=1.2)
    c.pluck("yangqin", jiahua(A, sc, rng, 0.5, "pipa"), 8, vel=0.40, octave=0, ring=0.7)
    c.arp("guzheng", rootsA, 8, "brisk", vel=0.46, ring=1.6, octave=-1)
    # B (16-23): call-and-response
    for k, (who, a, b_) in enumerate([("erhu", 0, 2), ("dizi", 2, 4), ("erhu", 4, 6), ("dizi", 6, 8)]):
        sub = B.sub(a, b_)
        c.voice(who, jiahua(sub, sc, rng, 0.35, who), 16 + a, dyn=0.72, slide_p=0.2 if who == "erhu" else 0.0, auto_slur=True)
        other = "dizi" if who == "erhu" else "erhu"
        c.voice(other, sub, 16 + a, dyn=0.40, vib_all=True, gap=0.1)
    c.pluck("pipa", jiahua(B, sc, rng, 0.9, "pipa"), 16, vel=0.50, octave=-1, ring=1.2)
    c.pluck("yangqin", jiahua(B, sc, rng, 0.4, "pipa"), 16, vel=0.40, octave=0, ring=0.7)
    c.arp("guzheng", rootsB, 16, "lilt", vel=0.46, ring=1.6, octave=-1)
    # A'' (24-31): tutti
    c.voice("dizi", jiahua(A, sc, rng, 0.6, "dizi"), 24, dyn=0.74, auto_slur=True)
    c.voice("erhu", jiahua(A, sc, rng, 0.35, "erhu"), 24, dyn=0.66, slide_p=0.2, auto_slur=True)
    c.pluck("pipa", jiahua(A, sc, rng, 1.0, "pipa"), 24, vel=0.52, octave=-1, ring=1.2)
    c.pluck("yangqin", jiahua(A, sc, rng, 0.6, "pipa"), 24, vel=0.42, octave=1, ring=0.7)
    c.arp("guzheng", rootsA, 24, "brisk", vel=0.48, ring=1.6, octave=-1)
    # B' (32-39): thinner - dizi + pipa + guzheng, erhu returns on the last 2 bars
    c.voice("dizi", jiahua(B, sc, rng, 0.55, "dizi"), 32, dyn=0.70, auto_slur=True)
    c.pluck("pipa", jiahua(B, sc, rng, 0.9, "pipa"), 32, vel=0.50, octave=-1, ring=1.2)
    c.voice("erhu", B.sub(6, 8), 38, dyn=0.60, slide_p=0.2, auto_slur=True)
    c.arp("guzheng", rootsB, 32, "lilt", vel=0.44, ring=1.6, octave=-1)
    c.pluck("yangqin", jiahua(B.sub(4, 8), sc, rng, 0.5, "pipa"), 36, vel=0.38, octave=1, ring=0.7)
    # coda (40-42)
    c.voice("erhu", Z, 40, dyn=0.62, slide_p=0.15, auto_slur=True)
    c.voice("dizi", jiahua(Z, sc, rng, 0.4, "dizi"), 40, dyn=0.56, auto_slur=True)
    c.pluck("pipa", jiahua(Z, sc, rng, 0.8, "pipa"), 40, vel=0.46, octave=-1, ring=1.6)
    c.arp("guzheng", "1 | 1, | 1", 40, "slow", vel=0.42, ring=3.0, octave=-1)
    c.gliss("guzheng", 42 * 4 + 1.0, c.p("1,"), c.p("1'"), up=True, t_step=(0.05, 0.025), vel=(0.2, 0.4), ring=2.2)
    return c


MIX_TEA = Mix(gain_db={"erhu": 0.0, "dizi": -0.5, "pipa": -2.0, "guzheng": -3.5, "yangqin": -4.5},
              send_db={"erhu": -3.0, "dizi": -3.0, "pipa": -4.5, "guzheng": -4.5, "yangqin": -3.5}, wet_db=-1.5, rt60=1.9,
              damp=0.45, predelay_ms=24.0, dry_lp=7200.0, dry_shelf_db=-1.5, noise_db=-48.0, target_lufs=-19.0)


# ============================================================================
# 7. stingers
# ============================================================================
def _sting_ctx(name, key="D4"):
    return Ctx(name, key, 60, 4, 3, phrase_beats=999, breath_amt=0.0, drift=0.0)   # 1 beat == 1 second


def build_sting_morning() -> Ctx:
    c = _sting_ctx("sting_morning")
    c.harm("guzheng", 0.10, c.p("1'"), vel=0.40, ring=4.0, pan=-0.2)
    c.harm("guzheng", 0.70, c.p("5'"), vel=0.34, ring=4.0, pan=0.25)
    c.gliss("guzheng", 0.25, c.p("1,"), c.p("1"), up=True, t_step=(0.15, 0.09), vel=(0.18, 0.28), ring=3.0)
    c.note("dizi", 0.85, 0.9, c.p("5"), dyn=0.52, slur=True, gin=1.6, vib=False)
    c.note("dizi", 1.75, 0.4, c.p("6"), dyn=0.56, slur=True, vib=False)
    c.note("dizi", 2.15, 0.5, c.p("1'"), dyn=0.60, slur=True, vib=False)
    c.note("dizi", 2.65, 1.5, c.p("2'"), dyn=0.60, vib=True, swell=0.08)
    c.harm("guzheng", 3.0, c.p("5'"), vel=0.30, ring=3.0)
    c.pl["guzheng"].append(PEvent(c.tm.start(2.8), c.p("1"), 0.32, ring=3.0))
    return c


def build_sting_day_end() -> Ctx:
    c = _sting_ctx("sting_day_end")
    seq = [(0.0, "5'", 0.50), (0.45, "3'", 0.44), (0.92, "2'", 0.44), (1.40, "1'", 0.46), (1.92, "6", 0.44),
           (2.45, "5", 0.46), (3.02, "3", 0.46), (3.60, "2", 0.42)]
    for t, d, v in seq:
        c.pl["guzheng"].append(PEvent(c.tm.start(t) + 0.02, c.p(d), v, ring=2.4))
    c.pl["guzheng"].append(PEvent(c.tm.start(4.1), c.p("1"), 0.46, ring=3.2))
    c.pl["guzheng"].append(PEvent(c.tm.start(4.1), c.p("1,"), 0.48, ring=3.6))
    c.pl["guzheng"].append(PEvent(c.tm.start(4.18), c.p("5,"), 0.36, ring=3.0))
    return c


def build_sting_unlock() -> Ctx:
    c = _sting_ctx("sting_unlock")
    t_end = c.gliss("guzheng", 0.0, c.p("1"), c.p("1''"), up=True, t_step=(0.058, 0.022), vel=(0.28, 0.62), ring=2.6)
    base = t_end + 0.12
    for midi, v, d in [(c.p("5'"), 0.58, 0.0), (c.p("1''"), 0.6, 0.02), (c.p("1'"), 0.52, 0.06)]:
        c.pl["guzheng"].append(PEvent(base + d, midi, v, ring=3.0))
    c.pl["guzheng"].append(PEvent(base + 0.05, c.p("1,"), 0.46, ring=3.0))
    c.pl["guzheng"].append(PEvent(base + 0.45, c.p("5''"), 0.30, kind="harm", ring=3.0))
    return c


def build_sting_unease() -> Ctx:
    c = _sting_ctx("sting_unease", "G4")
    c.pl["guzheng"].append(PEvent(0.05, c.p("6,,"), 0.45, ring=4.0, extra={"bright": 0.7}))
    notes = [VNote(0.15, 0.85, c.p("5"), 0.62, slur=True, vib=True, port=0.30),
             VNote(1.0, 0.8, c.p("3"), 0.62, slur=True, vib=True, vib_depth=1.4, port=0.40),
             VNote(1.8, 1.25, c.p("6,"), 0.56, vib=True, vib_depth=1.8, swell=0.0)]
    c.vo["erhu"].extend(notes)
    c.pl["guzheng"].append(PEvent(1.3, c.p("2"), 0.22, kind="harm", ring=2.5))
    return c


MIX_STING = Mix(gain_db={"dizi": 0.0, "guzheng": -1.0, "erhu": 0.0}, send_db={"dizi": -4.0, "guzheng": -5.0, "erhu": -4.0},
                wet_db=-2.5, rt60=1.5, damp=0.4, target_lufs=-16.0, noise_db=-80.0, tail_s=4.0)


# ============================================================================
# registry
# ============================================================================
TRACKS = {
    "title": dict(title="《德厚当》", build=build_title, mix=MIX_TITLE, loop=True, volume_db=-3.0,
                  mood="怀旧、安静；父母失踪的当铺。二胡独奏，古筝稀疏琶音。"),
    "town_day": dict(title="《桥头街》", build=build_town_day, mix=MIX_DAY, loop=True, volume_db=-4.0,
                     mood="日间主城：笛子、琵琶、古筝、扬琴；温暖、从容，步行速度。"),
    "town_dusk": dict(title="《傍晚》", build=build_town_dusk, mix=MIX_DUSK, loop=True, volume_db=-4.0,
                      mood="黄昏，人们归家；二胡领奏，古筝琶音，琥珀色的光。"),
    "night": dict(title="《夜·后门》", build=build_night, mix=MIX_NIGHT, loop=True, volume_db=-5.0,
                  mood="夜里，收音机与后门；低音箫、古筝泛音、长长的空白，安静的紧张。"),
    "pawnshop": dict(title="《柜台》", build=build_pawnshop, mix=MIX_PAWN, loop=True, volume_db=-6.0,
                     mood="柜台对话时的底乐；琵琶/古筝独奏，中低音区，稀疏轻柔。"),
    "teahouse": dict(title="《茶馆》", build=build_teahouse, mix=MIX_TEA, loop=True, volume_db=-5.0,
                     mood="茶馆角落里的丝竹小合奏，稍活泼，带距离感。"),
    "sting_morning": dict(title="晨", build=build_sting_morning, mix=MIX_STING, loop=False, volume_db=-3.0, dur_s=6.0,
                          mood="天亮：笛子上行短句，古筝泛音。"),
    "sting_day_end": dict(title="日终", build=build_sting_day_end, mix=MIX_STING, loop=False, volume_db=-3.0, dur_s=6.0,
                          mood="一天结束：古筝下行终止式。"),
    "sting_unlock": dict(title="解锁", build=build_sting_unlock, mix=MIX_STING, loop=False, volume_db=-3.0, dur_s=4.0,
                         mood="线索/地点解锁：古筝明亮刮奏，落在稳定的音上。"),
    "sting_unease": dict(title="不安", build=build_sting_unease, mix=MIX_STING, loop=False, volume_db=-3.0, dur_s=4.0,
                         mood="坏消息：二胡下滑音，低音古筝。"),
}
