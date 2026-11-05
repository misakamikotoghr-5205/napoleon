# W2-7a 第二批候选（I-101..I-118）
Refs #200 #212。Flow 图片线出图，MISAKA 在云端虚拟机里操作 Google Flow，下载原图后交给 box 做后处理。
> **主创 10-18 决定（#212，见 `docs/cards/ART_SPEC.md` 顶部、`docs/handoff_cards/W2_HANDOFF.md` 任务 7 与末尾一节）：这一版美术用 AI，带 AI 内容声明发。** 原来写的“AI 只出占位、不进 Steam 包”已作废。定稿图放 `art/ai/<类别>/<id>.png`，清单登记 `ai` 路径和 `_provenance`（#201）。这批图仍然只是给主创挑风格的候选，不是定稿，所以本 PR 不登记进 `data/cards/art/manifest.json`，也不放进 `art/ai/**`、`art/cards/**` 或 `art/_placeholder/**`。主创每类挑定风格后，再按 #201 批量生产、放进 `art/ai/**`。

## 返工记录（Claude 审核 10-18）

1. **白天 / 黄昏 / 夜里改成同一个场景。** 原来的 I-102（黄昏）、I-103（夜）是另外两间屋子，已从仓库删掉。新的黄昏、夜里都以 I-101（白天，已对位）为底图，用 `relight_counter.py` 在后处理里只换光线和颜色：每个像素的新颜色只由“同位置的白天颜色 + 该位置的光照档（灯旁 / 远处 / 门洞外）”决定，不移动任何像素。所以门、柜台、桌下的轮廓和白天**逐像素对齐**。核对：黄昏、夜里比白天多出来的颜色分界全部落在灯光圈和门洞的边上（脚本外另跑的检查，多出的分界里没有一条是别处来的）。黄昏：门外是琥珀色的街，灯旁保持原色，远处暗一档、偏暖。夜：门外是靛蓝的街，灯旁保持原色，其余暗一档，离灯远的地方再偏冷。只用 §4 的 11 色，不抖动，同样输入跑两次输出字节相同。没有重新出图，没有用 Flow 额度。三张并排对比：`counter_day_dusk_night.png`（×3）。
2. **原图 JPG 不进仓库。** 19 张原图（本批 18 张 + `bg_counter_cand01_original.jpg`）已从分支里删掉，仓库只留后处理好的 PNG。原图的文件名和 sha256 见下面“原图（不在仓库里）”一节；原件暂存在 Flow 图片线的 box 上，等定好放网盘还是 Release 附件再上传。注意：已经推上去的旧提交（`bce0de52`、`ccd994a6`）里还有这些 JPG，按规矩不改写已推送的历史。
3. **说明按主创 10-18 的决定改了**（见上面的引用块）；总览图 `batch2_contact.png` 标题里的 “AI placeholder only” 改成 “AI art for the AI-disclosed build, #212”，柜台一行换成同一场景的白天 / 黄昏 / 夜里。
4. **出图账号的邮箱已从说明里删掉**（`bg_counter_cand01.md` 和本文件）。旧提交里仍有，同第 2 条，不改写历史。
5. **行走图对照 §12.5 自查、试切一帧**，见下面“行走图自查”一节。

## 第二次返工（Claude 10-18 复审：黄昏 / 夜里）

> 这一节的“硬边光圈、不抖动”已被下面的**第三次返工**取代（主创 #200 10-18 定稿：灯光用像素抖动渐变）。查表、门外街景、柜台下半截的做法照旧。

复审说黄昏太平、太饱和（门洞和街成了一整块纯黄，墙面整片芥末黄），夜里门洞整块纯蓝，柜台下半截在黄昏和夜里几乎全黑。黄昏 / 夜里**重新用 `relight_counter.py` 从白天图换光**，取代上面第 1 条里的旧版换光（旧版只在 11 色里“暗一档”，所以亮度全挤在一起）：

- **按亮度映射调色**：每个像素先认出它在白天图里的色板键，再按位置分区（门洞外的街 / 柜台下半截 / 屋里其他地方），屋里再按离油灯火苗的距离分光档（黄昏 5 档、夜里 6 档）。新颜色 = 查表[时段][分区][白天的键][光档]。表按亮度排：白天越亮的键映到越亮的目标；黄昏亮处偏橙（`frame_person` `gold` `frame_gold` `lamp` `candle_tint`）、暗处偏棕紫（`reply_off` `frame_street` `frame_fate` `frame_prison`）；夜里远处偏冷偏暗，灯旁偏暖。相邻亮度的键映到不同目标，所以轮廓和纹理不会并成一块。
- **门外街景**：黄昏街上分三层（亮面 `frame_gold` / `btn_day`，消失点一圈 `candle_tint` 像落日，房子的边线 `frame_person`，窗和招牌 `frame_street`），街道的透视线、两边房子、窗都看得出。夜里街是 `indigo`，房子是 `frame_big_fate` 剪影，近处地面 `frame_night`，右边房子点亮两扇窗（`frame_gold`，脚本里两块固定矩形）。
- **油灯暖光**：火苗周围一圈一圈往外暗（像素画的硬边光圈，不做渐变）；黄昏另把柜台面以上、门洞四周 18 px 抬一档，当作门外夕照漏进来。夜里灯这一角最亮，屋子右侧最暗。
- **柜台下半截**：远处的暗部抬一点（黄昏 `wood` → `frame_fate`，夜里 `wood` / `wood_mid` → `frame_fate`，`ink` 不变），抽屉、拉手和木纹的轮廓留下来。
- **色值**：目标色只用 `data/cards/theme/palette.dev.json` 里已有的不透明键，不发明色值，不抖动；比第 1 条多用了 §4 表外、但已在开发配色里的键（`frame_person` `frame_gold` `frame_street` `frame_estate` `frame_fate` `frame_prison` `frame_news` `frame_night` `frame_big_fate`、`reply_off`、`good`、`danger`、`btn_day`、`candle_tint`、`scene_void`）。正式配色由 A 定，到时候按键换值即可。真正的“紫”色板里没有，要的话得开 `[shared]` 加键。黄昏 18 色、夜里 19 色。
- **对位不变**：只换颜色，不动任何像素位置，三张图逐像素对齐；尺寸、格式不变（320×180，8 位 RGBA，只有 IHDR/IDAT/IEND）。同样输入跑两次输出字节相同。
- **怎么重跑**：`python3 relight_counter.py I-101_bg_counter_day.png ../../../../../data/cards/theme/palette.dev.json <输出目录> counter_day_dusk_night.png`（第 4 个参数顺便导出三图对比，2976×630，每张 ×3）。`batch2_contact.png` 用 `contact.py`（不改）重出，只把预览里的 `I-101_dusk` / `I-101_night` 换成新图。
- **AI 声明**（#212）：底图 I-101 是 AI 图（Flow / Nano Banana 2.1）；黄昏 / 夜里是对这张 AI 图的确定性脚本换色，没有重新出图，没有用 Flow 额度，没有手绘。挑定后进 #201，按 AI 图登记 `_provenance`。

## 第三次返工（Claude 10-18 14:50 复审 + 主创 #200 15:00 定稿：灯光改抖动渐变）

复审：油灯的光和夜里右半边那一大片是硬边同心圆（像几层半透明灰圆片）；夜里右半边有一条大圆弧（遮罩边）；夜里灯光偏灰、把画面洗白。主创 #200 定稿：一天三个时段永远是同一张底图换光，灯光用像素抖动渐变，不要硬边圆盘，批量（#201）前先把这张改好做样板。仍然只改 `relight_counter.py`，**没有重新出图，没有用 Flow 额度**：

- **后处理步骤（新）**：屋里先算一个连续的光量 v（0 = 环境光，4 = 火苗旁），v 只由到火苗 (21, 86) 的距离 r 决定，按控制点分段线性插值（黄昏 r = 6/18/32/52/76 → v = 4/3/2/1/0，夜里 r = 3/14/28/46/70 → 4/3/2/1/0；竖直方向距离 ×1.25，夜里火苗以下到柜台面 ×0.9，柜台下半截再 ×1.6（黄昏）/ ×2.4（夜里））。光档 = floor(v + Bayer 4×4 阈值)，阈值表按画面绝对坐标 (x%4, y%4) 铺，抖动点和像素格对齐。两档之间是有序抖动（点阵 → 棋盘 → 点阵），从灯往外一格一格变暗，没有硬边。新颜色仍是查表[时段][分区][白天的键][光档]。
- **硬边圆盘 → 抖动渐变**：黄昏、夜里的灯光都改成上面的抖动渐变；黄昏门洞四周的夕照也从“18 px 内硬抬一档”改成随距离线性减弱的抖动（距门洞 0 px 时 v = 1，22 px 时 0，只在柜台面 y < 100 以上）。
- **夜里右半边的大圆弧去掉**：旧版夜里有 6 档、最外一圈半径 190，右半边那条弧就是它的边。现在 r ≥ 70 以后 v 恒为 0，远处整片都是同一档环境光；核对：夜里门洞外、离火苗 r ≥ 70 的 45,780 个像素，颜色只由白天的键（和是否在柜台下半截）决定，没有一个例外，所以不会出现任何弧线。
- **夜里灯光改暖黄，只照左侧柜台一角**：夜里 1–4 档（灯光）只用暖棕 / 暖黄（`wood_mid` `frame_person` `gold` `frame_gold` `lamp`，红用 `danger` / `seal`），不再用 `frame_street` `frame_estate` `frame_news` 这些灰色键；光只到火苗左右约 70 px、往上约 56 px（柜台左端、账本、左墙下半截），灯脚下那片柜面最亮。环境光（0 档）整屋一样：墙 `frame_fate` / `frame_estate`，告示 `frame_night`，木头 `frame_prison` / `ink`，墨线 `scene_void`。
- **保留**：黄昏门外街景和尽头的夕阳、夜里街道剪影和两扇亮窗、柜台下半截的抽屉和木纹（门外街和柜台下半截 0 档的查表都没改）；只换颜色、不动像素，三张逐像素对齐；320×180、8 位 RGBA、只有 IHDR/IDAT/IEND、透明度和白天图逐像素相同；只用 `palette.dev.json` 里已有的不透明键（黄昏 18 色、夜里 16 色）。同样输入跑两次输出字节相同（四个输出都核对过）。
- **怎么重跑**：`python3 relight_counter.py I-101_bg_counter_day.png ../../../../../data/cards/theme/palette.dev.json <输出目录> counter_day_dusk_night.png counter_lamp_dither_x3.png`（第 4 个参数导出三图对比 2976×630，每张 ×3；第 5 个参数导出黄昏 / 夜里油灯一角 x 0–127、y 36–131 的 ×3 局部图 `counter_lamp_dither_x3.png`，840×364，看抖动用）。`batch2_contact.png` 仍用 `contact.py`（不改）重出，只把预览里的 `I-101_dusk` / `I-101_night` 换成新图；和上一版比，只有柜台那一行的黄昏、夜里两格变了。

## 出图

- 工具：Google Flow 图片模式，Flow 图片线的 Google AI Ultra 账号（邮箱不写进仓库）
- 模型：Nano Banana 2.1，每条只生成一次、每次 1 张，没有放大，没有重试
- 积分：这 18 张一起看，生成前 10,002，生成后 10,002，**扣了 0**（单张扣费没有单独测）。同一时段 Flow 另有 3 段视频（D-001..003）各扣 12，那是 Flow 视频线的，不在这里
- 比例：I-101..103 是 16:9（I-102、I-103 已不用，见返工记录第 1 条）（1376×768），I-104..106 和 I-113..115 是 3:4（896×1200），I-107..109 是 9:16（768×1376），I-110..112 是 1:1（1024×1024），I-116..118 是 4:3（1200×896）
- MISAKA 那边的审计（`audit-report.json`）通过：18 个文件的 sha256 和账本一致
## 后处理（`make_batch2.py`，同样的输入跑两次，输出字节相同）

通用步骤：先用 BOX（面积平均）缩小，再按 CIELAB 色差换成最近的色板颜色，不抖动。导出 8 位 RGBA PNG，只有 IHDR/IDAT/IEND 三个块。绿底 #00ff00 先抠成透明：缩小前先乘上透明度再平均，缩小后覆盖率 ≥ 0.5 的格子算不透明，牌框放宽到 0.35。

色板用 §4 的 11 个开发初值。牌框另加 `frame_person` #8c6a44 和 `frame_gold` #d9a520；`frame_event` #5a3f2a 和 `gold_glow` #ffd25a 本来就在 11 色里。

- **柜台背景**：居中裁成 16:9，缩到 320×180，再做对位（见下节）。
- **半身像**：居中裁成 3:4，缩到 48×64，不抠图（纸色底）。
- **行走图**：原图按 4×4 等分。每格抠绿后取外框，整张表用同一个缩放倍数，放进 16×32 的格子里，脚点 (8,30)。Flow 把第 2、3 行都画成了朝右，所以**第 2 行做了水平镜像**，当成朝左用。
- **物品**：抠绿，取外框，长边缩到 60，放在 64×64 正中。
- **牌框**：抠绿，把外框直接缩成 36×50（中心透明）。
- **小插图**：找出和纸色不同的主体，外扩 25% 并补成 4:3，缩到 64×48，不抠图。
## 柜台对位（§12.2：门洞 112,8,96,92，柜台面 y=100）

下面的值都是在 16:9 裁剪后、320×180 坐标下测的。门的左右边界看的是门框或门扇的外缘。

| id | 门 x（测量） | 门顶（测量） | 柜台面（测量） | 处理 | 对位后 |
|---|---|---|---|---|---|
| I-101 | 111–209 | 21 | 110 | 整体上移 10 px，底部「桌下」10 行用镜像补 | 门 x 111–209，门顶 11，柜台面 100 |

结论：门在水平方向本来就对上了，误差在 ±2 px 以内。柜台面原来低了 10 px，上移后对齐到 y=100，门顶落在 11（规格要 8，差 3 px）。黄昏、夜里直接用对位后的 I-101 换光，所以位置和白天完全一样。如果用整体缩放来同时对齐门顶，需要的源图高度超出原图，所以没有缩放，只做了平移和底部镜像。没有对位的版本保存为 `I-101_bg_counter_day_unaligned.png`。
## 文件与 sha256

| id | 类别 | 清单 id | 文件 | 尺寸 | 字节 | sha256 |
|---|---|---|---|---|---|---|
| I-101 | 柜台背景 | `bg.counter.day` | `I-101_bg_counter_day.png` | 320×180 | 6390 | `d8d7d829e7f9a380ac841c88c283c06868a0c94e8527fe8786825764cf864965` |
| I-101 | 柜台背景 | `bg.counter.day` | `I-101_bg_counter_day_unaligned.png` | 320×180 | 6593 | `ea032d2ecdc379045bf415373182bdbd73693d88ca7d214e5304f4af37c48dfc` |
| I-101 | 柜台背景 | `bg.counter.dusk` | `I-101_bg_counter_dusk.png` | 320×180 | 7615 | `9717038d6ad355b4e19b9344c6a15b1f2d138148d5d7545a5eb1cafac9895808` |
| I-101 | 柜台背景 | `bg.counter.night` | `I-101_bg_counter_night.png` | 320×180 | 6713 | `1b4f1d3d199976badebe488b7f0d9d2ade31f573744935418d2c25a2f5dc092e` |
| I-104 | 半身像 | `portrait.linsao` | `I-104_portrait_linsao.png` | 48×64 | 889 | `c77170738b936707e036c1b8a58bcedd0a57718798e3f2daa69006219a175109` |
| I-105 | 半身像 | `portrait.suanming` | `I-105_portrait_suanming.png` | 48×64 | 1067 | `17e9f6b6936deb1c5ec7eea621ccacc444ebf35e576055f77c59e13b209f190f` |
| I-106 | 半身像 | `portrait.postman` | `I-106_portrait_postman.png` | 48×64 | 881 | `b0f08ed860ed5110e3cfdec6e3d2522926c22fc82a59d1e552d21a1df20182c0` |
| I-107 | 行走图 | `walk.ex_newsboy` | `I-107_walk_ex_newsboy.png` | 64×128 | 2168 | `d2c2b390d569bf9055e89187f9f03678a18a224316da1c4c5d9122738dfbdfd6` |
| I-108 | 行走图 | `walk.ex_porter` | `I-108_walk_ex_porter.png` | 64×128 | 2129 | `359598cfb97dc2a60759b0e0044ff75fc7adf0df865b7202461e4d2ea54e7af7` |
| I-109 | 行走图 | `walk.stranger_peddler` | `I-109_walk_stranger_peddler.png` | 64×128 | 2255 | `834edb11cfbf31e08d4f074227df33d748c219f0113642bdd3c23c9567b66a52` |
| I-110 | 物品 | `item.jewelry.hairpin` | `I-110_item_jewelry_hairpin.png` | 64×64 | 558 | `8aa79418dc005e1653b0f05ce62748f9e94040dc93e5d29ad6c5dd4fce4f9879` |
| I-111 | 物品 | `item.utensils.clock` | `I-111_item_utensils_clock.png` | 64×64 | 912 | `89c30088bb6d5e4319d59203b757553a83a011c85df7b87601a869cd4c2f23f6` |
| I-112 | 物品 | `item.jewelry.jade` | `I-112_item_jewelry_jade.png` | 64×64 | 898 | `bd8cb7d205fbb178c83a5b58618ef5b73c42f8777e8e9981186b6b542b5ebca1` |
| I-113 | 牌框 | `frame.person` | `I-113_frame_person.png` | 36×50 | 222 | `5311d276ac89b3c6e5223a74883293968559b3a3e982b251f077d7091009036c` |
| I-114 | 牌框 | `frame.gold` | `I-114_frame_gold.png` | 36×50 | 440 | `25cded2ce095c468964ce90a2e8fbb19a740a30a80061d644c0e4ab26de20a32` |
| I-115 | 牌框 | `frame.event` | `I-115_frame_event.png` | 36×50 | 283 | `9749024433ad3c1bf2b0fb4fa49470892cc6208f19d3f24f0a64014522745b6b` |
| I-116 | 小插图 | `illus.es.shopfront` | `I-116_illus_es_shopfront.png` | 64×48 | 559 | `1757defd2df300efa9f5a1f7ea65edec93aa3e4ee32e434e8af5befe23d4e1fd` |
| I-117 | 小插图 | `illus.ev.any.fortune_teller` | `I-117_illus_ev_any_fortune_teller.png` | 64×48 | 495 | `a6707bcc16ed0dc0fd0a11638403ae0448d702a507d10dbab3b7dbbfeb53beae` |
| I-118 | 小插图 | `illus.nt.family_dinner` | `I-118_illus_nt_family_dinner.png` | 64×48 | 806 | `7252f303c09bdc8569781ae88655dade35764028e657a5b69ad40446758c808a` |
| — | — | — | `batch2_contact.png` | 4000×3126 | 250070 | `074ce3e9ae55bdd1a0f34491046e2fcd6abed474cd299178a60e393fbcd8eb88` |
| — | — | — | `counter_day_dusk_night.png` | 2976×630 | 55233 | `df82f22b59e716b9b1c871ef2261d813d2d4e337a73ee2c5bc4916683148b64b` |
| — | — | — | `counter_lamp_dither_x3.png` | 840×364 | 17116 | `d00d9499d0460f0ac1deff1db55162dbfc05026f465aa65a04140316a46dd0c6` |
| — | — | — | `walk_door_slice_mock.png` | 1920×360 | 18590 | `2748d4b34e48dbf3797d27f57d8d9c9410bd925f4bf79e186af1df0655f60d0c` |
| — | — | — | `make_batch2.py` |  | 6517 | `af8e338c7f643f05c10e1d60833b18cc1dcb4732308228eadcb999d55c63e904` |
| — | — | — | `contact.py` |  | 2494 | `aff7889df832d9c65fa4bbeb08fc86f0016e99ee92e8106a0abc03754e1239e6` |
| — | — | — | `relight_counter.py` |  | 10659 | `cf9c1f87828b1d1875105defd5457f6d67192c59fbff193baae0357b958811cc` |
| — | — | — | `walk_check.py` |  | 2953 | `58ce98d69fe198c8c3e464e7b247e2b95a95e36d494c1d64c4f3f62d50ccbf7e` |
| — | — | — | `walk_check.json` |  | 10634 | `6d3f252352dd168e02ca0e64a29e06a4903d6597bbb2d7053a88f959f615aef6` |

## 原图（不在仓库里）

Flow 原图都不放进仓库，只在这里留文件名和 sha256，原件暂存在 Flow 图片线的 box 上。`make_batch2.py` 读原图时用的是 `I-1xx.jpg` 这个短名，内容和下表同 id 的文件字节相同。柜台试图 cand01 的原图见 `../bg_counter_cand01.md`。

| id | 原图文件名（仓库里已删） | 尺寸 | 字节 | sha256 |
|---|---|---|---|---|
| I-101 | `I-101_bg_counter_day_original.jpg` | 1376×768 | 542149 | `7833eed85a9ee8f4521f24350ce7a15253ebcf2daa4708aeebdcf6793b50f022` |
| I-102（已不用：另一间屋子） | `I-102_bg_counter_dusk_original.jpg` | 1376×768 | 493128 | `844b3032dab649a2952f42b0f10a922093993c5f37a00ec0fa2b0bf1418231ac` |
| I-103（已不用：另一间屋子） | `I-103_bg_counter_night_original.jpg` | 1376×768 | 433313 | `04e43587d8898164d5b3e3cf6023f37a1fb738f21bd0fe632ade683b4e403156` |
| I-104 | `I-104_portrait_linsao_original.jpg` | 896×1200 | 432459 | `d60812f98f7736d45d0e4a90aa963b952cad1ceeaab813a4a3c902b5ddc07cb8` |
| I-105 | `I-105_portrait_suanming_original.jpg` | 896×1200 | 529331 | `3515f7e2c8665143cc96cc1ce42c19c4f6b0ce0aa5f11b8675e0a21048165636` |
| I-106 | `I-106_portrait_postman_original.jpg` | 896×1200 | 444554 | `ab2ed0c0f978589252dbd3f0bc623093bd0e829936288c3511c71f365a3b6dfb` |
| I-107 | `I-107_walk_ex_newsboy_original.jpg` | 768×1376 | 789416 | `6cfbbc895099a2db9c21caaa5872de44bd5134f2434219b7743a78ddbdf455e7` |
| I-108 | `I-108_walk_ex_porter_original.jpg` | 768×1376 | 926545 | `875d7eba50421b1b428e436dce6068c03b7ec2f25cc2bca71f5ccb5bccf688ff` |
| I-109 | `I-109_walk_stranger_peddler_original.jpg` | 768×1376 | 765364 | `da995c3ed17b5e4ba19f69306a914f69c343b4c3ff4d85d37c41d2e4db2121f2` |
| I-110 | `I-110_item_jewelry_hairpin_original.jpg` | 1024×1024 | 444927 | `08810a278d7e0b5a24ed1cf8723eed44e8fe2a7ba15582c2b703ea226426a075` |
| I-111 | `I-111_item_utensils_clock_original.jpg` | 1024×1024 | 518686 | `0f7c4644f6aeb0275ac11ebfd58ef07df4af79aa9e33f917891cce854cdb6007` |
| I-112 | `I-112_item_jewelry_jade_original.jpg` | 1024×1024 | 534208 | `dc56339f823cc50fb8056efb5e526a4ffdbd677336dc4e401041bb134153fe45` |
| I-113 | `I-113_frame_person_original.jpg` | 896×1200 | 444085 | `da00d1256b1bdc058b0a38a9eac8377c26f87c6cfbb8862a9716de6859c25603` |
| I-114 | `I-114_frame_gold_original.jpg` | 896×1200 | 552327 | `19b6511ce9cf1b380257c8938df602b20a3a90c7116de91497ac638003161ae2` |
| I-115 | `I-115_frame_event_original.jpg` | 896×1200 | 443279 | `b34807415432c327769b1606b9f82d564d39402f9908b8e23eb6fff2aa6298a7` |
| I-116 | `I-116_illus_es_shopfront_original.jpg` | 1200×896 | 412343 | `7966dbdb4e6d102ec884cda5c1f4a4d4c4d7a10d54c3da5fe98daafd3709831c` |
| I-117 | `I-117_illus_ev_any_fortune_teller_original.jpg` | 1200×896 | 387782 | `922aaf789f6a57a7d660c14499413cf26d65df89424a2a362e917c27082fac7a` |
| I-118 | `I-118_illus_nt_family_dinner_original.jpg` | 1200×896 | 391212 | `d1333af8efb20dd9e272213b22b8d032eb8faf0be6ba3c708c2ebbd81ff2b5ef` |

## 行走图自查（§12.5：64×128，一帧 16×32，4 行 = 朝下 / 朝左 / 朝右 / 朝上，4 列 = 站 / 迈左脚 / 站 / 迈右脚，脚点 (8, 30)）

`walk_check.py` 按这个帧表把每张切成 16 帧，逐帧查连通块数、外框、脚底行和贴不贴格子边，再比同一行各帧之间有多少像素不同（结果在 `walk_check.json`）。然后按 #196 要的做法试切：只取朝下第一帧 (0, 0, 16, 32)，按门口 ×8（场景坐标里是 ×2，32×64）贴到白天柜台的 `door` 站位 (144, 36, 32, 64)，三张并排导出 `walk_door_slice_mock.png`（×2）。牌桌代码还在等 #196 修，所以这是按 `card_stage.gd` 的站位和倍数在脚本里模拟的，不是真引擎截图。

| id | 尺寸 / 帧表 | 每帧几个人 | 脚底行 | 走路循环有没有动作差别（同一行：站 vs 迈左 / 站 vs 站 / 站 vs 迈右，不同像素数） | 结论 |
|---|---|---|---|---|---|
| I-107 报童 | 64×128，4×4 | 16 帧都是 1 个连通块，不贴格子边 | 全是 y=30 | 朝下 152 / 38 / 163，朝左 158 / 18 / 166，朝右 156 / 25 / 151，朝上 114 / 84 / 129 | 通过：一帧一个人，迈步帧和站立帧差别明显 |
| I-108 挑夫 | 64×128，4×4 | 9 帧有 2–3 个连通块，16 帧都贴到格子左右边 | 全是 y=30 | 朝下 73 / 79 / 117，朝左 100 / 28 / 128，朝右 112 / 32 / 108，朝上 87 / 36 / 113 | **不通过**：扁担比 16 px 宽，被格子切断，切一帧时会带出断开的扁担头。建议不选这张，或换成不挑扁担的群演重出 |
| I-109 货郎 | 64×128，4×4 | 16 帧都是 1 个连通块，不贴格子边 | 全是 y=30 | 朝下 108 / 64 / 161，朝左 185 / 80 / 201，朝右 138 / 58 / 164，朝上 163 / 20 / 156 | 通过 |

另外两点：朝左一行是把 Flow 画的第 2 行（朝右）水平镜像来的，不是另画的；两张“站”帧之间也有 18–84 px 的差别，因为 Flow 每格单独画，站姿不完全一样，循环播放时会轻微抖动。挑定风格后正式生产时，建议站帧统一用同一张。

## 质量备注（供挑选）

- **I-101** `bg.counter.day`：构图最接近：门洞两扇门开着，正中能看到白天的街。两侧墙有一点透视，墙上的告示里有伪字（规矩允许）。
- **黄昏 / 夜里**：现在是 I-101 换光（第三次返工的版本：灯光是有序抖动渐变，见“第三次返工”一节）。原来的 I-102、I-103 是另外两间屋子，已不用。
- **I-104** `portrait.linsao`：林嫂：五官清楚，靛蓝衣服，可以用。
- **I-105** `portrait.suanming`：算命先生：墨镜、签筒都看得出，可以用。
- **I-106** `portrait.postman`：邮差：绿制服 + 斜挎带，可以用。不过制服绿不在色板里，量化后变成 jade。
- **I-107** `walk.ex_newsboy`：报童：4×4 网格完整，16×32 下还认得出，最能用。
- **I-108** `walk.ex_porter`：挑夫：扁担太宽，只能按宽度缩到约 16×24，箩筐糊成一片。16×32 下不实用；试切一帧也不通过（见行走图自查）。
- **I-109** `walk.stranger_peddler`：货郎：网格完整，斗笠、背箱读得出，可以用。
- **I-110** `item.jewelry.hairpin`：金簪：清楚，可以用。
- **I-111** `item.utensils.clock`：座钟：清楚，表盘没有数字，可以用。
- **I-112** `item.jewelry.jade`：玉璧：清楚，红绳也看得出，可以用。
- **I-113** `frame.person`：人物牌框：边是平纹，满足九宫格（四条边中段 100% 重复），但很素。原图比例 0.687，压成 36:50 时有轻微拉伸。
- **I-114** `frame.gold`：金框：最好认，但角花约 9 px，超出九宫格 6 px 的角块，拉伸时角花会被切断；边上还有亮带不均。要么手修，要么换图。
- **I-115** `frame.event`：事件牌框：角章在 6 px 以内，但边上有木纹条，不是纯平纹，九宫格拉伸后会有条纹。
- **I-116** `illus.es.shopfront`：铺面：主体清楚，但这是像素画，不是 §5 要的水墨风。
- **I-117** `illus.ev.any.fortune_teller`：算命摊：主体偏小，64×48 下细节少。
- **I-118** `illus.nt.family_dinner`：家宴：最有情绪，三人背影 + 灯，可以用。

## 提示词

每条都是：主体提示词 + 共用风格后缀 + 共用负面词。

**共用风格后缀**：`16-bit pixel art, crisp hard pixel edges, flat color fills with one shadow tone, dark ink outlines, no gradients, no anti-aliasing. Single warm oil-lamp light from upper left, shadows to lower right. Limited palette only: #f4e2b0 #d9c49a #1f1712 #3a2a1e #5a3f2a #ffd25a #b0262a #a07a2c #2f6b5a #2f4670 #9aa4aa.`

**共用负面词**：`photorealistic, 3D render, gradients, glow, bloom, blur, anti-aliasing, lens flare, readable text, letters, numbers, watermark, signature, logo, modern objects, isometric, perspective tilt, cropped subject, weapons, blood, injury`

- **I-101**（16:9）：Front-facing flat view from behind a 1930s Chinese pawnshop counter. Back wall fills top 56%. Open double-door doorway exactly centered, spanning 35%–65% of width, top near the top edge, bottom resting on the counter line; daylit street visible through it, empty. Long dark wooden counter top from 56% to 83% height, plain panels below. Lamp on left counter end; ledger and abacus at left; center of counter clear. Daytime.
- **I-102**（16:9）：Same composition as day: centered doorway spanning 35%–65% width, bottom on the counter line at 56% height; counter top 56%–83%; plain panels below. Dusk: doorway shows amber evening street, lamp lit, warmer, longer shadows to lower right. Empty doorway, clear counter center.
- **I-103**（16:9）：Same composition: centered doorway spanning 35%–65% width, bottom on the counter line at 56% height; counter top 56%–83%; plain panels below. Night: doorway is deep indigo with door half shut, oil lamp at upper left the only light, walls fall into ink-dark shadow at lower right. Empty doorway, clear counter center.
- **I-104**（3:4）：Bust portrait of Lin Sao, a thin working-class Chinese woman in her thirties, 1938, hair in a low bun, faded indigo cotton jacket with cloth buttons, worried but composed face, front view, shoulders up, centered. Face drawn in paper tone with ink lines. Plain flat old-paper background.
- **I-105**（3:4）：Bust portrait of an old Chinese street fortune teller, 1930s, round dark glasses, thin grey goatee, black skullcap, worn grey long gown, holding a small bamboo fortune-stick tube at chest, calm sly smile, front view, centered. Plain flat old-paper background.
- **I-106**（3:4）：Bust portrait of a 1930s Chinese postman, young man, green uniform jacket with brass buttons, peaked cap, leather mail satchel strap across chest, friendly face, front view, shoulders up, centered. Plain flat old-paper background.
- **I-107**（9:16）：Sprite sheet of a 1930s Chinese newsboy: one character drawn in a 4 rows × 4 columns grid of equal cells. Rows from top: facing down, facing left, facing right, facing up. Columns: stand, left foot forward, stand, right foot forward. Small boy, flat cap, short jacket, folded newspapers under one arm. Full body, feet at the bottom of each cell, same size in every cell. Solid flat #00ff00 background, no grid lines.
- **I-108**（9:16）：Sprite sheet, 4×4 grid of equal cells, same character. Rows: down, left, right, up. Columns: stand, left step, stand, right step. A 1930s Chinese dock porter, sturdy man, short sleeveless cotton top, rolled trousers, straw sandals, towel over shoulder, carrying pole. Full body, feet at cell bottom. Solid flat #00ff00 background, no grid lines.
- **I-109**（9:16）：Sprite sheet, 4×4 grid of equal cells, same character. Rows: down, left, right, up. Columns: stand, left step, stand, right step. A 1930s Chinese traveling peddler, middle-aged man, wide straw hat, patched grey jacket, small wooden goods box on his back. Full body, feet at cell bottom. Solid flat #00ff00 background, no grid lines.
- **I-110**（1:1）：Single object icon: an old Chinese gold hairpin with a small plum-blossom head, lying diagonally, slightly worn, one tiny repaired seam. Centered, fills about 80% of the frame, top-down view. Solid flat #00ff00 background, no shadow on the background.
- **I-111**（1:1）：Single object icon: a 1930s wooden mantel clock with a round paper-white dial, brass bezel, dark wood case, hands without numbers. Front view, centered, fills about 80% of the frame. Solid flat #00ff00 background.
- **I-112**（1:1）：Single object icon: a carved jade pendant, round bi disc with a cloud pattern, jade green, a red silk cord loop on top. Front view, centered, fills about 80% of the frame. Solid flat #00ff00 background.
- **I-113**（3:4）：Empty playing-card border for a pixel-art card game, portrait rectangle, proportion 36:50. Thin wooden frame in brown #8c6a44 with dark ink outline; small identical carved corner ornaments only in the four corners; the four edges between the corners are plain uniform straight bands. Center fully empty, solid flat #00ff00. Nothing outside the card, flat #00ff00.
- **I-114**（3:4）：Empty premium card border, portrait rectangle 36:50. Gold frame #d9a520 with a bright #ffd25a inner highlight edge and ink outline; ornate cloud-scroll corner pieces only in the four corners; edges between corners are plain uniform straight bands. Center fully empty, solid flat #00ff00. Background flat #00ff00.
- **I-115**（3:4）：Empty card border, portrait rectangle 36:50. Dark wood frame #5a3f2a, ink outline, small square seal-red #b0262a corner stamps only in the four corners; edges between corners are plain uniform straight bands. Center fully empty, solid flat #00ff00. Background flat #00ff00.
- **I-116**（4:3）：Small ink-wash vignette on aged paper: the front of a 1930s Chinese pawnshop, two-story wooden facade, big blank signboard, one large symbol-free pawn banner, closed shutters, a stone step. Simple, centered, generous paper margin, one subject only. Background plain #f4e2b0 paper.
- **I-117**（4:3）：Small ink-wash vignette on aged paper: a street fortune teller's table, a blank cloth banner on a pole, a bamboo tube of fortune sticks, a small brush and inkstone, a stool. No people. Simple, centered, generous paper margin. Background plain #f4e2b0 paper.
- **I-118**（4:3）：Small ink-wash vignette on aged paper: a modest family dinner seen from the side, a small square wooden table with rice bowls, one vegetable dish, chopsticks, a teapot, an oil lamp glowing upper left; three simple seated figures from behind. Warm, quiet, centered, generous paper margin. Background plain #f4e2b0 paper.
