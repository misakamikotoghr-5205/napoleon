# bg.counter 候选 01（W2-7a 出图流程试跑）

Refs #200。这是 **Flow 图片** 线跑通出图流程的第一张试图：Misaka 在云端虚拟机上用 Google Flow 出图、下载，再由 Flow 图片在 box 上做后处理、计算哈希并提 PR。

> **主创 10-18 决定（#212，见 `docs/cards/ART_SPEC.md` 顶部、`docs/handoff_cards/W2_HANDOFF.md` 任务 7 与末尾一节）：这一版美术用 AI，带 AI 内容声明发。** 原来写的“AI 只出占位、不进 Steam 包”已作废。定稿图放 `art/ai/<类别>/<id>.png`，清单登记 `ai` 路径和来源（#201）。这张仍然只是出图流程的试图，用来定风格，不是定稿，所以本 PR 不登记进 `data/cards/art/manifest.json`，也不放进 `art/ai/**` 或 `art/cards/**`。

## 文件

| 文件 | 说明 | 尺寸 | 字节 | sha256 |
|---|---|---|---|---|
| `bg_counter_cand01_original.jpg`（**不在仓库里**，见下） | Flow 原图，未放大、未修改（原文件名 `Interior_of_1930s_Chinese_pawnshop_20261018024059.jpg`） | 1376×768 JPEG（RGB） | 624650 | `0ebbac2492f400ac4305a665a23ff2c542899a5509621eb9c4f8b60d5cdf8d70` |
| `bg_counter_cand01.png` | 320×180 预览，8 位 RGBA，只有 IHDR/IDAT/IEND 三个块（没有 iCCP、sRGB、tIME），只用 §4 的 11 种颜色 | 320×180 | 7070 | `e916c3102f1e2d28347d0ba772d87120577515097a0f65b4b11e0a41bfe6ea81` |

按审核意见，原图 JPG 不进仓库（只放后处理好的 PNG）。上面这张原图已从分支里删掉，按文件名和 sha256 留档；原件暂存在 Flow 图片线的 box 上，等定好放网盘还是 Release 附件再上传。

Misaka 传来的压缩包是 `Dehoudang-W2-7a-originals.zip`，617918 字节，里面只有上面这张 jpg。sha256：`353785bc4240bf9d1415d2ed7673add8b22f95bcfcd7a374b59c1a59d78cf219`。

## 出图

- 工具：Google Flow（labs.google/flow），图片模式
- 账号：Flow 图片线的 Google AI Ultra 账号（邮箱不写进仓库）
- 模型：Nano Banana 2.1
- 设置：16:9，1 张，只生成一次，下载原图（没有放大）
- 积分：生成前 10,050，生成后 10,050，**这次扣了 0**
- 生成时间：2026-10-18 02:40（UTC）

### 提示词

```
16-bit pixel art game background, 16:9, interior of a 1930s Chinese pawnshop (当铺) seen from behind the counter, flat front-facing view.
A tall dark wooden counter runs across the lower half; its top edge sits slightly above the middle of the frame.
A wooden shop door with paper-lattice panels is centered in the upper part of the back wall, a little left of center.
Single warm oil lamp on the counter at upper left is the only light source; light falls from upper left, shadows to lower right.
Limited palette only: aged paper #f4e2b0, old paper #d9c49a, ink #1f1712, dark wood #3a2a1e, mid wood #5a3f2a, lamp yellow #ffd25a, seal red #b0262a, gold #a07a2c, jade #2f6b5a, indigo #2f4670, mist grey #9aa4aa.
Crisp hard pixel edges, flat color fills with one shadow tone, ink outlines, no gradients, no anti-aliasing, no characters, no text.
```

### 负面词

```
photorealistic, 3D render, smooth gradients, glow, bloom, blur, anti-aliasing, lens flare, people, text, letters, watermark, signature, modern objects, isometric view
```

## 后处理（320×180 预览）

1. 居中裁成 16:9：从 1376×768 裁出 1365×768，裁剪框 (5, 0, 1370, 768)。
2. 用 BOX（面积平均）缩到 320×180。原图只是看起来像像素画，像素网格并不整齐，直接用最近邻缩会断线、出噪点。
3. 不抖动，每个像素换成 CIELAB 色差最近的 §4 颜色。只用 11 个开发初值：`paper` `paper_old` `ink`/`wood_dark` `wood` `wood_mid`/`ink_soft` `lamp`/`gold_glow` `seal` `gold` `jade` `indigo` `mist`。我先试过 RGB 色差，结果墙面出现大块青绿色和靛蓝色，所以改用 Lab。
4. 写成 8 位 RGBA PNG，只有 IHDR/IDAT/IEND，zlib 压缩级别 9。同样的输入跑两次，输出的字节完全相同。

## 和 ART_SPEC 对照

- 光源：左上有一盏油灯，暗部在右下。符合 §5。
- 构图：门在后墙偏左、柜台横在下半部，大体对得上，但**没有对准**旧图的坐标。§5 要求门在 112,8,96,92、柜台面在 y=100；这张门大约在 x≈88–155，柜台面大约在 y≈105–110。正式候选需要在 Flow 里加构图参考图，或者后期对位。
- 右半边偏暗、偏冷，缩到 320×180 后细节丢得多。
- 画面里没有人物、没有字。卷轴上有看不清的伪字，这符合规矩。
