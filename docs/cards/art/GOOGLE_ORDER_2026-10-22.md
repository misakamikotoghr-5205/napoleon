# 给 Google 的出图单（2026-10-22，第三批：I-201 起）

> 主创 10-22：“你要是需要美术素材写一个单子我让 Google 给你生成”。这就是那张单子。
> 风格照主创 10-18 认可的第二批（`docs/cards/art/candidates/batch2/`，I-101 柜台、I-104 林嫂、I-110 金簪、I-118 回家吃饭）。工具、模型、出图方式也照第二批：Google Flow 图片模式（Nano Banana 2.1），原样下载，不放大。
> 目标：先让 1938 年第 1 天到第 30 天看起来是一套画，再往后补。按优先级分三批：**第 0 批（P0）= 每一局第 1 天必然看到、画面上占大块的；第 1 批（P1）= 第一个月常见的；第 2 批（P2）= 以后。** 建议先只做第 0 批，交回来进游戏看过效果，再做第 1 批。

---

## 0. 做完怎么交回（先看这一节）

1. **一条提示词 = 一个编号**（I-201、I-202……）。Flow 下载的文件**原样**保存，只改文件名：
   - 单张：`I-2xx_<下面每条写的短名>.<原扩展名>`，例：`I-206_portrait_ruhua.jpg`
   - 同一条出了几个变体：加 `_v1` `_v2`，例：`I-206_portrait_ruhua_v1.jpg`、`I-206_portrait_ruhua_v2.jpg`
   - 拼图（一张图里画了 4 格或 9 格的）：`I-2xx_sheet_<短名>.<扩展名>`，例：`I-211_sheet_night_a.jpg`。格子顺序在本单里写死了，不用另外标。
   - 不要裁、不要缩放、不要压缩、不要在 Flow 里放大（upscale），不要转格式。
2. **原图不进仓库**（第二批定的规矩）。请放进一个 Google 云端硬盘文件夹（建议名 `德厚当_batch3_原图`，第 0 批、第 1 批可以各建子文件夹），把链接发给 Claude；或者直接打包发到对话里。
3. 同一个文件夹里放一份 `ledger.csv`（或在聊天里列出来）：`文件名, I 编号, 工具/模型, 比例, 变体数, 出图日期, 出图前积分, 出图后积分`。**不要写出图账号的邮箱。**
4. Claude 收到后照第二批的流程做：写 `docs/cards/art/candidates/batch3/make_batch3.py`（照 `make_batch2.py`：抠绿、BOX 缩小、11 色 CIELAB 量化、拼图切格），产出每张的 PNG、一张总览 `batch3_contact.png` 和 `README.md`（每条的提示词、原图 sha256、质量备注），放在 `docs/cards/art/candidates/batch3/` 给主创挑；柜台三时段照旧用 `relight_counter.py` 从白天图换光。主创挑定的，再放进 `art/ai/<类别>/<id>.png`，在 `data/cards/art/manifest.json` 登记 `ai` 路径和 `_provenance: "ai:google-flow:<出图日期>:I-2xx"`。没挑中的不进 `art/ai/**`。
5. 某一格画坏了：可以整条重出，也可以在 Flow 里用编辑功能只改那一格（“只重画左下那一格，画成……”）。重出的文件名加 `_r1`。

---

## 1. 为什么要这些图（对照网页原型和现在的截图）

原型（`docs/cards/prototype/shots/*.png`）好看，主要是因为整个画面是**一套**：一张干净的柜台底图 + 摆在上面的工具 + 同一种画法的人。牌框、对话框、抽屉都是 CSS 画的，不是图。现在的 Godot 版（`pck_bot/*.png`）问题出在：

- **人像三种画法混在一起**：v0.4 旧图（透明底、Q 版）、程序像素画（纸底）、Google 三张（纸底、写实像素）。同一手牌里并排，一眼就看出不是一套。
- **纸底人像站到柜台前会变成一块米色方块**：林嫂、邮差、算命先生和程序画的新面孔、过路客都是不透明的纸底（48×64 里一个透明像素都没有），柜台前是直接贴图，门洞里会多出一块纸。所以**这次所有人像都要绿底，抠成透明**；牌面上的纸底由代码垫（见第 8 节）。已经认可的三张也要换成绿底重出（照原样，只换底色）。
- **柜台底图和柜上的工具打架**：I-101 画好了油灯、摊开的账本、算盘、砚台，代码又在同一处贴了放大镜、算盘、钱匣，墙上又贴了黄历、条子、告示，左右各一盏灯。原型的底图是空柜台，工具全是可点的热点。所以要一张**空台面、空墙面**的 I-101（在原图上编辑，不重新构图），再出一套同画风的工具。
- **物品不少是借来的旧图**：`art.woodcut` 和 `documents.receipt` 用的是旧报纸，`art.flowers` 用的是《辞源》，`documents.letter` 用的是田契，三种银元和银戒指都是同一张银饰，`papers.*` 用的是假地契和小报。第一个月柜台上都会出现。
- **标题和开场**用的是旧的夜景小镇，和 Google 柜台不是一个画法；开场三段字底下也是这张。

---

## 2. 每一条都适用的规矩

### 2.1 怎么贴

每条提示词 = **主体（下面每条的英文块）+ 一句底色句 + 共用风格后缀 + 共用负面词**。英文照抄就行。底色句四选一，每条都写了用哪句。

**共用风格后缀**（和第二批一字不差）：

```
16-bit pixel art, crisp hard pixel edges, flat color fills with one shadow tone, dark ink outlines, no gradients, no anti-aliasing. Single warm oil-lamp light from upper left, shadows to lower right. Limited palette only: #f4e2b0 #d9c49a #1f1712 #3a2a1e #5a3f2a #ffd25a #b0262a #a07a2c #2f6b5a #2f4670 #9aa4aa.
```

**共用负面词**（第二批的那串，后面加了这次的几项）：

```
photorealistic, 3D render, gradients, glow, bloom, blur, anti-aliasing, lens flare, readable text, letters, numbers, Chinese characters, watermark, signature, logo, modern objects, isometric, perspective tilt, cropped subject, weapons, blood, injury, corpses, flags, insignia, emblems, badges, armband lettering, Japanese soldiers, price tags, speech bubbles, captions, borders or frames around the picture
```

**底色句**：

- 【绿底】（人像、物品、道具、行走图）：`Solid flat #00ff00 background, no shadow on the background, nothing touches the image edges.`
- 【纸底小图】（牌面小插图，照 I-116～I-118）：`Each picture is a small ink-wash vignette on aged paper: one simple centered subject, generous paper margin, background plain #f4e2b0 paper.`
- 【整幅场景】（标题、开场、柜台）：`Full-bleed scene that fills the whole frame.`
- 【编辑原图】（只用于 I-203 和三张人像重出）：见那几条。

### 2.2 图里不要有的

- **任何字**：中文、英文、数字、招牌字、告示上的字、店名“当”字都不要。告示、账本、信上可以有看不清的灰色笔画或印刷块（第二批说过“伪字”可以），但不能认出是哪个字。标题“德厚当”、牌名、价钱全部由代码用字体写。
- **现代东西**：塑料、拉链、电灯泡招牌、汽车、现代眼镜框等。1938 年江南小镇。
- **血、伤口、尸体、刀枪**。王山手上的绷带画干净的白布。伪军、巡警可以出现，但只画深色制服，**不带任何旗、徽章、袖标字**；不画日本兵（原设定：“你只会见到替他们说话的人”）。伪政权的人尽量画背影或远景。
- **隐藏数值的暗示**：东西画成普通、完好的样子，**不画裂纹、补痕、霉斑、成色好坏、真假的破绽**（真假和成色是小游戏里另画的，不能在牌面和柜台图上先露出来）；不画价签。人物不画暗示秘密身份的东西：陈文庭不画电台、李敬之不画报纸稿子、王山不画枪和标志。人的表情照性格画，不要画出“好人/坏人”的提示。
- **画框、边框、标题条、对话气泡**。

### 2.3 参考图（Flow 里能加参考图的就加）

第二批原图都在 Flow 图片线那台机器上（`batch2/README.md` “原图（不在仓库里）”一节有文件名和 sha256）：

| 用在哪 | 参考图 |
|---|---|
| I-203 空台面柜台 | `I-101_bg_counter_day_original.jpg`（**必须**，是在它上面编辑） |
| 所有人像 | `I-104_portrait_linsao_original.jpg`（画风参考：胸像、纸色的脸、墨线） |
| 三张人像重出 | 各自的原图 I-104 / I-105 / I-106（**必须**） |
| 物品、道具 | `I-110_item_jewelry_hairpin_original.jpg`、`I-111_item_utensils_clock_original.jpg` |
| 牌面小插图 | `I-118_illus_nt_family_dinner_original.jpg`、`I-116_illus_es_shopfront_original.jpg` |
| 标题、开场 | `I-101_bg_counter_day_original.jpg`（只借画风和配色） |

找不到原图时，可以用仓库里的 `docs/cards/art/candidates/batch2/batch2_contact.png` 截对应那一格当参考，效果差一点。

### 2.4 尺寸（后处理由 Claude 做，出图时不用管像素）

| 类别 | 出图比例 | 游戏里的底图 | 后处理 |
|---|---|---|---|
| 背景 | 16:9 | 320×180，画面 ×4 | 裁 16:9 → 缩到 320×180；柜台要对位（门洞 112,8,96,92，柜台面 y=100） |
| 人像 | 3:4 | 48×64，柜台前 ×4，牌面 ×2/×4 | 抠绿 → 透明；胸像底边贴图片底边（站在柜台后面，下边压在柜台面上） |
| 物品 | 1:1 | 64×64，柜台 ×2，细看 ×4 | 抠绿 → 长边 60 → 居中 |
| 道具 | 1:1（九宫） | 每样尺寸不同（见 I-204、I-205） | 抠绿 → 按清单尺寸等比放进去、底边对齐 |
| 小插图 | 4:3（四宫） | 64×48，牌面 ×2/×4 | 切四格 → 主体外扩 → 4:3 → 64×48 |
| 行走图 | 9:16 | 64×128，一帧 16×32 | 照第二批切 4×4 |

全部量化到第二批那 11 色，不抖动（灯光抖动只在 `relight_counter.py` 里做）。

---

## 3. 总表

| 批 | 条数 | 填的 id | 内容 |
|---|---|---|---|
| 第 0 批 P0 | 12 | 37 | 标题、开场、空台面柜台（白天出图，黄昏和夜里换光）、柜台和墙上的工具 19 样、主角和第 1 天进门的 4 个人、夜里的 6 张牌 + 2 张主线信物 |
| 第 1 批 P1 | 43 | 131 | 其余主要人物 10 个 + 已认可的 3 个换绿底、1938 新面孔 4 个、过路客 8 个、全部物品 38 样、1938 年常见的事件 / 命运 / 生活 / 消息 / 条子小插图 68 张 |
| 第 2 批 P2 | 36（另有 2 条可选） | 118（可选再加 1） | 1939、1940 新面孔，门口走过的群演行走图，次要背景，其余道具，大命运 / 街头 / 牢房 / 家当 / 留着的牌，1939–1940 的小插图 |

总计 91 条（可选 2 条另算）。第二批 18 张没扣积分，变体多出一两张不心疼；但请**每条只点一次生成**，要几个变体就在 Flow 里把输出张数设成几。

---

## 4. 第 0 批 P0（每局第 1 天都看到，12 条）

### I-201 标题画 `bg.title`
- **短名** `bg_title`；**比例** 16:9；**变体** 2；**底色句** 【整幅场景】
- **画什么**：一进游戏就看到。夜里的青溪镇，德厚当的门面在石桥桥头，门里亮着油灯。原型的标题字在左、按钮在右下，现在的 Godot 标题字在正上方、菜单在正中，所以**左半边和上三分之一要安静**（深色夜空、平静的河面，细节少），铺子和桥放在右半边。
- **注意**：招牌、幌子画成空白，不能有“当”字。
```
Night view of a small Jiangnan water town in early spring 1938, flat front view. On the right half: the two-storey wooden front of an old pawnshop at the head of a stone arch bridge, shutters half open with warm lamplight inside, a large blank signboard over the door and a tall blank cloth banner hanging beside it; whitewashed walls and black tile roofs; the canal in front reflecting the lamplight. A thin crescent moon. The left half and the top third are calm: dark indigo night sky and still dark water with very little detail, leaving space for a title. No people.
```

### I-202 开场底图 `bg.stage.1938`
- **短名** `bg_stage_1938`；**比例** 16:9；**变体** 2；**底色句** 【整幅场景】
- **画什么**：开局三段字（`stage.1938` 的 p1–p3：“一九三八年三月，江南小镇青溪。镇子沦陷才几个月，出入要查良民证，镇上的事由伪维持会管着……”）垫在这张图上。字框盖住画面下面大约 45%，所以**要紧的东西放在上面 55%**。阴冷的早春白天：桥头街口设了木栅和沙袋，两个穿深色制服的巡警背对画面，几个镇上的人排着队手里拿着小纸片（良民证），白墙上新贴一张告示（看不清的字块 + 红印），柳枝还没发芽。
```
Grey early-spring morning, March 1938, in a small Jiangnan water town shortly after it was occupied, flat front view. At the mouth of a stone-paved street by a canal bridge: a simple wooden barrier with a few sandbags; two policemen in plain dark uniforms seen from behind, no insignia; a short line of townspeople in cotton jackets waiting, each holding a small paper card; a whitewashed wall with one freshly pasted notice made of grey illegible print blocks and a red seal; bare willow branches. Keep all important content in the upper 55% of the image; the lower 45% is plain wet paving and the canal edge with little detail, because a text panel will cover it. Muted cold daylight.
```

### I-203 空台面柜台 `bg.counter.day`（黄昏 `bg.counter.dusk`、夜里 `bg.counter.night` 由脚本换光）
- **短名** `bg_counter_clean`；**比例** 16:9；**变体** 2；**底色句** 【编辑原图】；**参考图** I-101 原图（必须）
- **画什么**：在 I-101 原图上**编辑**，不要重新构图。屋子、镜头、门、门框、门外白天的空街、柜台边沿、柜台下半截都**原样不动**；只把柜台面上的东西（油灯、摊开的账本、算盘、砚台、毛笔）全部拿掉，柜台面变成一整条空的深色木头；把后墙上的纸告示、红对联条、挂轴、两侧墙上的招贴拿掉，墙变成素白旧墙（木柱、横梁、门洞照旧）。因为代码会在这些位置贴可点的工具：左边柜面放大镜 / 算盘 / 钱匣，右边柜面账簿 / 档案簿，门左边告示和门旗，门右上招牌、条子、黄历，右墙脚油灯（见 `scripts/cards/api/card_layout.gd` 的 `S_HOTSPOTS`）。
- **之后**：白天图对位后，`relight_counter.py` 照第三次返工的做法换出黄昏和夜里，不再出图；油灯改成右边那盏（见第 8 节）。
```
Edit this image. Keep the room, the camera position, the open double doors, the door frame, the daylit empty street outside, the counter edge and the panels under the counter exactly as they are, pixel for pixel in position. Remove every object from the counter top (the oil lamp, the open book, the abacus, the inkstone, the brush) so the counter top is one long empty plain dark wooden surface. Remove all paper notices, red couplet strips, hanging scrolls and posters from the back wall and side walls, leaving plain aged whitewashed plaster between the wooden posts and beams. Do not add anything new. Keep the same pixel-art style and colors.
```

### I-204 柜面工具九宫 `prop.magnifier` `prop.abacus` `prop.cashbox` `prop.ledger` `prop.notebook` `prop.lamp`（`prop.lamp_off` 由脚本去火苗）`prop.stamp` `prop.scale` `prop.candle`
- **短名** `sheet_props_counter`；**比例** 1:1；**变体** 1（不满意整条重出）；**底色句** 【绿底】
- **画什么**：柜台上能点的工具，原型里就是这些东西摆在空柜台上。每样的长宽比要对上清单底图（括号里），后处理按这个比例放进去。账簿是蓝布面（原型和现在都是蓝的），档案簿是棕布面系绳。
```
Nine separate objects for a 1930s Chinese pawnshop counter, arranged in a 3 by 3 grid with wide green gaps; nothing overlaps or crosses into another cell; every object seen from the front and slightly above, lit from the upper left, drawn in the same style. Row 1: (1) a brass-rimmed magnifying glass with a short wooden handle, lying flat, wide and low, about 3:2; (2) a dark wooden abacus lying flat, very wide and low, about 5:2; (3) a small wooden cash box with a brass lock plate, about 2:1. Row 2: (4) a closed account ledger bound in dark blue cloth with a pale blank label strip, lying flat, about 3:2; (5) a closed thick notebook bound in brown cloth and tied with string, lying flat, about 3:2; (6) a brass kerosene table lamp with a glass chimney and a small lit flame, tall, about 5:8. Row 3: (7) a carved wooden seal standing beside a small round red ink-paste box, about 1:1; (8) a small Chinese hand steelyard for weighing silver, a thin wooden beam with a small brass pan and weight, wide and low, about 2:1; (9) a short red candle in a small brass holder, lit, tall and thin, about 1:2.
```

### I-205 墙上和纸类九宫 `prop.calendar` `prop.sign` `prop.notice` `prop.notice_wall` `prop.door_flag` `prop.door_flag_red` `prop.door_flag_white` `prop.ticket` `prop.letter`
- **短名** `sheet_props_wall`；**比例** 1:1；**变体** 1；**底色句** 【绿底】
- **画什么**：黄历（红头、撕页的挂历，原型右上那本）、门右上挂的空白木招牌、门左边的告示、墙上钉的条子（胡二送来的，有红手印）、三面门旗（蓝 / 红 / 白，陈叔叔教的暗号旗，平时只是小布旗）、当票、信。全部不能有可认的字。
```
Nine separate flat paper and wall objects for a 1930s Chinese pawnshop, arranged in a 3 by 3 grid with wide green gaps; nothing overlaps or crosses into another cell; front view, lit from the upper left. Row 1: (1) a wall almanac calendar: a thick pad of tear-off paper sheets under a red header board, hanging from a nail, about 2:3; (2) a small blank wooden signboard hanging from a string, about 3:4; (3) a printed public notice sheet made of grey illegible print blocks with a red seal near the bottom, about 3:4. Row 2: (4) a narrow paper slip nailed to a board, a few illegible brush strokes and a red thumbprint, about 2:3; (5) a small narrow blue cloth pennant on a thin bamboo stick, very tall and narrow, about 1:3; (6) the same pennant in red, about 1:3. Row 3: (7) the same pennant in white, about 1:3; (8) an old pawn ticket: one paper sheet with printed border lines and a red seal, about 3:4; (9) a letter envelope with a postage stamp and a round postmark, lying flat, about 3:4.
```

### I-206 至 I-210 主角和第 1 天进门的人（每人一条）
- **比例** 3:4；**变体** 各 2；**底色句** 【绿底】；**参考图** I-104 原图（画风）
- **共同的人像句**（加在每条主体后面，和第二批 I-104 一样的取景，只是底色换成绿）：
```
Front view, shoulders up, centered, the bust is cut by the bottom edge of the image at mid-chest with no empty space below. Face drawn in paper tone with ink lines.
```
- 名字照人名表（`playable/BRIEF.md`），外貌照 `docs/town/research/repo_story.md` 和 v0.4 旧图，让老玩家认得出。

| 编号 | 短名 / id | 人 | 第几天见到 |
|---|---|---|---|
| I-206 | `portrait_ruhua` / `portrait.ruhua` | 沈如花，主角，16 岁，当铺的妹妹 | 一直在左下角，第 1 天起每天 |
| I-207 | `portrait_brother` / `portrait.brother` | 沈如松，哥哥，19 岁 | 第 1–2 天在柜台边教你（教的人站位 ×4），第 2 天金色告别牌 |
| I-208 | `portrait_zhang` / `portrait.zhang` | 张慧娟，张护士，26 岁 | 第 1 天教学：来当簪子 |
| I-209 | `portrait_wu` / `portrait.wu` | 吴长发，裕丰米行掌柜 | 第 1 天教学：来卖簪子 |
| I-210 | `portrait_xiaoding` / `portrait.xiaoding` | 小丁，孙府伙夫，17 岁 | 第 1 天教学：来买首饰 |

```
I-206: Bust portrait of Shen Ruhua, a 16-year-old Chinese girl who keeps her family's pawnshop in 1938: black hair with a straight fringe and one long braid over her shoulder tied with a small red string, indigo-blue cotton jacket with cloth buttons, the white strap of a small cloth bag across her chest, calm alert eyes, a little stubborn.
I-207: Bust portrait of Shen Rusong, a 19-year-old Chinese young man in 1938: short black hair, navy-blue long gown with a high collar, a small old pale scar over his left eyebrow, steady, serious, protective expression.
I-208: Bust portrait of Zhang Huijuan, a 26-year-old Chinese nurse in 1938: short bobbed black hair, no cap, a greyish-white nurse's coat worn open over a navy qipao, the handle of a woven basket on her arm at the edge of the picture, brisk capable look.
I-209: Bust portrait of Wu Changfa, a Jiangnan rice-shop owner around fifty in 1938: round face with a ready smile, receding hairline, brown cotton jacket with cloth buttons, a little rice dust on the sleeves, holding a small cloth sample bag of rice.
I-210: Bust portrait of Xiao Ding, a tall thin 17-year-old kitchen boy of a landlord household in 1938: grey cotton jacket, a stained cook's apron, a towel around his neck, timid worried face.
```

### I-211 夜牌四宫 A `illus.nt.tidy` `illus.nt.accounts` `illus.nt.early_sleep` `illus.nt.sleep`（新 id）
- **短名** `sheet_night_a`；**比例** 4:3；**变体** 1；**底色句** 【纸底小图】；**参考图** I-118 原图
- **画什么**：每天打烊后手里就是这几张夜牌，和已经认可的“回家吃饭”（I-118）放在一起。`illus.nt.sleep` 是“睡了”那张（现在是空白牌面），清单里还没有这个 id，要代码配合（第 8 节）。
- **四宫的通用句**（所有四宫小插图都加）：
```
A 2 by 2 grid of four separate small pictures in four equal panels, separated by wide plain paper gutters, no lines, no numbers, no captions; each panel has its own single subject.
```
| 格 | id | 牌名 / 牌上的话 | 画什么 |
|---|---|---|---|
| 左上 | `illus.nt.tidy` | 整理库房：把货架上的东西擦洗归置一遍 | 夜里库房一角，木架上几个布包和盒子，最下层搭着掸子和抹布，凳子上一盏油灯 |
| 右上 | `illus.nt.accounts` | 对账：夜里把这个月的账从头对一遍 | 油灯下摊开的账本、算盘，毛笔搁在砚台上 |
| 左下 | `illus.nt.early_sleep` | 早点睡：早早上了门板歇下 | 从屋里看铺门，一块块门板已经插上，最后一块靠在旁边，钩子上挂一盏灯笼 |
| 右下 | `illus.nt.sleep` | 睡了：今晚什么也不做 | 窄木床，被子拉好，窗格里透进淡淡月光，小桌上的油灯拧得很小 |
```
Top-left: a storeroom corner at night, wooden shelves with a few cloth-wrapped bundles and boxes, a feather duster and a rag on the lowest shelf, an oil lamp on a stool. Top-right: an open account book and an abacus on a desk under an oil lamp, a brush resting on an inkstone. Bottom-left: a shopfront seen from inside, vertical wooden door boards slotted in place across the doorway, the last board leaning beside it, a lantern on a hook. Bottom-right: a narrow wooden bed with a quilt pulled up, a lattice window with pale moonlight, a small oil lamp turned down low on a little table.
```

### I-212 夜牌四宫 B + 主线信物 `illus.nt.backdoor` `illus.nt.telegraph` `illus.kp.brother_note` `illus.tk.de196`
- **短名** `sheet_night_b`；**比例** 4:3；**变体** 1；**底色句** 【纸底小图】+ 四宫通用句
- 后两格严格说是 P1（第 2 天起每局都有“哥哥的交代”；“德字第一九六号”是 1938 主线当票），顺手放在这一张里。

| 格 | id | 牌名 / 牌上的话 | 画什么 |
|---|---|---|---|
| 左上 | `illus.nt.backdoor` | 后门收货：夜里有人敲后门，要把货便宜出给你 | 半开的后门外是黑巷子，一只手从门缝递进一个布包，门边挂盏灯笼 |
| 右上 | `illus.nt.telegraph` | 发电报：去邮电代办那里发一封电报 | 邮电代办的小柜台，一个铜电键、一张空白电报纸、一支笔、一盏台灯 |
| 左下 | `illus.kp.brother_note` | 哥哥的交代：哥哥临走前把铺子的规矩一条条交代给你 | 柜台上一张折好的纸（看不清的工整笔画），旁边一把旧铜钥匙、一杆装在木匣里的小戥子（哥哥留下的父亲的小秤和库房钥匙） |
| 右下 | `illus.tk.de196` | 一张撕碎的旧当票，“德字第一九六号” | 深色木面上摆着撕成五片的旧当票，印的边框线和一部分红印，一个字都认不出 |
```
Top-left: a narrow back door half open onto a dark alley at night, a hand reaching in through the gap holding a cloth-wrapped bundle, a lantern hanging by the door. Top-right: a small post-office counter at night with a brass telegraph key, a blank telegram form, a pen and a desk lamp. Bottom-left: on a wooden counter, a folded sheet of paper covered in neat illegible brush strokes, an old brass key, and a small hand steelyard in an open wooden case. Bottom-right: an old pawn ticket torn into five pieces laid out on dark wood, printed border lines and part of a red seal visible, nothing readable.
```

---

## 5. 第 1 批 P1（第一个月常见，43 条）

### 5.1 其余主要人物（I-221 至 I-230，每人一条）
- **比例** 3:4；**变体** 各 2；**底色句** 【绿底】+ 第 4 节的共同人像句；**参考图** I-104 原图
- 排的顺序就是第一个月见到的先后。

| 编号 | 短名 / id | 人 | 什么时候见到 |
|---|---|---|---|
| I-221 | `portrait_sunyoung` / `portrait.sunyoung` | 孙富贵，孙少爷，22 岁 | 第 2 天教学来当簪子；买首饰、问田契 |
| I-222 | `portrait_guanjia` / `portrait.guanjia` | 孙福，孙府管家，52 岁 | 第 2 天教学来买首饰；问账、要米 |
| I-223 | `portrait_li` / `portrait.li` | 李敬之，县立中学学生，18 岁 | 第 3 天教学来卖簪子；当信、赎信 |
| I-224 | `portrait_zhouma` / `portrait.zhouma` | 周妈，桥头茶馆厨娘，45 岁 | 第 6–7 天教消息和人脉；第一个月最常来 |
| I-225 | `portrait_hu2` / `portrait.hu2` | 胡二，给伪维持会保长跑腿的 | 每周一送条子（条子牌的说话人就是他） |
| I-226 | `portrait_ma` / `portrait.ma` | 马万利，马保长，38 岁 | 金色摊派牌；卖米、打听人 |
| I-227 | `portrait_zhao` / `portrait.zhao` | 赵老三，佃户，40 岁 | 金色借钱牌；当袍子 |
| I-228 | `portrait_chen` / `portrait.chen` | 陈文庭，陈叔叔，济生堂，50 岁 | 看字画、问当票 |
| I-229 | `portrait_wangshan` / `portrait.wangshan` | 王山，自称过路的青年，22 岁 | 金色“过路的青年”牌；讨饭、问路 |
| I-230 | `portrait_sunlaoye` / `portrait.sunlaoye` | 孙德昌，孙老爷，55 岁，孙府当家、商会会长 | 买文书、托事 |

```
I-221: Bust portrait of Sun Fugui, the 22-year-old only son of the town's richest landlord in 1938: slicked-back hair, Western suit jacket, a long cream-colored scarf over both shoulders, a gold pocket-watch chain, careless half-smile.
I-222: Bust portrait of Sun Fu, the 52-year-old steward of a landlord household in 1938: black melon skullcap with a small red knot on top, grey long gown under a brown vest, a string of wooden prayer beads in one hand, polite thin smile, sharp eyes.
I-223: Bust portrait of Li Jingzhi, an 18-year-old Chinese middle-school student in 1938: dark grey student uniform with a stand-up collar and buttons, student cap pulled low, sleeves a little too short, proud earnest face.
I-224: Bust portrait of Zhou Ma, a plump 45-year-old cook at a bridge-head teahouse in 1938: white head cloth, white apron over a brown cotton jacket, sleeves rolled up, warm talkative grin.
I-225: Bust portrait of Hu Er, a thin man about thirty who runs errands for the local headman in 1938: bowl-cut black hair, black short cotton jacket buttoned to the neck, a folded blank paper slip held between two fingers, sly half-smile.
I-226: Bust portrait of Ma Wanli, a 38-year-old local headman in 1938: black bowler hat, thin little moustache, dark Western-style suit, a plain white cloth armband on his left upper arm with nothing on it, a ledger tucked inside his coat, smiling with narrowed eyes.
I-227: Bust portrait of Zhao Laosan, a 40-year-old tenant farmer in 1938: thin and sun-darkened, short cropped hair, patched blue-grey cotton jacket, a long bamboo tobacco pipe in his hand, silent stubborn face.
I-228: Bust portrait of Chen Wenting, a 50-year-old pharmacist and old family friend in 1938: grey hair, small round wire glasses, dark brown long gown, gentle careful expression.
I-229: Bust portrait of Wang Shan, a 22-year-old young man passing through a small town in 1938: short hair, an old straw rain cape over his shoulders, a plain grey jacket underneath, a clean white cloth bandage around his left hand, upright posture, watchful eyes.
I-230: Bust portrait of Sun Dechang, the 55-year-old head of the richest family in town and chairman of the merchants' association in 1938: black silk skullcap, black silk mandarin jacket over a dark blue long gown, neat grey goatee, heavy dignified face.
```

### 5.2 已认可的三张换绿底重出（I-231 至 I-233）
- **比例** 3:4；**变体** 各 2；**底色句** 【编辑原图】；**参考图** 各自原图（必须）
- 林嫂（`portrait.linsao`，I-104）、邮差何启明（`portrait.postman`，I-106，第 3 天教学来买首饰，也教电码）、算命先生（`portrait.suanming`，I-105，第 5 天教求签测字）。人、衣服、姿势、脸都不变，只把纸底换成纯绿，好抠成透明站到柜台前。
- **短名** `portrait_linsao` `portrait_postman` `portrait_suanming`
```
Edit this image. Keep the same person, the same face, clothes, pose, framing and pixel-art style exactly. Only replace the plain paper background with solid flat #00ff00, with a clean edge around the hair and shoulders and no paper color left around the figure.
```

### 5.3 新面孔和过路客（I-234 至 I-236，一张四个人）
- **比例** 3:4；**变体** 1；**底色句** 【绿底】；**参考图** I-104 原图
- 外貌依据 `data/cards/era/1938/people.json` 和 `data/cards/era/common/passersby.json` 的 brief（档案页里几处年纪和身份写得不一样，以 people.json 为准）。
- **四人通用句**：
```
Four separate bust portraits in a 2 by 2 grid of equal panels on one solid flat #00ff00 background, wide green space between the panels, every figure at the same scale, each centered in its panel and cut at mid-chest by the bottom of its panel. Front view, shoulders up. Faces drawn in paper tone with ink lines.
```

**I-234 新面孔 1938** `sheet_newfaces_1938`：`portrait.nf1938a` 钱阿根（米行脚夫，四十出头）/ `portrait.nf1938b` 周阿绣（原茧行女工，二十出头，在桥头做针线）/ `portrait.nf1938c` 方小安（济生堂学徒，十八九岁）/ `portrait.nf1938d` 崔老奎（更夫，五十出头）
```
Top-left: Qian Agen, a sun-darkened rice-shop porter in his early forties, coarse undyed short jacket, a sweat towel around his neck, a rice sack on one shoulder. Top-right: Zhou Axiu, a young woman in her early twenties who used to work at a silk filature and now sews by the bridge, hair in a neat low bun, faded green jacket, a needle and thread pinned at her collar. Bottom-left: Fang Xiao'an, an 18-year-old pharmacy apprentice, clean blue cotton jacket with white sleeve covers, holding a small folded paper medicine packet. Bottom-right: Cui Laokui, a night watchman in his early fifties, dark padded jacket, felt cap, a wooden watchman's clapper hanging on a cord at his chest.
```

**I-235 过路客甲** `sheet_strangers_a`：`portrait.stranger_refugee` 逃难的人 / `portrait.stranger_peddler` 货郎（和已认可的货郎行走图 I-109 同一个人）/ `portrait.stranger_collector` 上门收货的 / `portrait.stranger_fence` 销赃的
```
Top-left: a thin refugee man, patched dusty clothes, a cloth bundle and a rolled straw mat on his back, tired face. Top-right: a middle-aged traveling peddler, wide straw hat, patched grey jacket, the strap of a small wooden goods box over his shoulder. Bottom-left: a middle-aged dealer who buys old goods door to door, black brimmed hat, dark long gown, a small cloth bag, appraising look. Bottom-right: a younger man with a cap pulled low and his collar turned up, hands tucked in his sleeves, glancing sideways.
```

**I-236 过路客乙** `sheet_strangers_b`：`portrait.stranger_waixiang` 外乡人 / `portrait.stranger_boatman` 船工 / `portrait.stranger_student` 赶路的学生 / `portrait.stranger_widow` 守寡的过路人
```
Top-left: a traveler from another province, worn felt hat, dusty grey jacket, a cloth-wrapped bundle on his shoulder. Top-right: a weathered boatman, conical bamboo hat, short indigo jacket, a coil of rope over his shoulder. Bottom-left: a traveling student, school cap, dark student uniform, a white scarf, the strap of a cloth satchel across his chest. Bottom-right: a quiet young widow, hair in a plain bun with a small white mourning flower, plain dark clothes.
```

### 5.4 物品（I-241 至 I-250，一张四样）
- **比例** 1:1（I-250 是 16:9 两样）；**变体** 1；**底色句** 【绿底】；**参考图** I-110、I-111 原图
- 物品名和描述照 `data/cards/text_ai/items.text.json`。第一个月里来当、来卖的客人会随机带这些东西上柜台（×2），细看时放大到 ×4。已经有 Google 图的金簪、白玉坠、座钟不再出。
- **物品通用句**：
```
Four separate objects in a 2 by 2 grid on one solid flat #00ff00 background with wide green gaps, each object centered in its quarter and filling about 70% of it, seen from slightly above like goods laid on a counter, lit from the upper left. Each object is in ordinary intact condition: no cracks, mends, stains, mould, price tags or any sign of being fake or genuine. Any writing is illegible grey marks.
```

| 编号 / 短名 | 左上 | 右上 | 左下 | 右下 |
|---|---|---|---|---|
| I-241 `sheet_items_rice` | `item.rice.jing` 本地粳米 | `item.rice.xian` 籼米 | `item.rice.nuo` 糯米 | `item.rice.broken` 碎米 |
| I-242 `sheet_items_medicine` | `item.medicine.aspirin` 阿司匹林 | `item.medicine.iodine` 碘酒 | `item.medicine.quinine` 奎宁片 | `item.medicine.sulfa` 磺胺药粉 |
| I-243 `sheet_items_silver` | `item.silver.yuan_a` 袁头银元 | `item.silver.yuan_b` 船洋银元 | `item.silver.yuan_c` 龙洋银元 | `item.silver.bits` 碎银 |
| I-244 `sheet_items_clothing` | `item.clothing.coat` 旧棉袄 | `item.clothing.qipao` 旗袍料 | `item.clothing.robe` 藏青长衫 | `item.clothing.scarf` 灰羊毛围巾 |
| I-245 `sheet_items_documents` | `item.documents.field` 田契 | `item.documents.house` 旧房契 | `item.documents.letter` 旧家书一束 | `item.documents.receipt` 商号货单一叠 |
| I-246 `sheet_items_papers` | `item.papers.iou` 借据 | `item.papers.shop_slip` 商号条子 | `item.papers.tax_slip` 捐税收据 | `item.papers.waybill` 船行运单 |
| I-247 `sheet_items_art` | `item.art.calligraphy` 行书条幅 | `item.art.flowers` 花鸟小册 | `item.art.landscape` 山水画轴 | `item.art.woodcut` 旧版画一套 |
| I-248 `sheet_items_silverware` | `item.jewelry.bangle` 旧银镯 | `item.jewelry.ring` 银戒指 | `item.silverware.cup` 银酒杯 | `item.silverware.spoon` 银汤匙 |
| I-249 `sheet_items_gold` | `item.goldbar.bar_one` 小黄鱼 | `item.goldbar.bar_ten` 大黄鱼 | `item.silverware.box` 錾花银盒 | `item.utensils.warmer` 铜手炉 |
| I-250 `sheet_items_utensils`（16:9，左右两样） | `item.utensils.bowl` 青花碗一对 | `item.utensils.tinpot` 锡茶壶 | — | — |

```
I-241: Top-left: a small open cloth sack of short, round, semi-translucent rice grains (local japonica). Top-right: the same sack with long, thin, off-white grains (indica). Bottom-left: the same sack with plump milky-white opaque grains (glutinous rice). Bottom-right: the same sack with small broken rice fragments. All four sacks the same plain undyed cloth, same size and shape, tops rolled down to show the grain, no markings.
I-242: Top-left: a small paper box of aspirin tablets with a plain printed label. Top-right: a small brown glass iodine bottle with a stopper and a paper label. Bottom-left: a small clear glass bottle of white quinine tablets with a paper seal over the cap. Bottom-right: a small round tin of sulfa powder with a paper label on the lid.
I-243: Three silver dollar coins of the same size lying flat and one cloth bundle. Top-left: a silver dollar showing a man's profile portrait, finely reeded edge. Top-right: a silver dollar showing a sailing junk. Bottom-left: a silver dollar showing a coiled dragon. Bottom-right: a few irregular lumps of broken silver on a small square of old cloth. Coin lettering only as tiny dots, nothing readable.
I-244: Top-left: a folded padded cotton jacket in blue cloth. Top-right: a folded bolt of pale patterned silk fabric, uncut. Bottom-left: a folded navy-blue long gown with long sleeves. Bottom-right: a folded thick grey knitted wool scarf.
I-245: Top-left: an old land deed on large aged paper with a red seal and an attached tail slip, unfolded. Top-right: an old house deed, a single sheet with a red seal. Bottom-left: a bundle of old family letters in envelopes tied with string. Bottom-right: a small stack of shop delivery slips tied with string.
I-246: Single paper sheets of slightly different sizes and paper colors. Top-left: an IOU slip with a red thumbprint. Top-right: a shop pickup slip with a square red shop seal. Bottom-left: a tax receipt with a round red official seal. Bottom-right: a boat-company waybill with printed boxes.
I-247: Top-left: a calligraphy hanging scroll, partly unrolled, flowing black brush strokes that are abstract, not real characters. Top-right: a small cloth-bound album opened to a painting of a bird on a flowering branch. Bottom-left: a rolled landscape painting scroll wrapped in blue cloth and tied. Bottom-right: a set of black-and-white woodcut prints in a paper folder, the top print a simple figure scene.
I-248: Top-left: an old round silver bangle with fine engraved flowers. Top-right: a small silver ring with a simple engraved pattern. Bottom-left: a small silver wine cup with chased vine scrolls. Bottom-right: a silver soup spoon with a finely engraved handle.
I-249: Top-left: a small gold bar with one stamped rectangular mark. Top-right: a larger, longer and thicker gold bar with a stamped mark. Bottom-left: a small silver box with a chased flower-and-bird lid. Bottom-right: a small round brass hand warmer with a pierced lid.
I-250 (16:9, two objects side by side instead of a 2 by 2 grid): left, a pair of blue-and-white porcelain rice bowls with similar patterns, stacked slightly offset; right, a pewter teapot with a short spout and an overhead loop handle.
```

### 5.5 1938 年常见的牌面小插图（I-251 至 I-267，一张四格）
- **比例** 4:3；**变体** 1；**底色句** 【纸底小图】+ 四宫通用句（见 I-211）；**参考图** I-118、I-116 原图
- 68 个 id：1938 年和“任何年”都会发的事件、命运、生活、消息、条子，加良民证。题目和那句话是牌上的字（`data/cards/text_ai/**`），图要对得上，但**不要画出结果**。
- 画风说明：第二批认可的是纸底小图（I-116～I-118）。现在游戏里另外 172 张是程序画的整幅小场景。若主创要整幅场景，把底色句换成 `Each panel is a full small scene with its own background filling the panel.` 就行，其他不变。

**I-251 查验** `sheet_illus_check`
- 左上 `illus.ev.1938.police_check` 查良民证（警察挨家挨户查良民证，后头跟着伪维持会的人）
- 右上 `illus.ev.1938.road_pass` 出镇路口（出镇的路口设了卡，要看证件才放行）
- 左下 `illus.ev.1938.night_patrol` 夜里查街（夜里有人沿街敲窗查问）
- 右下 `illus.ev.any.curfew` 宵禁提前（告示贴出来，天一黑过街都要查）
```
Top-left: a policeman in a plain dark uniform seen from behind, checking a small paper identity card held out by a shopkeeper at a shop door, a man in a long gown with a notebook waiting behind him. Top-right: a road leaving town blocked by a simple wooden barrier and a small guard hut, a traveler with a bundle holding out a paper. Bottom-left: a night street of shuttered shopfronts, two men with a paper lantern knocking on a window shutter. Bottom-right: an empty street at dusk, shutters closed, one fresh notice of illegible print on a wall, a single lantern.
```

**I-252 伪维持会** `sheet_illus_committee`
- 左上 `illus.ev.1938.levy_call` 门上的摊派单
- 右上 `illus.ev.1938.puppet_roll` 点名听会（点铺户到场听会）
- 左下 `illus.ev.1938.wharf_due` 码头捐
- 右下 `illus.ev.1938.police_open` 警察所开门（月底警察所开门，铺户都被叫去看）
```
Top-left: a paper levy notice with a red seal pasted on a pawnshop's wooden door. Top-right: a plain meeting room, rows of shopkeepers on benches facing a table where a man in a long gown reads from a list. Bottom-left: a canal wharf, a boatman handing coins to a collector sitting at a small table with a ledger. Bottom-right: a newly opened police post, a whitewashed building with a blank signboard and open doors, townspeople gathered in front.
```

**I-253 罚与封** `sheet_illus_fines`
- 左上 `illus.fa.1938.door_fine` 门上的罚单
- 右上 `illus.fa.any.street_fine` 罚款（有人上门要一笔罚款，名目说不清楚）
- 左下 `illus.fa.any.shop_sealed` 要查封三天
- 右下 `illus.fa.any.false_charge` 被人诬告
```
Top-left: a small paper fine slip with a red seal pasted on a shop door beside the latch. Top-right: a man in a dark jacket at a shop counter holding out his open palm, the shopkeeper's hand resting on a cash box. Bottom-left: two crossed paper seal strips pasted across closed shop doors. Bottom-right: a man pointing toward a pawnshop while talking to an official seated at a desk.
```

**I-254 条子** `sheet_illus_demands`（胡二每周一送来，限七天）
- 左上 `illus.dm.money` 要钱（门牌小捐、按月摊派）
- 右上 `illus.dm.goods` 要货（交一袋米、两件衣物）
- 左下 `illus.dm.people` 要人（看门搬告示、出夫修路）
- 右下 `illus.dm.info` 要消息（问谁常来、问谁进了货）
```
Each panel shows the same narrow folded demand slip with a red thumbprint. Top-left: the slip on a counter beside a small stack of coins. Top-right: the slip tied to a sack of rice with a folded garment beside it. Bottom-left: the slip next to a shovel and a straw hat leaning on a wall. Bottom-right: the slip beside a small open notebook and a writing brush.
```

**I-255 征用与派差** `sheet_illus_requisition`
- 左上 `illus.fa.1938.requisition` 征用的风声（要粮或要船）
- 右上 `illus.fa.any.requisition` 上门征用（要从货架上拿走一件货）
- 左下 `illus.ev.any.demand_return` 派出去的人（当差的人今天该回来了）
- 右下 `illus.kp.liangmin` 良民证
```
Top-left: boats tied at a canal bank and rice sacks being counted by a man with a ledger, townspeople watching from a distance. Top-right: a man in a plain dark uniform carrying a wrapped item away from a pawnshop shelf. Bottom-left: a tired young man with a bundle walking back along a country road toward the town at dusk. Bottom-right: a small folded identity card with a blank square photo space and a red seal, lying on a cloth.
```

**I-256 码头与米** `sheet_illus_rice`
- 左上 `illus.ev.1938.dock_night` 码头夜船（船家找人手连夜卸货）
- 右上 `illus.ev.1938.rice_line` 米行排队（每人限买）
- 左下 `illus.fa.1938.rice_ease` 米价松了
- 右下 `illus.fa.any.rice_dip` 米价跌了
```
Top-left: a canal dock at night, a cargo boat with a lantern, porters carrying sacks up stone steps. Top-right: a line of townspeople with cloth bags in front of a rice-shop counter with a big wooden rice measure. Bottom-left: a rice shop with full open sacks, a scoop, a relaxed shopkeeper. Bottom-right: a basket heaped with rice and a hand pouring rice into a cloth bag with a wooden scoop.
```

**I-257 庙会街市** `sheet_illus_fair`
- 左上 `illus.ev.any.fair` 庙会（城隍庙办庙会，可以转庙会的轮盘）
- 右上 `illus.ev.any.market_haggle` 集市讲价
- 左下 `illus.ev.any.temple_lot` 城隍庙求签
- 右下 `illus.ev.any.cezi_stall` 测字摊
```
Top-left: a temple fair with red lanterns, a crowd and a painted wheel of fortune on a stand. Top-right: market day, a farmer with two baskets of vegetables on a carrying pole, a buyer pointing at them. Bottom-left: inside a town-god temple, an altar with candles and incense, a person kneeling and shaking a bamboo tube of fortune sticks. Bottom-right: a small street table with a brush, ink and a blank sheet of paper, a blank cloth banner on a pole, a stool.
```

**I-258 赌与吵** `sheet_illus_quarrel`
- 左上 `illus.ev.any.gamble_stall` 街口赌摊
- 右上 `illus.ev.any.wheel_go` 去转轮盘
- 左下 `illus.ev.any.alley_row` 巷口评理
- 右下 `illus.fa.any.neighbor_row` 邻里口角（扯到了铺子头上）
```
Top-left: a street gambling stall, a small spinning wheel on a low table, two men crouching, a few coins. Top-right: a painted wheel of fortune standing alone on a wooden stand with a pointer on top. Bottom-left: two neighbors arguing at an alley mouth with raised arms, a third person standing between them. Bottom-right: two women arguing across a doorway under bamboo laundry poles, one pointing toward a pawnshop.
```

**I-259 门口来人** `sheet_illus_door`
- 左上 `illus.ev.1938.refugee_door` 后门的逃难人（想讨一口饭）
- 右上 `illus.fa.any.night_knock` 夜里敲门
- 左下 `illus.fa.any.stranger_deal` 生人的买卖（来路说不清）
- 右下 `illus.fa.any.regular_intro` 老主顾荐客
```
Top-left: at a back door, a thin refugee with a bundle holding out an empty bowl. Top-right: a closed shop door at night, a dark figure knocking, a lantern on the ground. Bottom-left: a stranger with his hat pulled low laying a cloth-wrapped parcel on a counter. Bottom-right: an elderly customer in a long gown at a counter, gesturing to a younger companion behind him.
```

**I-260 钱** `sheet_illus_money`
- 左上 `illus.fa.1938.kin_money` 远亲寄钱（1938：托人捎来一笔钱）
- 右上 `illus.fa.any.kin_money` 远亲寄钱（任何年）
- 左下 `illus.fa.any.found_purse` 拾到钱袋
- 右下 `illus.fa.any.found_claim` 失主上门
```
Top-left: a courier handing a small cloth money pouch across a counter. Top-right: an opened envelope and a small stack of silver coins on a table. Bottom-left: a small embroidered money purse lying on a stone-paved street. Bottom-right: a worried woman at a counter pointing at a money purse that the shopkeeper holds out.
```

**I-261 天气** `sheet_illus_weather`
- 左上 `illus.ev.any.rain_leak` 铺面漏雨
- 右上 `illus.fa.any.damp_loss` 货受潮
- 左下 `illus.fa.any.snow_day` 下雪了
- 右下 `illus.fa.any.clear_road` 天放晴了
```
Top-left: rain dripping from a roof beam into a wooden basin on a shop floor. Top-right: bolts of cloth and paper bundles on a shelf beside a window with rain outside, a damp cloth draped over them. Bottom-left: an empty snowy street with shuttered shops and a line of footprints. Bottom-right: a sunny street after rain, puddles, people walking, a stone bridge.
```

**I-262 祸事** `sheet_illus_trouble`
- 左上 `illus.fa.any.fire_next_door` 邻铺失火
- 右上 `illus.fa.any.theft` 铺里丢了东西
- 左下 `illus.fa.any.illness` 病了一场
- 右下 `illus.lf.any.debt_due` 欠债到期（债主上门来要）
```
Top-left: flames and smoke rising from the roof of the neighboring shop, people carrying buckets, nobody hurt. Top-right: a shop shelf with one empty gap among wrapped goods, a dark figure slipping out of a door. Bottom-left: a girl lying in bed under a quilt with a cloth on her forehead, a medicine bowl on a stool. Bottom-right: a creditor in a long gown standing at a door holding up an account book.
```

**I-263 柴米油** `sheet_illus_household`
- 左上 `illus.lf.any.rice_low` 米缸见底
- 右上 `illus.lf.any.coal_out` 煤用完了
- 左下 `illus.lf.any.lamp_oil` 灯油快完了
- 右下 `illus.lf.any.rent` 房租到期
```
Top-left: a large clay rice jar with its lid off, almost empty, a wooden scoop inside. Top-right: a cold kitchen stove with an empty coal basket beside it. Bottom-left: an oil lamp with a low dim flame and a nearly empty oil bottle beside it. Bottom-right: a landlord at a doorway holding out his hand, a receipt book under his arm.
```

**I-264 看病上学** `sheet_illus_care`
- 左上 `illus.lf.any.see_doctor` 家里有人病了
- 右上 `illus.lf.any.mother_cough` 母亲咳嗽
- 左下 `illus.lf.1938.spring_chill` 春寒（倒春寒，家里有人咳嗽）
- 右下 `illus.lf.any.school_fee` 学堂催学费
```
Top-left: an old herbal doctor taking the pulse of a patient lying in bed. Top-right: a middle-aged woman in a padded jacket coughing into a handkerchief, a bowl of medicine nearby. Bottom-left: a cold spring morning indoors, someone wrapped in a quilt beside a small charcoal brazier, frost on the window paper. Bottom-right: a schoolteacher in a long gown at a door holding a fee slip, a child with a cloth book bag.
```

**I-265 人情节令** `sheet_illus_customs`
- 左上 `illus.lf.any.wedding_gift` 喜帖上门
- 右上 `illus.lf.any.funeral` 街坊办丧事
- 左下 `illus.lf.any.new_year` 过年
- 右下 `illus.lf.1938.qingming_prep` 备清明（纸锭和一桌饭）
```
Top-left: a red invitation card and a red paper gift envelope on a table, both blank. Top-right: a neighbor's doorway hung with white cloth and a white paper lantern, mourners in white. Bottom-left: New Year: red paper lanterns, a table with dumplings and a fish dish, blank red paper strips beside a door. Bottom-right: folded silver-paper ingots, incense sticks and a small offering table with dishes.
```

**I-266 消息一** `sheet_illus_news_a`
- 左上 `illus.nw.lead` 线索（如“要查良民证”“一九六号当票”）
- 右上 `illus.nw.rumor` 闲话（周妈的闲话、码头见王山）
- 左下 `illus.nw.price` 行市（米行行市）
- 右下 `illus.nw.paper` 剪报（南京的剪报）
```
Top-left: two people whispering behind a raised hand at a counter. Top-right: a teahouse corner, a plump woman cook leaning in to tell gossip to two customers holding teacups. Bottom-left: a rice shop's blank wooden price board with chalk scribbles and a scoop of rice. Bottom-right: a folded newspaper page of grey print columns, a pair of scissors and a clipped piece.
```

**I-267 消息二 + 屋子** `sheet_illus_news_b`
- 左上 `illus.nw.letter` 信（哥哥的家书等）
- 右上 `illus.nw.telegram` 电报（压着的信、电码）
- 左下 `illus.lf.any.repair_house` 屋子要修
- 右下 `illus.lf.1938.spring_roof` 春雨漏屋
```
Top-left: an opened envelope with a postage stamp and a folded letter of illegible writing. Top-right: a telegram slip covered in rows of short dashes in groups of four, on a post-office counter. Bottom-left: a workman on a ladder fixing roof tiles, a broken door leaning against the wall. Bottom-right: spring rain on dark roof tiles seen from outside, water seeping under the eaves into a basin.
```

---

## 6. 第 2 批 P2（以后，36 条，另 2 条可选）

写法和前两批一样，这里只列每条填什么、画什么；提示词照前面同类的通用句拼。

### 6.1 1939、1940 新面孔（一张四个人，3:4，【绿底】+ 5.3 的四人通用句）

| 编号 | 左上 | 右上 | 左下 | 右下 |
|---|---|---|---|---|
| I-271 `sheet_newfaces_1939` | `portrait.nf1939a` 柴佬：城门外卖柴的人，年关进城当冬衣 | `portrait.nf1939b` 茧账：茧行的账房伙计，来打听茧农的当 | `portrait.nf1939c` 乡嫂：乡下进城过年的妇人，来当冬衣 | `portrait.nf1939d` 区抄：伪区公所新来的抄写员 |
| I-272 `sheet_newfaces_1940` | `portrait.nf1940a` 顾承年：二十出头的年轻书记，随新官来核对当铺名册 | `portrait.nf1940b` 齐路生：四十上下的报贩，从南京方向走来 | `portrait.nf1940c` 蔡布成：三十五上下的布贩，被摊派挤得周转不开 | `portrait.nf1940d` 方晚晴：二十八上下的寻人妇人，带着半张旧当票 |

冬天的衣服给 1939（腊月），春天的给 1940。区抄、顾承年是伪政权里的小职员：深色长衫或中山装，不画徽章。

### 6.2 门口走过的群演行走图（每人一张，9:16，【绿底】）

`walk.ex_girl` 对门的姑娘（红衣，旧图就是红的）、`walk.ex_oldman` 街上的老先生、`walk.ex_patrol` 巡警、`walk.ex_porter` 码头扛包的（**不要扁担**，第二批 I-108 就是扁担太宽切坏了，改成肩上扛一个袋子）、`walk.ex_shopboy` 邻铺伙计、`walk.ex_soldier` 伪军（深色制服、不拿枪、不带徽章）、`walk.ex_student` 镇上的学生、`walk.ex_hu2_man` 胡二的人（代码会压成剪影，画一个穿黑短褂、戴帽的男人即可）。编号 I-273 至 I-280，短名 `walk_<id 去掉 walk.>`。可选 I-281 `walk.ruhua`（照 I-206 新立绘的样子：蓝褂、长辫）。
- 门口每天走过一两个群演（×4），站在门口时是第一帧 ×8。旧图本身是干净的像素画，原型里用的就是它们，所以排在 P2。
- 群演头像 `portrait.ex_*` 按规格从行走图朝下第一帧派生（9 个，含已有的报童），不另出图。
- 提示词照第二批 I-107，改两处：
```
Sprite sheet of <who>: one character drawn in a 4 rows by 4 columns grid of equal cells. Rows from top: facing down toward the viewer; facing LEFT (nose pointing to the left edge); facing RIGHT (nose pointing to the right edge); facing up (back view). Columns: stand, left foot forward, stand (identical to the first column), right foot forward. Full body, feet at the bottom of each cell, same size in every cell. The character and everything carried stay inside a narrow tall cell: no poles, no wide loads. Solid flat #00ff00 background, no grid lines.
```

### 6.3 次要背景（16:9，【整幅场景】）

| 编号 | id | 画什么 |
|---|---|---|
| I-282 | `bg.stage.1939` | 1939 腊月开场：屋顶积雪的水乡，城门口设岗盘查，背着年货的人排队；同样把要紧的东西放在上面 55% |
| I-283 | `bg.stage.1940` | 1940 春天开场：新贴的大告示前围着人，衙门口换了新匾（空白），柳枝发芽；上面 55% |
| I-284 | `bg.street` | 流落街头：雨后桥头街，屋檐下一块空地，几家关着的铺子 |
| I-285 | `bg.prison` | 牢房：木栅、草席、高处一扇小铁窗，一张桌和一支蜡烛在左边（代码会压冷色） |
| I-286 | `bg.temple` | 城隍庙前院（庙会、转轮盘用）：香炉、红灯笼、供桌，正中留空给轮盘 |

### 6.4 其余道具九宫（1:1，【绿底】，照 I-204 的写法）
I-287 `sheet_props_misc`：`prop.telegraph` 电报机（盖着，38×28）、`prop.telegraph_open`（同一台，盖子打开）、`prop.medbook` 药书（36×16）、`prop.trash` 纸篓（30×28）、`prop.trunk` 小箱（16×14）、`prop.broom` 扫帚（8×22）、`prop.rice_sacks` 米袋（20×16）、`prop.cat` 猫（14×12，1938 中段那只进店的猫）、`prop.lantern_post` 灯笼杆（16×34）。

### 6.5 可选：面板底纹（1:1，【整幅场景】）
I-288 `sheet_textures`（可选）：左半一块可平铺的旧纸纹理、右半一块可平铺的深色木纹，平涂、低对比。只有在代码画出来的抽屉和对话框显得太“平”时才用；原型就是平色，不用也行。

### 6.6 其余牌面小插图（I-291 至 I-310，一张四格，4:3，【纸底小图】+ 四宫通用句）

1938 年会出现、但只在快输、流落街头、坐牢、押家当时才看到的，以及 1939、1940 两关的，共 79 个 id。

| 编号 / 短名 | 左上 | 右上 | 左下 | 右下 |
|---|---|---|---|---|
| I-291 `bigfate_a` | `bf.wheel` 大轮盘：香案后面一个彩绘大轮盘 | `bf.any.mystery_box` 来路不明的箱子：柜台上一只捆着绳的上锁木箱，陌生人的手按着 | `bf.any.ship_ticket` 一张船票：码头上方一张船票，远处一条小火轮 | `bf.any.house_offer` 有人买老宅：体面的买主站在老宅门口递出厚信封 |
| I-292 `bigfate_b` | `bf.any.sun_guarantee` 孙老爷要人作保：穿马褂的老人隔着桌子递出盖印的纸和钱袋 | `bf.any.quiet_fee` 花钱消灾：一把钱推向扭头看别处的深色短褂男人 | `bf.any.street_bed` 有人留宿：夜里好心的邻居开门，门外站着拎小包袱的姑娘 | `bf.1938.bail_shop` 交钱作保：警察所桌上放下钱袋和铺子的印 |
| I-293 `bigfate_c` | `bf.1938.night_cargo` 码头夜货：夜里几只盖布的木箱从船上搬进后门 | `bf.1939.gate_passage` 出城躲两天：天亮前一条小船从芦苇里划出城墙 | `bf.1939.rice_hoard` 一批来路米：昏暗库房里草席盖着一摞米袋 | `pr.cell` 牢房：木栅、草席、高处小窗 |
| I-294 `bigfate_d` | `bf.1940.night_road` 一张夜路条：灯笼边一张折好的路条塞进手里 | `bf.1940.yamen_crate` 一箱旧文书：衙门口一只装满成捆旧文书的木箱 | `kp.gate_pass` 城门路条：布上一张盖红印的小路条 | `kp.blank_ticket` 空白当票：印好边框、盖了铺号红印、一栏没填的当票 |
| I-295 `estates` | `es.counter` 柜台：高高的深色老柜台带矮栏 | `es.jewel_cabinet` 首饰柜：带很多小抽屉、铜拉手的漆柜 | `es.old_house` 老宅：白墙黑瓦的院子、月洞门 | `es.storeroom` 库房：高架子上的布包、一架梯子 |
| I-296 `favors` | `kp.ma_owes` 马保长欠你一次：桌上一顶圆礼帽和一张按了红手印的欠条 | `kp.hu_owes` 胡二欠你一次：对折的条子系着一截绳、红手印 | `kp.zhao_favor` 赵老三欠你一次：柜台上一杆长烟袋和一把新鲜青菜 | `kp.sunfu_letter` 孙府介绍信：红边信封、孙家的红印 |
| I-297 `keepsakes` | `kp.gold_bar` 一根金条：折好的红布上一根小金条 | `kp.silver_keepsake` 银饰信物：旧红绳穿着的小银锁 | `kp.mystery_box` 来路不明的箱子（留着）：库房角落布盖着的捆绳木箱 | 备用：`bf.any.mystery_box` 的另一版 |
| I-298 `leverage` | `kp.leverage.xiaoding` 小丁的把柄：灶台后面藏着一只破了角的米袋 | `kp.leverage.li` 李敬之的把柄：课本里夹着几页看不清的手稿 | `kp.leverage.zhang` 张护士的把柄：护士篮子里布下面一小盒药粉 | `kp.leverage.wu` 吴掌柜的把柄：账本底下压着一张船期单和一小袋米样 |
| I-299 `street_a` | `st.beg` 沿街乞讨：街角坐着的姑娘，面前一只缺口碗 | `st.odd_job` 打零工：工地上搬砖 | `st.stall` 摆地摊：地上铺块布摆几样小东西 | `st.write_letters` 替人写信：街角小桌，姑娘执笔替老妇人写信 |
| I-300 `street_b` | `st.errand` 跑腿：姑娘拿着小包沿河边跑 | `st.pawn_own` 当掉随身东西：一双手把小布包递上高高的当铺柜台 | `st.gamble` 赌一把：街边赌桌、小轮盘、铜钱、围观的人 | `st.ask_kin` 找熟人：姑娘敲亲戚家院门，门缝里有人探头 |
| I-301 `street_c` | `st.scavenge` 拾荒：河边提篮翻拣 | `st.watch` 替人守夜：夜里坐在货栈门口，灯笼和梆子 | `st.copy` 替人抄写：窗边小桌抄账 | `st.carry` 码头扛包：扛着袋子上码头台阶 |
| I-302 `y1939_a` | `ev.1939.year_debt` 年关讨债：雪天拿账本上门的债主 | `ev.1939.night_market` 年关夜市：红灯笼、摊子、人挤人 | `lf.1939.new_year_goods` 置办年货：挂着的腊鱼腊肉、一篮红纸 | `lf.1939.year_tab` 年关清账：账本、算盘、一捆用绳扎的欠条 |
| I-303 `y1939_b` | `ev.1939.charcoal_spike` 柴价飞涨：卖柴的只剩一小堆，一群人围着买 | `fa.1939.charcoal_wind` 柴价又动了：一捆柴挂在秤上，旁边几枚钱 | `lf.1939.fuel_stock` 置办柴火：屋檐下靠墙码好的柴 | `ev.1939.snow_road` 大雪封路：城外被雪埋住的路，没有行人 |
| I-304 `y1939_c` | `ev.1939.gate_check` 城门盘查：城门口守卫（背影、无徽章）翻行人的包袱 | `ev.1939.refugee_cold` 城门口的难民：寒风里挤在城墙根的人 | `fa.1939.gate_wink` 城门通融：背后一只手把钱塞进守卫手里 | `ev.1939.patrol` 街上盘查：街口巡警查过路人的证件 |
| I-305 `y1939_d` | `ev.1939.cocoon_desk` 茧行核账：茧行里一张登记桌，几筐白茧，账房拿着账本 | `ev.1939.countryside_word` 乡下来的话：挎篮的乡下妇人隔着柜台说话 | `ev.1939.district_levy` 伪区公所要货：小职员指着一袋米 | `fa.1939.district_fine` 伪区公所罚款：小职员隔着柜台递来盖红印的罚单 |
| I-306 `y1939_e` | `ev.1939.wu_price` 米行涨价：米行掌柜把价牌（空白）翻过来 | `fa.1939.year_remittance` 远亲汇钱：汇款信封和银元，旁边是过年的红纸 | `lf.1939.pawn_coat` 当衣过年：姑娘把自己的棉袄叠在当铺柜台上 | `fa.1940.rice_spike` 米价猛涨：春天米行门口抢米的人群 |
| I-307 `y1940_a` | `ev.1940.new_official` 新官到任：轿子和随从到了衙门口 | `ev.1940.wang_regime` 南京的告示：城墙上新贴的大告示，一群人围着看 | `ev.1940.signboard` 换门匾：衙门口摘下旧匾、抬上新匾（都空白） | `ev.1940.levy_rename` 摊派换名目：门上两张摊派单，旧的撕掉一半，新的盖红印 |
| I-308 `y1940_b` | `ev.1940.household_count` 清点户口：拿名册的小职员和巡警站在一户门口点人 | `ev.1940.papers_swap` 换新证件：桌上旧证换新证 | `lf.1940.census_chit` 补户口纸：饭桌上一张户口纸和毛笔 | `lf.1940.door_paper` 门上贴纸：铺子门框上贴的一张纸条 |
| I-309 `y1940_c` | `ev.1940.shop_search` 上门查铺：巡警翻铺子的货架，掌柜站在一边 | `ev.1940.curfew` 提前净街：黄昏上门板，打更的走过 | `ev.1940.gate_tight` 城门加岗：守卫多了，城门口排长队 | `fa.1940.whisper` 有人告了一状：一个人凑在官员耳边说话 |
| I-310 `y1940_d` | `ev.1940.rice_notice` 米行贴告示：米行门边新贴告示，有人围着看 | `fa.1940.spring_rain` 春雨连绵：河上和黑瓦屋顶的绵绵春雨 | `fa.1940.old_buyer` 旧主顾上门：穿长衫的老主顾在柜台前笑着挑东西 | `lf.1940.school_rename` 学堂催学费：学堂门口挂了新匾（空白），先生拿着学费单 |

“茧行”是日商把持的，图里只画茧行和账房，不画日本人。

---

## 7. 不向 Google 要的（代码画，或先不要）

| 东西 | 为什么 |
|---|---|
| 牌框 `frame.*`（36×50，九宫格角块 6 px） | 角块太小，AI 图缩下来会糊；第二批 I-114 金框角花 9 px 就切坏了。原型的牌面是 CSS：纸底、顶部一条类别色带、圆角、细描边、主线牌金边加斜角标签。照原型用代码画更像。 |
| 对话框 `frame.dialog`、英雄框 `frame.hero`、批注纸 `frame.guide_note`、指引气泡 `frame.guide_bubble` | 原型都是 CSS：半透明深木色底 + 内圈金线。代码画。 |
| 图标 `icon.*`（16×16、24×24）、铜钱正反面 | 程序像素图已经是一套；16 px 的东西 AI 缩下来只剩色块。 |
| 轮盘面 `wheel.*` | 扇区由代码画；现在的程序盘面够用。 |
| 光、夜色、雨、火、烟、封条、剪影 | 规格 §9 写明是代码效果。 |
| 所有的字（标题、牌名、价钱、告示上的字） | 全部由代码用字体写，图里一个字都不要。 |
| `bg.market` `bg.teahouse` `bg.ricehall` `bg.pharmacy` `bg.post` `bg.baogong` `bg.candle` `bg.dock` | 现在没有牌用到这些场景，先不出。 |
| 小目标 `illus.gl.*`（18 张） | 开月的小目标页只显示文字，界面里没有地方显示这些图，先不出。 |
| 主要人物的行走图 | 规格说可选：没有行走图时立绘从下面滑进来。 |

**新手指引要用的图**都在上面了：教的人是哥哥（I-207，P0）、周妈（I-224）、胡二（I-225）、算命先生和邮差（I-232、I-233 换绿底）；第 1–3 天的教学客人是张护士、吴掌柜、小丁、孙少爷、孙福、李敬之、邮差。三枚物件图标和气泡由代码 / 现有程序图负责。

---

## 8. 图到了以后要代码配合的地方（不是美术，但不改图就落不了地）

1. **人像改透明底**：柜台前直接贴透明人像就对了；牌面（`CardWidget`）和左下角英雄框要在人像后面垫一块纸色（`paper`），和原型一样。否则透明人像在牌面上会露出牌底。
2. **柜台用空台面图**（I-203）后：`relight_counter.py` 的油灯位置 `LAMP = (21, 86)` 改到右墙脚那盏油灯（`prop.lamp` 在 `S_HOTSPOTS` 里是 (292, 68, 20, 32)，火苗约在 (302, 78)）；门洞 `OPEN`、消失点 `VP`、夜里亮的两扇窗 `WINDOWS` 按新图重新量。黄昏、夜里仍是同一张底图换光、抖动渐变，不另出图。
3. **新 id `illus.nt.sleep`**：清单登记；夜里手牌里那张“睡了”（`hand_fan.gd` 里 def 为空的那张）用它当牌面图。
4. **`prop.lamp_off`** 用脚本从 `prop.lamp` 去掉火苗得到，保证点灯 / 熄灯两张逐像素对齐。
5. 主创挑定后，清单把对应 id 的 `ai` 换成新图、`_provenance` 写 `ai:google-flow:<出图日期>:I-2xx`；被顶替的程序图和旧图不删，留作占位。
