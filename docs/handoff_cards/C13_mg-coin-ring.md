# C13 `mg-coin-ring` · 吹银元

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C13 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C13: …` 报给 Claude。

> **鉴定改版（主创 10-25：“你那个鉴定不能只是点点点，要玩家看出来才算数”）**：本卡下文凡和合同 §3.3、§4.8、§8、附录 H 对不上的，以合同为准。吹银元去掉时机条：两枚样洋（`samples`，先足银 `good` 后哑板 `dull`）和客人的一枚或一摞（`coins` 最多 5），点哪枚吹哪枚、余音画成线留淡影（`ghosts`），两枚相碰（`clink`）；玩家自己说像哪个（`measures.call` 1/2/3），一摞一枚枚标（`measures.marks` 0/1/2）；新锚点 `a.mg.coin_ring.samples`。下文“按住松开的时机、贴耳、对标准声”的旧说法作废。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 13**（在第 13 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C13`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）：小游戏基类 `CardMiniGame`、宿主 `CardMiniGameHost`（C01）。参数格式 §8.2 已定，W1 用自己写的参数夹具；W2 接 G04 给的真参数（物理量由 K11 的 `it.silver.*` 规格算出）。正式声音样本由 B 录（W3），在那之前开发版用运行时合成的占位声。
- **波次（Wave）**：W1 开发并合入；W2 补对真引擎的集成测试和 K16 步骤复测。

## 分支

`cards/C13-mg-coin-ring`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

银元的鉴定小游戏：捏住银元、吹一下（按住松开的时机）、贴到耳边听余音——声音的长短、高低、杂音用**波形和声音**表现；可以和标准银元对比，一摞里的两枚可以相碰。**只给观察**：“余音细长”“短而闷”“有杂音”“和标准的差不多”“没听清”这一类观察键，永远不说“真/假/掺铜”。

## 必读

1. `docs/cards/DESIGN_cards.md` §三.2（吹银元：捏住吹一下放到耳边，听长短高低，和标准声比）、附录“史实核对与来源”（银元按枚计价、一般不称）。
2. `docs/cards/CARDS_INTERFACES.md`：§0（红线 1：音频——Steam 版只放 B 录的样本，运行时合成只在 `!CardShip.is_ship()` 时允许；红线 5）、§3.3 C13、§4.7.15（`it.silver.yuan_a` 的规格只有引擎读）、§4.8（观察键目录、无判词）、§6.3（随机域 `c.mg.coin_ring.layout`）、§7.10.5、§8（插件接口；`coin_ring` 参数 `coins[{id, ring_ms, pitch_cents, buzz}]`、`reference{ring_ms, pitch_cents, buzz}`、`tries`；`measures`：`listened_ms` `compared` `clinked`；无头运行用 Dummy 音频驱动不报错）、§11.2、§11.4 第 5 条（占位音频合成要有 `is_ship()` 守卫，审核静态检查）、§12.2、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/api/{card_minigame,card_ship}.gd`、`scripts/cards/minigames/coin_ring/coin_ring_game.gd` 与 `scenes/cards/minigames/coin_ring/CoinRingGame.tscn`（W0 桩）、`scripts/cards/mock/example_minigame.gd`、`scripts/cards/ui/table/minigame_host.gd`、`data/cards/_examples/minigames/items.json`（`it.silver.yuan_a` 的规格范围，只用来编测试参数）。
4. 只读参考：`scripts/ui/beeper.gd`（旧版运行时合成声音的做法；**它在旧版里，不受 `is_ship()` 守卫，你的代码要自己加守卫**）。

## 要做的事

- [ ] **CardCoinRingGame**（`coin_ring_game.gd`，`class_name CardCoinRingGame`，**改成 `extends CardMiniGame`**）：`kind()` → `&"coin_ring"`；`start(params)` 只用参数；`autoplay(skill)`；`abort()` 用基类的；分钟数按操作次数算（例：每吹一次 1 分钟，`minutes_per_step` 为单位，不超过 `max_minutes`）。
- [ ] **玩法**（文字全走 `CardText`，本任务的键 `c13.*`）：
  - 捏住（按住鼠标或 Space）→ 松开吹；松开时机落在“好”的窗口里才吹得响（窗口位置由 `JevRng.draw(params.seed, "c.mg.coin_ring.layout", [i])` 摆，影响手感不影响物理量）；吹不好就是一次“没听清”。
  - 贴耳听（E 或“听”按钮）：播声音 + 画波形：长度 ∝ `ring_ms`、音高偏移 = `pitch_cents`、杂音 = `buzz`；`listened_ms` 累计。
  - 和标准比（R）：听 `reference`，画在同一张图上（另一条线），`compared = true`。
  - 两枚相碰（C，`coins` 多于一枚时）：`clinked = true`。
  - `tries` 用完只能交。
  - 每用一个动作发 `ui_event("mg_tool", {"kind": "coin_ring", "tool": "blow"|"ear"|"compare"|"clink"})`。
  - Esc → `abort()`。
- [ ] **声音**：
  - 发行版：只用 B 录的样本 `res://audio/cards/sfx/coin_ring_*.ogg`（用 `AudioStreamPlayer` 的 `pitch_scale` 和音量包络改音高、衰减）；样本不存在就不出声（只画波形），不报错。
  - 开发版：样本不存在时用运行时合成的占位声（`AudioStreamGenerator`：一个随 `ring_ms` 衰减的正弦 + 按 `buzz` 加的噪声），**整段合成代码只在 `if not CardShip.is_ship():` 里可达**（K15 的审核会静态检查这个守卫）。
  - 无头运行（`--headless`，Dummy 音频驱动）不报任何错误、不卡住；测试里不依赖真的听到声音。**无头或 Dummy 驱动时不建 `AudioStreamGenerator`**（旧版 `scripts/ui/beeper.gd` 的 `_ready()` 开头就是这么做的：哑驱动下生成器退出时会残留，测试会因泄漏失败），只画波形、照样记 `listened_ms`。
- [ ] **波形**：代码画（`draw_polyline`），只用配色键（K12 的 `ART_SPEC.md` 写明：代码画的小游戏画面算代码，不算美术，但只许用调色板键）。银元图经 `CardArt`（`params.art`，整数倍放大、NEAREST）。
- [ ] **结果**：`{"quality_permille": <整数>, "observations": [...], "minutes": n, "measures": {"listened_ms": n, "compared": bool, "clinked": bool}, "aborted": false}`；观察按物理量与玩家的操作给（例：听清了 → 按 `ring_ms` 长短、`buzz` 大小、`pitch_cents` 高低给对应的键；和标准比过 → 加“和标准的比”一类键；没吹好/没听 → `unsure`）；`quality_permille` 由吹得好不好、听了多久、比没比算。
- [ ] **autoplay(skill)**：走和玩家同一条代码路径（模拟按住、松开、听、比）；skill 高 → 时机准、会对比；skill 低 → 时机偏、不对比。`autoplay(0.2)` 与 `autoplay(0.8)` 给出清晰度不同的观察；同参数同 skill 同结果。
- [ ] **观察键目录** `data/cards/minigames/obs/coin_ring.json`（`{"_meta": {"owner": "C13", "schema": 1, "kind": "coin_ring", "_provenance": {...}}, "obs": {...}}`）：键以 `obs.coin_ring.` 开头，无判词英文（例：`ring_long` `ring_short` `dull` `buzzy` `pitch_low` `like_reference` `unlike_reference` `ring_vague` `unsure`）；每个带 `fidelity` 与 `brief`（只写观察的意思，不写成观察句正文，不写判词）。
- [ ] **键盘可玩**：Space 按住/松开吹、E 听、R 比、C 碰、F 交、Esc 放弃。
- [ ] **界面键** `data/cards/ui_keys/C13.json`（`c13.` 开头，键 + `brief`，`_meta._provenance`）：`c13.title` `c13.tool.<blow|ear|compare|clink>` `c13.btn.done` `c13.tries`。
- [ ] **参数夹具**（`scripts/tests/cards/C13/fixtures/`）：`good.json`（余音长、杂音小）、`bad.json`（短、闷、杂音大、音低）、`stack.json`（三枚，一枚不同）、`one_try.json`。只放 §8.2 允许的键。

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

- `scenes/cards/minigames/coin_ring/**`、`scripts/cards/minigames/coin_ring/**`、`data/cards/minigames/obs/coin_ring.json`
- 默认拥有：`scripts/tests/cards/C13/**`、`scripts/tests/cards/suites/C13.txt`、`data/cards/tags/C13.json`、`data/cards/ui_keys/C13.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（`scripts/cards/api/**`、`mock/**`、C01 的宿主、`scripts/ui/beeper.gd` 等旧代码、`data/cards/minigames/items.json`（归 K11））。
2. **不做正式音频**：不往 `audio/cards/**` 放任何文件（那是 B 的）；不往 `audio/_placeholder/**` 放文件（归 K12）；占位声只能运行时合成且有 `is_ship()` 守卫。
3. **不判真假**：观察键无判词；不显示“足银/掺铜”；不把 `ring_ms` `pitch_cents` `buzz` 的数字写在界面上（只用声音和波形表现）。
4. **不写最终内容**：观察句、按钮字由人写；不碰 `data/cards/text/**`、`art/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII、`.tscn` 不出现中文。
5. 不写颜色字面量（波形、底色只用配色键）。
6. 随机只用 `JevRng.draw(params.seed, "c.mg.coin_ring.layout", [i])`；不加 `class_name`（`CardCoinRingGame` 除外）；不加 autoload/InputMap/音频总线设置（`project.godot` 不许改）。
7. 不发 `first_time`；只发 `mg_tool`。

## 接口

**用到**：`CardMiniGame`（§8.1）；参数（§8.2 公共字段 + `coins` `reference` `tries`）；`CardShip.is_ship()`；`JevRng.draw`；`CardArt`、`CardText.ui/obs`、`CardTheme`、`CardAnchors`；`CardBus.ui_event`。

**提供（冻结）**：`CardCoinRingGame`（`res://scenes/cards/minigames/coin_ring/CoinRingGame.tscn`）；观察键目录 `obs/coin_ring.json`。

## 新手指引

- **必须登记的锚点**：`a.mg.coin_ring.main`（整块）`a.mg.coin_ring.blow`（吹的按钮/银元）`a.mg.coin_ring.ear`（听的按钮/波形）。
- **必须发的 ui_event**：`mg_tool {kind: "coin_ring", tool}`。
- **first-time**：不发；依赖 `mg.coin_ring`。
- **要证明会亮的步骤**：`gd.mg.coin_ring`（第一次出吹银元 → `a.mg.coin_ring.blow`；教的人默认 `obj.brother_ledger`）。
- **测试做法**：实例化 `CoinRingGame.tscn`、`start(<good params>)`；挂指引（`GuideOverlay.tscn`，`bind(mock, bus)` → `force(true)` → `skip_fades = true` → `load_steps(<本目录 guide_steps.json>)`）；`bus.first_time.emit(&"mg.coin_ring", {"uid": …})` → `evaluate_now()` → `active_step() == "gd.mg.coin_ring"`；吹一次（`mg_tool`）后完成。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C13.txt`：

```
# C13 吹银元（docs/handoff_cards/C13_mg-coin-ring.md）
C13_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/minigames/obs/coin_ring.json --name=C13_validate
C13_determinism|res://scripts/tests/cards/C13/test_determinism.gd|120|
C13_fidelity|res://scripts/tests/cards/C13/test_fidelity.gd|120|
C13_audio_guard|res://scripts/tests/cards/C13/test_audio_guard.gd|120|
C13_controls|res://scripts/tests/cards/C13/test_controls.gd|120|
C13_guide|res://scripts/tests/cards/C13/test_guide.gd|120|
```

| 测试 | 通过条件 |
|---|---|
| `C13_validate` | 观察键目录过校验器（V23） |
| `test_determinism.gd` | 同参数 + 同一串操作（模拟按键时序，按帧推进，不用墙钟）两遍结果相同；`autoplay(0.5)` 两遍相同 |
| `test_fidelity.gd` | `autoplay(0.2)` 与 `autoplay(0.8)` 观察清晰度不同；结果键只有 §8.1 的五个；`quality_permille` 整数；观察键都在目录里、无判词 |
| `test_audio_guard.gd` | 无头运行整局没有任何 ERROR/WARNING；静态扫描自己的 `.gd`：创建 `AudioStreamGenerator` / 往缓冲推样本的代码都在 `if not CardShip.is_ship()` 分支里；样本路径只在 `audio/cards/sfx/` 下 |
| `test_controls.gd` | 键盘能玩完一局；`tries` 用完只能交；Esc → `aborted: true`；每个动作有 `mg_tool`；界面上没有数字（`tries` 可以用图标表示）和 `%`；`t.all_text_from_cardtext()` 为空 |
| `test_guide.gd` | `gd.mg.coin_ring` 按做法亮、完成；三个锚点 `t.anchor_ok()` |

另：每帧 CPU ≤ 4 ms（PR 列数）；面板 ≤ 1100×640。

- **W2 加**：`test_real_engine.gd`（真引擎：来当银元的客人 → `mg.request` → G04 的参数 → `autoplay(0.8)` → `mg.report` 成功）；清单加一行 `C13_guide_k16|res://scripts/tests/cards/C13/test_guide.gd|180|--steps=k16 --name=C13_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C13 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C13/shot_coin_ring.gd -- --out=/tmp/shots/C13
  ```
- **截图**（不进清单）：开局、吹的时机条、听（波形）、和标准对比（两条线）、一摞相碰各一张；`guide_gd.mg.coin_ring.png`。1280×720 画面截图（1.3：小游戏叠在柜台画面上拍，见上方“10-13 变更二”）；上传 PR 或提交到 `scripts/tests/cards/C13/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：银元图整数倍、NEAREST；波形线宽一致、只用配色键；面板 ≤ 1100×640。

## 交付

- PR 标题 `[C13] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①插件骨架 + 结果 + 观察目录 + 波形 + 测试；②声音（样本优先、开发版合成）、对比与相碰、截图；③（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；**用到的 JevRng 域：`c.mg.coin_ring.layout`**；锚点、`mg_tool`、依赖的 first-time；给 B 的音频需求（样本文件名、长度、几种）；给 A 的观察句待写清单；性能数；“回报”。

## 审核（Claude 重点）

- 合成占位声全在 `is_ship()` 守卫里；没有往 `audio/**` 放文件；无头无报错。
- 观察无判词、界面上没有物理量的数字；同参数同操作同结果。
- 随机只用 `c.mg.coin_ring.layout`。

## 回报（执行者填写）

> 执行者**不要改本文件**。把下表贴在 PR 描述最后一节“回报”。

| 项 | 填写 |
|---|---|
| 分支 / PR 链接 | |
| 做了什么（文件 → 内容） | |
| 测试结果（贴最后 20 行） | |
| 截图 | |
| 登记的锚点 / mg_tool / 证明会亮的步骤 | |
| 观察键清单（给 A）/ 音频需求（给 B） | |
| 性能实测 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 遗留 / 没做 | |
