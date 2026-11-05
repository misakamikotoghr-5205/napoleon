# C15 `mg-fragments-decode` · 拼碎片 + 解密

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C15 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C15: …` 报给 Claude。

> **鉴定改版（主创 10-25：“你那个鉴定不能只是点点点，要玩家看出来才算数”）**：本卡下文凡和合同 §3.3、§4.8、§8、附录 H 对不上的，以合同为准。拼碎片：所有碎片描边一样（异纸不再描红），参数多了 `stain`（水渍干扰）`rotate` `lens_px` `backlight`，玩家在接不上的缝上打叉、说骑缝印对不对得上（`measures.seams` `seal_call`）；解密：引擎给整本电码本 `book`、洇字 `smudges`、加码 `key_shift` / 本号 `crib`，小游戏不再自己读文件，抄错照记（`measures.picked`）；新锚点 `a.mg.fragments.seam` `a.mg.decode.sheet`。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 15**（在第 15 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C15`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）：小游戏基类 `CardMiniGame`、宿主 `CardMiniGameHost`（C01）、例子集里的电码本骨架 `data/cards/_examples/minigames/codebook.json` 和主线当票 `tk.1938.de196`。正式的电码本骨架由 K11 写（`data/cards/minigames/codebook.json`），词由 A 写（`data/cards/text/codebook.text.json`）；主线电报由 K08 写。
- **波次（Wave）**：W1 开发并合入；W2 补对真引擎（G04 的 `mg.request {uid}`：当票、电报这类没有物品的牌用牌上的 `minigame`）的集成测试和 K16 步骤复测。

## 分支

`cards/C15-mg-fragments-decode`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

两个小游戏插件：①**拼碎片** `CardFragmentsGame`——把撕破的当票、裂开的字画、信拖动、旋转、吸附拼回去；拼好后看印章对不对得上、墨色接不接得上、“当字”的笔画、缺没缺一块；主线当票“德字第一九六号”走这个。②**解密** `CardDecodeGame`——电报四位码对照电码本、账本暗语；主线专用；观察 = 译出的片段键。两个都**只给观察，不给结论**。

## 必读

1. `docs/cards/DESIGN_cards.md` §三.2（拼碎片：看印章和落款；解密：电报码、暗信、账本暗语，主线专用）、§五“首发三关的主线”（德字第一九六号、哥哥的信）。
2. `docs/cards/CARDS_INTERFACES.md`：§0（红线 1、5）、§3.3 C15、§4.7.8（`telegram`/`letter` 消息可带 `minigame`）、§4.7.16（主线当票：`minigame: "fragments"`、外来当票只记录不动钱）、§4.7.23（电码本骨架：四位码 → 词的键 + brief；**不读旧的 `data/codebook.json`**）、§4.8（观察键目录、无判词）、§6.3（随机域 `c.mg.fragments.layout` `c.mg.decode.layout`）、§7.4（`mg.request {uid, item: ""}`）、§7.10.5、§8（插件接口；`fragments` 参数 `doc` `pieces` `seal_offset_px` `ink_mismatch` `dangzi_marks` `missing_piece`，`measures` `placed` `rotations` `seal_checked`；`decode` 参数 `cipher` `message` `codes` `book_words`，`measures` `decoded` `lookups`）、§11.2、§12.2、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/api/card_minigame.gd`、`scripts/cards/minigames/{fragments,decode}/*.gd` 与 `scenes/cards/minigames/{fragments,decode}/*.tscn`（W0 桩）、`scripts/cards/mock/example_minigame.gd`、`scripts/cards/ui/table/minigame_host.gd`、`data/cards/_examples/minigames/codebook.json`、`data/cards/_examples/era/1938/story.json`（`tk.1938.de196`）。
4. 只读参考：`scripts/ui/telegraph_panel.gd`、`scripts/ui/ticket_panel.gd`（旧版电报、当票面板的做法；**旧文字和 `data/codebook.json` 的词都是 AI 写的，一个也不许拷、不许读**）。

## 要做的事

- [ ] **CardFragmentsGame**（`scripts/cards/minigames/fragments/fragments_game.gd`，`class_name CardFragmentsGame`，**改成 `extends CardMiniGame`**，`kind()` → `&"fragments"`）：
  - `start(params)`：底图 `CardArt.texture(params.art)`（当票、字画、信的图；整数倍、NEAREST）；按 `pieces` 用 `JevRng.draw(params.seed, "c.mg.fragments.layout", [i])` 切成多边形碎片（代码切、代码描边，只用配色键），打乱摆在桌上；`missing_piece >= 0` 的那块不给。
  - 操作：拖动、旋转（Q/E 或右键，90° 一档）、靠近正确位置自动吸附；拼好后可以“看印章”（`seal_checked = true`；印章错位 `seal_offset_px` 画出来让玩家自己看）、看墨色接缝（`ink_mismatch` 里的那几块墨色接不上）、看“当字”笔画（`dangzi_marks` 处）。每个操作发 `ui_event("mg_tool", {"kind": "fragments", "tool": "move"|"rotate"|"seal"|"ink"})`。Esc → `abort()`。
  - 结果：`{"quality_permille", "observations", "minutes", "measures": {"placed": n, "rotations": n, "seal_checked": bool}, "aborted": false}`；观察例：`obs.fragments.seal_aligned` / `seal_offset` / `ink_continuous` / `ink_breaks` / `dangzi_clear` / `piece_missing` / `unsure`（按拼了多少、看没看印章给；无判词）。
- [ ] **CardDecodeGame**（`scripts/cards/minigames/decode/decode_game.gd`，`class_name CardDecodeGame`，**改成 `extends CardMiniGame`**，`kind()` → `&"decode"`）：
  - `start(params)`：电报纸（`cipher: "telegraph"`）或账本页（`"ledger"`）上的一串 `codes`（四位码，数字可以显示——那是纸上本来就有的码）；电码本：`book_words` 是玩家能查到的词的**键**（`cb.word.<码>`），翻电码本时显示 `CardText.t(<键>)`（词由 A 写；开发版是【稿】+ brief）。码和键的对应：键名里带码（`cb.word.0417`）；需要时读 K11 的 `data/cards/minigames/codebook.json`（例子集阶段读 `data/cards/_examples/minigames/codebook.json`）只取 `codes` 的 `key`，**绝不读 `data/codebook.json`**。
  - 操作：在电码本里翻查（`lookups += 1`）、把查到的词填到对应的码下面（`decoded += 1`）；电码本的翻页顺序/干扰项用 `JevRng.draw(params.seed, "c.mg.decode.layout", [i])`。每个操作发 `ui_event("mg_tool", {"kind": "decode", "tool": "lookup"|"write"})`。Esc → `abort()`。
  - 结果：观察 = 译出的片段键（例 `obs.decode.<码>`，每个译对的码一条；没译完的部分给 `obs.decode.partial` 一类；无判词），`measures {"decoded": n, "lookups": n}`。
- [ ] 两个插件的 **autoplay(skill)** 都走和玩家同一条代码路径（模拟拖动/旋转/查本子/填写）；skill 高拼得全、看印章、译得全；skill 低拼一半、不看印章、译一部分。`autoplay(0.2)` 与 `autoplay(0.9)` 清晰度不同；同参数同 skill 同结果。
- [ ] **观察键目录**：`data/cards/minigames/obs/fragments.json`（`_meta.kind: "fragments"`）与 `data/cards/minigames/obs/decode.json`（`_meta.kind: "decode"`）；键前缀 `obs.fragments.` / `obs.decode.`；每个带 `fidelity` 与 `brief`（只写观察的意思，不写判词、不写成观察句正文）；`_meta._provenance`。解密的“每个码一条”观察键要和 K11 电码本里的码对得上：W1 先按例子集的码列，K11 合入后补全（PR 里写明，或写一个测试检查两边一致）。
- [ ] **键盘可玩**：拼碎片——Tab 选碎片、方向键移动、Q/E 转、S 看印章、F 交；解密——方向键选码、B 翻电码本、Enter 填、F 交；两者 Esc 放弃。
- [ ] **界面键** `data/cards/ui_keys/C15.json`（`c15.` 开头，键 + `brief`，`_meta._provenance`）：`c15.fragments.title` `c15.decode.title` `c15.tool.<move|rotate|seal|ink|lookup|write>` `c15.btn.done` `c15.book.title`。
- [ ] **参数夹具**（`scripts/tests/cards/C15/fixtures/`）：`ticket196.json`（`doc: pawn_ticket`，6 片，印章错位，一块墨色接不上）、`scroll.json`、`letter_missing.json`（缺一块）、`telegram.json`（`cipher: telegraph`，用例子集电码本里的码）、`ledger.json`。只放 §8.2 允许的键。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- 合同 1.3 不影响本任务的玩法、参数、结果格式和冻结接口；只改截图。
- 小游戏仍由 C01 的宿主开在叠层之上；入口变成柜台那一出里的“细看”回话或柜台上的放大镜（都发 `mg.request`，C04 做），对你没有影响；小游戏框外的“算了”按钮照旧由 C01 放。

**新增 / 作废的交付**

- 没有新增；也没有作废的。

**锚点、界面事件、要证明的步骤**

- 不变。

**测试与截图**

- 测试不变。
- 截图改成画面版：小游戏叠在柜台画面上（背后看得见客人和柜台），清单照原卡。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- 全部。

## 只能改这些文件

- `scenes/cards/minigames/fragments/**`、`scripts/cards/minigames/fragments/**`、`scenes/cards/minigames/decode/**`、`scripts/cards/minigames/decode/**`、`data/cards/minigames/obs/fragments.json`、`data/cards/minigames/obs/decode.json`
- 默认拥有：`scripts/tests/cards/C15/**`、`scripts/tests/cards/suites/C15.txt`、`data/cards/tags/C15.json`、`data/cards/ui_keys/C15.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（`data/cards/minigames/codebook.json`（归 K11）、`scripts/cards/api/**`、`mock/**`、C01 的宿主、旧代码 `scripts/ui/{telegraph_panel,ticket_panel}.gd`）。
2. **不读、不拷旧的 AI 内容**：`data/codebook.json`、旧电报/当票面板里的中文一律不碰。
3. **不判真假**：观察键无判词；不写“伪造/假当票”；印章错位、墨色接不上只画出来、只给观察。
4. **不写最终内容**：电码本的词、观察句、按钮字由人写；当票上的字（“德字第……号”）用 G04 的键 `g04.ticket.number`；不碰 `data/cards/text/**`、`art/**`（底图经 `CardArt`）、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII、`.tscn` 不出现中文。
5. 不写颜色字面量（碎片描边、接缝提示只用配色键）。
6. 随机只用 `JevRng.draw(params.seed, "c.mg.fragments.layout" / "c.mg.decode.layout", [i])`；不加 `class_name`（两个冻结类除外）；不加 autoload/InputMap。
7. 不发 `first_time`；只发 `mg_tool`。

## 接口

**用到**：`CardMiniGame`（§8.1）；参数（§8.2 公共字段 + `fragments` / `decode` 专有字段）；`JevRng.draw`；`CardDB.read_json`（只读电码本骨架的 `key`）；`CardArt`、`CardText.t/ui/obs`、`CardTheme`、`CardAnchors`；`CardBus.ui_event`。

**提供（冻结）**：`CardFragmentsGame`（`res://scenes/cards/minigames/fragments/FragmentsGame.tscn`）、`CardDecodeGame`（`res://scenes/cards/minigames/decode/DecodeGame.tscn`）；观察键目录 `obs/fragments.json`、`obs/decode.json`。

## 新手指引

- **必须登记的锚点**：`a.mg.fragments.main`（整块）`a.mg.fragments.board`（拼的那块桌面）`a.mg.fragments.seal`（看印章的按钮/区域）`a.mg.decode.main`（整块）`a.mg.decode.book`（电码本）。
- **必须发的 ui_event**：`mg_tool {kind: "fragments"|"decode", tool}`。
- **first-time**：不发；依赖 `mg.fragments` `mg.decode`。
- **要证明会亮的步骤**：`gd.mg.fragments`（第一次出拼碎片 → `a.mg.fragments.board`；教的人默认 `obj.brother_ledger`）、`gd.mg.decode`（第一次出解密 → `a.mg.decode.book`；教的人 `postman` 何启明）。
- **测试做法**：实例化场景、`start(<夹具参数>)`；挂指引（`GuideOverlay.tscn`，`bind(mock, bus)` → `force(true)` → `skip_fades = true` → `load_steps(<本目录 guide_steps.json>)`）；`bus.first_time.emit(&"mg.fragments", {"uid": …})` → `evaluate_now()` → `active_step() == "gd.mg.fragments"`；拖一块（`mg_tool`）后完成；解密同理。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C15.txt`：

```
# C15 拼碎片与解密（docs/handoff_cards/C15_mg-fragments-decode.md）
C15_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/minigames/obs/fragments.json,data/cards/minigames/obs/decode.json --name=C15_validate
C15_fragments|res://scripts/tests/cards/C15/test_fragments.gd|120|
C15_decode|res://scripts/tests/cards/C15/test_decode.gd|120|
C15_determinism|res://scripts/tests/cards/C15/test_determinism.gd|120|
C15_no_legacy|res://scripts/tests/cards/C15/test_no_legacy.gd|60|
C15_guide|res://scripts/tests/cards/C15/test_guide.gd|120|
```

| 测试 | 通过条件 |
|---|---|
| `C15_validate` | 两个观察键目录过校验器（V23） |
| `test_fragments.gd` | 6 片全拼上后 `placed = 6`；看印章 → `seal_checked`、观察含 `seal_offset`（`seal_offset_px > 0` 时）；缺一块的夹具有 `piece_missing`；`autoplay(0.2)` 与 `autoplay(0.9)` 清晰度不同；Esc → `aborted: true` |
| `test_decode.gd` | 译出的码各有一条观察；电码本里显示的词来自 `CardText.t(cb.word.<码>)`；`lookups` `decoded` 整数；`autoplay` 两档清晰度不同 |
| `test_determinism.gd` | 两个插件：同参数 + 同一串操作两遍结果相同；同参数的碎片切法相同（只用 `c.mg.*.layout`） |
| `test_no_legacy.gd` | 静态扫描自己的 `.gd`：不出现 `data/codebook.json`、不读 `scripts/ui/telegraph_panel.gd`；结果字典只有 §8.1 的五个键；观察键都在目录里、无判词；界面没有 `%`、`t.all_text_from_cardtext()` 为空（电码数字只由数字组成，合格） |
| `test_guide.gd` | 两个步骤按做法亮、完成；五个锚点 `t.anchor_ok()` |

另：每帧 CPU ≤ 4 ms（拖动时测，PR 列数）；面板 ≤ 1100×640；无头无报错。

- **W2 加**：`test_real_engine.gd`（真引擎、例子集：手上的 `tk.1938.de196` → `mg.request {uid, item: ""}` → G04 给的参数 → `autoplay(0.8)` → `mg.report` 成功、记成外来当票）；清单加一行 `C15_guide_k16|res://scripts/tests/cards/C15/test_guide.gd|180|--steps=k16 --name=C15_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）；K11 的电码本合入后加一条“观察键目录覆盖电码本所有码”的检查。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C15 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C15/shot_fragments_decode.gd -- --out=/tmp/shots/C15
  ```
- **截图**（不进清单）：当票打乱、拼了一半、拼好看印章、缺一块；电报开局、翻电码本、译了一半各一张；`guide_gd.mg.fragments.png`、`guide_gd.mg.decode.png`。1280×720 画面截图（1.3：小游戏叠在柜台画面上拍，见上方“10-13 变更二”）；上传 PR 或提交到 `scripts/tests/cards/C15/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：底图整数倍、NEAREST；碎片描边是代码画的、只用配色键；面板 ≤ 1100×640。

## 交付

- PR 标题 `[C15] <中文摘要>`（可以拼碎片、解密各开一个 PR），目标 `claude/festive-ride-vud32a`。建议：①拼碎片插件 + 观察目录 + 测试；②解密插件 + 观察目录 + 测试；③截图、键盘；④（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；**用到的 JevRng 域：`c.mg.fragments.layout`、`c.mg.decode.layout`**；锚点、`mg_tool`、依赖的 first-time；给 A 的观察句与电码本词的待写清单（键）；性能数；“回报”。

## 审核（Claude 重点）

- 没读、没拷 `data/codebook.json` 和旧面板文字；电码本的词只经 `CardText`。
- 观察无判词；同参数同操作同结果；随机只用两个登记过的域。
- 当票号用 `g04.ticket.number`；没有中文/颜色字面量。

## 回报（执行者填写）

> 执行者**不要改本文件**。把下表贴在 PR 描述最后一节“回报”。

| 项 | 填写 |
|---|---|
| 分支 / PR 链接 | |
| 做了什么（文件 → 内容） | |
| 测试结果（贴最后 20 行） | |
| 截图 | |
| 登记的锚点 / mg_tool / 证明会亮的步骤 | |
| 观察键清单（给 A） | |
| 性能实测 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 遗留 / 没做 | |
