# C12 `mg-spot` · 找不同（从旧验货面板分出来）

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C12 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C12: …` 报给 Claude。

> **鉴定改版（主创 10-25：“你那个鉴定不能只是点点点，要玩家看出来才算数”）**：本卡下文凡和合同 §3.3、§4.8、§8、附录 H 对不上的，以合同为准。找不同改成“点出那一处、说旧痕还是不一样”：参数多了 `marks[].look` `marks[].at` `legend` `lens_px` `blink`，`atlas_open` 起手是 false，每件固定 3 处痕迹；结果交 `measures.spots [[x, y, tag]]`（1 旧痕、2 不一样）；不画部位框、不按对错着色；新锚点 `a.mg.spot.tag`。下文“圈一圈、按参数给结论、分钟 = 笔数 × 2”的旧说法作废。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 12**（在第 12 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C12`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）：小游戏基类 `CardMiniGame`、宿主 `CardMiniGameHost`（C01，W0 版能用）、`day_counter` 夹具（金簪的布局由真 `ItemGen` 生成并按 §8.2 转好，不用等 G04）。
- **波次（Wave）**：W1 开发并合入；W2 补对真引擎（G04 的 `CardAppraisal` 给的参数、K11 的物品数据）的集成测试和 K16 步骤复测。第 1 天的教学客人固定出找不同，所以这是新手第一次见到的小游戏。

## 分支

`cards/C12-mg-spot`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

把旧版“对图鉴找不同”的验货玩法做成卡牌版的小游戏插件 `CardSpotGame`：对照图鉴，在东西上画圈，圈出和图鉴不一样的地方、旧痕；放大镜看细处；墨有限（每笔约两分钟）。**只给观察，不给结论**：结果是观察键 `obs.spot.<部位>.<differs|wear|plain|unclear>`，永远不说“真/假/仿”；参数只有**布局**（部位矩形、哪种工具看得出、痕迹的样子），没有 `tell`/`fake`。旧的 `scripts/ui/appraise_panel.gd` 不实例化、不改——它按 `tell` 把圈中的地方涂红、数“还剩几处”、有“我看这是假货”勾选、提示句写死中文，全都违反红线 1 和 5。

## 必读

1. `docs/cards/DESIGN_cards.md` §三.2（鉴定小游戏：随机出、永远不直接告诉你真假、客人有耐心）、§九.4（第 1 天哥哥在柜台教找不同）。
2. `docs/cards/CARDS_INTERFACES.md`：§0（红线 1、5）、§1.2、§3.3 C12、§4.8（观察键目录格式、键里不许出现判词英文）、§6.3（随机域 `c.mg.spot.layout`，键 `[i]`，种子 `params.seed`）、§7.10.5（锚点、`mg_tool`）、§8（插件接口、参数只有物理量和摆设、`spot` 的参数与 `measures`、禁用键、结果格式、Esc = `abort()`）、§11.2、§12.2（C12–C15 必须有的测试）、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/api/card_minigame.gd`（冻结基类）、`scripts/cards/minigames/spot/spot_game.gd` 与 `scenes/cards/minigames/spot/SpotGame.tscn`（W0 桩，继承示例插件）、`scripts/cards/mock/example_minigame.gd`（示例：`start` / `autoplay` / `finished` 的写法）、`scripts/cards/ui/table/minigame_host.gd`、`scripts/cards/mock/fixtures/day_counter.json`（`mg.request` 回应里的 `params`：`parts` `marks` `atlas_art` `ink` `tools` `atlas_open` `seed`）。
4. 只读、只 `preload` 来算和画（不改）：`scripts/core/appraise.gd`（`fit_circle(points)`、`part_rect(p)`、`hit_test(item, center, radius, tool, revealed)`——传 `{"parts": params.parts}` 当 item，工具名照参数里的 `eye` / `lens` / `atlas`）、`scripts/core/flaw_render.gd`（`apply(img, f, seed, rect)` 等画痕迹的函数）。只读参考做法、**不实例化、不拷文字**：`scripts/ui/appraise_panel.gd`（第 306 行“假货”勾选、第 381 行按 `tell` 涂红、第 434 行数 `tells_left`——这些都不要）。

## 要做的事

- [ ] **CardSpotGame**（`spot_game.gd`，`class_name CardSpotGame`，**改成 `extends CardMiniGame`**，不再继承示例插件）：`kind()` → `&"spot"`；`start(params)` 只用参数搭局面（不读引擎、不读存档、不读物品模板的文字）；`autoplay(skill)`；`abort()` 用基类的；`minutes_spent()` = 笔数 × 2。
- [ ] **spot_panel.gd**（`scripts/cards/minigames/spot/spot_panel.gd`，`preload`，不写 `class_name`；从旧面板“分”出来的部分**重写**）：
  - 左：东西的图（`CardArt.texture(params.art)`，64×64 整数倍放大，例 ×6 = 384，NEAREST），上面按 `marks` 画痕迹（`differs` 和图鉴不一样 / `wear` 旧痕；`fine` 越大越细微；`seed` 给 `FlawRender`；把 `marks` 转成 `FlawRender` 认的形状，转不了的部分自己用配色键画，**不改 `flaw_render.gd`**）。右：图鉴（`atlas_art`，`atlas_open` 为假时要先翻开，翻开是一次工具使用）。
  - 画圈：鼠标拖一笔 → `Appraise.fit_circle(points)` → `Appraise.hit_test({"parts": params.parts}, center, radius, tool, revealed)`；每笔扣一格墨（`ink` 格，墨尽为止）；圈中的部位记下“看过了”，**不着色、不说对错、不数还剩几处、没有“我看是假货”**。
  - 工具：肉眼 `eye`（默认）、放大镜 `lens`（跟着鼠标的放大圈，细微的痕迹只有它看得清）、图鉴 `atlas`（翻开/合上）；只给 `params.tools` 里有的；每次用工具发 `ui_event("mg_tool", {"kind": "spot", "tool": <名>})`。
  - “看完了” → 交结果。Esc → `abort()`。
  - 文字全走 `CardText`（工具名、按钮、墨的说明用本任务的界面键 `c12.*`），**没有任何教学文字和提示句**。
- [ ] **结果**（`finished` 发出一次）：`{"quality_permille": <0–1000 整数>, "observations": [...], "minutes": 笔数 × 2, "measures": {"strokes": n, "hits": n}, "aborted": false}`。观察：每个**圈过**的部位一条——那里有 `differs` 痕迹且用对了工具（细微的要放大镜、要和翻开的图鉴比）→ `obs.spot.<部位>.differs`；有 `wear` → `.wear`；什么都没有 → `.plain`；工具不对或圈得太偏 → `.unclear`。`quality_permille` 由“圈中/笔数”和工具用得对不对算（整数）。小游戏内部可以用浮点，交出来一律整数。
- [ ] **autoplay(skill)**：走和玩家**同一条代码路径**（生成一串圈的点 → 同一个判圈函数）：按部位顺序，skill 高就圈得准、先翻图鉴、细微处用放大镜；skill 低就圈偏、不用放大镜。要随机就只用 `JevRng.draw(params.seed, "c.mg.spot.layout", [i])`；同样的参数 + 同样的 skill → 同样的结果。`autoplay(0.2)` 和 `autoplay(0.9)` 给出的观察清晰度不同。
- [ ] **观察键目录** `data/cards/minigames/obs/spot.json`（§4.8 格式：`{"_meta": {"owner": "C12", "schema": 1, "kind": "spot", "_provenance": {...}}, "obs": {...}}`）：物品模板的部位表里出现的**每个部位 id** × `differs` `wear` `plain` `unclear`；`fidelity`：`differs`/`wear`/`plain` 为 `clear`，`unclear` 为 `vague`（可以按需要加 `partial` 的变体）；`brief` 只写“这一处和图鉴不一样”这类观察的意思，**不写判词、不写成观察句正文**（正文由 A 写在 `data/cards/text/minigames/obs/spot.text.json`）。部位 id 从 `data/town/item_templates.json` 的部位表（和 K11 的 `templates_extra.json`）收集——写一个小脚本列全，脚本放测试目录。注意：旧模板里有 `authenticity` `provenance` 这类部位 id，只当键用，**界面上从不显示部位 id**。
- [ ] **键盘可玩**：方向键移动准星、`+`/`-` 调圈大小、Enter 落一笔、L 放大镜、A 图鉴、F 看完了、Esc 放弃。
- [ ] **界面键** `data/cards/ui_keys/C12.json`（`c12.` 开头，键 + `brief`，`_meta._provenance`）：`c12.tool.<eye|lens|atlas>` `c12.ink` `c12.btn.done` `c12.btn.atlas_open` `c12.title`。
- [ ] **参数夹具**（`scripts/tests/cards/C12/fixtures/`）：`hairpin.json`（直接取 `day_counter` 夹具里 `mg.request` 回应的 `params`）、`scroll.json`（字画）、`rice.json`（米：只有 `plain`）、`fine_only.json`（只有 `fine` 很大的痕迹，要放大镜）、`no_atlas.json`（`atlas_open: false`）。参数里只放 §8.2 允许的键。

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

- `scenes/cards/minigames/spot/**`、`scripts/cards/minigames/spot/**`、`data/cards/minigames/obs/spot.json`
- 默认拥有：`scripts/tests/cards/C12/**`、`scripts/tests/cards/suites/C12.txt`、`data/cards/tags/C12.json`、`data/cards/ui_keys/C12.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. **不改任何旧文件**：`scripts/ui/appraise_panel.gd`、`scripts/core/appraise.gd`、`scripts/core/flaw_render.gd`、`data/town/**`、`art/items/**` 只读；不实例化 `appraise_panel.gd`。也不改 `scripts/cards/api/**`、`mock/**`（含 `example_minigame.gd`）、C01 的宿主。
2. **不判真假**：结果里永远没有判词；观察键里不出现 `fake` `real` `genuine` `forged` `true` `false` `authentic`；不按 `tell`/`benign` 着色；不数“还剩几处”；不读参数里的 `tell` `fake` `est` 等禁用键（参数里本来就不该有，有了也不许用）。
3. **不写最终内容**：观察句、工具名、按钮字由人写；不拷旧面板的任何中文（提示句、批注、“墨（每笔约两分钟）”等）；不碰 `data/cards/text/**`、`art/**`（东西和图鉴的图经 `CardArt`）、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII、`.tscn` 不出现中文。
4. 不写颜色字面量（圈、墨、放大镜框、痕迹的补画都用配色键）。
5. 随机只用 `JevRng.draw(params.seed, "c.mg.spot.layout", [i])`；不用 `randf/randi/RandomNumberGenerator/Time` 影响结果。
6. 不加 `class_name`（`CardSpotGame` 除外）；不加 autoload/InputMap。
7. 不发 `first_time`；只发 `mg_tool`。

## 接口

**用到**：`CardMiniGame`（§8.1：`signal finished(result)`、`kind()`、`start(params)`、`autoplay(skill)`、`abort()`、`minutes_spent()`）；参数（§8.2 公共字段 + `spot` 的 `parts` `marks` `atlas_art` `ink` `tools` `atlas_open`）；`Appraise.fit_circle/part_rect/hit_test`、`FlawRender` 的画图函数（`preload`）；`JevRng.draw`；`CardArt`、`CardText.ui/obs`、`CardTheme`、`CardAnchors`；`CardBus.ui_event`（`get_node_or_null("/root/CardBus")`，测试里注入）。

**提供（冻结）**：`CardSpotGame`（`res://scenes/cards/minigames/spot/SpotGame.tscn`）；观察键目录 `obs/spot.json`。

## 新手指引

- **必须登记的锚点**：`a.mg.spot.main`（整块小游戏）`a.mg.spot.atlas`（图鉴）`a.mg.spot.lens`（放大镜按钮）。
- **必须发的 ui_event**：`mg_tool {kind: "spot", tool}`（每次用工具）。
- **first-time**：不发；依赖 `mg.spot`（G04 在第一次出找不同时发）。
- **要证明会亮的步骤**：`gd.d1.spot`（第一次出找不同 → `a.mg.spot.atlas`，备用 `a.mg.spot.main`；完成于 `ui:mg_tool` 或超时，以 K16 的数据为准）。
- **测试做法**：把 `SpotGame.tscn` 实例化进测试场景（或用牌桌宿主 + `day_counter` 夹具发 `mg.request`），`start(<hairpin params>)`；挂指引（`GuideOverlay.tscn`，`bind(mock, bus)` → `force(true)` → `skip_fades = true` → `load_steps(<本目录 guide_steps.json>)`）；`bus.first_time.emit(&"mg.spot", {"uid": …})` → `evaluate_now()` → `active_step() == "gd.d1.spot"`；翻开图鉴（发 `mg_tool`）后完成。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C12.txt`：

```
# C12 找不同（docs/handoff_cards/C12_mg-spot.md）
C12_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/minigames/obs/spot.json --name=C12_validate
C12_determinism|res://scripts/tests/cards/C12/test_determinism.gd|120|
C12_fidelity|res://scripts/tests/cards/C12/test_fidelity.gd|120|
C12_no_verdict|res://scripts/tests/cards/C12/test_no_verdict.gd|120|
C12_controls|res://scripts/tests/cards/C12/test_controls.gd|120|
C12_guide|res://scripts/tests/cards/C12/test_guide.gd|120|
```

| 测试 | 通过条件 |
|---|---|
| `C12_validate` | 观察键目录过校验器（V23：键前缀、无判词、`fidelity` 合法） |
| `test_determinism.gd` | 每个参数夹具：同样的参数 + 同样的一串操作（模拟鼠标笔画）跑两遍，结果完全相同；`autoplay(0.6)` 跑两遍相同 |
| `test_fidelity.gd` | `autoplay(0.2)` 和 `autoplay(0.9)` 的观察清晰度不同（按目录里的 `fidelity` 比较）；`quality_permille` 是 0–1000 的整数；`minutes` = 笔数 × 2；`measures` 只有整数 `strokes` `hits` |
| `test_no_verdict.gd` | 结果里每个观察键都在 `obs/spot.json` 里；没有判词；静态扫描自己的 `.gd`：不出现 `"tell"` `"fake"` `"benign"` `"est"` 等禁用键名的读取；结果字典只有 §8.1 的五个键 |
| `test_controls.gd` | 键盘能玩完一局；Esc → `finished` 的 `aborted: true`、观察为空；每次用工具都有 `mg_tool`；墨尽后不能再落笔；界面上没有 `%`、`t.all_text_from_cardtext()` 为空 |
| `test_guide.gd` | `gd.d1.spot` 按做法亮、完成；三个锚点 `t.anchor_ok()` |

另：每帧 CPU ≤ 4 ms（测 60 帧取最大，PR 列数）；面板 ≤ 1100×640；无头运行没有报错。

- **W2 加**：`test_real_engine.gd`（真引擎、例子集：第 1 天教学客人 `mg.request` → G04 给的参数 → `autoplay(0.8)` → `mg.report` 成功、观察记到物品上）；清单加一行 `C12_guide_k16|res://scripts/tests/cards/C12/test_guide.gd|180|--steps=k16 --name=C12_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C12 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C12/shot_spot.gd -- --out=/tmp/shots/C12
  ```
- **截图**（不进清单）：金簪（图鉴合上、翻开、放大镜、画了三笔、墨尽）、字画、米各一张；`shot_guide.gd` 的 `guide_gd.d1.spot.png`。1280×720 画面截图（1.3：小游戏叠在柜台画面上拍，见上方“10-13 变更二”）；上传 PR 或提交到 `scripts/tests/cards/C12/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：物品图整数倍放大、NEAREST；圈和墨是“毛笔”的样子但只用配色键；没有红色标出“破绽”。

## 交付

- PR 标题 `[C12] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①插件骨架 + 判圈 + 结果 + 观察目录 + 测试；②放大镜、图鉴、痕迹绘制、键盘、截图；③（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；**用到的 JevRng 域：`c.mg.spot.layout`**；锚点、`mg_tool`、依赖的 first-time；从旧面板分出了哪些做法、去掉了哪些（逐条）；给 A 的观察句待写清单（键列表）；性能数；“回报”。

## 审核（Claude 重点）

- 没有改、没有实例化任何旧文件；没有 `tell` 着色、剩几处、假货勾选、提示句。
- 结果只有观察键和整数；观察键在目录里、无判词；参数只读布局。
- 同参数同操作同结果；`autoplay` 两档清晰度不同；随机只用 `c.mg.spot.layout`。

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
