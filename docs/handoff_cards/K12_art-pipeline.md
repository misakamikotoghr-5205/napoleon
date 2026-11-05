# K12 `art-pipeline` · 占位美术生成器、美术清单、给画师的美术规格；画面美术类别

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K12 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K12: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 12**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | `data/cards/art/manifest.json` 初版（109 个 id：牌框 16、头像 22（21 张旧立绘 `legacy: true` + 待生成的 `portrait.suanming`）、插图 30、物品 28（17 张旧图 `legacy: true` + 11 个旧版程序化绘制、没有图的变体）、图标 8、轮盘面 4、背景 1；`legacy` 以外的占位文件都还没生成）；`CardArt`（C02，W0 版能用：先找 `human`，再找 `placeholder`，再用 `art/_placeholder/cards/missing.png`）；`art/_placeholder/.gitkeep` | W0（已完成） |
| K01–K11、K16 | 数据里的美术 id（`art` 字段、`persons` 块的 `portrait`、`stage.json` 的 `bg`、轮盘的 `art`、扇区的 `icon.ws.*`、新模板的 `item.<cat>.<variant>`）——**他们合入一批，你补一批占位** | W1–W2（滚动） |
| C01–C16 | 界面代码里直接用的美术 id（已知：`bg.title` `bg.street` `bg.prison` `frame.guide_bubble` `icon.obj.*` `portrait.suanming` `icon.coin.head` `icon.coin.tail` `icon.demand.<kind>` `icon.seal`……）；各 C 卡的回报栏“缺的美术 id”、`[content]` issue | W1–W2（滚动） |
| Claude | CI 里装 Pillow（你开 `[shared] K12→Claude` issue；装上之前，字节确定性测试在没有 Pillow 的环境里跳过并打印 `NOTE`） | W1 |

- **波次**：W1 开发并合入生成器、清单与规格；W2 跟着数据合入补齐（**W2 完成条件“审核只剩正文/美术未写”要求清单覆盖所有引用**）。

## 分支

`cards/K12-art-pipeline`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

让开发版从第一天起每个美术 id 都有图可看——但**全是明确标记、导出时排除的占位**（红线 1：Steam 版不能有 AI 美术）：一个确定性的占位图生成器（每张图左上角打“稿”角标）、完整的美术清单（id → 底图尺寸、9 宫格边距、正式路径、占位路径）、给画师 A/外包的美术规格 `ART_SPEC.md`。新手指引要用的图（教的人头像、物件图标、气泡框）一张不缺。

## 必读

1. 合同 §0（红线 1）、§1.2（**像素插图整数倍放大、`TEXTURE_FILTER_NEAREST`**；底图尺寸表：头像 48×64、小插图 64×48、物品 64×64、牌框 9 宫格 36×50 边距 6、背景 320×180、轮盘面 120×120、图标 16×16 / 24×24；新手指引：气泡、教的人）、§2.2、§2.4（配色键：界面只用键；`palette.json` 只有 A 写，W0 的 `palette.dev.json` 是开发初值）、§3.4 K12、§4.8（美术清单格式与 id 类别；`legacy: true`；CardArt 的查找顺序）、§7.8（`CardArt` 的四个静态函数）、§7.10.5 / §7.10.7 第 5 条（教的人头像：人物 `portrait.<person>`、物件 `icon.obj.<名>`；气泡框）、**§11（来源与审核：§11.2 占位规则——每张左上角带“稿”角标、`art/_placeholder/cards/manifest.json` 记生成器名和种子、导出排除；§11.3 `ASSET_PROVENANCE.csv` 的列；§11.4 第 3、4 项）**、§12.4（占位总量 ≤ 20 MB）、§12.7（Python 工具：K12 可以用 Pillow）、**§4.8 的“画面用的美术”（1.3 新）、§7.11.2（画面坐标，1.3 新）、§4.7.24（演出块，1.3 新）**。
2. `docs/cards/DESIGN_cards.md` §七“美术”（牌框 8–10 种 + 金色；头像约 30；小插图约 60，可以做成统一的水墨小图；~~场景：柜台、街头、牢房、每关开场 3 张~~（10-13 作废，DESIGN 1.3 改写：柜台白天/黄昏/夜里 3 张、街头牢房城隍庙码头集市等各 1 张、每关开场 3 张、标题 1 张；另有少量行走图、柜台工具与道具约 30 件、对话框/头像框/标签图标，见 §七“美术”与 §九.6））、§九.6（画面与对话，1.3 新）。
3. 现有工具（只读、可以 import 复用）：`tools/art/pixlib.py`（调色板 Canvas 做法；它读 `data/palette.json`）、`tools/art/gen_*.py`（旧生成器的写法）；现有旧图 `art/portraits/*.png`（48×64）、`art/items/*.png`（64×64）。
4. `scripts/cards/ui/card/card_art.gd`（CardArt 怎么读清单）、`data/cards/art/manifest.json`（W0 初版）、`data/cards/theme/palette.dev.json`（开发配色键）。

## 要做的事

### A. 生成器 `tools/cards/art/gen_placeholders.py`
- [ ] Python 3 + Pillow（其余只用标准库）；命令行：`python3 tools/cards/art/gen_placeholders.py [--out=<根目录，默认仓库根>] [--only=<id 前缀>] [--check]`。
- [ ] **确定性**：同样的输入两次运行**字节相同**——每张图的随机只用 `random.Random(<sha256(art_id) 的整数>)`（不用全局 `random`、不读时间）；PNG 用固定参数保存（不写时间戳、不带色彩配置文件）；文件遍历先排序。
- [ ] **“稿”角标**：每张图左上角一个小角标（写死在生成器里的点阵字形，不依赖系统字体渲染——不同机器的 FreeType 会让字节不同）。
- [ ] 按类别生成到 `art/_placeholder/cards/<类别>/<名>.png`，尺寸 = 清单的 `base`：
  - 牌框 `frame.<类型>`（`person self contact event fate big_fate demand life news kept estate night street prison` 14 种 + `gold` = 合同说的 15 种，另有新手指引的 `frame.guide_bubble`）：36×50、9 宫格边距 6；金色牌框一眼能认（亮边、角花）。
  - 头像 `portrait.<人物>`：没有旧立绘的（新面孔 `nf19xx*`、新过路客 `stranger_waixiang` `stranger_boatman` `stranger_student` `stranger_widow`、**算命先生 `suanming`**）生成 48×64 剪影（按人物 id 的种子变化发型、衣领）；有旧立绘的保持清单里 `legacy: true` 指向 `art/portraits/<id>.png`（旧图按占位对待）。
  - 小插图 `illus.<牌 id 或类别>`：64×48，按牌的类型画类别小图标 + 水墨底纹。
  - 物品 `item.<cat>.<variant>`：64×64——新模板（K11 的 `templates_extra.json`）；旧模板里 11 个没有图的变体（`sprite` 为空、旧版程序化画的：`art.calligraphy` `art.landscape` `clothing.*` 四个、`jewelry.bangle` `jewelry.jade` `utensils.bowl` `utensils.clock` `utensils.tinpot`）；有旧图的 17 个保持 `legacy: true`。
  - 背景 `bg.<名>`：320×180（`bg.stage.1938` `bg.stage.1939` `bg.stage.1940` `bg.title` `bg.street` `bg.prison`，以及 C 任务要的）。（10-13：1.3 起 `bg.title` `bg.street` 和柜台三张等用旧图 `legacy: true`，只有 `bg.stage.<年>` `bg.prison` `bg.temple` 由你生成；画面的全部背景见下方“10-13 变更二”。）
  - 轮盘面 `wheel.<kind>`：120×120（四种：`month` `big` `fair` `gamble`；只画盘面底纹，扇区由 C06 用代码画）。
  - 图标 `icon.<名>`：16×16 或 24×24——**新手指引的物件图标 `icon.obj.notice` `icon.obj.almanac` `icon.obj.brother_ledger`（24×24）**、扇区图标 `icon.ws.<slug>`、`icon.coin.head` `icon.coin.tail`、`icon.demand.<money|goods|people|info>`、`icon.seal` 等。
  - 缺图方块 `art/_placeholder/cards/missing.png`。
- [ ] 写 `art/_placeholder/cards/manifest.json`：`{"generator": "tools/cards/art/gen_placeholders.py", "version": n, "seed_rule": "sha256(art_id)", "files": {"<路径>": "<sha256>"}}`（§11.2）。
- [ ] 颜色：可以用 `tools/art/pixlib.py` 的调色板，或 `palette.dev.json` 的键对应的颜色；不读 `palette.json`（那是 A 的）。
- [ ] 占位总量 ≤ 20 MB（`--check` 时报告总量）。

### B. 清单 `data/cards/art/manifest.json`（W0 起头，你接手）
- [ ] 每个 id：`base`、`human`（`art/cards/<类别>/<名>.png`，A/外包交付的路径）、`placeholder`（`art/_placeholder/cards/<类别>/<名>.png` 或旧图）、牌框加 `nine: [6, 6, 6, 6]`、旧图加 `legacy: true`；`_meta.owner` 保持 `K12`。
- [ ] 覆盖：数据里引用的全部 id + 界面代码里用到的全部 id + 新手指引要的（教的人的头像：`brother` `zhouma` `hu2` `suanming` `postman`；`icon.obj.*`；`frame.guide_bubble`）。

### C. 覆盖检查 `tools/cards/art/check_manifest.py`（只用标准库）
- [ ] 扫描：`data/cards/**`（不含 `_examples/`、`text/`）里的 `art` 字段、`persons.*.portrait`、`stage.json` 的 `bg`、轮盘/扇区的 `art`、`templates_extra.json` 的新变体（→ `item.<cat>.<variant>`）、每种牌类型的 `frame.<类型>` 与 `frame.gold`；`scripts/cards/**/*.gd` 里形如 `"bg.…"` `"icon.…"` `"frame.…"` `"wheel.…"` `"portrait.…"` `"illus.…"` `"item.…"` 的字符串字面量（1.3：再加演出块里的美术 id 与 `"prop.…"` `"walk.…"` `"stage.…"` 字面量，见下方“10-13 变更二”）。
- [ ] 报告：引用了但清单里没有的 id；清单里 `placeholder` 指向的文件不存在的；尺寸和 `base` 不符的（读 PNG 头，标准库能做）；占位总量。参数 `--refs=error|note`（默认 `error`）：清单内部的问题（文件不存在、尺寸不符、超 20 MB）永远退出码 1；**“数据或界面引用了、清单里还没有”在 `--refs=note` 时只打印不失败**——清单里的 CI 测试用 `note`（别的线合入新美术 id 时不能让所有人的 CI 变红），你的 PR 和 W2 完成检查用 `error`。
- [ ] 输出一行一个：`ART MISSING <id> (referenced by <文件>)`、`ART NOFILE <id> <路径>`、`ART SIZE <id> <实际> != <base>`，最后 `ART CHECK OK <n> ids, <bytes> bytes` 或 `ART CHECK FAILED …`。

### D. `docs/cards/ART_SPEC.md`（给 A / 外包）
- [ ] 每种图：尺寸、整数倍显示（×2 / ×4 / ×8 的场合）、9 宫格边距、调色板（列 §2.4 的配色键与开发初值；正式值由 A 在 `palette.json` 定）、光源、分层、导出格式（PNG、8 位 RGBA、无色彩配置文件）、文件名（`art/cards/<类别>/<名>.png`，和清单的 `human` 一致）、交付清单（按清单 id 列）、来源登记（`legal/ASSET_PROVENANCE.csv` 每行的列：`path, sha256, author, method, source_file, license, license_file, order_no, no_ai_proof, date, reviewer`；分层源文件不进发行路径）。
- [ ] 写明：**代码画出来的小游戏画面**（吹银元的波形、秤杆、碎片描边）算代码、不算美术，但只许用调色板键（§3.4 K12）；新手指引的气泡框、物件图标、教的人头像的规格。
- [ ] 写明占位与正式图的关系：占位只在开发版；发行版缺正式图 = 审核失败（§11.4 第 3 项）。

### E. 测试（Python 的测试用 GDScript 包装，因为 `run_card_tests.sh` 只跑 Godot 脚本）
- [ ] `scripts/tests/cards/K12/test_art_tools.gd`：用 `OS.execute` 依次跑：①`python3 tools/cards/art/check_manifest.py --refs=note`（必须 0 退出；输出里的 `ART MISSING` 行原样转成 `NOTE:` 打印）；②若 `python3 -c "import PIL"` 成功：把生成器跑两遍到 `t.user_dir()` 下的两个目录，逐文件比字节（必须全同）；没有 Pillow → 打印 `NOTE: Pillow not installed; generator determinism skipped` 并继续（不算失败，Claude 合并前在有 Pillow 的环境复跑）。找不到 `python3` 时试 `python`。
- [ ] `scripts/tests/cards/K12/test_art_load.gd`：清单里每个 id 都能 `CardArt.texture(id)` 拿到非空贴图，且 `CardArt.base_size(id)` 等于贴图尺寸；新手指引的 `icon.obj.notice` `icon.obj.almanac` `icon.obj.brother_ledger` `frame.guide_bubble` `portrait.suanming` 不是缺图方块。

### F. 占位音频（可选）
- [ ] `audio/_placeholder/**` 归你，但只在 C13/C16 开 `[content]` issue 要占位音频时才做（标准库 `wave` 合成、确定性）；C13 的吹银元用运行时合成，不需要你。

### G. Godot 的 `.import`
- [ ] 生成 PNG 后跑 `$GODOT --headless --path . --import`，把 `art/_placeholder/**` 下新生成的 `.import` 一起提交（它们归你）；以后重跑生成器**不删** `.import`（重建会换 uid，别人的场景会对不上）。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **清单**：加合同 §4.8 “画面用的美术”表里的全部 id：三张柜台背景（`bg.counter.day` `bg.counter.dusk` `bg.counter.night`）、各场景背景（`bg.candle` `bg.prison` `bg.street` `bg.market` `bg.temple` `bg.dock` `bg.teahouse` `bg.ricehall` `bg.pharmacy` `bg.post` `bg.baogong`，以及 `bg.title` `bg.stage.<年>`）、群演的 `portrait.ex_*` 与 `walk.ex_*`（九个，`CardIds.EXTRAS`）、主要人物的 `walk.*`（有旧行走图的：`brother chen guanjia li linsao ma postman ruhua sunyoung wangshan wu xiaoding zhang zhao zhouma stranger_collector stranger_fence stranger_peddler stranger_refugee`；`walk.hu2` 借 `stranger_collector`、`walk.suanming` 借 `passerby_3`）、全部 `prop.*`、`frame.dialog` `frame.hero` `frame.guide_note`、8 个 `icon.tab.*`（`contacts demands dossier rules shelf tickets estates settings`）、`icon.coin.head` `icon.coin.tail`。有旧图的写 `legacy: true` 指向旧图（路径照合同那张表：`art/bg/*.png`、`art/town/shops/*_bg.png`、`art/town/chars/*.png`、`art/tools/*.png`（`prop.cashbox` = `pawnbox.png`）、`art/town/props/*.png`、`art/town/ui/dialog_frame.png`、`art/ui/stamp.png`、`art/town/ui/coin_icon.png`）；`stage.*` 不用建（界面回退到 `portrait.*`）。旧图的尺寸都已经和表里的底图一致（背景 320×180、行走图 64×128、工具按表），`base` 照表写。
- [ ] **生成器**：生成表里标“K12 生成”的占位：`bg.prison`（从 `art/bg/candle.png` 调冷色）、`bg.temple`（从 `market_bg.png` 压暖 + 灯笼杆）、`walk.ex_soldier`（`patrol.png` 调色）、`portrait.ex_*`（行走图朝下第一帧 ×2 贴在 48×64 的 (8,0)，做法照 `docs/cards/prototype/art_map.md` §0 第 3 条）、`prop.notice` 24×32、`prop.ticket` 24×32、`prop.letter` 24×32、`frame.hero` 27×36、`frame.guide_note` 24×24、`icon.tab.*` 24×24；派生图照样左上角打“稿”、确定性（`sha256(art_id)` 种子）；读旧图用 Pillow。`bg.stage.<年>` 照旧生成。
- [ ] **check_manifest.py**：多扫演出块：`props[].art`、`set`（不是 `counter` 的 → `bg.<set>`；`counter` → 三张柜台背景）、`cast[].who` 站 `customer`/`companion` → `portrait.<who>`、群演站门口/街上 → `walk.<who>`；界面代码里的 `"prop.…"` `"walk.…"` `"stage.…"` 字面量也扫。
- [ ] **ART_SPEC.md**：加“画面”一章：320×180 的构图与坐标（直接抄合同 §7.11.2 的场景坐标）、三张柜台背景必须和旧图同构图、站位与放大倍数、行走图的帧排法（16×32、4 行 × 4 列、脚点 (8,30)）、道具底图尺寸表、对话框/英雄头像/批注纸的九宫格、标签图标；首发必需的交付清单（合同表里打 ✓ 的）。
- 写的时候对的数（合同 §1.2、§4.8、§7.11.2）：
  - 放大倍数：背景、立绘、工具、道具 ×4；柜台上的物品 `item.*` ×2；门口的行走图 ×8、街上的 ×4；对话框框 ×2、英雄头像框 ×4、批注纸 ×2；标签图标 ×1。
  - 九宫格：`frame.dialog` 48×48 边距 7；`frame.hero` 27×36 边距 6；`frame.guide_note` 24×24 边距 6（清单里写 `nine`）。
  - 行走图 `walk.<person>` 64×128：16×32 一帧，4 行 = 朝下/左/右/上，4 列 = 站、迈左脚、站、迈右脚，脚点 (8,30)。
  - 场景坐标（320×180）：墙 0,0,320,100；门洞 112,8,96,92；柜台面 0,100,320,50；桌下 0,150,320,30；客人站位 136,36,48,64；柜台一侧 236,36,48,64；门口 144,36,32,64（左右 128 / 160）；柜上的东西 116,104,88,42。
  - 场景里代码画的效果（雨、火光、烟、夜色、封条、影子、灯光）算代码、不算美术，只用配色键（`rain` `fire_glow` `smoke` `night_tint` `night_dark` `seal_paper` `silhouette` `lamp_glow` …，合同 §2.4 的“画面（1.3）”一行）——ART_SPEC 里写明。

**新增 / 作废的交付**

- 新增：上面的清单条目、占位图与 `.import`、`check_manifest.py` 的演出块扫描、ART_SPEC 的“画面”一章。
- 作废：上文 A 节“背景”那一条里 `bg.title` `bg.street` 由生成器出的说法——1.3 起它们用旧图（`legacy: true`），只有 `bg.prison` `bg.temple` `bg.stage.<年>` 由你生成。

**锚点、界面事件、要证明的步骤**

- 工具任务照旧不登记锚点、不发界面事件。新手指引里的“教的人”1.3 起在画面里开口：人物站到柜台一侧（`GUIDE_TEACHER`，用 `stage.<人物>`，没有就 `portrait.<人物>` ×4），物件用一张批注纸（`frame.guide_note` 九宫格 + `icon.obj.<名>`）——所以上文“新手指引”表加了 `frame.guide_note` 一行。

**测试与截图**

- `K12_art_load` 加：新 id 都能 `CardArt.texture()`、`base_size` 对；三张柜台背景 320×180；`frame.guide_note` 24×24 带 `nine`、不是缺图方块。
- `K12_art_tools` 照旧（`check_manifest.py --refs=note` 0 退出；有 Pillow 时两次生成字节相同——新派生图也在里面）。
- 截图：占位总览拼图加一行“画面”（三张柜台背景、群演头像与行走图第一帧、道具、对话框框、头像框、批注纸、标签图标）。

**已经做了的哪些还有效**

- 生成器、清单、检查工具、规格全部有效；新类别另开 PR。

**日期**：新类别的 PR 目标 **10-27**（1938 用到的先交：三张柜台背景、`bg.candle` `bg.prison` `bg.street` `bg.market`、群演、柜台上 9 个热点的道具、`frame.dialog` `frame.hero` `frame.guide_note`、`icon.tab.*`）。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `tools/cards/art/**`、`art/_placeholder/**`、`audio/_placeholder/**`、`data/cards/art/manifest.json`、`docs/cards/ART_SPEC.md`
- 默认拥有：`scripts/tests/cards/K12/**`、`scripts/tests/cards/suites/K12.txt`、`data/cards/tags/K12.json`、`data/cards/ui_keys/K12.json`

## 不能做的事

1. **不画、不放正式美术**：不碰 `art/cards/**`（A/外包）、`audio/cards/**`（B）、`data/cards/theme/palette.json`（A）、`legal/**`、`fonts/**`。占位图**只**放 `art/_placeholder/**`，每张都带“稿”角标。
2. 不改旧图（`art/portraits/**`、`art/items/**` 等归 Claude，只读、可以缩放后输出到占位目录）；不改 `tools/art/**`（只 import）。
3. 不改别人的数据和代码（美术 id 由数据和界面的主人写；你只补清单和占位）；缺的 id 不在数据里乱加。
4. 生成器不联网、不用任何生成式模型或在线服务；只用 Pillow + 标准库；确定性。
5. 不往 `user://` 以外的地方写测试输出；测试不 sleep、不依赖墙钟。

## 接口

**用到**：清单格式（§4.8）；`CardArt`（`texture` `path` `is_placeholder` `base_size`）；数据里的美术 id。

**提供**：`data/cards/art/manifest.json`（C02 的 `CardArt` 读它；V12 strict 校验查 id 在不在里面；K15 的审核第 3 项按 `human` 路径查正式图）；占位图；`ART_SPEC.md`（A/外包）；`check_manifest.py`（K15 的审核可以调用）。

## 新手指引

- **锚点**：不登记（工具任务）。**first-time**：不发。
- **你支持的步骤**：所有步骤的“教的人”头像与物件图标、气泡框——

| 美术 id | 用在哪些步骤 |
|---|---|
| `portrait.brother` | `gd.m.*`、`gd.d1.*`、`gd.d2.*`、`gd.choice` |
| `icon.obj.brother_ledger` | `gd.slots` `gd.coins` `gd.fate` `gd.life` `gd.kept_*` 等（哥哥走后讲规矩的账簿批注） |
| `portrait.zhouma` | `gd.news` `gd.dossier` `gd.contact` `gd.tiers` |
| `portrait.hu2` | `gd.demand` `gd.demand_delay` `gd.demand_fail` |
| `portrait.suanming` | `gd.lot` `gd.cezi` |
| `portrait.postman` | `gd.mg.decode` |
| `icon.obj.notice` | `gd.market_day` `gd.weather` `gd.shop_closed` `gd.fair_wheel` `gd.currency` |
| `icon.obj.almanac` | `gd.almanac` |
| `frame.guide_bubble` | 每一步的气泡底框（C16） |
| `frame.guide_note` | 物件（`obj.notice` `obj.almanac` `obj.brother_ledger`）当教的人时的批注纸（C16，1.3） |

- **指引验收（必须有测试）**：`test_art_load.gd` 断言上表每个 id 都在清单里、有占位文件、尺寸对（头像 48×64、物件图标 24×24、气泡框 36×50 带 `nine`、批注纸 `frame.guide_note` 24×24 带 `nine`）；`check_manifest.py` 对 `data/cards/guide/steps.json` 里出现的每个 `teacher`（人物 → `portrait.<id>`，物件 → `icon.<obj.名>`）也做覆盖检查。
- **截图**：PR 附一张占位总览拼图（生成器加 `--sheet=<文件>` 输出到仓库外，Pillow 拼），其中单独一行是“教的人”头像与物件图标、气泡框 ×4 放大。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K12.txt`：

```
# K12 占位美术管线（docs/handoff_cards/K12_art-pipeline.md）
K12_art_tools|res://scripts/tests/cards/K12/test_art_tools.gd|300|
K12_art_load|res://scripts/tests/cards/K12/test_art_load.gd|120|
```

**通过条件**（合同 §3.4 K12 验收）：
- [ ] 生成器两次运行**字节相同**（有 Pillow 的环境；PR 里贴本地运行结果）。
- [ ] `check_manifest.py`（默认 `--refs=error`）对**当前已合并的全部数据**与界面代码 0 缺失（命令行一条能跑；PR 里贴输出）。
- [ ] 占位总量 ≤ 20 MB（贴数字）。
- [ ] 每张占位图左上角有“稿”角标（拼图里看得见）；`art/_placeholder/cards/manifest.json` 记了生成器与种子规则。
- [ ] `tools/run_card_tests.sh` 全绿（含真数据 default 校验，`manifest.json` 的 `_meta.owner` 对）；`tools/run_legacy_smoke.sh` 全绿；无 `SCRIPT ERROR` `ERROR` `WARNING` `FAIL:`、无泄漏。

**怎么跑**：
```bash
python3 -m pip install pillow     # 本地
python3 tools/cards/art/gen_placeholders.py
python3 tools/cards/art/check_manifest.py
export GODOT=<你的 Godot 4.7>
$GODOT --headless --path . --import
CARDS_SUITES=K12 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```

## 交付

- **PR 标题** `[K12] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K12] 占位生成器、牌框与新手指引用图、覆盖检查`（先合：C02、C16 在等）；②`[K12] 美术规格 ART_SPEC.md`；③之后每批数据合入后 `[K12] 补齐 <哪几条线> 的占位`。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；`check_manifest.py` 的输出；两次生成的字节比较结果；占位总量；占位拼图（含“教的人”一行）；新增的美术 id 清单（按类别计数）；开过的 `[shared]`（CI 装 Pillow）；完成写“交付”。

## 审核（Claude 重点）

1. 越界：只动美术工具、占位目录、清单、规格；没碰 `art/cards/**`、`palette.json`、旧图。
2. 确定性：在有 Pillow 的环境跑两遍字节相同；没有 `random` 全局状态、没有时间。
3. 每张占位带“稿”角标；占位清单记了生成器与种子；总量 ≤ 20 MB。
4. 覆盖：数据 + 界面 + 新手指引要的 id 0 缺失。
5. `ART_SPEC.md` 写全尺寸、整数倍、调色板键、交付与来源登记；写明代码画的小游戏画面只用调色板键。
6. `.import` 一起提交、不重建 uid。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| `check_manifest.py` 输出 | |
| 字节确定性（两次运行比较） | |
| 占位总量 | |
| 美术 id 数（按类别） | |
| 占位拼图链接 | |
| 开的 issue（Pillow、缺的 id） | |
| 合同或数据缺口 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
