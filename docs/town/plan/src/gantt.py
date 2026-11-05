# 生成甘特图 SVG（德厚当 2026-10-12 → 2027-02-14）
import datetime as dt
from html import escape

D0 = dt.date(2026, 10, 12)
D1 = dt.date(2027, 2, 15)
W = 1060
LABEL_W = 92
PLOT_W = W - LABEL_W - 8
DAYS = (D1 - D0).days
ROW_H = 31
BAR_H = 23

C = {"A": "#2a78d6", "B": "#eb6834", "OUT": "#1baf7a", "STEAM": "#eda100"}
INK = "#0b0b0b"
INK2 = "#52514e"
MUTED = "#8a8984"
GRID = "#e4e3df"


def x(d):
    if isinstance(d, str):
        d = dt.date.fromisoformat(d)
    return LABEL_W + (d - D0).days / DAYS * PLOT_W


def d(s):
    return dt.date.fromisoformat(s)


# lane: (key, title, rows[[(label, start, end_inclusive, critical)]])
LANES = [
    ("A", "A 剧情·美术", [
        [("大纲·风格指南·角色设定", "2026-10-12", "2026-10-25", False), ("剧情重写 序章–第8天", "2026-10-26", "2026-11-15", False), ("观察句1", "2026-11-16", "2026-11-22", False), ("第9–14天·结局", "2026-11-30", "2026-12-13", False), ("数据·叙事文字·观察句2", "2026-12-14", "2027-01-03", False), ("校对→锁定", "2027-01-04", "2027-01-08", True), ("试玩修正·宣传", "2027-01-11", "2027-01-31", False)],
        [("背景5·柜台工具25", "2026-10-26", "2026-11-08", False), ("物品1–12·贴花", "2026-11-09", "2026-11-22", False), ("室内地砖", "2026-11-23", "2026-11-29", False), ("文案·UI", "2026-11-30", "2026-12-06", False), ("物品13–22", "2026-12-07", "2026-12-20", False), ("审外包·调色变体", "2026-12-28", "2027-01-10", False)],
    ]),
    ("B", "B 程序·音乐", [
        [("来源清单·白名单·CI", "2026-10-12", "2026-10-25", False), ("结局系统·存档迁移", "2026-10-26", "2026-11-08", False), ("鉴定改造·守铺一致性", "2026-11-09", "2026-11-22", False), ("平衡1", "2026-11-23", "2026-11-29", False), ("Steam", "2026-12-07", "2026-12-13", False), ("平衡2", "2026-12-14", "2026-12-20", False), ("试玩修复·平衡3·RC", "2026-12-21", "2027-01-10", False), ("RC1", "2027-01-11", "2027-01-15", True), ("修bug·发布·热修", "2027-01-18", "2027-02-04", False)],
        [("作曲：标题→当铺→夜→短乐句", "2026-10-19", "2026-11-29", False), ("音效", "2026-11-30", "2026-12-06", False), ("结局曲", "2026-12-14", "2026-12-20", False)],
        [("商店图·截图", "2026-11-23", "2026-12-02", True), ("系统/规矩文字", "2026-12-03", "2026-12-13", False), ("预告片", "2027-01-11", "2027-01-15", True)],
    ]),
    ("OUT", "外包（禁AI合同）", [
        [("C1 主视觉·封面", "2026-10-21", "2026-11-25", True)],
        [("C2 试稿", "2026-10-21", "2026-11-01", False), ("C2 头像 第1批(8人)", "2026-11-02", "2026-12-04", False), ("C2 第2批", "2026-12-05", "2026-12-30", False)],
        [("C3 试稿", "2026-10-21", "2026-11-01", False), ("C3 行走图身体16个", "2026-11-02", "2026-12-30", False)],
        [("C4 通用物品11·陈设15", "2026-11-02", "2026-12-23", False)],
    ]),
    ("STEAM", "Steam·行政", [
        [("入驻·税表·银行", "2026-10-12", "2026-11-13", True), ("商店素材", "2026-11-16", "2026-12-02", True), ("店审", "2026-12-07", "2026-12-15", True), ("即将推出（≥14天，这里43天）", "2026-12-16", "2027-01-27", True), ("首发折扣", "2027-01-28", "2027-02-11", False)],
        [("付费后30天等待", "2026-10-23", "2026-11-22", True), ("构建审核", "2027-01-13", "2027-01-27", True)],
        [("店主节", "2027-01-25", "2027-02-01", False)],
    ]),
]

MILESTONES = [
    ("M0", "2026-10-16"), ("M1", "2026-10-30"), ("M2", "2026-11-27"), ("M3", "2026-12-16"),
    ("M4", "2026-12-18"), ("M5", "2027-01-08"), ("M6", "2027-01-13"), ("M7", "2027-01-28"),
]

BANDS = [("Valve 假期·不提交审核", "2026-12-21", "2027-01-04"), ("春节", "2027-02-05", "2027-02-11")]


def svg() -> str:
    top = 46
    rows_total = sum(len(l[2]) for l in LANES)
    lane_gap = 8
    h = top + 36 + rows_total * ROW_H + len(LANES) * lane_gap + 30
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{h}" viewBox="0 0 {W} {h}" font-family="WenQuanYi Zen Hei, sans-serif">']
    out.append('<defs><pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="6" height="6" fill="#f3f2ee"/><line x1="0" y1="0" x2="0" y2="6" stroke="#d9d7d0" stroke-width="2"/></pattern></defs>')
    # bands
    for name, a, b in BANDS:
        x0, x1 = x(a), x(d(b) + dt.timedelta(days=1))
        out.append(f'<rect x="{x0:.1f}" y="{top-14}" width="{x1-x0:.1f}" height="{h-top-8}" fill="url(#hatch)"/>')
        out.append(f'<text x="{(x0+x1)/2:.1f}" y="{h-6}" font-size="10" fill="{INK2}" text-anchor="middle">{escape(name)}</text>')
    # week grid + labels
    wk = D0
    n = 1
    while wk < D1:
        xx = x(wk)
        out.append(f'<line x1="{xx:.1f}" y1="{top-14}" x2="{xx:.1f}" y2="{h-20}" stroke="{GRID}" stroke-width="1"/>')
        out.append(f'<text x="{xx+3:.1f}" y="{top-18}" font-size="9.5" fill="{INK2}">W{n}</text>')
        out.append(f'<text x="{xx+3:.1f}" y="{top-6}" font-size="9" fill="{MUTED}">{wk.month}/{wk.day}</text>')
        wk += dt.timedelta(days=7)
        n += 1
    # month labels
    for m in [dt.date(2026, 10, 12), dt.date(2026, 11, 1), dt.date(2026, 12, 1), dt.date(2027, 1, 1), dt.date(2027, 2, 1)]:
        out.append(f'<text x="{x(m)+2:.1f}" y="12" font-size="11" fill="{INK}" font-weight="bold">{m.year}年{m.month}月</text>')
        out.append(f'<line x1="{x(m):.1f}" y1="15" x2="{x(m):.1f}" y2="{top-26}" stroke="{INK2}" stroke-width="1"/>')
    # milestone row（菱形在上，标签在下；挨得近的两个错开一行）
    y = top + 2
    out.append(f'<text x="4" y="{y+14}" font-size="12" fill="{INK}" font-weight="bold">里程碑</text>')
    for mid, ds in MILESTONES:
        xx = x(ds) + (x(d(ds) + dt.timedelta(days=1)) - x(ds)) / 2
        out.append(f'<path d="M{xx:.1f},{y} l6,7 l-6,7 l-6,-7 z" fill="{INK}" stroke="#fcfcfb" stroke-width="1.5"/>')
        dd = d(ds)
        lab = f"{mid} {dd.month}/{dd.day}"
        anchor, dx = "middle", 0
        if mid in ("M3", "M5"):
            anchor, dx = "end", -2
        if mid in ("M4", "M6"):
            anchor, dx = "start", 2
        out.append(f'<text x="{xx+dx:.1f}" y="{y+26}" font-size="10.5" fill="{INK}" text-anchor="{anchor}" font-weight="bold">{lab}</text>')
    y += 36
    # lanes
    for key, title, rows in LANES:
        lane_h = len(rows) * ROW_H
        out.append(f'<rect x="0" y="{y-3}" width="{W}" height="{lane_h+4}" fill="none" stroke="{GRID}"/>')
        out.append(f'<rect x="2" y="{y+2}" width="4" height="{lane_h-6}" fill="{C[key]}" rx="2"/>')
        tl = title.split("（")
        out.append(f'<text x="10" y="{y+13}" font-size="11" fill="{INK}" font-weight="bold">{escape(tl[0])}</text>')
        if len(tl) > 1:
            out.append(f'<text x="10" y="{y+26}" font-size="9" fill="{INK2}">（{escape(tl[1])}</text>')
        for r, bars in enumerate(rows):
            by = y + r * ROW_H
            for label, a, b, crit in bars:
                x0 = x(a)
                x1 = x(d(b) + dt.timedelta(days=1))
                wbar = max(x1 - x0 - 2, 3)
                dash = ' stroke-dasharray="4 2" stroke="#0b0b0b" stroke-width="1.2"' if crit else ""
                out.append(f'<rect x="{x0+1:.1f}" y="{by}" width="{wbar:.1f}" height="{BAR_H}" rx="4" fill="{C[key]}" fill-opacity="0.24"{dash}/>')
                out.append(f'<rect x="{x0+1:.1f}" y="{by}" width="3" height="{BAR_H}" rx="1.5" fill="{C[key]}"/>')
                # label: inside if fits, else clipped by font size
                fs = 11.5
                approx = len(label) * fs * 0.95
                if approx > wbar - 8:
                    fs = max(7.5, (wbar - 8) / max(len(label), 1) / 0.95)
                out.append(f'<text x="{x0+6:.1f}" y="{by+15.5}" font-size="{fs:.1f}" fill="{INK}">{escape(label)}</text>')
        y += lane_h + lane_gap
    # deadline + today
    for ds, lab in [("2027-01-31", "交付截止 1/31"), ("2026-10-12", "今天")]:
        xx = x(d(ds) + dt.timedelta(days=1)) if ds == "2027-01-31" else x(ds)
        out.append(f'<line x1="{xx:.1f}" y1="{top-14}" x2="{xx:.1f}" y2="{h-20}" stroke="{INK}" stroke-width="1.5"/>')
        if ds != "2026-10-12":
            out.append(f'<text x="{xx-3:.1f}" y="{h-8}" font-size="10.5" fill="{INK}" text-anchor="end" font-weight="bold">{lab}</text>')
    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    open("gantt.svg", "w", encoding="utf-8").write(svg())
