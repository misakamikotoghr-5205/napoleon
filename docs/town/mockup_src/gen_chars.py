"""16x32 character sheets (3 frames x 4 directions) for the 青溪镇 mockups.

Sheet layout: 48x128 — columns = frames (0 stand, 1 step-A, 2 step-B),
rows = directions (0 down/front, 1 left, 2 right, 3 up/back).
Feet touch y=30 of each 16x32 cell (outline on y=31). Anchor = (8, 30).
"""
import os
from pix import Cv, C, ASSETS, mix, from_ascii

OUT = os.path.join(ASSETS, "chars")
DIRS = ("down", "left", "right", "up")

# ------------------------------------------------------------------ heads
# rows for y = 2..15 (14 rows). Keys: H hair, h hair hi, S skin, s skin shade,
# E eye, b blush, A accent, W white, w white shade, K hat, k hat hi, d hat dark
HEADS = {
    "girl": {
        "down": [
            "......HHHH......",
            "....HHHHHHHH....",
            "...HHHHhhHHHH...",
            "..HHHHhHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHHSHHHHSHHH..",
            "..HSSSSSSSSSSH..",
            "..HSSESSSSESSH..",
            "..HSSESSSSESSH..",
            "..HSbSSSSSSbSH..",
            "...sSSSSSSSSs...",
            "....sSSSSSSs....",
            "......SSSS......",
        ],
        "up": [
            "......HHHH......",
            "....HHHHHHHH....",
            "...HHHHhhHHHH...",
            "..HHHHhHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHHHHhHHHHHH..",
            "..HHHHHHhHHHHH..",
            "..HHHHHhHHHHHH..",
            "..HHHHHHhHHHHH..",
            "..sHHHHhHHHHHs..",
            "...sHHHHhHHHs...",
            "....sSSHHSSs....",
            "......SHHS......",
        ],
        "right": [
            ".....HHHH.......",
            "...HHHHHHHH.....",
            "..HHHHHhhHHH....",
            "..HHHHhHHHHHH...",
            ".HHHHHHHHHHHH...",
            ".HHHHHHHHHHHHH..",
            ".HHHHHHHSSHHSH..",
            ".HHHHHSSSSSSSS..",
            ".HHHHHSSSSSESS..",
            "..HHHHSSSSSESSS.",
            "..HHHHsSSSSSbS..",
            "...HHsSSSSSSS...",
            "......sSSSSS....",
            ".......sSSs.....",
        ],
    },
    "bun": {   # old woman, grey hair in a low bun
        "down": [
            "......HHHH......",
            ".....HhhHHH.....",
            "....HHHHHHHH....",
            "...HHHhhHHHHH...",
            "..HHHhHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHSSSSSSSSHH..",
            "..HSSSSSSSSSSH..",
            "..HSsESSSSEsSH..",
            "..HSSSSSSSSSSH..",
            "..HSbSssssSbSH..",
            "...sSSSSSSSSs...",
            "....sSSSSSSs....",
            "......SSSS......",
        ],
        "up": [
            "......HHHH......",
            ".....HhhHHH.....",
            "....HHHHHHHH....",
            "...HHHhhHHHHH...",
            "..HHHhHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHHHHhHHHHHH..",
            "..HHHHHAAHHHHH..",
            "..HHHHAhhAHHHH..",
            "..HHHAhhHhAHHH..",
            "..sHHAHHHHAHHs..",
            "...sHHAAAAHHs...",
            "....sSSSSSSs....",
            "......SSSS......",
        ],
        "right": [
            "................",
            "....HHHHH.......",
            "...HHhhHHHH.....",
            "..HHHhHHHHHH....",
            ".HHHHHHHHHHHH...",
            ".HHHHHHHHHHHH...",
            "HHHHHHHHSSSSHH..",
            "HhHHHHHSSSSSSS..",
            "HHHHHHHSSsSESS..",
            ".HHHHHHSSSSSSSS.",
            "..HHHHHsSSSsbS..",
            "...HHHsSSSSSS...",
            "......sSSSSS....",
            "........SSs.....",
        ],
    },
    "nurse": {  # bob hair + white cap with red cross
        "down": [
            ".....WWWWWW.....",
            "....WWWAWWWW....",
            "...HWWAAAWWWH...",
            "..HHwwwAwwwwHH..",
            "..HHHHHHHHHHHH..",
            "..HHhHHHHHHHHH..",
            "..HHHHHSSHHHHH..",
            "..HHSSSSSSSSHH..",
            "..HHSESSSSESHH..",
            "..HHSESSSSESHH..",
            "..HHbSSSSSSbHH..",
            "..HHsSSSSSSsHH..",
            "...H.sSSSSs.H...",
            "......SSSS......",
        ],
        "up": [
            ".....WWWWWW.....",
            "....WWWWWWWW....",
            "...HwwwwwwwwH...",
            "..HHHHHHHHHHHH..",
            "..HHhHHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "...HsSSSSSSsH...",
            "......SSSS......",
        ],
        "right": [
            ".....WWWWW......",
            "...WWWWWAWW.....",
            "..HWWWWAAAWH....",
            "..HHwwwwAwwHH...",
            ".HHHHHHHHHHHH...",
            ".HHHhHHHHHHHHH..",
            ".HHHHHHHHSSSSH..",
            ".HHHHHHSSSSSSS..",
            ".HHHHHHSSSSESS..",
            ".HHHHHHSSSSESSS.",
            ".HHHHHHsSSSSbS..",
            ".HHHHHHsSSSSS...",
            "..HHHH.sSSSS....",
            "........SSs.....",
        ],
    },
    "crop": {  # labourer: cropped hair + white towel band
        "down": [
            "................",
            ".....HHHHHH.....",
            "....HHhhHHHH....",
            "...HHhHHHHHHH...",
            "..HHHHHHHHHHHH..",
            "..WWWWWWWWWWWW..",
            "..wSSSSSSSSSSw..",
            "..SSSSSSSSSSSS..",
            "..SSdESSSSEdSS..",
            "..SSSESSSSESSS..",
            "..sSSSSssSSSSs..",
            "...sSSSSSSSSs...",
            "....sSSssSSs....",
            "......ssss......",
        ],
        "up": [
            "................",
            ".....HHHHHH.....",
            "....HHhhHHHH....",
            "...HHhHHHHHHH...",
            "..HHHHHHHHHHHH..",
            "..WWWWWWWWWWWW..",
            "..wHHHHHHHHHHw..",
            "..HHHHHHHHHHHH..",
            "..HHHHHHHHHHHH..",
            "..sHHHHHHHHHHs..",
            "..sSHHHHHHHHSs..",
            "...sSSSSSSSSs...",
            "....sSSSSSSs....",
            "......ssss......",
        ],
        "right": [
            "................",
            "....HHHHHH......",
            "...HHhhHHHH.....",
            "..HHhHHHHHHH....",
            "..HHHHHHHHHHH...",
            "..WWWWWWWWWWW...",
            "..wHHHHSSSSSSS..",
            "..HHHHSSSSSSSS..",
            "..HHHHSSSSdESS..",
            "..HHHsSSSSSESSS.",
            "..sHHsSSSSSSsS..",
            "...sssSSSSSSS...",
            "......sSSSSS....",
            "........sss.....",
        ],
    },
    "felthat": {
        "down": [
            "......KKKK......",
            "....KKkkKKKK....",
            "....KkKKKKKK....",
            "....AAAAAAAA....",
            "..KKKKKKKKKKKK..",
            "...dddddddddd...",
            "...HSSSSSSSSH...",
            "...SSSSSSSSSS...",
            "...SEESSSSEES...",
            "...SSSSSSSSSS...",
            "...sSSSHHSSSs...",
            "....sSHHHHSs....",
            ".....sSSSSs.....",
            "......ssss......",
        ],
        "up": [
            "......KKKK......",
            "....KKkkKKKK....",
            "....KkKKKKKK....",
            "....AAAAAAAA....",
            "..KKKKKKKKKKKK..",
            "...dddddddddd...",
            "...HHHHHHHHHH...",
            "...HHHHHHHHHH...",
            "...HHHHHHHHHH...",
            "...sHHHHHHHHs...",
            "...sSSSSSSSSs...",
            "....sSSSSSSs....",
            ".....sSSSSs.....",
            "......ssss......",
        ],
        "right": [
            ".....KKKK.......",
            "....KkkKKKK.....",
            "....KkKKKKK.....",
            "....AAAAAAA.....",
            "..KKKKKKKKKKKK..",
            "....dddddddd....",
            "....HHHSSSSSS...",
            "....HHSSSSSSS...",
            "....HHSSSSESSS..",
            "....HsSSSSSSSSS.",
            "....sSSSSSHHS...",
            ".....sSSSHHHS...",
            "......sSSSSs....",
            "........ss......",
        ],
    },
    "police": {
        "down": [
            "................",
            "....KKKKKKKK....",
            "...KkkKKKKKKK...",
            "...KKKKAAKKKK...",
            "...KKKKAAKKKK...",
            "...wwwwwwwwww...",
            "...dddddddddd...",
            "...SSSSSSSSSS...",
            "...SEESSSSEES...",
            "...SSSSSSSSSS...",
            "...sSSSSSSSSs...",
            "....sSSssSSs....",
            ".....sSSSSs.....",
            "......ssss......",
        ],
        "up": [
            "................",
            "....KKKKKKKK....",
            "...KkkKKKKKKK...",
            "...KKKKKKKKKK...",
            "...KKKKKKKKKK...",
            "...wwwwwwwwww...",
            "...HHHHHHHHHH...",
            "...HHHHHHHHHH...",
            "...HHHHHHHHHH...",
            "...sHHHHHHHHs...",
            "...sSSSSSSSSs...",
            "....sSSSSSSs....",
            ".....sSSSSs.....",
            "......ssss......",
        ],
        "right": [
            "................",
            "....KKKKKKK.....",
            "...KkkKKKKKK....",
            "...KKKKKKAAK....",
            "...KKKKKKAAK....",
            "...wwwwwwwwwdd..",
            "....HHHSSSSdd...",
            "....HHSSSSSSS...",
            "....HHSSSSESSS..",
            "....HsSSSSSSSSS.",
            "....sSSSSSSSs...",
            ".....sSSSSSS....",
            "......sSSSSs....",
            "........ss......",
        ],
    },
    "boy": {  # shaved head with a front tuft (child)
        "down": [
            "................",
            "......HH........",
            ".....HHHHHH.....",
            "....hhhhhhhh....",
            "...hSSSSSSSSh...",
            "..hSSSSSSSSSSh..",
            "..SSSSSSSSSSSS..",
            "..SSSSSSSSSSSS..",
            "..SSSESSSSESSS..",
            "..SSSESSSSESSS..",
            "..SbSSSSSSSSbS..",
            "...sSSSSSSSSs...",
            "....sSSssSSs....",
            "......SSSS......",
        ],
        "up": [
            "................",
            "......HH........",
            ".....HHHHHH.....",
            "....hhhhhhhh....",
            "...hhhhhhhhhh...",
            "..hhhhhhhhhhhh..",
            "..hhhhhhhhhhhh..",
            "..hhhhhhhhhhhh..",
            "..hhhhhhhhhhhh..",
            "..shhhhhhhhhhs..",
            "..sSSSSSSSSSSs..",
            "...sSSSSSSSSs...",
            "....sSSSSSSs....",
            "......SSSS......",
        ],
        "right": [
            "................",
            ".........HH.....",
            "......HHHHHH....",
            "....hhhhhhhh....",
            "...hhhhhSSSSS...",
            "..hhhhhSSSSSSS..",
            "..hhhhSSSSSSSS..",
            "..hhhhSSSSSSSS..",
            "..hhhSSSSSSESS..",
            "..hhhSSSSSSESSS.",
            "..shhsSSSSSSbS..",
            "...ssSSSSSSSS...",
            ".....sSSSSSS....",
            "........SSs.....",
        ],
    },
}

# ------------------------------------------------------------------ torsos
# rows for y = 16..23 (8 rows). T main, t shade, L light, C collar/trim, S skin,
# P apron/panel, p panel shade, G belt, g buckle
TORSO = {
    "jacket": {
        "down": [
            "....tTTCCTTt....",
            "..ttLTTTCTTTtt..",
            "..ttLTTTTCTTtt..",
            "..ttLTTTTTCTtt..",
            "..ttLTTTTTTCtt..",
            "..ttLTTTTTTTtt..",
            "..SSLTTTTTTTSS..",
            "..SStttttttsSS..",
        ],
        "up": [
            "....tTTTTTTt....",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..SSLTTTTTTTSS..",
            "..SSttttttttSS..",
        ],
        "right": [
            "......TTTT......",
            ".....LTTTTTC....",
            ".....LTttTTC....",
            ".....LTttTTT....",
            ".....LTttTTT....",
            ".....LTttTTT....",
            ".....LTSSTTT....",
            ".....ttSStttt...",
        ],
    },
    "apron": {
        "down": [
            "....tTTTTTTt....",
            "..ttLTTTTTTTtt..",
            "..ttLTPPPPTTtt..",
            "..ttLPPPPPpTtt..",
            "..ttLPPPPPpTtt..",
            "..ttTPPPPPpTtt..",
            "..SSTPPPPPpTSS..",
            "..SStPPPPPptSS..",
        ],
        "up": [
            "....tTTTTTTt....",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..ttLTTPPTTTtt..",
            "..ttLTTTTTTTtt..",
            "..SSLTTTTTTTSS..",
            "..SSttttttttSS..",
        ],
        "right": [
            "......TTTT......",
            ".....LTTTTTT....",
            ".....LTttTPP....",
            ".....LTttTPPP...",
            ".....LTttTPPp...",
            ".....LTttPPPp...",
            ".....LTSSPPPp...",
            ".....ttSSPPPp...",
        ],
    },
    "dress": {
        "down": [
            "....tTTCCTTt....",
            "..ttLTTTCTTTtt..",
            "..ttLTTTCTTTtt..",
            "..ttLTTTCTTTtt..",
            "..ttLTGGGGTTtt..",
            "..ttLTTTTTTTtt..",
            "..SSLTTTTTTTSS..",
            "..SSLTTTTTTTSS..",
        ],
        "up": [
            "....tTTTTTTt....",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..ttLTGGGGTTtt..",
            "..ttLTTTTTTTtt..",
            "..SSLTTTTTTTSS..",
            "..SSLTTTTTTTSS..",
        ],
        "right": [
            "......TTTT......",
            ".....LTTTTTC....",
            ".....LTttTTC....",
            ".....LTttTTT....",
            ".....GGttGGG....",
            ".....LTttTTT....",
            ".....LTSSTTT....",
            ".....LTSSTTTT...",
        ],
    },
    "labor": {  # open jacket over white undershirt, rolled sleeves
        "down": [
            "....tTTPPTTt....",
            "..ttLTTPPTTTtt..",
            "..ttLTPPPPTTtt..",
            "..SSLTPPPPTTSS..",
            "..SSLTPPPpTTSS..",
            "..SSLTPPPpTTSS..",
            "..SSLTPPPpTTSS..",
            "...GGGGGGGGGG...",
        ],
        "up": [
            "....tTTTTTTt....",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..SSLTTTTTTTSS..",
            "..SSLTTTTTTTSS..",
            "..SSLTTTTTTTSS..",
            "..SSLTTTTTTTSS..",
            "...GGGGGGGGGG...",
        ],
        "right": [
            "......TTTT......",
            ".....LTTTTPP....",
            ".....LTttTPP....",
            ".....LTSSTPP....",
            ".....LTSSTPP....",
            ".....LTSSTPp....",
            ".....LTSSTPp....",
            ".....GGGGGGG....",
        ],
    },
    "gown": {  # 长衫 + short black 马褂 over it
        "down": [
            "....tPPCCPPt....",
            "..ttLPPPPPPPtt..",
            "..ttLPPPPPPPtt..",
            "..ttLPPAPPPPtt..",
            "..ttLPPPPPPPtt..",
            "..ttLPPAPPPPtt..",
            "..SSLTTTTTTTSS..",
            "..SSLTTTTTTTSS..",
        ],
        "up": [
            "....tPPPPPPt....",
            "..ttLPPPPPPPtt..",
            "..ttLPPPPPPPtt..",
            "..ttLPPPPPPPtt..",
            "..ttLPPPPPPPtt..",
            "..ttLPPPPPPPtt..",
            "..SSLTTTTTTTSS..",
            "..SSLTTTTTTTSS..",
        ],
        "right": [
            "......PPPP......",
            ".....LPPPPPC....",
            ".....LPttPPP....",
            ".....LPttPPP....",
            ".....LPttPPP....",
            ".....LPttPPP....",
            ".....LTSSTTT....",
            ".....LTSSTTT....",
        ],
    },
    "uniform": {
        "down": [
            "....tTTCCTTt....",
            "..ttLTTTTTTTtt..",
            "..ttLTTAATTTtt..",
            "..ttLTTTCTTTtt..",
            "..ttLTTTCTTTtt..",
            "..ttGGGGgGGGtt..",
            "..SSLTTTCTTTSS..",
            "..SSLTTTTTTTSS..",
        ],
        "up": [
            "....tTTTTTTt....",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..ttLTTTTTTTtt..",
            "..ttGGGGGGGGtt..",
            "..SSLTTTTTTTSS..",
            "..SSLTTTTTTTSS..",
        ],
        "right": [
            "......TTTT......",
            ".....LTTTTTC....",
            ".....LTttTTT....",
            ".....AAttTTT....",
            ".....LTttTTT....",
            ".....GGttGGG....",
            ".....LTSSTTT....",
            ".....LTSSTTT....",
        ],
    },
}

LEGSTYLE = {"jacket": "trousers", "apron": "trousers", "dress": "dress", "labor": "rolled",
            "gown": "gown", "uniform": "trousers", "child": "shorts"}


def legs(c, style, d, frame, y0=24, ytot=30):
    """Draw lower body from y0 down to ytot (feet bottom) for direction d and walk frame."""
    B, b, F, S, T, t, W, L = "B", "R", "F", "S", "T", "t", "W", "L"
    put = lambda x, y, k: c.__setitem__((x, y), k)
    n = ytot - y0 + 1   # rows available (7 for adults)
    # leg columns per direction
    if d in ("down", "up"):
        lx, rx = (5, 8)
        lift = {0: (0, 0), 1: (0, 2), 2: (2, 0)}[frame]
        if style in ("gown", "dress"):
            skirt_rows = n - 2 if style == "gown" else n - 3
            for i in range(skirt_rows):
                y = y0 + i
                flare = 1 if i >= skirt_rows - 3 else 0
                for x in range(4 - flare, 12 + flare):
                    k = T if x > 4 else L
                    if x >= 10:
                        k = t
                    put(x, y, k)
                if style == "gown" and d == "down" and i < skirt_rows:
                    put(8, y, t)   # front opening seam
            ys = y0 + skirt_rows
            if style == "dress":
                # stockings
                for (x0, lf) in ((lx, lift[0]), (rx, lift[1])):
                    for y in range(ys, ytot - 1 - lf + 1):
                        put(x0 + 1, y, W)
                        put(x0 + 2 if x0 == lx else x0, y, W)
            for (x0, lf) in ((lx, lift[0]), (rx, lift[1])):
                for x in range(x0, x0 + 3):
                    put(x, ytot - lf - 1, F)
                    put(x, ytot - lf, F)
            return
        for (x0, lf, kk) in ((lx, lift[0], B), (rx, lift[1], b)):
            yb = ytot - lf
            for y in range(y0, yb - 1):
                for x in range(x0, x0 + 3):
                    k = kk
                    if style == "rolled" and y >= yb - 4:
                        k = S
                    if style == "shorts" and y >= y0 + 2:
                        k = S
                    if style == "rolled" and y == yb - 5:
                        k = "W"   # rolled cuff
                    put(x, y, k)
            for x in range(x0, x0 + 3):
                put(x, yb - 1, F)
                put(x, yb, F)
        # hips
        for x in range(4, 12):
            if (x, y0) not in c:
                put(x, y0, B if x < 8 else b)
        return
    # side view (right). frame 0 together, 1 & 2 apart (near/far swapped)
    if style in ("gown", "dress"):
        rows = n - 2 if style == "gown" else n - 3
        for i in range(rows):
            for x in range(5, 11 + (1 if i >= rows - 2 else 0)):
                put(x, y0 + i, L if x == 5 else (t if x >= 10 else T))
        ys = y0 + rows
        feet = {0: [(6, 0), (7, 0)], 1: [(4, 0), (9, 1)], 2: [(9, 0), (4, 1)]}[frame]
        if style == "dress":
            for (fx, lf) in feet:
                for y in range(ys, ytot - lf - 1):
                    put(fx + 1, y, W)
        for (fx, lf) in feet:
            for x in range(fx, fx + 3):
                put(x, ytot - lf, F)
            put(fx + 1, ytot - lf - 1, F)
        return
    if frame == 0:
        for y in range(y0, ytot - 1):
            for x in range(6, 10):
                k = B if x < 8 else b
                if style == "rolled" and y >= ytot - 5:
                    k = S
                if style == "rolled" and y == ytot - 6:
                    k = "W"
                if style == "shorts" and y >= y0 + 2:
                    k = S
                put(x, y, k)
        for x in range(6, 11):
            put(x, ytot - 1, F); put(x, ytot, F)
        return
    # stride: back leg goes left/down-left, front leg right
    near, far = (B, b) if frame == 1 else (b, B)
    for i, y in enumerate(range(y0, ytot - 1)):
        fx = 7 + (i * 3) // 6       # front leg drifts right
        bx = 7 - (i * 3) // 6       # back leg drifts left
        for (x0, kk) in ((bx, far), (fx, near)):
            for x in range(x0, x0 + 2):
                k = kk
                if style == "rolled" and y >= ytot - 5:
                    k = S
                if style == "rolled" and y == ytot - 6:
                    k = "W"
                if style == "shorts" and i >= 2:
                    k = S
                put(x, y, k)
    for x in range(10, 13):
        put(x, ytot - 1, F)
        put(x, ytot, F)
    for x in range(3, 6):
        put(x, ytot - 1, F)
    put(3, ytot - 2, F)


def compose(char, d, frame):
    """Return a 16x32 Cv for one cell."""
    spec = CHARS[char]
    keymap = spec["colors"]
    grid = {}
    child = spec.get("child", False)
    dd = "right" if d == "left" else d
    hy = 7 if child else 2
    # head
    for i, row in enumerate(HEADS[spec["head"]][dd]):
        assert len(row) == 16, (char, dd, i, row)
        for x, ch in enumerate(row):
            if ch != ".":
                grid[(x, hy + i)] = ch
    # torso
    ty = 21 if child else 16
    torso = TORSO[spec["torso"]][dd]
    rows = torso if not child else torso[:1] + torso[2:6] + torso[7:]
    bob = 1 if (frame != 0 and d in ("left", "right")) else 0
    for i, row in enumerate(rows):
        assert len(row) == 16, (char, dd, i, row)
        for x, ch in enumerate(row):
            if ch != ".":
                grid[(x, ty + i)] = ch
    # arm swing in side view
    if dd == "right" and frame in (1, 2):
        sw = 1 if frame == 1 else -1
        for y in range(ty + 2, ty + len(rows)):
            for x in (6, 7, 8):
                if grid.get((x, y)) in ("t", "S"):
                    grid[(x, y)] = "T" if grid[(x, y)] == "t" else grid[(x, y)]
        hx = 7 + sw
        for y in range(ty + 2, ty + len(rows) - 2):
            grid[(hx, y)] = "t"; grid[(hx + 1, y)] = "t"
        grid[(hx, ty + len(rows) - 2)] = "S"; grid[(hx + 1, ty + len(rows) - 2)] = "S"
    ly = ty + len(rows)
    legs(grid, LEGSTYLE["child" if child else spec["torso"]] if not spec.get("legs") else spec["legs"], dd, frame, y0=ly, ytot=30)
    # extras (braid etc.)
    for fn in spec.get("extras", []):
        fn(grid, dd, frame)
    c = Cv(16, 32)
    for (x, y), ch in grid.items():
        col = keymap.get(ch)
        if col is not None and 0 <= x < 16 and 0 <= y < 32:
            c.put(x, y, col)
    # vertical bob: lift whole sprite 1px on step frames (feels alive)
    if frame in (1, 2):
        shifted = Cv(16, 32)
        shifted.blit(c, 0, -1 if d in ("down", "up") else 0)
        c = shifted
    c.outline(spec.get("outline", C.dkbrown))
    if d == "left":
        c = c.mirror_x()
    return c


# -------------------------------------------------------------- extras
def braid(grid, d, frame):
    if d == "up":
        for y in range(16, 25):
            grid[(7, y)] = "H" if y % 2 else "h"
            grid[(8, y)] = "h" if y % 2 else "H"
        grid[(7, 24)] = "A"; grid[(8, 24)] = "A"
        grid[(7, 25)] = "H"; grid[(8, 25)] = "H"
    elif d == "right":
        sway = {0: 0, 1: -1, 2: 0}[frame]
        for y in range(14, 23):
            grid[(3 + sway, y)] = "H" if y % 2 else "h"
            grid[(4 + sway, y)] = "h" if y % 2 else "H"
        grid[(3 + sway, 22)] = "A"; grid[(4 + sway, 22)] = "A"
        grid[(4 + sway, 23)] = "H"
    elif d == "down":
        # braid peeks over the right shoulder
        for y in range(15, 21):
            grid[(12, y)] = "H" if y % 2 else "h"
        grid[(12, 20)] = "A"
        grid[(12, 21)] = "H"


def bun_back(grid, d, frame):
    if d == "right":
        for (x, y) in ((1, 9), (1, 10), (2, 10), (1, 11), (2, 11)):
            grid[(x, y)] = "H"
        grid[(1, 10)] = "A"


def bag(grid, d, frame):
    """Nurse's small medical bag in hand."""
    if d == "down":
        for x in range(12, 15):
            for y in range(23, 26):
                grid[(x, y)] = "G"
        grid[(13, 24)] = "A"
    elif d == "right":
        for x in range(4, 7):
            for y in range(22, 25):
                grid[(x, y)] = "G"


def pole(grid, d, frame):
    """Labourer's carrying pole (扁担) across the shoulder."""
    if d == "down":
        for x in range(0, 16):
            grid[(x, 17)] = "Q"
    elif d == "up":
        for x in range(0, 16):
            grid[(x, 17)] = "Q"
    elif d == "right":
        for y in range(9, 16):
            pass
        for x in range(0, 16):
            grid[(x, 16)] = "Q"


def baton(grid, d, frame):
    if d == "right":
        for y in range(21, 26):
            grid[(4, y)] = "G"
    elif d == "down":
        for y in range(21, 26):
            grid[(12, y)] = "q"


CHARS = {
    "ruhua": {
        "name": "沈如花", "head": "girl", "torso": "jacket",
        "colors": {"H": C.hair, "h": C.gray, "S": C.skinm, "s": C.skin, "E": C.dkbrown, "b": C.blush,
                   "A": C.seal_red, "T": C.indigo2, "t": C.indigo1, "L": C.blue_hi, "C": C.ww0,
                   "B": C.indigo0, "b_": None, "F": C.black, "W": C.white, "G": C.wood1},
        "extras": [braid],
    },
    "zhouma": {
        "name": "周妈", "head": "bun", "torso": "apron",
        "colors": {"H": C.silver, "h": C.fog, "S": C.skinm, "s": C.skin, "E": C.dkbrown, "b": C.blush,
                   "A": C.gray, "T": C.wood1, "t": C.wood0, "L": C.wood2, "P": C.ww0, "p": C.ww2,
                   "B": C.hair, "F": C.black, "W": C.white},
        "extras": [bun_back],
    },
    "zhang": {
        "name": "张护士", "head": "nurse", "torso": "dress",
        "colors": {"H": C.hair, "h": C.gray, "S": C.skinm, "s": C.skin, "E": C.dkbrown, "b": C.blush,
                   "A": C.seal_red, "W": C.ww0, "w": C.ww2, "T": C.ww0, "t": C.ww2, "L": C.white,
                   "C": C.indigo2, "G": C.indigo2, "F": C.black},
        "extras": [bag],
    },
    "wangshan": {
        "name": "王山", "head": "crop", "torso": "labor",
        "colors": {"H": C.hair, "h": C.gray, "S": C.skin, "s": C.skin_lo, "E": C.dkbrown, "d": C.skin_lo,
                   "W": C.ww1, "w": C.ww2, "T": C.wood3, "t": C.wood2, "L": C.tan, "P": C.ww1, "p": C.ww2,
                   "G": C.wood1, "B": C.wall1, "F": C.tan, "Q": C.gold},
        "extras": [],
    },
    "ma": {
        "name": "马保长", "head": "felthat", "torso": "gown",
        "colors": {"K": C.hair, "k": C.gray, "A": C.wood1, "d": C.rf0, "H": C.hair, "S": C.skinm, "s": C.skin,
                   "E": C.dkbrown, "P": C.rf1, "C": C.ww0, "T": C.wall2, "t": C.wall1, "L": C.mist,
                   "B": C.wall1, "F": C.black},
        "extras": [],
    },
    "police": {
        "name": "警察", "head": "police", "torso": "uniform",
        "colors": {"K": C.rf1, "k": C.rf3, "A": C.gold, "w": C.ww1, "d": C.black, "H": C.hair, "S": C.skinm,
                   "s": C.skin, "E": C.dkbrown, "T": C.rf1, "t": C.rf0, "L": C.rf3, "C": C.gold,
                   "G": C.wood1, "g": C.gold, "B": C.rf1, "R": C.rf0, "F": C.black, "q": C.wood2},
        "extras": [baton],
    },
    "xiaoding": {
        "name": "小丁", "head": "boy", "torso": "jacket", "child": True,
        "colors": {"H": C.hair, "h": C.gray, "S": C.skin, "s": C.skin_lo, "E": C.dkbrown, "b": C.blush,
                   "T": C.paper, "t": C.paper_old, "L": C.paper_hi, "C": C.wood2, "B": C.wood1, "F": C.wood0},
        "colors_fix": {"h": C.rf2},
        "extras": [],
    },
}


def fix_colors():
    # lower-case 'b' (trouser shade) collides with blush in heads; resolve per char
    for k, spec in CHARS.items():
        cm = spec["colors"]
        cm.update(spec.get("colors_fix", {}))
        cm.setdefault("B", C.indigo0)
        cm.setdefault("R", mix(cm["B"], C.black, 0.35))


def sheet(char):
    s = Cv(48, 128)
    for r, d in enumerate(DIRS):
        for f in range(3):
            s.blit(compose(char, d, f), f * 16, r * 32)
    return s


def gen_all():
    fix_colors()
    os.makedirs(OUT, exist_ok=True)
    for k in CHARS:
        s = sheet(k)
        s.save(os.path.join(OUT, "%s_sheet.png" % k))


if __name__ == "__main__":
    gen_all()
