"""W2-7a 行走图自查：按 ART_SPEC §12.5（64×128，16×32 一帧，4 行 下/左/右/上，4 列 站/迈左/站/迈右，脚点 (8,30)）
切帧并检查：每帧连通块数、外框、脚底行、同一行各帧之间的差异像素数；再把朝下第一帧 (0,0,16,32)
按门口 ×8（场景坐标 ×2）贴到 I-101 的 door 站位 (144,36,32,64)，导出 ×4 的牌桌模拟图。"""
import sys, json
import numpy as np
from PIL import Image
from scipy import ndimage
D = sys.argv[1]; BG = sys.argv[2]; OUT = sys.argv[3]
IDS = ["I-107_walk_ex_newsboy", "I-108_walk_ex_porter", "I-109_walk_stranger_peddler"]
ROWS = ["down", "left", "right", "up"]
rep = {}
bg = Image.open(BG).convert("RGBA")
mock = Image.new("RGBA", (320 * 3, 180))
for k, n in enumerate(IDS):
    a = np.asarray(Image.open(f"{D}/{n}.png").convert("RGBA"))
    assert a.shape == (128, 64, 4), a.shape
    fr = {}
    for r in range(4):
        for c in range(4):
            f = a[r*32:(r+1)*32, c*16:(c+1)*16]
            op = f[..., 3] > 0
            lab, num = ndimage.label(op, structure=np.ones((3, 3)))
            sizes = sorted([int((lab == i).sum()) for i in range(1, num + 1)], reverse=True)
            ys, xs = np.nonzero(op)
            fr[(r, c)] = f
            rep.setdefault(n, {}).setdefault("frames", {})[f"{ROWS[r]}{c}"] = dict(
                components=num, comp_sizes=sizes, bbox=[int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1],
                feet_row=int(ys.max()), touches_cell_edge=bool(op[:, 0].any() or op[:, -1].any() or op[0].any()))
    diffs = {}
    for r in range(4):
        d = []
        for c in range(1, 4):
            d.append(int((np.any(fr[(r, c)] != fr[(r, 0)], -1)).sum()))
        diffs[ROWS[r]] = dict(vs_stand0=d, stand0_vs_stand2=d[1])
        # 迈左脚 vs 迈右脚
        diffs[ROWS[r]]["step1_vs_step3"] = int((np.any(fr[(r, 1)] != fr[(r, 3)], -1)).sum())
    rep[n]["row_diffs"] = diffs
    # left vs mirrored right
    rep[n]["left_eq_mirror_right"] = bool(all((fr[(1, c)] == fr[(2, c)][:, ::-1]).all() for c in range(4)))
    # 牌桌模拟：门口 ×8 = 场景 ×2
    tile = bg.copy()
    one = Image.fromarray(fr[(0, 0)]).resize((32, 64), Image.NEAREST)
    tile.alpha_composite(one, (144, 36))
    mock.paste(tile, (320 * k, 0))
mock.resize((mock.width * 4 // 2, mock.height * 4 // 2), Image.NEAREST).convert("RGB").save(f"{OUT}/walk_door_slice_mock.png")
json.dump(rep, open(f"{OUT}/walk_check.json", "w"), indent=1, ensure_ascii=False)
for n in IDS:
    f = rep[n]["frames"]
    print(n, "max components/frame:", max(v["components"] for v in f.values()),
          "frames>1comp:", [k for k, v in f.items() if v["components"] > 1],
          "feet rows:", sorted(set(v["feet_row"] for v in f.values())),
          "edge-touching:", [k for k, v in f.items() if v["touches_cell_edge"]])
    print("   diffs:", rep[n]["row_diffs"], "left==mirror(right):", rep[n]["left_eq_mirror_right"])
