"""W2-7a 第三次返工（Claude 10-18 14:50 复审 + 主创 #200 15:00 定稿）：以 I-101（白天，已对位）为底图，按“亮度映射 + 有序抖动”重做黄昏 / 夜里。

做法（全部确定性，没有随机数，同样输入跑两次输出字节相同）：
1. 每个像素先认出它在白天图里是哪个色板键（白天图只有 10 个色板色）。
2. 再按位置分区：门洞外的街（门洞里原来亮的像素）/ 柜台下半截 / 屋里其他地方。
3. 屋里算一个连续的“光量” v（0 = 环境光，最大 = 火苗旁）：v 只由到油灯火苗的距离决定，按几个控制点做分段线性插值，
   到了最外一个控制点以后 v 恒为 0（远处只是整体暗下去，没有圈，也没有遮罩边）。
   黄昏另加门洞四周的夕照 v_spill（同样是随距离线性减弱），两者取大。
4. 光档 = floor(v + Bayer4×4[y%4][x%4])，阈值表按画面的绝对像素坐标铺，所以抖动点和像素格对齐；
   两档之间的过渡是像素画的有序抖动（棋盘 / 点阵），一格一格往外变暗，不出现硬边圆盘。
5. 新颜色 = 查表[时段][分区][白天的键][光档]。表是“亮度映射”：白天越亮的键映到越亮的目标；
   黄昏亮处偏橙、暗处偏棕紫；夜里环境光偏冷偏暗，灯光档只用暖黄 / 暖棕（不再用灰色键），只照亮左侧柜台一角。
   相邻亮度的键映到不同的目标，所以门外街景的轮廓、柜台下的抽屉和木纹都留下来。
6. 夜里门外是靛蓝的街，房子是剪影，另点亮两扇窗（两块固定矩形里原来的 mist 像素改成灯色）。
只换颜色，不动任何像素位置；目标色只用 data/cards/theme/palette.dev.json 里已有的不透明键，不发明色值。
输出 8 位 RGBA PNG，只有 IHDR/IDAT/IEND。
用法：python3 relight_counter.py <I-101_bg_counter_day.png> <palette.dev.json> <输出目录> [<三图对比.png> [<油灯局部×3.png>]]
给了第 4 个参数时，另把白天 / 黄昏 / 夜里各放大 ×3 并排导出成一张对比图（2976×630，PR 里贴的就是它）；
给了第 5 个参数时，另导出黄昏 / 夜里油灯一角（x 0–127、y 36–131）放大 ×3 的局部图，看抖动用。"""
import sys, json, zlib, struct
import numpy as np
from PIL import Image
SRC, PAL, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
CMP = sys.argv[4] if len(sys.argv) > 4 else None
ZOOM = sys.argv[5] if len(sys.argv) > 5 else None
COL = json.load(open(PAL))["colors"]
def rgb(k):
    v = COL[k].lstrip("#"); assert len(v) == 6, k  # 只用不透明键
    return tuple(int(v[i:i+2], 16) for i in (0, 2, 4))
# 白天图里出现的键（ink == wood_dark、wood_mid == ink_soft 在开发初值里同色，这里用 ink / wood_mid）
SRC_KEYS = ["paper", "paper_old", "mist", "gold", "lamp", "seal", "jade", "wood_mid", "wood", "ink"]
NAME = {rgb(k): k for k in SRC_KEYS}
LAMP = (21, 86)                 # 柜上油灯火苗（320×180 坐标）
OPEN = (130, 18, 190, 100)      # 门洞里两扇门之间露出街的部分 x0,y0,x1,y1（不含）
VP = (160, 58)                  # 街的消失点（最远、最亮）
COUNTER_LOW = 116               # 柜台面以下（抽屉、木纹）从这一行起
WINDOWS = [(172, 30, 180, 49), (179, 43, 190, 50)]  # 夜里点亮的两扇窗（门外右侧房子）
# 有序抖动阈值（Bayer 4×4，(i+0.5)/16）
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16
# 光量控制点：到火苗的距离 r（px，竖直方向 ×1.25）→ 光量 v；最后一个点以外 v = 0
FALL = dict(dusk=([6, 18, 32, 52, 76], [4, 3, 2, 1, 0]),
            night=([3, 14, 28, 46, 70], [4, 3, 2, 1, 0]))
LOW_Y = dict(dusk=1.6, night=2.4)   # 柜台下半截在灯下面、被柜台面挡着：竖直距离再放大这么多倍
TOP_Y = dict(dusk=1.25, night=0.9)  # 火苗以下到柜台面（灯照在柜面上的那一片）竖直距离的倍数；夜里放小一点，灯脚下那片柜面最亮
SPILL = (0, 22, 1.0)                # 黄昏：门洞外夕照漏进屋，距门洞 0 px 时 v = 1，22 px 时降到 0（只在柜台面以上）
# 屋里：键 -> [环境光 0, 1, 2, 3, 火苗旁 4]
ROOM = dict(
  dusk=dict(
    paper=    ["frame_person", "gold", "frame_gold", "lamp", "candle_tint"],
    paper_old=["reply_off", "frame_person", "gold", "frame_gold", "lamp"],
    mist=     ["frame_street", "frame_estate", "frame_news", "frame_news", "night_tint"],
    gold=     ["reply_off", "frame_person", "gold", "frame_gold", "lamp"],
    lamp=     ["frame_gold", "lamp", "lamp", "lamp", "lamp"],
    seal=     ["danger", "danger", "seal", "seal", "seal"],
    jade=     ["good", "good", "jade", "jade", "jade"],
    wood_mid= ["wood_mid", "wood_mid", "reply_off", "frame_person", "frame_person"],
    wood=     ["frame_prison", "wood", "wood", "wood_mid", "wood_mid"],
    ink=      ["ink", "ink", "ink", "wood", "wood"]),
  night=dict(   # 0 = 环境光（偏冷偏暗，整屋一样）；1–4 = 油灯暖光，只用暖棕 / 暖黄
    paper=    ["frame_estate", "frame_person", "gold", "frame_gold", "lamp"],
    paper_old=["frame_fate", "wood_mid", "frame_person", "gold", "frame_gold"],
    mist=     ["frame_night", "wood_mid", "reply_off", "frame_person", "gold"],
    gold=     ["frame_prison", "wood_mid", "frame_person", "gold", "frame_gold"],
    lamp=     ["gold", "frame_gold", "lamp", "lamp", "lamp"],
    seal=     ["wood", "wood_mid", "danger", "seal", "seal"],
    jade=     ["frame_night", "frame_fate", "good", "jade", "jade"],
    wood_mid= ["frame_prison", "wood_mid", "frame_person", "frame_person", "gold"],
    wood=     ["ink", "wood", "wood_mid", "frame_person", "gold"],
    ink=      ["scene_void", "scene_void", "ink", "ink", "wood"]))
# 柜台下半截在环境光（0 档）里用这张表：暗部抬一点，抽屉和木纹留轮廓
LOW = dict(
  dusk=dict(wood_mid="wood_mid", wood="frame_fate", ink="ink", gold="reply_off", mist="frame_street"),
  night=dict(wood_mid="frame_fate", wood="frame_fate", ink="ink", gold="frame_fate", mist="frame_night"))
# 门外街：键 -> [消失点附近, 中, 两侧/近处]
STREET = dict(
  dusk=dict(paper=["candle_tint", "btn_day", "frame_gold"], paper_old=["frame_gold", "frame_person", "frame_person"],
            mist=["frame_street", "frame_street", "frame_fate"], gold=["frame_person"] * 3, wood_mid=["frame_fate"] * 3),
  night=dict(paper=["indigo", "indigo", "indigo"], paper_old=["frame_night", "frame_big_fate", "frame_big_fate"],
             mist=["frame_night", "frame_big_fate", "frame_big_fate"], gold=["frame_big_fate"] * 3, wood_mid=["scene_void"] * 3))
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
def save(a, p):
    h, w, _ = a.shape; b = a.astype(np.uint8).tobytes()
    raw = b"".join(b"\x00" + b[y*w*4:(y+1)*w*4] for y in range(h))
    open(p, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                        + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
src = np.asarray(Image.open(SRC).convert("RGBA"))
h, w = src.shape[:2]
names = [[NAME[tuple(int(c) for c in src[y, x, :3])] for x in range(w)] for y in range(h)]
yy, xx = np.mgrid[0:h, 0:w]
rv = np.hypot(xx - VP[0], (yy - VP[1]) * 1.4)
in_open = (xx >= OPEN[0]) & (xx < OPEN[2]) & (yy >= OPEN[1]) & (yy < OPEN[3])
thr = BAYER[yy % 4, xx % 4]
def in_win(y, x): return any(x0 <= x < x1 and y0 <= y < y1 for x0, y0, x1, y1 in WINDOWS)
outs = {}
for mode in ("dusk", "night"):
    ky = np.where(yy >= COUNTER_LOW, 1.25 * LOW_Y[mode], np.where(yy > LAMP[1], TOP_Y[mode], 1.25))
    r = np.hypot(xx - LAMP[0], (yy - LAMP[1]) * ky)
    xp, fp = FALL[mode]
    v = np.interp(r, xp, fp)                      # r ≥ 最后一个控制点 → 0，远处整片一样
    if mode == "dusk":
        dx = np.maximum(np.maximum(OPEN[0] - xx, xx - (OPEN[2] - 1)), 0)
        dy = np.maximum(np.maximum(OPEN[1] - yy, yy - (OPEN[3] - 1)), 0)
        d = np.hypot(dx, dy)
        vs = np.where(yy < 100, np.interp(d, SPILL[:2], [SPILL[2], 0.0]), 0.0)
        v = np.maximum(v, vs)
    level = np.minimum(np.floor(v + thr), 4).astype(int)   # 有序抖动：小数部分 = 落到上一档的像素比例
    sband = np.where(rv < 9, 0, np.where(rv < 20, 1, 2))
    out = src.copy()
    for y in range(h):
        for x in range(w):
            n = names[y][x]; lv = int(level[y, x])
            if in_open[y, x] and n in STREET[mode]:
                m = STREET[mode][n][int(sband[y, x])]
                if mode == "night" and n == "paper" and y >= 84: m = "frame_night"   # 近处地面更暗
                if mode == "night" and n == "mist" and in_win(y, x): m = "frame_gold"  # 两扇亮着的窗
            elif y >= COUNTER_LOW and lv == 0 and n in LOW[mode]:
                m = LOW[mode][n]
            else:
                m = ROOM[mode][n][lv]
            out[y, x, :3] = rgb(m)
    save(out, f"{OUT}/{mode}.png")
    outs[mode] = out
if CMP:
    from PIL import ImageDraw, ImageFont
    try: font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 28)
    except Exception: font = ImageFont.load_default()
    sheet = Image.new("RGB", (2976, 630), (60, 60, 60)); dr = ImageDraw.Draw(sheet)
    panels = [("bg.counter.day  I-101", src), ("bg.counter.dusk  I-101 relit v3 (dither)", outs["dusk"]),
              ("bg.counter.night  I-101 relit v3 (dither)", outs["night"])]
    for i, (label, a) in enumerate(panels):
        x = 24 + i * 984
        sheet.paste(Image.fromarray(a.astype(np.uint8), "RGBA").convert("RGB").resize((960, 540), Image.NEAREST), (x, 60))
        dr.text((x, 16), label, font=font, fill=(255, 255, 255))
    sheet.save(CMP, optimize=True)
if ZOOM:
    from PIL import ImageDraw, ImageFont
    try: font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24)
    except Exception: font = ImageFont.load_default()
    box = (0, 36, 128, 132)                        # 油灯一角，128×96
    cw, ch = (box[2] - box[0]) * 3, (box[3] - box[1]) * 3
    sheet = Image.new("RGB", (24 + 2 * (cw + 24), ch + 76), (60, 60, 60)); dr = ImageDraw.Draw(sheet)
    for i, (label, a) in enumerate([("dusk lamp x3", outs["dusk"]), ("night lamp x3", outs["night"])]):
        x = 24 + i * (cw + 24)
        crop = Image.fromarray(a.astype(np.uint8), "RGBA").convert("RGB").crop(box)
        sheet.paste(crop.resize((cw, ch), Image.NEAREST), (x, 56))
        dr.text((x, 16), label, font=font, fill=(255, 255, 255))
    sheet.save(ZOOM, optimize=True)
