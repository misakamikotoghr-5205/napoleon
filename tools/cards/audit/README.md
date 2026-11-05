# 来源审核工具（K15）

Steam 包支持两条出包变体（`#202` / `#212`）：
1. **带 AI 声明版**（`--variant=ai-disclosure`，默认）：包含 `art/ai/**`、`audio/ai/**`、`data/cards/text_ai/**`，按 `human → ai → 占位` 顺序解析；审核工具把 `art/ai/**`、`audio/ai/**`、`data/cards/text_ai/**` 标成「AI 生成、需声明」，并按类别与 `_provenance` 来源统计件数及已被人工资产覆盖的件数。
2. **无 AI 声明版（纯人工包）**（`--variant=no-disclosure` 或 `--no-ai`）：排除一切 `art/ai/**`、`audio/ai/**`、`data/cards/text_ai/**`；缺任何一张人工图或混入任何一件 AI 资产直接失败。

剧情插件 `packs/<id>/`（2026-10-22 框架版收尾默认，主创可改；`docs/cards/PLUGINS.md`）：`stage_ship.py` 只拷启用的发行插件（id 不以 `_` 开头、`enabled` 不为 false）的 `pack.json` 和 `text/**.json`，无声明版只拷 `source: "human"` 的；`audit.py` 第 1 项拦开发插件、停用插件、插件里的杂文件和无声明版里的 AI 插件，第 2 项查清单与正文来源，第 6、7 项把插件正文算进判词、百分号和字体覆盖，第 9 项在 `.pck` 里复查插件清单；`source: "ai"` 的插件算进「AI 生成、需声明」的台词统计。`check_pr_paths.py` 把 `source: "human"` 的插件当人写层保护。

这四个脚本加上 `tools/package_steam.sh` 负责：把要发行的文件收进暂存目录、逐项审核、拦越界的 PR、给 A/B 一份待写清单。它们只使用 Python 标准库。夹具在 `fixtures/`，单测在 `tests/`。

合同：`docs/cards/CARDS_INTERFACES.md` §11。任务卡：`docs/handoff_cards/K15_audit-provenance.md`。

## 在出包流程里的位置（§11.6）

```text
stage_ship.py <暂存目录> [--variant=ai-disclosure|no-disclosure]
    → validate_main.gd --mode=ship（对着暂存目录）
    → audit.py <暂存目录> [--variant=ai-disclosure|no-disclosure]
    → 从暂存目录导出 .pck（"Steam (AI Disclosure)" 或 "Steam (No AI Disclosure)"）
    → audit.py <暂存目录> --pck=<导出的.pck> [--variant=ai-disclosure|no-disclosure]
```

也可以直接运行一键出包脚本：`bash tools/package_steam.sh [--variant=ai-disclosure|no-disclosure]`。
某一步查不了（缺文件、缺 Godot、缺措辞工具）算失败，没有跳过开关。单测用夹具里的替身，不改这个规矩。

## 命令

在仓库根目录运行。

```bash
python3 tools/cards/audit/stage_ship.py <暂存目录> [--src=<仓库根>] [--variant=ai-disclosure|no-disclosure] [--no-ai]
python3 tools/cards/audit/audit.py <暂存目录> [--report=<路径>] [--pck=<导出的.pck>] [--godot=<Godot>] [--wording-lint=<脚本>] [--variant=ai-disclosure|no-disclosure] [--no-ai]
python3 tools/cards/audit/audit.py --build-legacy-hashes
python3 tools/cards/audit/missing_text.py [--src=<仓库根>] [--out=docs/cards/audit/missing_text]
python3 tools/cards/audit/check_pr_paths.py <base> <head> --author=<github 登录名> [--task=<ID>] [--branch=<分支名>]
bash tools/package_steam.sh [--variant=ai-disclosure|no-disclosure] [--no-ai]
```

`check_pr_paths.py` 的命令行和 `PATH ERROR` / `PATHS OK|FAILED` 输出与 W0 的 CI 调用兼容。`human_only`（`data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`data/cards/theme/palette.json`、`legal/**`、`fonts/**`）仍只允许 `legal/human_authors.json` 中的人类作者修改；`ai_paths`（`art/ai/**`、`audio/ai/**`、`data/cards/text_ai/**`）允许 AI 线按任务范围写入。改动用 `git diff --name-status -M`（三点），改名和拷贝的新旧路径都查，删除也查。

`stage_ship.py` 成功时打印 `STAGED <n> files, <bytes> bytes`。`audit.py` 最后一行是 `AUDIT OK` 或 `AUDIT FAILED: <n> problems`，前面有 `AUDIT FAIL: item N: …`（每项最多 80 条）。`missing_text.py` 打印 `MISSING TEXT <n> entries, A=<a> B=<b>`，退出码 0（缺很多也是 0，这是清单不是门禁）。

## stage_ship 拷什么、剥什么

从 `scenes/cards/CardGame.tscn`、`project.godot` 的 `[autoload]`（CardBus），以及 `scripts/cards/core/validate_main.gd` 出发。出包流程要在暂存目录里面跑这个校验脚本，游戏场景本身不引用它，所以单独作为起点，再顺着依赖把 `CardValidator` 带上。接着追 `.tscn`/`.tres` 的 `res://`、`.gd` 字符串字面量里的 `res://`（注释不算），再用全仓库的 `class_name` 表补上被引用的脚本。另外整份拷贝 `data/cards/**`（下面的排除项除外）、`art/cards/**`、`audio/cards/**`，以及在 `ai-disclosure` 变体下拷贝 `art/ai/**`、`audio/ai/**`、`data/cards/text_ai/**`，再加上 `data/town/item_templates.json`、`data/cast.json`、`fonts/**`、`project.godot`、`export_presets.cfg`，以及这些文件的 `.import` 旁注。不追 `.import` 里面的路径，不跟主场景 `Main.tscn`，不进 `.godot`。

不拷：`art/_placeholder/**`、`audio/_placeholder/**`、`data/cards/_examples/**`、`data/cards/_dev/**`、`data/cards/branch/**`、`data/cards/theme/palette.dev.json`、`data/cards/rules/wording.json`、`scripts/tests/**`、`scripts/town/**`、`tools/**`、`docs/**`、`scenes/` 下非 `scenes/cards/` 的场景、`data/town/**`（物品模板除外）、`data/codebook.json`、`art/{bg,portraits,tools,ui,town}/**`、`audio/music/**`。在 `no-disclosure` 变体下，额外不拷 `art/ai/**`、`audio/ai/**`、`data/cards/text_ai/**`。`art/items` 如果被引用，不在排除名单里。

JSON 重写时保持键顺序、2 空格缩进、UTF-8、末尾换行。剥掉 `brief`、`_doc`、`_test`、`_meta.brief`。`brief` 在每一层都剥，演出块也不例外：`stage.brief`、`stage.cast[i].brief`、`stage.props[i].brief`、`stage.intro[i].brief`、`stage.after.<键>[i].brief`。剥完 `stage` 本身还在。`_provenance` 也剥，但以下几处保留给后续审核：

- `data/cards/text/**` 上的登记（`human:A:日期` 或 `human:B:日期`）。`validate --mode=ship` 和审核第 2 项都看它。
- `data/cards/theme/palette.json` 的 `_meta._provenance`（必须是 `human:A:日期`）。审核第 8 项看它。
- 在 `ai-disclosure` 变体下：`data/cards/text_ai/**`（严格五段文件级 `_meta._provenance`）、`data/cards/art/manifest.json`（`art.<id>`）、`data/cards/audio/*.json`（`cues.<id>` / `sfx.<id>`）和 `audio/ai/sfx/manifest.json`（`cues.<id>`）上的 `ai:...` 字符串 `_provenance`。在 `no-disclosure` 变体下，这些 AI 路径键（`ai`）和 `ai:...` `_provenance` 会被剥除，且 `audio/ai/sfx/manifest.json` 中的音效条目在剥离后落入 `data/cards/audio/sfx.json` 以强制要求对应人工音效。

骨架上那种 `{by, task, date}` 的 AI 来源对象会被剥掉。暂存目录不能放在源仓库里面。

## audit 十项

报告默认写到 `docs/cards/audit/last_audit.md`（`--report=` 可改）。报告里有 ISO 时间、`git rev-parse HEAD`（没有 git 就写 `unknown`）。没给 `--pck` 时第 9 项不跑，也不因此失败。

| 项 | 查什么 | 不过的时候 |
|---|---|---|
| 1 | 暂存目录里没有草稿键，也没有上面那些不该进包的路径。`_provenance` 只允许留在正文和配色的 `_meta` | 剥漏了，或拷进了占位/例子/开发文件 |
| 2 | 正文的 `_provenance` 必须是 `human:A:YYYY-MM-DD` 或 `human:B:…`。真 Godot 会先 `--import`（否则 `class_name` 看不见），再跑 `$GODOT --headless --path <暂存目录> -s res://scripts/cards/core/validate_main.gd -- --mode=ship --name=audit_ship`。退出码 0，标准输出最后一行 `CARDS TEST PASS audit_ship`。`DATA ERROR` 行原样进报告。单测用 `.py` 替身，不跑 import | 正文没人写、格式不对，或校验器没过 |
| 3 | 数据里每个 `art` / `bg` 字符串引用都能在 `data/cards/art/manifest.json` 找到，不是 `legacy: true`，`human` 路径在 `art/cards/**` 且文件在，`legal/ASSET_PROVENANCE.csv` 的 sha256 对得上，作者在 `legal/human_authors.json`，`method` 不是 AI（空的 method 也算 AI）。一条引用都没有 = 失败 | 图还没画、清单还是旧版、来源表没有这行 |
| 4 | 每个 png/jpg/jpeg/webp/svg/ogg/wav/mp3 都在来源表里，sha256 对得上，并且不在 `docs/cards/audit/legacy_hashes.json`（v0.4.2 旧素材）。一张图都没有 = 失败 | 图没登记，或误把旧版图拷进来了 |
| 5 | `.gd` 只查字符串字面量（`"…"` `'…'` `"""…"""` `&"…"` `^"…"`，注释忽略）。`.json` `.tscn` `.tres` 全文查。`data/cards/text/**` 以外的中日韩字符必须写在 `cjk_allowlist.json`（Claude 维护，本任务只读）。`scripts/cards/ui/**` 和 `minigames/**` 不许写颜色字面量；放过 `Color.WHITE`、`Color.TRANSPARENT`、`Color(1, 1, 1[, a])`；另外只有 `scripts/cards/ui/common/card_theme.gd` 里读配色文件的 `Color.html(` 放过（`COLOR_PARSE_EXCEPTIONS`，合同 §11.4，#74）。`AudioStreamGenerator` 和 `res://audio/music/` 必须包在 `CardShip.is_ship()` 守卫里：同一函数里前面有 `if CardShip.is_ship(): return`，或写在 `if not CardShip.is_ship():` 块里，或写在 `if CardShip.is_ship():` 的 `else` 里。缩进把 Tab 算作 4 | 字面量里有中文、界面脚本写了颜色、占位音效没拦住 |
| 6 | 判词（`verdict_words.json`）只查观察句、签的 `verse`/`gloss`、测字的 `has`/`none`。不单列「伪」字。所有玩家能读到的正文字符串里不许有 `%`（`_` 开头的键跳过），包括指引的 `say`/`bubble`、规矩页、F1 帮助。然后跑 `wording_lint.py <暂存目录>/data/cards/text --scope=text --fail-on=must`。工具不在 = 失败 | 观察句写了真假、指引里出现百分号、措辞工具没过或还没合进来 |
| 7 | 用标准库 `struct` 读两套字体的 cmap（format 4 和 12）。正文里每个码位 ≥ 32 的字都要两套字体都有。不 import fontTools | 用了子集里没有的字，或字体没拷进暂存目录 |
| 8 | `data/cards/theme/palette.json` 存在，且 `_meta._provenance` 是 `human:A:YYYY-MM-DD`（必须是 A） | 还在用开发配色，或来源不是 A |
| 9 | 只在给了 `--pck` 时：按 Godot 4 包格式读目录（魔数 GDPC，版本 2/3/4），再跑第 1 项的路径规则和第 4 项。加密文件算失败（算不出哈希），删除标记跳过 | 包里混进了 `docs/` 之类，或图对不上来源表 |
| 10 | 把上面的结果写成报告。写不出来也是失败 | 报告路径没权限 |

来源表和作者名单先找暂存目录里的 `legal/`，没有再找 `--src`（默认本仓库）。`human_authors.json` 接受 `["login"]` 或 `{"humans":[{"login":…}]}`。来源表列：`path,sha256,author,method,…`。

旧素材黑名单：`python3 tools/cards/audit/audit.py --build-legacy-hashes`，扫 `art/{bg,items,portraits,tools,ui,town}/**` 和 `audio/music/**`，写到 `docs/cards/audit/legacy_hashes.json`。

## 怎么读报告

每一节是 `OK` 或 `FAIL` 加条目。最后一行是结论。标准输出的 `AUDIT FAIL: item N:` 和报告里的条目是同一件事，标准输出每项截到 80 条。

## 给 A / B 的白话

- **正文还没写**（第 2、6、7 项）：按 `missing_text.md` 写。A 写剧情、牌面、签、观察句、人物名、物品、指引和规矩页、电码本。B 写界面、F1 帮助（`c10.help.*`）、设置里的新手提示（`c16.settings.guide_hints`）。写完在对应的 `.text.json` 上加 `_provenance`：`human:A:2026-01-15` 这种，日期用写完那天。不要把 brief 原文抄进去。观察句、签、测字不要写「赝品」「是真的」这类断语。任何玩家能读到的句子里不要写 `%`。
- **图还没画或还是旧图**（第 3、4 项）：正式图放 `art/cards/**`，在美术清单里写成 `human` 路径，不要 `legacy: true`。来源表里要有一行，sha256 和文件一致，作者在 `human_authors.json` 里，method 写人做的方式（不要留空，不要写 AI）。不要把 v0.4.2 的旧图直接拿来当新图。
- **配色**（第 8 项）：交 `data/cards/theme/palette.json`，`_meta._provenance` 写成 `human:A:日期`。`palette.dev.json` 不会进包。
- **占位和草稿**：`brief`、`art/_placeholder/`、开发配色、例子、解放后分支、措辞规则文件都不会进包。不用在正文里解释它们。
- **`w0.*` 界面键**：清单里单独一节。正式界面换掉桩以后可以删。例外是 `w0.stage.enter`、`w0.stage.at_door`、`w0.stage.leave`（参数 `{name}`）：这三句是默认演法一直要用的旁白，归 A，写在 `data/cards/text/ui/W0.text.json`，不进“桩用完可删”那一节。
- **打烊没理会**：有非空 `effects.on_expire`、会进打烊清单的牌（person、event、fate、big_fate、street、life）多一句 `outcomes.ignored`。`g01.end.*`、`g02.end.*` 这种界面键跟别的界面键一样，归 B，写 `t`。
- **演出拍子**：带 `stage` 的牌，`intro` 和 `after.<键>` 里每一拍的 `ref`（`body`、`lines.*`、`outcomes.*`、`choices.*`）都要写。清单标谁在说：空的是旁白，`me` 是沈如花，别的是人物 id，并标明在 `intro` 还是 `after.<键>`。同一张牌同一个字段已经在必填里的，不重复列。拍子的 brief 不进清单。
- **群演名字**：`data/cards/common/extras.json` 的 `persons`（`ex_*`，`dossier: false` 也要名字）和别的人物名一起列在 `persons.text.json`。文件还没有就先不列。

`missing_text.py` 不抄 brief。一行一个 id：缺哪些字段，外加类型、选项、格子、谁、教哪个机制、开场几段、演出拍子。发行年代来自 `rules/stages.json`。年代对不上（也不是 `*`）的牌不列。例子集不列。

## 测试

```bash
python3 -m unittest discover -s tools/cards/audit/tests
```

好包在 `fixtures/good/`。每一项的坏包在 `fixtures/bad/`（残留 brief、占位路径、来源不是 human、缺 say、缺 `outcomes.ignored`、没写没理会后果的 V37、演出拍子的 `ref` 没有正文、legacy 美术、图不在来源表、旧素材哈希、字面量中文、颜色字面量、没守卫的占位音频、观察句判词、指引 bubble 里的 `%`、字体没有的字、缺 palette、pck 里的 `docs/`）。第 2 项的 Godot 和第 6 项的措辞工具在单测里用 `fixtures/fake_godot.py`、`fixtures/wording_ok.py`。替身只按校验器的输出口径打印 `DATA ERROR`（含 V27、V37），不改 `validate_main.gd`。

卡牌测试清单：`scripts/tests/cards/suites/K15.txt`。
