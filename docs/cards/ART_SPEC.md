# 卡牌版美术规格（给画师 A / 外包）

> **主创 10-18 决定（优先于本文下面“AI 只出占位”的说法）**：这一版（首发版）美术先用 AI——用 Google AI Ultra 的工具出图，后处理成规定尺寸和调色板，放 `art/ai/<类别>/<id>.png`，清单加 `ai` 路径与 `_provenance: "ai:google-<工具名>:<日期>:<提示词 id>"`；运行时查找顺序 human → ai → placeholder；这一版在 Steam 上做 AI 内容声明。人画的正式图以后放 `art/cards/**` 自动顶替 AI 图，那时再出不带声明的版本。见 `docs/handoff_cards/W2_HANDOFF.md` 任务 7 与 #200 #201 #202。


主人：K12。合同：`docs/cards/CARDS_INTERFACES.md` §1.2、§2.4、§3.4 K12、§4.8、§11.2–§11.4、§12.4。
玩法侧的数量级见 `docs/cards/DESIGN_cards.md` §七「美术」。画面（柜台三时段、各场景、行走图、道具、对话框）的尺寸与倍数以本文 **§12** 和合同 §1.2、§4.8、§7.11.2 为准。

正式图只有 A / 外包画。AI 只出占位，占位不进 Steam 包。

## 0. 开发工具（K12，不是画师要跑的）

```bash
python3 tools/cards/art/gen_placeholders.py [--out=<根目录>] [--only=<id 前缀>] [--check] [--sheet=<仓库外的拼图>]
python3 tools/cards/art/check_manifest.py [--refs=error|note]
```

- 生成器：Python 3 + Pillow。同样的清单跑两次，PNG **字节相同**（每张图的随机只用 `random.Random(sha256(art_id) 的前 8 字节整数)`；PNG 只有 IHDR/IDAT/IEND，压缩级别固定，不写时间戳、不写色彩配置）。
- 覆盖检查：只用标准库。`--refs=error`（默认）时，数据或界面引用了、清单里没有的 id 会失败；`--refs=note` 只打印 `ART MISSING`，不因此失败（别的线新加 id 时不把所有人的 CI 打红）。文件缺失、尺寸不对、没有「稿」角标、总量超过 20 MB，两种模式都失败。
- 清单：`data/cards/art/manifest.json`（`_meta.owner` 是 K12）。运行时 `CardArt` 先找 `human`，没有再找 `placeholder`，再没有用 `missing`。

## 1. 占位和正式图

| | 占位 | 正式 |
|---|---|---|
| 谁画 | K12 生成器（或 v0.4.2 旧图，清单里 `legacy: true`） | A / 外包 |
| 放哪 | `placeholder` 路径。新图在 `art/_placeholder/cards/<类别>/<名>.png`；旧图仍指 `art/portraits/**`、`art/items/**`，K12 不改那些文件 | `human` 路径：`art/cards/<类别>/<名>.png` |
| 角标 | 生成出来的每张左上角有点阵「稿」（码点 U+7A3F，写死在生成器里，不用系统字体）。短边 ≥ 24 的用 16×16，16×16 图标用 8×8 | **不要**「稿」角标 |
| 发行 | 导出排除 `art/_placeholder/**`。`art/_placeholder/cards/manifest.json` 记录 `generator`、`version`、`seed_rule: sha256(art_id)`、每个文件的 sha256 | 进包。缺文件、或仍引用 `legacy: true` = 审核失败（§11.4 第 3 项） |

开发版查找顺序：`human` 文件存在就用正式图，否则占位，否则 `art/_placeholder/cards/missing.png`（32×32，只给开发版缺图，不是交付项）。发行版（`CardShip.is_ship()`）不读占位，解析不到 `art/cards/**` 里的正式文件即失败。

旧图是 v0.4.2 的 AI 产出，卡牌版按占位对待：清单 `legacy: true`，发行包不得引用。不要在旧图上补「稿」——那些目录不归 K12。

占位总量 ≤ 20 MB（§12.4）。`check_manifest.py` 最后一行会报字节数。

## 2. 像素、整数倍、最近邻

全部是像素图。显示只用**整数倍**放大，过滤 `TEXTURE_FILTER_NEAREST`（界面已在 `CardWidget` 上设置）。禁止 1.5 倍、禁止线性过滤、禁止把一张底图拉成非整数分辨率。

| 类别 | 底图 `base` | 常见显示 |
|---|---|---|
| 头像 `portrait.*` | 48×64 | 手牌 ×2（96×128），放大 ×4（192×256） |
| 小插图 `illus.*` | 64×48 | ×2 / ×4 |
| 物品 `item.*` | 64×64 | 手牌与货架 ×2，鉴定放大 ×4 |
| 牌框 `frame.*`（含 `frame.gold`、`frame.guide_bubble`） | 36×50 | ×4。九宫格边距 6，见下节 |
| 背景 `bg.*` | 320×180 | ×4 = 1280×720，铺满画面 |
| 轮盘面 `wheel.*` | 120×120 | ×4 = 480。只画盘面底纹，扇区由界面用代码画 |
| 图标 `icon.*` | 16×16 或 24×24 | ×2 或 ×4。新手指引的三枚物件图标是 24×24 |
| 缺图方块 | 32×32 | 仅开发版，无正式路径 |

同一张图在不同界面可以换倍数，但每一处都必须是整数倍。不要另做一套「高清版」尺寸；要更清楚就提高整数倍。

牌面上的倍数见上表。**画面里**的倍数（背景与立绘与道具 ×4、柜台上的 `item.*` ×2、门口行走图 ×8、街上 ×4、对话框 ×2、英雄头像框 ×4、批注纸 ×2、标签图标 ×1）写在 §12，不要和上表混用，也不要改这些数。

## 3. 九宫格

只有牌框用九宫格。清单字段 `nine: [6, 6, 6, 6]`，顺序是左、上、右、下，单位是**底图像素**（显示 ×4 之后边距是 24 屏像素）。

- 四个角各 6×6，放角花、框色。这四块不拉伸。
- 四条边在两个角之间必须是可横向或纵向拉伸的平纹（同一条边上的像素重复），不要在边的中段放花纹或尾巴——一拉伸就会糊。
- `frame.gold` 要一眼能认：亮边（`gold_glow` / `gold`）加角花。占位已经这样做，正式图保持这个对比。
- 普通牌框的**中心透明**，牌面内容从中间露出来。
- `frame.guide_bubble` 的中心是不透明的气泡底色（`guide_bubble`），边是 `guide_ink`。它是每一步气泡的底，不是一张牌。若要气泡尾巴，尾巴只能画在角块里，不能画在边的中段。

## 4. 调色板

界面和正式图**只用键**，不写死别的颜色。键的名单在合同 §2.4。开发初值在 `data/cards/theme/palette.dev.json`（下表）。正式值只有 A 写在 `data/cards/theme/palette.json`；发行版没有这份文件 = 审核失败（§11.4 第 8 项）。要新键：开 `[shared]`，Claude 先加开发初值，A 再定正式值。

| 键 | 开发初值 | 用途 |
|---|---|---|
| `paper` | `#f4e2b0` | 纸 |
| `paper_old` | `#d9c49a` | 旧纸 |
| `ink` | `#1f1712` | 墨、最深的线 |
| `ink_soft` | `#5a3f2a` | 次要线 |
| `wood` | `#3a2a1e` | 木 |
| `wood_mid` | `#5a3f2a` | 木，中间调 |
| `wood_dark` | `#1f1712` | 木，暗部 |
| `lamp` | `#ffd25a` | 灯 |
| `seal` | `#b0262a` | 印泥 |
| `gold` | `#a07a2c` | 金 |
| `gold_glow` | `#ffd25a` | 金的高光（金色牌框的亮边） |
| `jade` | `#2f6b5a` | 玉 |
| `indigo` | `#2f4670` | 靛 |
| `mist` | `#9aa4aa` | 雾、远景 |
| `good` | `#4a6a3a` | 顺 |
| `danger` | `#a8322a` | 险 |
| `shade` | `#000000a0` | 半透明遮罩 |
| `frame_person` | `#8c6a44` | 人物牌框 |
| `frame_self` | `#2f6b5a` | 自己 |
| `frame_contact` | `#2f4670` | 人脉 |
| `frame_event` | `#5a3f2a` | 事件 |
| `frame_fate` | `#3a3532` | 命运 |
| `frame_big_fate` | `#1b1714` | 大命运 |
| `frame_demand` | `#a8322a` | 条子 |
| `frame_life` | `#6b7a4a` | 生活 |
| `frame_news` | `#8c8378` | 消息 |
| `frame_kept` | `#a07a2c` | 留着的 |
| `frame_estate` | `#5a524a` | 家当 |
| `frame_night` | `#2d3a5a` | 夜 |
| `frame_street` | `#6a6058` | 街头 |
| `frame_prison` | `#2a2422` | 牢房 |
| `frame_gold` | `#d9a520` | 金色牌框 |
| `guide_glow` | `#ffd25a` | 指引高亮 |
| `guide_bubble` | `#fffdf8` | 气泡底 |
| `guide_ink` | `#1b1714` | 气泡上的线 |

`wood_mid` 与 `ink_soft`、`wood_dark` 与 `ink` 在开发初值里碰巧同色。正式配色可以拆开，键不要合并。

## 5. 光源与分层

- **光源**：主光从左上，当铺柜上的一盏灯（`lamp`）。暗部在右下，用 `ink` / `shade`，不要另起一个灰。
- **头像**：胸像，脸在纸色上用墨线，头发和衣领分开。不要写实摄影，不要渐变光晕。
- **小插图**：可以是统一的水墨小图（纸底 + 一类一个符号）。事件、命运、条子、留牌、消息、家当、夜、街头、牢房、当票都走这一档，不要每张换成不同画风。
  - 10-22 能玩版：程序像素画（`tools/cards/art/gen_ai_illus_a.py`、`gen_ai_illus_b.py`）用的是**整幅小场景**（不透明、有背景），和 batch2 三张纸底小图（`nt.family_dinner`、`es.shopfront`、`ev.any.fortune_teller`）风格不同。正式出图时由主创定走哪一种，再统一。
- **背景**：320×180，画面里 ×4。三张柜台背景必须和旧图同一构图（门 112,8,96,92，柜台面 y=100）。开场、街头、牢房、城隍庙等见 §12。不要另画一套把门或柜台挪位的底图。
- **轮盘**：只画盘面（环、圆心、边上一圈纹理）。不要画扇区分割线，扇区大小由代码画。
- **分层**：线、平涂、暗部。分层源文件（PSD 等）**不进**仓库的发行路径，只在 `legal/ASSET_PROVENANCE.csv` 的 `source_file` 里登记文件名。

## 6. 导出

- PNG，**8 位 RGBA**（每通道 8 bit，颜色类型真彩色+透明）。不要索引色，不要灰阶，不要 16 位。
- 不要色彩配置文件（不要 iCCP / sRGB 块），不要时间戳块。Godot 导入用默认无损，不要在导入里缩小。
- 文件名与清单的 `human` 完全一致，区分大小写，用 `.png`。id 里的点保留在文件名里（例：`art/cards/illus/ev.1938.police_check.png`）。
- 透明就是透明：牌框中心不要填纸色冒充透明。

## 7. 交付清单

下表按清单 id 列出。路径是 `human`（A / 外包交到这里）。`legacy` 的占位目前指向旧图，正式图仍然要画，画完发行包不再引用旧图。

尺寸、倍数、九宫格见 §2、§3。完整机器可读名单以 `data/cards/art/manifest.json` 为准；这里和它对得上。



### 牌框 frame（19）

牌面牌框显示 ×4，`nine: [6, 6, 6, 6]`。`frame.dialog` `frame.hero` `frame.guide_note` 的尺寸和倍数见 §12，不要套 36×50。

| id | 底图 | 正式路径 `human` | 占位 |
|---|---|---|---|
| `frame.big_fate` | 36×50 | `art/cards/frames/big_fate.png` | 生成占位 |
| `frame.contact` | 36×50 | `art/cards/frames/contact.png` | 生成占位 |
| `frame.demand` | 36×50 | `art/cards/frames/demand.png` | 生成占位 |
| `frame.estate` | 36×50 | `art/cards/frames/estate.png` | 生成占位 |
| `frame.event` | 36×50 | `art/cards/frames/event.png` | 生成占位 |
| `frame.fate` | 36×50 | `art/cards/frames/fate.png` | 生成占位 |
| `frame.gold` | 36×50 | `art/cards/frames/gold.png` | 生成占位 |
| `frame.guide_bubble` | 36×50 | `art/cards/frames/guide_bubble.png` | 生成占位 |
| `frame.kept` | 36×50 | `art/cards/frames/kept.png` | 生成占位 |
| `frame.life` | 36×50 | `art/cards/frames/life.png` | 生成占位 |
| `frame.news` | 36×50 | `art/cards/frames/news.png` | 生成占位 |
| `frame.night` | 36×50 | `art/cards/frames/night.png` | 生成占位 |
| `frame.person` | 36×50 | `art/cards/frames/person.png` | 生成占位 |
| `frame.prison` | 36×50 | `art/cards/frames/prison.png` | 生成占位 |
| `frame.self` | 36×50 | `art/cards/frames/self.png` | 生成占位 |
| `frame.street` | 36×50 | `art/cards/frames/street.png` | 生成占位 |
| `frame.dialog` | 48×48，nine [7,7,7,7]，画面 ×2 | `art/cards/frames/dialog.png` | legacy 旧图 `art/town/ui/dialog_frame.png` |
| `frame.guide_note` | 24×24，nine [6,6,6,6]，画面 ×2 | `art/cards/frames/guide_note.png` | 生成占位 |
| `frame.hero` | 27×36，nine [6,6,6,6]，画面 ×4 | `art/cards/frames/hero.png` | 生成占位 |

### 头像 portrait（47）

显示：×2 / ×4。

| id | 底图 | 正式路径 `human` | 占位 |
|---|---|---|---|
| `portrait.brother` | 48×64 | `art/cards/portraits/brother.png` | legacy 旧图 |
| `portrait.chen` | 48×64 | `art/cards/portraits/chen.png` | legacy 旧图 |
| `portrait.guanjia` | 48×64 | `art/cards/portraits/guanjia.png` | legacy 旧图 |
| `portrait.hu2` | 48×64 | `art/cards/portraits/hu2.png` | legacy 旧图 |
| `portrait.li` | 48×64 | `art/cards/portraits/li.png` | legacy 旧图 |
| `portrait.linsao` | 48×64 | `art/cards/portraits/linsao.png` | legacy 旧图 |
| `portrait.ma` | 48×64 | `art/cards/portraits/ma.png` | legacy 旧图 |
| `portrait.nf1938a` | 48×64 | `art/cards/portraits/nf1938a.png` | 生成占位 |
| `portrait.nf1938b` | 48×64 | `art/cards/portraits/nf1938b.png` | 生成占位 |
| `portrait.nf1938c` | 48×64 | `art/cards/portraits/nf1938c.png` | 生成占位 |
| `portrait.nf1938d` | 48×64 | `art/cards/portraits/nf1938d.png` | 生成占位 |
| `portrait.nf1939a` | 48×64 | `art/cards/portraits/nf1939a.png` | 生成占位 |
| `portrait.nf1939b` | 48×64 | `art/cards/portraits/nf1939b.png` | 生成占位 |
| `portrait.nf1939c` | 48×64 | `art/cards/portraits/nf1939c.png` | 生成占位 |
| `portrait.nf1939d` | 48×64 | `art/cards/portraits/nf1939d.png` | 生成占位 |
| `portrait.nf1940a` | 48×64 | `art/cards/portraits/nf1940a.png` | 生成占位 |
| `portrait.nf1940b` | 48×64 | `art/cards/portraits/nf1940b.png` | 生成占位 |
| `portrait.nf1940c` | 48×64 | `art/cards/portraits/nf1940c.png` | 生成占位 |
| `portrait.nf1940d` | 48×64 | `art/cards/portraits/nf1940d.png` | 生成占位 |
| `portrait.postman` | 48×64 | `art/cards/portraits/postman.png` | legacy 旧图 |
| `portrait.ruhua` | 48×64 | `art/cards/portraits/ruhua.png` | legacy 旧图 |
| `portrait.stranger_boatman` | 48×64 | `art/cards/portraits/stranger_boatman.png` | 生成占位 |
| `portrait.stranger_collector` | 48×64 | `art/cards/portraits/stranger_collector.png` | legacy 旧图 |
| `portrait.stranger_fence` | 48×64 | `art/cards/portraits/stranger_fence.png` | legacy 旧图 |
| `portrait.stranger_peddler` | 48×64 | `art/cards/portraits/stranger_peddler.png` | legacy 旧图 |
| `portrait.stranger_refugee` | 48×64 | `art/cards/portraits/stranger_refugee.png` | legacy 旧图 |
| `portrait.stranger_student` | 48×64 | `art/cards/portraits/stranger_student.png` | 生成占位 |
| `portrait.stranger_waixiang` | 48×64 | `art/cards/portraits/stranger_waixiang.png` | 生成占位 |
| `portrait.stranger_widow` | 48×64 | `art/cards/portraits/stranger_widow.png` | 生成占位 |
| `portrait.suanming` | 48×64 | `art/cards/portraits/suanming.png` | 生成占位 |
| `portrait.sunlaoye` | 48×64 | `art/cards/portraits/sunlaoye.png` | legacy 旧图 |
| `portrait.sunyoung` | 48×64 | `art/cards/portraits/sunyoung.png` | legacy 旧图 |
| `portrait.wangshan` | 48×64 | `art/cards/portraits/wangshan.png` | legacy 旧图 |
| `portrait.wu` | 48×64 | `art/cards/portraits/wu.png` | legacy 旧图 |
| `portrait.xiaoding` | 48×64 | `art/cards/portraits/xiaoding.png` | legacy 旧图 |
| `portrait.zhang` | 48×64 | `art/cards/portraits/zhang.png` | legacy 旧图 |
| `portrait.zhao` | 48×64 | `art/cards/portraits/zhao.png` | legacy 旧图 |
| `portrait.zhouma` | 48×64 | `art/cards/portraits/zhouma.png` | legacy 旧图 |
| `portrait.ex_girl` | 48×64 | `art/cards/portraits/ex_girl.png` | 生成占位（行走图朝下第一帧 ×2，贴在 (8,0)） |
| `portrait.ex_hu2_man` | 48×64 | `art/cards/portraits/ex_hu2_man.png` | 生成占位（同上，源 `stranger_collector`） |
| `portrait.ex_newsboy` | 48×64 | `art/cards/portraits/ex_newsboy.png` | 生成占位（同上，源 `passerby_0`） |
| `portrait.ex_oldman` | 48×64 | `art/cards/portraits/ex_oldman.png` | 生成占位（同上，源 `passerby_3`） |
| `portrait.ex_patrol` | 48×64 | `art/cards/portraits/ex_patrol.png` | 生成占位（同上，源 `patrol`） |
| `portrait.ex_porter` | 48×64 | `art/cards/portraits/ex_porter.png` | 生成占位（同上，源 `passerby_4`） |
| `portrait.ex_shopboy` | 48×64 | `art/cards/portraits/ex_shopboy.png` | 生成占位（同上，源 `passerby_2`） |
| `portrait.ex_soldier` | 48×64 | `art/cards/portraits/ex_soldier.png` | 生成占位（同上，源是调色后的 `walk.ex_soldier`） |
| `portrait.ex_student` | 48×64 | `art/cards/portraits/ex_student.png` | 生成占位（同上，源 `passerby_5`） |

### 小插图 illus（30）

显示：×2 / ×4。

| id | 底图 | 正式路径 `human` | 占位 |
|---|---|---|---|
| `illus.bf.any.mystery_box` | 64×48 | `art/cards/illus/bf.any.mystery_box.png` | 生成占位 |
| `illus.bf.any.ship_ticket` | 64×48 | `art/cards/illus/bf.any.ship_ticket.png` | 生成占位 |
| `illus.bf.wheel` | 64×48 | `art/cards/illus/bf.wheel.png` | 生成占位 |
| `illus.dm.goods` | 64×48 | `art/cards/illus/dm.goods.png` | 生成占位 |
| `illus.dm.info` | 64×48 | `art/cards/illus/dm.info.png` | 生成占位 |
| `illus.dm.money` | 64×48 | `art/cards/illus/dm.money.png` | 生成占位 |
| `illus.dm.people` | 64×48 | `art/cards/illus/dm.people.png` | 生成占位 |
| `illus.es.counter` | 64×48 | `art/cards/illus/es.counter.png` | 生成占位 |
| `illus.es.jewel_cabinet` | 64×48 | `art/cards/illus/es.jewel_cabinet.png` | 生成占位 |
| `illus.es.old_house` | 64×48 | `art/cards/illus/es.old_house.png` | 生成占位 |
| `illus.es.shopfront` | 64×48 | `art/cards/illus/es.shopfront.png` | 生成占位 |
| `illus.es.storeroom` | 64×48 | `art/cards/illus/es.storeroom.png` | 生成占位 |
| `illus.ev.1938.police_check` | 64×48 | `art/cards/illus/ev.1938.police_check.png` | 生成占位 |
| `illus.ev.any.demand_return` | 64×48 | `art/cards/illus/ev.any.demand_return.png` | 生成占位 |
| `illus.ev.any.fortune_teller` | 64×48 | `art/cards/illus/ev.any.fortune_teller.png` | 生成占位 |
| `illus.ev.any.wheel_go` | 64×48 | `art/cards/illus/ev.any.wheel_go.png` | 生成占位 |
| `illus.fa.any.fire_next_door` | 64×48 | `art/cards/illus/fa.any.fire_next_door.png` | 生成占位 |
| `illus.kp.brother_note` | 64×48 | `art/cards/illus/kp.brother_note.png` | 生成占位 |
| `illus.kp.liangmin` | 64×48 | `art/cards/illus/kp.liangmin.png` | 生成占位 |
| `illus.kp.ma_owes` | 64×48 | `art/cards/illus/kp.ma_owes.png` | 生成占位 |
| `illus.kp.mystery_box` | 64×48 | `art/cards/illus/kp.mystery_box.png` | 生成占位 |
| `illus.lf.any.coal_out` | 64×48 | `art/cards/illus/lf.any.coal_out.png` | 生成占位 |
| `illus.nt.early_sleep` | 64×48 | `art/cards/illus/nt.early_sleep.png` | 生成占位 |
| `illus.nt.family_dinner` | 64×48 | `art/cards/illus/nt.family_dinner.png` | 生成占位 |
| `illus.nt.tidy` | 64×48 | `art/cards/illus/nt.tidy.png` | 生成占位 |
| `illus.nw.letter` | 64×48 | `art/cards/illus/nw.letter.png` | 生成占位 |
| `illus.nw.rumor` | 64×48 | `art/cards/illus/nw.rumor.png` | 生成占位 |
| `illus.pr.cell` | 64×48 | `art/cards/illus/pr.cell.png` | 生成占位 |
| `illus.st.write_letters` | 64×48 | `art/cards/illus/st.write_letters.png` | 生成占位 |
| `illus.tk.de196` | 64×48 | `art/cards/illus/tk.de196.png` | 生成占位 |

### 物品 item（28）

显示：×2 / ×4。

| id | 底图 | 正式路径 `human` | 占位 |
|---|---|---|---|
| `item.art.calligraphy` | 64×64 | `art/cards/items/art.calligraphy.png` | 生成占位 |
| `item.art.flowers` | 64×64 | `art/cards/items/art.flowers.png` | legacy 旧图 |
| `item.art.landscape` | 64×64 | `art/cards/items/art.landscape.png` | 生成占位 |
| `item.art.woodcut` | 64×64 | `art/cards/items/art.woodcut.png` | legacy 旧图 |
| `item.clothing.coat` | 64×64 | `art/cards/items/clothing.coat.png` | 生成占位 |
| `item.clothing.qipao` | 64×64 | `art/cards/items/clothing.qipao.png` | 生成占位 |
| `item.clothing.robe` | 64×64 | `art/cards/items/clothing.robe.png` | 生成占位 |
| `item.clothing.scarf` | 64×64 | `art/cards/items/clothing.scarf.png` | 生成占位 |
| `item.documents.field` | 64×64 | `art/cards/items/documents.field.png` | legacy 旧图 |
| `item.documents.house` | 64×64 | `art/cards/items/documents.house.png` | legacy 旧图 |
| `item.documents.letter` | 64×64 | `art/cards/items/documents.letter.png` | legacy 旧图 |
| `item.documents.receipt` | 64×64 | `art/cards/items/documents.receipt.png` | legacy 旧图 |
| `item.jewelry.bangle` | 64×64 | `art/cards/items/jewelry.bangle.png` | 生成占位 |
| `item.jewelry.hairpin` | 64×64 | `art/cards/items/jewelry.hairpin.png` | legacy 旧图 |
| `item.jewelry.jade` | 64×64 | `art/cards/items/jewelry.jade.png` | 生成占位 |
| `item.jewelry.ring` | 64×64 | `art/cards/items/jewelry.ring.png` | legacy 旧图 |
| `item.medicine.aspirin` | 64×64 | `art/cards/items/medicine.aspirin.png` | legacy 旧图 |
| `item.medicine.iodine` | 64×64 | `art/cards/items/medicine.iodine.png` | legacy 旧图 |
| `item.medicine.quinine` | 64×64 | `art/cards/items/medicine.quinine.png` | legacy 旧图 |
| `item.medicine.sulfa` | 64×64 | `art/cards/items/medicine.sulfa.png` | legacy 旧图 |
| `item.rice.broken` | 64×64 | `art/cards/items/rice.broken.png` | legacy 旧图 |
| `item.rice.jing` | 64×64 | `art/cards/items/rice.jing.png` | legacy 旧图 |
| `item.rice.nuo` | 64×64 | `art/cards/items/rice.nuo.png` | legacy 旧图 |
| `item.rice.xian` | 64×64 | `art/cards/items/rice.xian.png` | legacy 旧图 |
| `item.utensils.bowl` | 64×64 | `art/cards/items/utensils.bowl.png` | 生成占位 |
| `item.utensils.clock` | 64×64 | `art/cards/items/utensils.clock.png` | 生成占位 |
| `item.utensils.tinpot` | 64×64 | `art/cards/items/utensils.tinpot.png` | 生成占位 |
| `item.utensils.warmer` | 64×64 | `art/cards/items/utensils.warmer.png` | legacy 旧图 |

### 背景 bg（18）

显示：画面里 ×4 = 1280×720。构图与哪些是首发见 §12。`bg.title` `bg.street` 从 1.3 起用旧图，不再由生成器画。

| id | 底图 | 正式路径 `human` | 占位 |
|---|---|---|---|
| `bg.baogong` | 320×180 | `art/cards/bg/baogong.png` | legacy `art/town/shops/baogong_bg.png` |
| `bg.candle` | 320×180 | `art/cards/bg/candle.png` | legacy `art/bg/candle.png` |
| `bg.counter.day` | 320×180 | `art/cards/bg/counter.day.png` | legacy `art/bg/counter_day.png` |
| `bg.counter.dusk` | 320×180 | `art/cards/bg/counter.dusk.png` | legacy `art/bg/counter_dusk.png` |
| `bg.counter.night` | 320×180 | `art/cards/bg/counter.night.png` | legacy `art/bg/counter_night.png` |
| `bg.dock` | 320×180 | `art/cards/bg/dock.png` | legacy `art/bg/title.png` |
| `bg.market` | 320×180 | `art/cards/bg/market.png` | legacy `art/town/shops/market_bg.png` |
| `bg.pharmacy` | 320×180 | `art/cards/bg/pharmacy.png` | legacy `art/town/shops/pharmacy_bg.png` |
| `bg.post` | 320×180 | `art/cards/bg/post.png` | legacy `art/town/shops/post_bg.png` |
| `bg.prison` | 320×180 | `art/cards/bg/prison.png` | 生成占位（`art/bg/candle.png` 调冷色） |
| `bg.ricehall` | 320×180 | `art/cards/bg/ricehall.png` | legacy `art/town/shops/ricehall_bg.png` |
| `bg.stage.1938` | 320×180 | `art/cards/bg/stage.1938.png` | 生成占位 |
| `bg.stage.1939` | 320×180 | `art/cards/bg/stage.1939.png` | 生成占位 |
| `bg.stage.1940` | 320×180 | `art/cards/bg/stage.1940.png` | 生成占位 |
| `bg.street` | 320×180 | `art/cards/bg/street.png` | legacy `art/town/shops/market_bg.png` |
| `bg.teahouse` | 320×180 | `art/cards/bg/teahouse.png` | legacy `art/town/shops/teahouse_bg.png` |
| `bg.temple` | 320×180 | `art/cards/bg/temple.png` | 生成占位（集市图压暖色 + 灯笼杆） |
| `bg.title` | 320×180 | `art/cards/bg/title.png` | legacy `art/bg/title.png` |

### 轮盘 wheel（4）

显示：×4 = 480。

| id | 底图 | 正式路径 `human` | 占位 |
|---|---|---|---|
| `wheel.big` | 120×120 | `art/cards/wheels/big.png` | 生成占位 |
| `wheel.fair` | 120×120 | `art/cards/wheels/fair.png` | 生成占位 |
| `wheel.gamble` | 120×120 | `art/cards/wheels/gamble.png` | 生成占位 |
| `wheel.month` | 120×120 | `art/cards/wheels/month.png` | 生成占位 |

### 图标 icon（23）

显示：牌面上 ×2 或 ×4。`icon.tab.*` 在标签上是 ×1，底图 24×24。`icon.coin.head` / `icon.coin.tail` 在柜台上是 ×3（16×16）。

| id | 底图 | 正式路径 `human` | 占位 |
|---|---|---|---|
| `icon.coin.head` | 16×16 | `art/cards/icons/coin.head.png` | 生成占位 |
| `icon.coin.tail` | 16×16 | `art/cards/icons/coin.tail.png` | 生成占位 |
| `icon.demand.goods` | 16×16 | `art/cards/icons/demand.goods.png` | 生成占位 |
| `icon.demand.info` | 16×16 | `art/cards/icons/demand.info.png` | 生成占位 |
| `icon.demand.money` | 16×16 | `art/cards/icons/demand.money.png` | 生成占位 |
| `icon.demand.people` | 16×16 | `art/cards/icons/demand.people.png` | 生成占位 |
| `icon.obj.almanac` | 24×24 | `art/cards/icons/obj.almanac.png` | 生成占位 |
| `icon.obj.brother_ledger` | 24×24 | `art/cards/icons/obj.brother_ledger.png` | 生成占位 |
| `icon.obj.notice` | 24×24 | `art/cards/icons/obj.notice.png` | 生成占位 |
| `icon.seal` | 16×16 | `art/cards/icons/seal.png` | 生成占位 |
| `icon.ws.caixing` | 16×16 | `art/cards/icons/ws.caixing.png` | 生成占位 |
| `icon.ws.fanshen` | 16×16 | `art/cards/icons/ws.fanshen.png` | 生成占位 |
| `icon.ws.liunian` | 16×16 | `art/cards/icons/ws.liunian.png` | 生成占位 |
| `icon.ws.pingan` | 16×16 | `art/cards/icons/ws.pingan.png` | 生成占位 |
| `icon.ws.zhuidi` | 16×16 | `art/cards/icons/ws.zhuidi.png` | 生成占位 |
| `icon.tab.contacts` | 24×24 | `art/cards/icons/tab.contacts.png` | 生成占位 |
| `icon.tab.demands` | 24×24 | `art/cards/icons/tab.demands.png` | 生成占位 |
| `icon.tab.dossier` | 24×24 | `art/cards/icons/tab.dossier.png` | 生成占位 |
| `icon.tab.estates` | 24×24 | `art/cards/icons/tab.estates.png` | 生成占位 |
| `icon.tab.rules` | 24×24 | `art/cards/icons/tab.rules.png` | 生成占位 |
| `icon.tab.settings` | 24×24 | `art/cards/icons/tab.settings.png` | 生成占位 |
| `icon.tab.shelf` | 24×24 | `art/cards/icons/tab.shelf.png` | 生成占位 |
| `icon.tab.tickets` | 24×24 | `art/cards/icons/tab.tickets.png` | 生成占位 |

### 行走图 walk（30）

底图 64×128。画面里：门口 ×8，街上 ×4。帧排法见 §12。群演首发要；主要人物可选。`stage.*` 不建。

| id | 底图 | 正式路径 `human` | 占位 |
|---|---|---|---|
| `walk.brother` | 64×128 | `art/cards/walk/brother.png` | legacy `art/town/chars/brother.png` |
| `walk.chen` | 64×128 | `art/cards/walk/chen.png` | legacy `art/town/chars/chen.png` |
| `walk.ex_girl` | 64×128 | `art/cards/walk/ex_girl.png` | legacy `art/town/chars/passerby_1.png` |
| `walk.ex_hu2_man` | 64×128 | `art/cards/walk/ex_hu2_man.png` | legacy `art/town/chars/stranger_collector.png` |
| `walk.ex_newsboy` | 64×128 | `art/cards/walk/ex_newsboy.png` | legacy `art/town/chars/passerby_0.png` |
| `walk.ex_oldman` | 64×128 | `art/cards/walk/ex_oldman.png` | legacy `art/town/chars/passerby_3.png` |
| `walk.ex_patrol` | 64×128 | `art/cards/walk/ex_patrol.png` | legacy `art/town/chars/patrol.png` |
| `walk.ex_porter` | 64×128 | `art/cards/walk/ex_porter.png` | legacy `art/town/chars/passerby_4.png` |
| `walk.ex_shopboy` | 64×128 | `art/cards/walk/ex_shopboy.png` | legacy `art/town/chars/passerby_2.png` |
| `walk.ex_soldier` | 64×128 | `art/cards/walk/ex_soldier.png` | 生成占位 |
| `walk.ex_student` | 64×128 | `art/cards/walk/ex_student.png` | legacy `art/town/chars/passerby_5.png` |
| `walk.guanjia` | 64×128 | `art/cards/walk/guanjia.png` | legacy `art/town/chars/guanjia.png` |
| `walk.hu2` | 64×128 | `art/cards/walk/hu2.png` | legacy `art/town/chars/stranger_collector.png` |
| `walk.li` | 64×128 | `art/cards/walk/li.png` | legacy `art/town/chars/li.png` |
| `walk.linsao` | 64×128 | `art/cards/walk/linsao.png` | legacy `art/town/chars/linsao.png` |
| `walk.ma` | 64×128 | `art/cards/walk/ma.png` | legacy `art/town/chars/ma.png` |
| `walk.postman` | 64×128 | `art/cards/walk/postman.png` | legacy `art/town/chars/postman.png` |
| `walk.ruhua` | 64×128 | `art/cards/walk/ruhua.png` | legacy `art/town/chars/ruhua.png` |
| `walk.stranger_collector` | 64×128 | `art/cards/walk/stranger_collector.png` | legacy `art/town/chars/stranger_collector.png` |
| `walk.stranger_fence` | 64×128 | `art/cards/walk/stranger_fence.png` | legacy `art/town/chars/stranger_fence.png` |
| `walk.stranger_peddler` | 64×128 | `art/cards/walk/stranger_peddler.png` | legacy `art/town/chars/stranger_peddler.png` |
| `walk.stranger_refugee` | 64×128 | `art/cards/walk/stranger_refugee.png` | legacy `art/town/chars/stranger_refugee.png` |
| `walk.suanming` | 64×128 | `art/cards/walk/suanming.png` | legacy `art/town/chars/passerby_3.png` |
| `walk.sunyoung` | 64×128 | `art/cards/walk/sunyoung.png` | legacy `art/town/chars/sunyoung.png` |
| `walk.wangshan` | 64×128 | `art/cards/walk/wangshan.png` | legacy `art/town/chars/wangshan.png` |
| `walk.wu` | 64×128 | `art/cards/walk/wu.png` | legacy `art/town/chars/wu.png` |
| `walk.xiaoding` | 64×128 | `art/cards/walk/xiaoding.png` | legacy `art/town/chars/xiaoding.png` |
| `walk.zhang` | 64×128 | `art/cards/walk/zhang.png` | legacy `art/town/chars/zhang.png` |
| `walk.zhao` | 64×128 | `art/cards/walk/zhao.png` | legacy `art/town/chars/zhao.png` |
| `walk.zhouma` | 64×128 | `art/cards/walk/zhouma.png` | legacy `art/town/chars/zhouma.png` |

### 道具 prop（36）

画面里一律 ×4。底图像素就是下表，不要改。热点和告示那一组首发要，其余用到才要，名单在 §12。

| id | 底图 | 正式路径 `human` | 占位 |
|---|---|---|---|
| `prop.abacus` | 52×22 | `art/cards/props/abacus.png` | legacy `art/tools/abacus.png` |
| `prop.back_door` | 16×32 | `art/cards/props/back_door.png` | legacy `art/town/props/back_door.png` |
| `prop.bed` | 32×28 | `art/cards/props/bed.png` | legacy `art/town/props/bed.png` |
| `prop.bench` | 26×12 | `art/cards/props/bench.png` | legacy `art/town/props/bench.png` |
| `prop.boat` | 48×22 | `art/cards/props/boat.png` | legacy `art/town/props/boat.png` |
| `prop.broom` | 8×22 | `art/cards/props/broom.png` | legacy `art/town/props/broom.png` |
| `prop.calendar` | 24×34 | `art/cards/props/calendar.png` | legacy `art/tools/calendar.png` |
| `prop.candle` | 8×16 | `art/cards/props/candle.png` | legacy `art/tools/candle.png` |
| `prop.cashbox` | 48×26 | `art/cards/props/cashbox.png` | legacy `art/tools/pawnbox.png` |
| `prop.cat` | 14×12 | `art/cards/props/cat.png` | legacy `art/town/props/cat.png` |
| `prop.clothes_rack` | 32×40 | `art/cards/props/clothes_rack.png` | legacy `art/town/props/clothes_rack.png` |
| `prop.coin` | 16×16 | `art/cards/props/coin.png` | legacy `art/town/ui/coin_icon.png` |
| `prop.door_flag` | 12×40 | `art/cards/props/door_flag.png` | legacy `art/tools/door_flag.png` |
| `prop.door_flag_red` | 12×40 | `art/cards/props/door_flag_red.png` | legacy `art/tools/door_flag_red.png` |
| `prop.door_flag_white` | 12×40 | `art/cards/props/door_flag_white.png` | legacy `art/tools/door_flag_white.png` |
| `prop.lamp` | 20×32 | `art/cards/props/lamp.png` | legacy `art/tools/lamp.png` |
| `prop.lamp_off` | 20×32 | `art/cards/props/lamp_off.png` | legacy `art/tools/lamp_off.png` |
| `prop.lantern_post` | 16×34 | `art/cards/props/lantern_post.png` | legacy `art/town/props/lantern_post.png` |
| `prop.ledger` | 40×26 | `art/cards/props/ledger.png` | legacy `art/tools/ledger.png` |
| `prop.letter` | 24×32 | `art/cards/props/letter.png` | 生成占位 |
| `prop.magnifier` | 30×20 | `art/cards/props/magnifier.png` | legacy `art/tools/magnifier.png` |
| `prop.medbook` | 36×16 | `art/cards/props/medbook.png` | legacy `art/tools/medbook.png` |
| `prop.notebook` | 40×26 | `art/cards/props/notebook.png` | legacy `art/tools/notebook.png` |
| `prop.notice` | 24×32 | `art/cards/props/notice.png` | 生成占位 |
| `prop.notice_wall` | 18×26 | `art/cards/props/notice_wall.png` | legacy `art/town/props/notice_wall.png` |
| `prop.rice_sacks` | 20×16 | `art/cards/props/rice_sacks.png` | legacy `art/town/props/rice_sacks.png` |
| `prop.scale` | 40×20 | `art/cards/props/scale.png` | legacy `art/tools/scale.png` |
| `prop.shelf` | 208×50 | `art/cards/props/shelf.png` | legacy `art/town/props/shelf.png` |
| `prop.sign` | 26×34 | `art/cards/props/sign.png` | legacy `art/tools/sign.png` |
| `prop.stamp` | 24×24 | `art/cards/props/stamp.png` | legacy `art/ui/stamp.png` |
| `prop.storeroom_door` | 32×46 | `art/cards/props/storeroom_door.png` | legacy `art/town/props/storeroom_door.png` |
| `prop.telegraph` | 38×28 | `art/cards/props/telegraph.png` | legacy `art/tools/telegraph.png` |
| `prop.telegraph_open` | 38×28 | `art/cards/props/telegraph_open.png` | legacy `art/tools/telegraph_open.png` |
| `prop.ticket` | 24×32 | `art/cards/props/ticket.png` | 生成占位 |
| `prop.trash` | 30×28 | `art/cards/props/trash.png` | legacy `art/tools/trash.png` |
| `prop.trunk` | 16×14 | `art/cards/props/trunk.png` | legacy `art/town/props/trunk.png` |

## 8. 来源登记

每张进发行包的正式图，在 `legal/ASSET_PROVENANCE.csv` 写一行。列（顺序固定）：

`path, sha256, author, method, source_file, license, license_file, order_no, no_ai_proof, date, reviewer`

| 列 | 填什么 |
|---|---|
| `path` | 相对仓库根的发行路径，等于清单 `human` |
| `sha256` | 该 PNG 字节的 sha256，小写十六进制 |
| `author` | 画画的人（在 `legal/human_authors.json` 里的那位） |
| `method` | 怎么画的（手绘像素、外包交稿等）。不是生成模型 |
| `source_file` | 分层源文件名。源文件本身不进发行路径 |
| `license` | 授权方式 |
| `license_file` | 授权文件路径（在 `legal/**`，人维护） |
| `order_no` | 外包单号；没有就按表留空的约定填 |
| `no_ai_proof` | 能证明不是 AI 画的材料（过程稿、合同、日期） |
| `date` | `YYYY-MM-DD` |
| `reviewer` | 审过这一行的人 |

作者不是 AI；`sha256` 必须和包里的文件一致（§11.4 第 3、4 项）。配色文件 `palette.json` 的 `_meta._provenance` 是 `human:A:…`，不进这张 CSV。

## 9. 代码画的小游戏画面

这些**算代码，不算美术**，不要画进 `art/cards/**`，也不要占位图：

- 吹银元的波形
- 秤杆
- 碎片描边（找不同）

它们只许用调色板键（经 `CardTheme`），不许在 `scripts/cards/ui/**`、`scripts/cards/minigames/**` 里写颜色字面量。占位阶段开发版可以没有 B 的音效样本；那是音频的事，不是这张规格的图。

画面里代码画的效果同样**不算美术**（雨、火光、烟、夜色、封条、影子、灯光）。只许用合同 §2.4「画面（1.3）」那一行的键，已知要用的有 `rain` `fire_glow` `smoke` `night_tint` `night_dark` `seal_paper` `silhouette` `lamp_glow`（还有 `cold_tint` `warm_tint` `candle_tint` `scene_void` 等，以合同那一行为全）。开发初值还没写进 `palette.dev.json` 的键，不要在这里发明色值。

## 10. 新手指引专用

C16 的气泡、教的人、物件图标。正式图按上表尺寸交到 `human`。

| id | 底图 | 用在 |
|---|---|---|
| `portrait.brother` | 48×64 | 哥哥教的那些步（开局、第 1–2 天、选择） |
| `portrait.zhouma` | 48×64 | 消息、档案、人脉、档位 |
| `portrait.hu2` | 48×64 | 条子、拖延、失败 |
| `portrait.suanming` | 48×64 | 求签、测字。没有旧立绘，占位是剪影 |
| `portrait.postman` | 48×64 | 电码小游戏 |
| `icon.obj.brother_ledger` | 24×24 | 哥哥走后，账簿批注讲规矩 |
| `icon.obj.notice` | 24×24 | 告示（集、天气、关铺、轮盘、钱） |
| `icon.obj.almanac` | 24×24 | 黄历 |
| `frame.guide_bubble` | 36×50，`nine: [6,6,6,6]` | 每一步的气泡底 |
| `frame.guide_note` | 24×24，`nine: [6,6,6,6]`，画面 ×2 | 物件当教的人时的批注纸（1.3） |

物件不是人物，id 是 `icon.obj.<名>`，不要画成头像。人物教的人站在 `GUIDE_TEACHER`（236, 36, 48, 64），用 `portrait.<人物>` ×4（没有 `stage.<人物>`，清单不建 `stage.*`）。

## 11. 占位生成器画了什么（给开发看，不是交付标准）

生成器读清单里 **没有** `legacy: true`、且 `placeholder` 在 `art/_placeholder/` 下的每一条，外加缺图方块。类别：

- 牌框：14 种牌 + `gold` + `guide_bubble`，另加画面的 `frame.hero` `frame.guide_note`（`frame.dialog` 是旧图，不生成）
- 没有旧立绘的头像：算命先生、`nf1938a`–`nf1940d`、外乡人 / 船工 / 学生 / 寡妇，以及九个群演 `portrait.ex_*`（从行走图朝下第一帧派生，不是剪影）
- 小插图、没有旧图的物品变体、四种轮盘面、图标（含 8 个 `icon.tab.*`）
- 画面里标了「K12 生成」的：`bg.prison`（烛光图调冷色）、`bg.temple`（集市图压暖 + 灯笼杆）、`walk.ex_soldier`（`patrol.png` 调色）、`prop.notice` `prop.ticket` `prop.letter`
- `bg.stage.<年>` 仍是绘制的开场底。`bg.title` `bg.street` 和三张柜台背景是 legacy，生成器不画

有旧图的头像、物品、行走图、道具、场景保持 `legacy: true`。生成器只读那些文件，写到 `art/_placeholder/`，不改旧图。

`--sheet=<文件>` 把总览拼到仓库外（不进仓库）。第一行是教的人（含旧立绘）和物件图标、气泡框，×4 最近邻。第二行 `SCENE` 是画面：三张柜台背景、群演头像、行走图朝下第一帧、全部道具、对话框框、英雄头像框、批注纸、标签图标。

## 12. 画面（合同 1.3）

画面是 **320×180** 的像素场景，整数 **×4** 铺满 1280×720。场景坐标 (sx, sy) → 屏幕 (4·sx, 4·sy)。过滤 `TEXTURE_FILTER_NEAREST`。下面的数照合同 §1.2、§4.8、§7.11.2，不要改。

`stage.<person>` **不建清单条目**。柜台前没有这张图就用 `portrait.<person>`。

### 12.1 放大倍数

| 东西 | 倍数 |
|---|---|
| 背景、立绘（柜台前的 `portrait`，以及将来若有的 `stage`）、柜台工具、道具 | ×4 |
| 柜台上的物品 `item.*` | ×2 |
| 门口的行走图 | ×8 |
| 街上的行走图 | ×4 |
| 对话框框 `frame.dialog` | ×2 |
| 英雄头像框 `frame.hero` | ×4 |
| 批注纸 `frame.guide_note` | ×2 |
| 标签图标 `icon.tab.*` | ×1 |

手牌里的头像仍是 ×2、选中放大 ×4（§2）。那是牌面，不是柜台前的立绘。

### 12.2 场景坐标（320×180）

| 名称 | x, y, w, h |
|---|---|
| 墙 | 0, 0, 320, 100 |
| 门洞 | 112, 8, 96, 92 |
| 柜台面 | 0, 100, 320, 50 |
| 桌下 | 0, 150, 320, 30 |
| 客人 `customer` | 136, 36, 48, 64 |
| 柜台一侧 `companion`（教的人 `GUIDE_TEACHER` 同这里） | 236, 36, 48, 64 |
| 门口正中 `door` | 144, 36, 32, 64 |
| 门口左 `door_l` / 门口右 `door_r` | 128, 36, 32, 64 / 160, 36, 32, 64 |
| 柜上的东西 | 116, 104, 88, 42 |

人物的下边压在柜台面 y=100 上。门外街上走过的人：y 66，x 从 116 到 192，一帧 16×32（合同 §7.11.2）。HUD、对话框、手牌扇是屏幕坐标，不要画进这张 320×180 的底图。

### 12.3 柜台背景

`bg.counter.day` `bg.counter.dusk` `bg.counter.night` 三张必须和旧图 **同一构图**：门洞 112,8,96,92，柜台面从 y=100 起。只换光，不挪门、窗、柜台、桌下。正式图沿用这个位置，坐标常量都按它定。占位直接用旧图（`legacy: true`）。

### 12.4 站位

| 站位 | 用的图 | 倍数 |
|---|---|---|
| `customer` / `companion` | `portrait.<who>`（48×64）。不建 `stage.<who>` | ×4 |
| `door` / `door_l` / `door_r` | `walk.<who>` 朝下第一帧 | ×8 |
| `street` | `walk.<who>` | ×4 |

主要人物没有行走图时，界面用立绘滑进来，清单里缺 `walk.<who>` 不算错。群演（`ex_*`）站门口或街上则必须有 `walk.<who>`。

### 12.5 行走图帧

`walk.<person>` 底图 **64×128**：

- 一帧 **16×32**
- **4 行** = 朝下、朝左、朝右、朝上
- **4 列** = 站、迈左脚、站、迈右脚
- 脚点 **(8, 30)**

朝下第一帧是左上角那一格 (0, 0, 16, 32)。群演头像 `portrait.ex_*` 的占位就是这一格 ×2，贴在 48×64 的 **(8, 0)**（和 `ruhua.png` 同一做法）。

### 12.6 九宫格（画面这三张）

边距单位是底图像素。顺序左、上、右、下。四条边的中段必须是可拉伸的平纹，花纹只放在角上。

| id | 底图 | `nine` | 画面里 |
|---|---|---|---|
| `frame.dialog` | 48×48 | [7, 7, 7, 7] | ×2 |
| `frame.hero` | 27×36 | [6, 6, 6, 6] | ×4（屏幕 108×144） |
| `frame.guide_note` | 24×24 | [6, 6, 6, 6] | ×2 |

`frame.dialog` 的占位是旧的 `art/town/ui/dialog_frame.png`。英雄框中心透明，头像从中间露出来。批注纸中心是不透明的纸色。牌面牌框仍是 36×50、边距 6（§3），不要和这三张混。

### 12.7 道具底图

全部在画面里 ×4。尺寸是底图像素：

| id | 底图 | 首发 |
|---|---|---|
| `prop.magnifier` | 30×20 | ✓ |
| `prop.abacus` | 52×22 | ✓ |
| `prop.scale` | 40×20 | 用到才要 |
| `prop.ledger` | 40×26 | ✓ |
| `prop.notebook` | 40×26 | ✓ |
| `prop.cashbox` | 48×26（旧图 `pawnbox.png`） | ✓ |
| `prop.medbook` | 36×16 | 用到才要 |
| `prop.trash` | 30×28 | 用到才要 |
| `prop.telegraph` / `prop.telegraph_open` | 38×28 | 用到才要 |
| `prop.lamp` / `prop.lamp_off` | 20×32 | ✓ |
| `prop.calendar` | 24×34 | ✓ |
| `prop.candle` | 8×16 | 用到才要 |
| `prop.sign` | 26×34 | 用到才要 |
| `prop.door_flag` / `prop.door_flag_red` / `prop.door_flag_white` | 12×40 | 用到才要 |
| `prop.notice` | 24×32 | ✓ |
| `prop.notice_wall` | 18×26 | ✓ |
| `prop.ticket` | 24×32 | ✓ |
| `prop.letter` | 24×32 | ✓ |
| `prop.stamp` | 24×24 | ✓ |
| `prop.coin` | 16×16 | ✓ |
| `prop.trunk` | 16×14 | 用到才要 |
| `prop.boat` | 48×22 | 用到才要 |
| `prop.broom` | 8×22 | 用到才要 |
| `prop.rice_sacks` | 20×16 | 用到才要 |
| `prop.shelf` | 208×50 | 用到才要 |
| `prop.lantern_post` | 16×34 | 用到才要 |
| `prop.bench` | 26×12 | 用到才要 |
| `prop.bed` | 32×28 | 用到才要 |
| `prop.back_door` | 16×32 | 用到才要 |
| `prop.clothes_rack` | 32×40 | 用到才要 |
| `prop.storeroom_door` | 32×46 | 用到才要 |
| `prop.cat` | 14×12 | 用到才要 |

`prop.notice` `prop.ticket` `prop.letter` 由 K12 从旧纸样缩到 24×32（信再压一道折痕，右上角盖 8×8 邮戳）。其余道具占位指向旧图。

### 12.8 标签图标

8 个，底图 **24×24**，画面里 **×1**：`icon.tab.contacts` `icon.tab.demands` `icon.tab.dossier` `icon.tab.rules` `icon.tab.shelf` `icon.tab.tickets` `icon.tab.estates` `icon.tab.settings`。全是首发。

柜台上的铜钱图是 `icon.coin.head` `icon.coin.tail`，16×16，画面里 ×3。也是首发。

### 12.9 首发要交的（合同表里打 ✓ 的）

- 背景：`bg.counter.day` `bg.counter.dusk` `bg.counter.night`、`bg.candle`、`bg.prison`、`bg.street`、`bg.market`、`bg.temple`、`bg.dock`、`bg.title`、`bg.stage.1938` `bg.stage.1939` `bg.stage.1940`
- 用到才要的背景：`bg.teahouse` `bg.ricehall` `bg.pharmacy` `bg.post` `bg.baogong`
- 每个主要人物 1 张头像（同时是柜台前的立绘）
- 群演 9 个的头像 `portrait.ex_*` 和行走图 `walk.ex_*`：`ex_patrol` `ex_soldier` `ex_newsboy` `ex_girl` `ex_shopboy` `ex_oldman` `ex_porter` `ex_student` `ex_hu2_man`
- 主要人物的行走图可选（有了客人才会从街上走进来）
- 道具：§12.7 里打 ✓ 的
- `frame.dialog` `frame.hero` `frame.guide_note`
- 8 个 `icon.tab.*`，以及 `icon.coin.head` `icon.coin.tail`

三张柜台背景的正式图必须和旧图同构图。路径都在 §7，和 `data/cards/art/manifest.json` 的 `human` 一致。
