# K15 `audit-provenance` · 来源审核工具（Steam 免 AI 声明）

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K15 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K15: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 15**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | `tools/cards/audit/check_pr_paths.py`（**能用，已接进 CI 的必过检查**——改它不许改坏命令行）、`tools/cards/audit/audit.py`（“关着门”的桩：没做完的项一律报失败）、`tools/cards/audit/cjk_allowlist.json`（**归 Claude**，你只读）、`docs/cards/ownership.json`、`.github/workflows/cards.yml` | W0（已完成） |
| G01 | `validate_main.gd --mode=ship` 的完整 V27（W0 只做了牌的必填正文，其余“关着门”报错，TODO(G01)） | W1（你的审核第 2 项调用它） |
| K13 | `tools/cards/review/wording_lint.py`（第 6 项调用：`wording_lint.py <暂存目录>/data/cards/text --scope=text --fail-on=must`） | W1（并行） |
| K12 | `data/cards/art/manifest.json`（第 3 项按 `human` 路径查正式图）、`check_manifest.py`（可以调用） | W1（并行） |
| Claude | Steam 导出预设（`ship` 特性、主场景覆盖、排除列表）与 `tools/package_steam.sh`（会依次调你的 `stage_ship.py` → 校验 → `audit.py` → 从暂存目录导出 → 复查 `.pck`）；`cjk_allowlist.json` 的条目 | W1–W2 |
| A / B | `legal/human_authors.json`、`legal/ASSET_PROVENANCE.csv`、`data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`palette.json`——W3 才有；**你的工具对着自己造的夹具开发** | W3 |

- **波次**：W1 做全工具（每一项都能对夹具报错）；**W2：审核演练**——对当时的仓库跑一遍，预期失败项 = 还没写的正文和美术（这份清单就是给 A/B 的待写清单，§13.4 W2）；W3：A/B 补齐后 `audit.py` 0 违规才能出包。

## 分支

`cards/K15-audit-provenance`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

保证 Steam 版**不需要任何 AI 内容声明**：发行包里玩家看得到、听得到、读得到的每一样东西（正文、界面字、人物名、签诗、观察句、物品名、美术、配色、音频）都是人做的、有来源登记；所有 AI 的占位（brief、`art/_placeholder/**`、开发配色、例子、旧版内容）一样都进不了包。做四个工具：把要发行的文件拷进暂存目录并剥掉草稿字段的 `stage_ship.py`、逐项审核的 `audit.py`（任何一项不过就非零退出）、PR 路径检查 `check_pr_paths.py`（W0 已有，你接手增强）、给 A/B 的待写清单 `missing_text.py`。

## 必读

1. 合同 §0（红线 1、8）、§1.1（“一切可见文字来自 CardText，一切颜色来自 CardTheme，一切图来自 CardArt”）、§1.2（配色、音乐那两行）、**§2.2、§2.3（Steam 预设只含卡牌版、排除列表、白名单旧数据）**、§3.4 K15、§4.3（`brief` `_provenance`）、§4.5（正文覆盖层的路径、各类型必填字段、`_provenance` 格式 `^human:(A|B):\d{4}-\d{2}-\d{2}$`）、§4.8（美术清单、`legacy: true`）、§4.9（V27 ship 模式）、§4.10、§7.10.1 第 9 条与 §7.10.2（指引正文由 A 写：步骤 `say` `bubble`、规矩页 `title` `body`；F1 帮助 `c10.help.*`、设置里那一行由 B 写）、**§11 全章**（什么算玩家消费的内容、AI 能放占位的地方、人做的内容怎么登记、审核 10 项、PR 路径检查、出包流程）、§12.1（测试登记）、§12.7（**Python 工具只用标准库**）、§13.3、**§4.7.24（演出块，1.3 新）、§4.5 必填表新加的“带演出块的牌”一行**。
2. W0 代码：`tools/cards/audit/{audit.py,check_pr_paths.py,cjk_allowlist.json}`、`.github/workflows/cards.yml`、`scripts/cards/core/{validate_main.gd,card_validator.gd}`（V27 怎么报）、`scripts/cards/core/card_db.gd`（`CARD_DIRS`：真数据里哪些目录被当作牌读）、`export_presets.cfg`（`script_export_mode=2`：导出时 `.gd` 变成二进制 token、注释被剥掉，字符串字面量还在）、`tools/build_fonts.py`（字体子集与覆盖检查的做法——它依赖第三方 `fontTools`，你**不能**直接 import）。
3. `docs/cards/ownership.json`（`human_only`、各任务路径、`default_owned`）。

## 要做的事

### A. `tools/cards/audit/stage_ship.py`
- [ ] `stage_ship.py <暂存目录> [--src=<仓库根，默认本仓库>]`：把发行需要的文件拷到暂存目录（目录已存在先清空），**确定**（同输入同输出、文件按路径排序处理），最后打印 `STAGED <n> files, <bytes> bytes`。
- [ ] 拷什么：从 `scenes/cards/CardGame.tscn` 和 `project.godot` 的 autoload（`CardBus`）出发，**静态追依赖**（`.tscn`/`.tres` 的 `ext_resource` 路径、`.gd` 里 `preload`/`load` 的 `res://` 字符串字面量、`class_name` 引用到的脚本——用全仓库的 `class_name` 表解析），加上 `data/cards/**`（运行时按路径读的数据）、白名单旧数据 `data/town/item_templates.json` `data/cast.json`、字体、`project.godot`、`export_presets.cfg`，以及这些文件的 `.import` 旁注。
- [ ] 不拷（§2.3、§11.4 第 1 项）：`art/_placeholder/**` `audio/_placeholder/**` `data/cards/_examples/**` `data/cards/_dev/**` `data/cards/theme/palette.dev.json` `scripts/tests/**` `tools/**` `docs/**`；旧版目录 `scripts/town/**`、`scenes/` 下非卡牌场景、`data/town/**`（模板除外）、`data/codebook.json`、`art/{bg,portraits,tools,ui,town}/**`、`audio/music/**`；**以及合同 §2.3 列的 `data/cards/rules/wording.json`（K13 的措辞规则，开发用，中文在 `_` 键里）和 `data/cards/branch/**`（解放后分支，首发不读）**。
- [ ] 所有拷进去的 JSON 递归剥掉键 `brief` `_doc` `_provenance` `_test` 和 `_meta.brief`（§11.4 第 1 项；`_meta` 的其他键保留）；JSON 重新写出时保持键顺序、2 空格缩进、UTF-8。

### B. `tools/cards/audit/audit.py <暂存目录> [--report=<路径>] [--pck=<导出的 .pck>]`（§11.4 十项，**全部实现，任何一项不过就非零退出**；保持“关着门”：某项因为缺工具/缺文件没法查 = 失败，不是跳过）
- [ ] 1. 暂存目录里没有：任何 `brief` / `_doc` / `_provenance` / `_meta.brief` / `_test` 键；上面 A 节列的不该拷的路径。
- [ ] 2. 调 `$GODOT --headless --path <暂存目录> -s res://scripts/cards/core/validate_main.gd -- --mode=ship --name=audit_ship`（`GODOT` 环境变量或 `--godot=`）：退出码 0 且最后一行 `CARDS TEST PASS audit_ship`；把它的 `DATA ERROR` 行原样收进报告。
- [ ] 3. 暂存数据里每个被引用的美术 id（K12 清单）都解析到 `art/cards/**` 下存在的文件，且在 `legal/ASSET_PROVENANCE.csv` 有行、`sha256` 对得上、作者在 `legal/human_authors.json` 里、`method` 不是 AI；**没有 `legacy: true` 的引用**。
- [ ] 4. 暂存目录里每个图片、音频文件（`.png .jpg .webp .svg .ogg .wav .mp3`）都在 `ASSET_PROVENANCE.csv` 里（白名单），且 sha256 **不在** v0.4.2 旧素材的哈希黑名单里（黑名单由 `audit.py --build-legacy-hashes` 对 `art/{bg,items,portraits,tools,ui,town}/**`、`audio/music/**` 算出，存 `docs/cards/audit/legacy_hashes.json`，提交）。
- [ ] 5. **发行包里每一个** `.gd .json .tscn .tres`：`data/cards/text/**` 以外不许有中日韩字符，除非在 `tools/cards/audit/cjk_allowlist.json`（Claude 维护）里逐个文件写了原因。`.gd` 只查**字符串字面量**（导出用二进制 token，注释会被剥掉；字面量要会认 `"…"` `'…'` `"""…"""` `&"…"` `^"…"`）；`.tscn` `.tres` `.json` 全文查。另外：`scripts/cards/ui/**` 与 `scripts/cards/minigames/**` 没有颜色字面量（`Color("#…")`、`Color.html(…)`、`Color8(…)`、`Color(r, g, b[, a])`；放过 `Color.WHITE`、`Color.TRANSPARENT`、`Color(1, 1, 1, a)`）；运行时占位音频（`AudioStreamGenerator` 一类）和旧版曲目（`res://audio/music/`）的每处引用都在 `CardShip.is_ship()` 守卫之下（静态检查：同一函数里在它之前有 `if CardShip.is_ship(): return`，或包在 `if not CardShip.is_ship():` 块里）。
- [ ] 6. 正文里没有判词（`tools/cards/audit/verdict_words.json`，**只查观察句、签、测字的正文**：`data/cards/text/minigames/obs/**`、签的 `verse`/`gloss`、字的 `has`/`none`）；所有正文（**含指引步骤 `say`/`bubble`、规矩页 `title`/`body`、F1 帮助 `c10.help.*`**）里没有 `%`；调 K13 的 `wording_lint.py <暂存目录>/data/cards/text --scope=text --fail-on=must`，退出码 0。
- [ ] 7. 字体覆盖：发行正文（`data/cards/text/**` 的所有字符串）里用到的每个字都在 `fonts/NotoSerifSC-Regular-subset.otf` 与 `fonts/MaShanZheng-Title-subset.ttf` 的 `cmap` 里——**自己用标准库 `struct` 读 OpenType 的 `cmap` 表（format 4 与 12）**，不 import `fontTools`；缺字列出来。
- [ ] 8. `data/cards/theme/palette.json` 存在，且 `_meta._provenance` 是 `human:A:…`。
- [ ] 9. 给了 `--pck=` 时：**用标准库读 Godot 4 的 `.pck` 文件目录**（文件头 + 文件表；不解压内容），对文件清单再跑第 1 项的路径部分和第 4 项。
- [ ] 10. 报告写到 `docs/cards/audit/last_audit.md`（或 `--report=`）：时间（ISO 8601，报告里允许出现时间）、提交号（`git rev-parse HEAD`，没有 git 时写 `unknown`）、每项结果（OK / FAIL + 条目）；最后一行 `AUDIT OK` 或 `AUDIT FAILED: <n> problems`。

### C. `tools/cards/audit/check_pr_paths.py`（W0 版能用，增强；**命令行与输出格式保持兼容**——CI 在用）
- [ ] 用 `git diff --name-status -M` 取改动（新增、修改、删除、改名的**新旧两个路径**都查）；sidecar `.uid` `.import` 归它的文件的主人（已有）。
- [ ] **不为任何分支设特例**：K13 不跨线改文件（合同 §2.6，审读结论走 `[K13→K0x]` issue），所以 `cards/K13-…` 分支和别的任务一样只按 `ownership.json` 查；保持 `^cards/([GCK]\d\d)-` 的识别。
- [ ] `legal/human_authors.json` 不存在时：所有作者按 AI 线查（已有，保持）；格式兼容 `["login"]` 和 `{"humans": [{"login": …}]}`。
- [ ] `--task=` 给了就用它；没给且分支名对不上 `cards/<ID>-…` 时打印 `NOTE` 跳过归属检查（已有，保持——`content/…`、`ui-text/…` 的人写分支走 CODEOWNERS）。

### D. `tools/cards/audit/missing_text.py`（给 A/B 的待写清单）
- [ ] `missing_text.py [--src=<仓库根>] [--out=docs/cards/audit/missing_text]` → 写 `missing_text.md` 与 `missing_text.json`：发行年代（`stages.json` 的年代 + `*`）里每一样还缺人写正文的东西，一行一个：**id/键、类型、文件、要写哪些字段**，外加机制要点（类型、选项 id、格子 id、谁、教哪个机制、`intro_paras` 几段）——**不带 brief 原文**（避免 AI 文字被照抄进正文）。
- [ ] 覆盖：每张会出现的牌（§4.5 表的必填字段）、所有界面键（`data/cards/ui_keys/*.json`，按任务号分组；`w0.*` 单列为“W0 桩用的键，正式界面换掉后可删”——`w0.stage.*` 除外，见下方“10-13 变更二”）、观察键（`minigames/obs/*.json`）、人物名（`persons.text.json`：`cast.json` + 各 `persons` 块）、物品名（`items.text.json`：首发物品模板）、**新手指引步骤 `say` `bubble`、规矩页 `title` `body`**、F1 帮助键 `c10.help.*`、设置里“新手提示”那一行（`c16.settings.guide_hints` 等）、开场段落 `stage.<年>#intro.p1…p<n>`、电码本的词 `cb.word.*`。
- [ ] 按负责人分：A（剧情、牌面、签、观察句、人物名、物品文字、指引与规矩页、电码本）、B（界面文字、F1 帮助、设置）。

### E. 其他文件
- [ ] `tools/cards/audit/verdict_words.json`：判词词表（中文：断定真假的词语，例“赝品”“仿品”“假货”“真品”“是真的”“是假的”等；**不要单独列“伪”字**——历史措辞要求伪政权名带“伪”）；这是 `tools/` 下的文件，不进包，可以有中文。
- [ ] `tools/cards/audit/README.md`：四个工具的用法、出包流程里的位置（§11.6）、每项检查查什么、怎么读报告、常见失败怎么修（给 A/B 看的那部分用白话）。
- [ ] `docs/cards/audit/`：`last_audit.md`（W2 演练的报告）、`legacy_hashes.json`、`missing_text.md` / `.json`（W2 演练产出）。

### F. 测试（只用标准库；Python 的测试用 GDScript 包装进清单）
- [ ] `tools/cards/audit/tests/test_*.py`（`unittest`）+ `tools/cards/audit/fixtures/`：
  - 一个“好包”夹具（极小的暂存目录：几张牌、对应的人写正文带 `human:A:…`、一张正式图和它的来源行、`palette.json`、`human_authors.json`）→ `audit.py` 第 1、3–8 项 OK（第 2 项和第 9 项在单测里用替身：给 `audit.py` 一个 `--godot=<夹具里的假脚本>` 和一个夹具 `.pck`）。
  - **“坏包”夹具，每一项至少一个**：残留 `brief`；残留 `art/_placeholder/` 文件；正文 `_provenance` 不是 human；美术引用 `legacy: true`；图片不在来源清单；旧素材哈希；`.gd` 字符串字面量里有中文（注释里的中文不报）；界面脚本有颜色字面量；占位音频没有 `is_ship()` 守卫；观察句里有判词；**指引步骤的 `bubble` 里有 `%`**；正文用了字体子集里没有的字；`palette.json` 缺失；`.pck` 里有 `docs/` 文件——逐项断言报错（§3.4 K15 验收）。
  - `stage_ship.py`：剥字段、排除路径、依赖追踪（夹具里一个场景 preload 一个脚本，脚本 load 一个数据文件）、两次运行结果相同。
  - `check_pr_paths.py`：在 `tempfile` 里建小 git 仓库，各造一个越界、碰人写路径、K13 分支改了 K0x 的数据（失败）、改名越界（新旧路径都查）、删除别人文件的提交。
  - `missing_text.py`：对夹具输出完整清单，**清单里不出现任何 brief 原文**，指引步骤和规矩页都在。
- [ ] `scripts/tests/cards/K15/test_audit_tools.gd`：`OS.execute("python3", ["-m", "unittest", "discover", "-s", "tools/cards/audit/tests"])`，退出码 0 才 PASS（找不到 `python3` 时试 `python`）。
- [ ] `scripts/tests/cards/K15/test_missing_text_real.gd`：对**当前真仓库**跑 `missing_text.py --out=<t.user_dir()>/mt`，断言：退出码 0；`mt.json` 里每个 `data/cards/guide/steps.json` 的步骤都有 `say` `bubble` 两条待写（W1 时用例子集兜底：真数据里还没有步骤就跳过并打印 `NOTE`）；不含任何 brief 原文（拿真数据里的 brief 逐条做子串检查）。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] `missing_text.py` 的待写清单：有非空 `effects.on_expire`、会进打烊清单的牌（person event fate big_fate street life）多列一项 `outcomes.ignored`（打烊确认里“没理会会怎样”那一句，合同 §4.5）；`g0x.end.*` 界面键照别的界面键列。
- [ ] 审核第 2 项跑 `validate_main.gd --mode=ship` 时 V27 会查 `outcomes.ignored`、V37 会查没理会的后果写没写——你的“坏包”夹具各加一个反例。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **`missing_text.py` 的待写清单加**：
  - 带演出块的牌里每一拍的 `ref`（合同 §4.5 必填表新加的那一行）：列出牌 id、字段（`body` / `lines.<名>` / `outcomes.<名>` / `choices.<id>`）、说话的人（`who`：`""` 写“旁白”、`"me"` 写“沈如花”、否则人物 id）、在 `intro` 还是 `after.<键>`；**`brief` 不带**（和别的条目一样）。同一张牌、同一个字段在默认必填里已经列过的不重复列。
  - W0 的演出旁白键 `w0.stage.enter` `w0.stage.at_door` `w0.stage.leave`（参数 `{name}`）：它们是 W0 默认演法 `CardStageScript` 一直要用的正式键，**不归**上文“`w0.*` 单列为 W0 桩用的键、正式界面换掉后可删”那一组，归 A（写在 `data/cards/text/ui/W0.text.json`）。
  - 群演的名字：K09 `data/cards/common/extras.json` 的 `persons` 块（`ex_*` 九个，`dossier: false` 也要名字），和别的人物名一起列在 `persons.text.json` 下。
- [ ] **`stage_ship.py`**：确认演出块里嵌套的 `brief` 都剥掉（`stage.brief`、`stage.cast[i].brief`、`stage.props[i].brief`、`stage.intro[i].brief`、`stage.after.<键>[i].brief`——“递归剥掉键 `brief`”本来就该做到，加一个夹具测它）。
- [ ] 审核第 2 项（`validate_main.gd --mode=ship`，V27）1.3 起也查拍子引用的正文、`w0.stage.*`、群演名字（G01 做）——你的“坏包”夹具加一个反例：一张带演出块的牌，某一拍的 `ref` 没有人写的正文 → 替身 GODOT 返回的 V27 `DATA ERROR` 被收进报告、第 2 项失败。

**新增 / 作废的交付**

- 新增：上面三处（待写清单的三类条目、剥嵌套 brief 的夹具、坏包反例）。
- 作废：无。`docs/cards/prototype/**`（网页原型，里面有 AI 写的占位台词和旧图）在 `docs/**` 里，本来就不进暂存目录——`audit.py` 第 1 项照旧查 `docs/` 不在包里。

**锚点、界面事件、要证明的步骤**

- 工具任务照旧不登记锚点、不发界面事件；指引步骤与规矩页的待写清单不变（`_test.d1_3` 不变）。

**测试与截图**

- `tools/cards/audit/tests/` 加：`stage_ship.py` 对一张带演出块（`cast`、`props`、`intro`、`after` 里都有 `brief`）的夹具牌——暂存目录里那张牌的 `stage` 还在、但没有任何一层 `brief`；`missing_text.py` 对同一张牌——清单里有每一拍的 `ref` 与说话的人、没有 brief 原文；`w0.stage.*` 归在 A 那组；群演名字在人物名里。
- `test_missing_text_real.gd` 加：真仓库里每张带 `stage` 的牌，每一拍的 `ref` 都在待写清单里（真数据里还没有演出块就跳过并打印 `NOTE`）。
- 截图：不交（工具任务）。

**已经做了的哪些还有效**

- 全部有效。

**日期**：随你下一个 PR 一起交；W2 的审核演练（11-09）照旧，失败项里演出拍子未写的正文归“正文未写”一类。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致（两处都逐个文件列出；同目录的 `cjk_allowlist.json` 归 Claude；PR 路径检查按 `ownership.json` 查）：

- `tools/cards/audit/check_pr_paths.py`、`tools/cards/audit/audit.py`、`tools/cards/audit/stage_ship.py`、`tools/cards/audit/missing_text.py`、`tools/cards/audit/verdict_words.json`、`tools/cards/audit/README.md`、`tools/cards/audit/tests/**`、`tools/cards/audit/fixtures/**`
- `docs/cards/audit/**`
- 默认拥有：`scripts/tests/cards/K15/**`、`scripts/tests/cards/suites/K15.txt`、`data/cards/tags/K15.json`、`data/cards/ui_keys/K15.json`
- **不能新建** `tools/cards/audit/` 下的其他文件（例：公共模块 `lib.py`）——共用代码写进上面的文件里；确实需要新文件，开 `[api] K15→Claude` 请 Claude 改 `ownership.json`。

## 不能做的事

1. 不改 `tools/cards/audit/cjk_allowlist.json`（Claude）；要加条目开 `[shared] K15→Claude`，写清文件和“为什么玩家永远看不到”。
2. 不改 `.github/**`、`tools/package*.sh`、`export_presets.cfg`、`project.godot`、`tools/run_*.sh`、`tools/build_fonts.py`（Claude）；不改 `legal/**`、`data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`palette.json`（人写——夹具里的“人写”文件只放在 `tools/cards/audit/fixtures/**` 下）。
3. **不放宽审核**：没法查 = 失败；不加“跳过”开关（单测用替身，不用跳过）；不信数据里自己写的 `human:…`（以 `legal/human_authors.json` 和 PR 作者为准）。
4. 只用 Python 标准库；不联网；输出确定（排序）。
5. 不改 `check_pr_paths.py` 的命令行参数与 `PATH ERROR` / `PATHS OK|FAILED` 输出格式（CI 依赖）。

## 接口

**用到**：`docs/cards/ownership.json`、`legal/human_authors.json`、`legal/ASSET_PROVENANCE.csv`、`data/cards/art/manifest.json`、`data/cards/**`、`validate_main.gd --mode=ship`（G01）、`wording_lint.py`（K13）、`cjk_allowlist.json`（Claude）。

**提供**：`stage_ship.py` / `audit.py`（Claude 的 `tools/package_steam.sh` 调用：`stage_ship.py` → `validate --mode=ship`（暂存目录上）→ `audit.py <staging>` → 从暂存目录导出 → `audit.py <staging> --pck=<输出>`）；`check_pr_paths.py`（CI 必过检查）；`missing_text.py`（给 A/B 的待写清单）。

## 新手指引

- **锚点**：不登记（工具任务）。**first-time**：不发。
- **你支持的步骤**：全部 66 个机制的指引步骤与规矩页——保证它们的正文由人写齐、不泄露数值才能出包：
  - `missing_text.py` 列出每个步骤的 `say` `bubble`、每页规矩的 `title` `body`、F1 帮助键、设置里“新手提示”那一行；
  - `audit.py` 第 2 项（V27：指引步骤、规矩页、F1 帮助键都有 human 正文）、第 6 项（指引与规矩页正文没有 `%`、过措辞检查）、第 7 项（正文用字在字体里）。
- **指引验收（必须有测试）**：F 节的“坏包”夹具里有一份指引步骤 `bubble` 带 `%` 的 → 第 6 项报错；一份缺 `say` 的 → 第 2 项（替身 GODOT 返回的 V27 `DATA ERROR`）报错；`test_missing_text_real.gd` 断言真仓库的每个 `gd.*` 和 `rule.*` 都在待写清单里。
- **截图**：不交截图（工具任务）。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K15.txt`：

```
# K15 来源审核工具（docs/handoff_cards/K15_audit-provenance.md）
K15_audit_tools|res://scripts/tests/cards/K15/test_audit_tools.gd|300|
K15_missing_text_real|res://scripts/tests/cards/K15/test_missing_text_real.gd|180|
```

**通过条件**（合同 §3.4 K15 验收）：
- [ ] 对人造“坏包”夹具**逐项报错**（十项都有反例）；“好包”通过。
- [ ] 对当前仓库（正文还没写）跑 `missing_text.py`，报出完整待写清单（PR 贴统计：按类型、按 A/B 各多少条）。
- [ ] 标准库之外不依赖第三方包（`grep -E "^(import|from) " tools/cards/audit/*.py` 只出现标准库模块，PR 贴结果）。
- [ ] `check_pr_paths.py` 的旧用法照常（CI 的 `paths` job 绿）。
- [ ] W2 演练：`stage_ship.py` + `audit.py` 对集成分支跑一遍，`docs/cards/audit/last_audit.md` 里**只剩“正文/美术未写”一类失败**（§13.4 W2 完成条件）；其他类失败开 issue 指给负责的任务。
- [ ] `tools/run_card_tests.sh` 与 `tools/run_legacy_smoke.sh` 全绿；无 `SCRIPT ERROR` `ERROR` `WARNING` `FAIL:`、无泄漏；每行 `CARDS TEST PASS <名字>`。

**怎么跑**：
```bash
python3 -m unittest discover -s tools/cards/audit/tests
python3 tools/cards/audit/stage_ship.py /tmp/staging
GODOT=<你的 Godot 4.7> python3 tools/cards/audit/audit.py /tmp/staging --report=/tmp/last_audit.md
python3 tools/cards/audit/missing_text.py --out=/tmp/missing_text
python3 tools/cards/audit/check_pr_paths.py origin/claude/festive-ride-vud32a HEAD --author=<你的账号> --branch=cards/K15-audit-provenance
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K15 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```

## 交付

- **PR 标题** `[K15] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K15] stage_ship.py 与审核第 1、5、8 项 + 坏包夹具`；②`[K15] 审核第 2、3、4、6、7、9、10 项`；③`[K15] check_pr_paths 增强（改名、删除）`；④`[K15] missing_text.py 与给 A/B 的待写清单`；⑤（W2）`[K15] 审核演练报告`。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；每一项检查的实现要点与对应的坏包夹具；标准库 import 清单；`missing_text` 统计；W2 演练的失败分类；需要 Claude 定的事（下面的合同缺口）；完成写“交付”。

## 审核（Claude 重点）

1. 越界（只动 `ownership.json` 列的 K15 文件）；`cjk_allowlist.json` 没动。
2. 十项全实现、关着门（缺东西 = 失败）、每项有坏包反例。
3. `.gd` 只查字面量、颜色字面量规则、`is_ship()` 守卫检查靠谱；`.pck` 读取不依赖第三方。
4. `stage_ship.py` 剥字段、排除路径完整、依赖追踪对；确定。
5. `check_pr_paths.py` 兼容 CI；改名的新旧路径都查；不设任何特例。
6. `missing_text` 不带 brief 原文、覆盖指引与规矩页。
7. 只用标准库。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 十项检查与坏包夹具对照 | |
| 标准库 import 清单 | |
| `missing_text` 统计（按类型 / A / B） | |
| W2 审核演练结果 | |
| 开的 issue | |
| 合同或数据缺口 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |

## 附：本卡原来报的合同缺口（交接包审计时已在合同里定，见合同附录 E）

1. `data/cards/rules/wording.json`（K13）与 `data/cards/branch/**`（K16，首发不读）已列进合同 §2.3 的排除列表和 §11.4 第 1 项——`stage_ship.py` 排除它们、`audit.py` 第 1 项查它们不在暂存目录里。
2. K13 不再跨线改文件（合同 §2.6）：`check_pr_paths.py` 不需要 `cards/K13-to-K0x-<slug>` 的特例。
3. 合同 §2.2 与 `ownership.json` 的 K15 条目已逐条一致（逐个文件）。
4. 合同 §11.4 第 7 项已改为“用标准库读 `cmap`”，不调用依赖 `fontTools` 的 `tools/build_fonts.py`；`fonts/**` 只归人（A/B）。
