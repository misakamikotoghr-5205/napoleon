# X02 `w0-sync-1.3` · W0 骨架按合同 1.3（画面与对话）同步

## 执行者
**待主创指派**（建议：一条空闲的 GPT 或 Cursor 线）。这些文件平时归 Claude（W0）；本任务期间按 `docs/cards/ownership.json` 的 `X02` 一栏归执行者，合入后归还 Claude。

## 为什么有这个任务
10-13 晚主创定了新画面方向（合同 1.3、DESIGN §九.6、原型 `docs/cards/prototype/`）。文档、合同、38 张任务卡已经改完并合入；W0 骨架代码的同步（新控件的接口基类与桩、`CardLayout`、Mock 视图的 `stage`、校验器的 `check_stage`、测试）还没做，由本任务补上。**C01、C02、C03、C04、C16 等界面线要用这里的接口基类和桩**——在本任务合入前，它们照合同 §7.11 的冻结签名先写自己的实现，合入后再接上。

## 分支与提审
从集成分支 `claude/festive-ride-vud32a` 最新提交切 `cards/X02-w0-sync-13`，PR 标题 `[X02] W0 骨架按合同 1.3 同步`，按 README §6 提审。**一个 PR 交完。**

## 必读
1. `docs/cards/CARDS_INTERFACES.md`：§1.2（1.3 改写）、§4.7.24（演出块 stage）、§7.5 视图、§7.8 面板表“呈现”一列、§7.10.4 / §7.10.5（锚点与界面事件，1.3）、**§7.11（画面与演出，全部）**、附录 G（1.3 修订）。
2. `docs/cards/DESIGN_cards.md` §九.6；原型 `docs/cards/prototype/README.md` 与截图。
3. 现有 W0 代码：`scripts/cards/api/card_ids.gd`、`dsl_shapes.gd`、`scripts/cards/ui/common/**`、`scripts/cards/mock/**`、`scripts/tests/cards/W0/**`、`scripts/tests/cards/lib/card_t.gd`。

## 验收
- `GODOT=<Godot 4.7> JOBS=3 bash tools/run_card_tests.sh` 与 `bash tools/run_legacy_smoke.sh` 全绿（任何 WARNING / ERROR 都算失败）；新桩场景都能实例化；`W0_skeleton` 覆盖新冻结接口；新增 `W0_stage` 测试。
- `.gd` 和 `.tscn` 里没有中文字面量；颜色只走 `CardTheme`；文字只走 `CardText`。
- 附 1280×720 截图：`--cards` 启动后的新根场景（桩也行）。

## 要做的事（合同 1.3 规格的 D 节原文；“E4”即本任务）

## D. W0 骨架同步（E4；只动 Claude 的文件）

> 原则：**C 线自己目录里的 W0 桩（CardTable、CounterPanel、SlotPanel……）这次一个都不动**——主人在自己分支里换成 1.3 的做法。1.3 的新控件由 Claude 在自己的目录里给“接口基类 + 桩”，主人没合入时用桩顶上。所以 W0 的测试、`--cards`、`--cards-autoplay`、`tools/run_legacy_smoke.sh` 在集成分支上照样全绿；C01 合入新画面以后也照样绿（测试按“新名或旧名都行”写）。
> 校验器（`scripts/cards/core/**`）和 `data/cards/_schema/**` 归 G01，这次不动：1.3 的 default 规则写在 `dsl_shapes.gd` 的 `check_stage()` 里，G01 的小 PR 负责挂上（C.3）。在那之前**例子集里不加 stage**（会被 V03 拦），演出块的例子先放在 Mock 自己的 `stage_examples.json`。

### D.1 文件清单（E4 只改这些）

| # | 文件 | 新/改 | 一句话 |
|---|---|---|---|
| 1 | `scripts/cards/api/card_ids.gd` | 改 | 1.3 常量（D.2） |
| 2 | `scripts/cards/api/card_layout.gd` | 新 | `class_name CardLayout`，§7.11.2 的全部常量与 5 个函数 |
| 3 | `scripts/cards/api/dsl_shapes.gd` | 改 | 加 `static func check_stage(card: Dictionary) -> PackedStringArray`（D.3） |
| 4 | `scripts/cards/ui/common/card_stage_api.gd` | 新 | `class_name CardStageApi extends Control`（§7.11.3 的信号与方法，方法体是空的默认实现） |
| 5 | `scripts/cards/ui/common/card_dialog_api.gd` | 新 | `class_name CardDialogApi extends Control`（§7.11.5） |
| 6 | `scripts/cards/ui/common/card_hand_api.gd` | 新 | `class_name CardHandApi extends Control`（§7.11.6） |
| 7 | `scripts/cards/ui/common/card_hero_api.gd` | 新 | `class_name CardHeroApi extends Control`（§7.11.6） |
| 8 | `scripts/cards/ui/common/card_checks_api.gd` | 新 | `class_name CardChecksApi extends Control`（§7.11.7） |
| 9 | `scripts/cards/ui/common/card_stage_panel.gd` | 新 | `class_name CardStagePanel extends CardPanel`（§7.11.4；`bind_stage` `begin_play` `end_play` 写成能用的实现，`on_reply` 空、`on_card_played`/`on_hotspot` 返回 false） |
| 10 | `scripts/cards/ui/common/card_stage_script.gd` | 新 | `class_name CardStageScript extends RefCounted`（§7.11.4 的默认演法表，完整实现） |
| 11 | `scripts/cards/ui/common/w0_stub.gd` | 改 | `PANEL_ANCHORS` 加 5 个抽屉 kind；夜牌的自动一步认字典 |
| 12 | `scripts/cards/ui/common/w0/{stage_stub,dialog_stub,hand_stub,hero_stub,checks_stub,panel_stub}.gd` | 新 | 六个桩脚本（不写 `class_name`，各自 `extends` 对应的接口基类 / `CardPanel`；D.4） |
| 13 | `scenes/cards/_w0/{Stage,DialogBox,HandFan,HeroBar,CounterChecks,PanelStub}.tscn` | 新 | 六个桩场景，根是 Control，挂上面的脚本 |
| 14 | `scripts/cards/mock/mock_scenario.gd` | 改 | 视图 `stage`、CardView 的 5 个新字段、`night_offers` 字典、记今天发的牌（D.5） |
| 15 | `scripts/cards/mock/stage_examples.json` | 新 | Mock 用的演出块例子（G01 的 1.3 PR 合入后挪进例子集再删） |
| 16 | `scripts/cards/mock/fixtures/*.json`（10 个） | 重新生成 | `$GODOT --headless --path . -s res://scripts/cards/mock/build_fixtures.gd` 重新生成（`build_fixtures.gd` 本身不用改） |
| 17 | `data/cards/_examples/common/extras.json` | 新 | 例子集的群演（`ex_patrol` `ex_shopboy` `ex_newsboy`） |
| 18 | `data/cards/_examples/guide/steps.json` | 改 | `gd.d1.deal` 的 `done_when` 加 `"ui:hand_played"`（新旧牌桌都能完成） |
| 19 | `data/cards/ui_keys/W0.json` | 改 | 加 `w0.stage.enter` `w0.stage.at_door` `w0.stage.leave`（`{name}`）与桩用的 `w0.dialog.skip` `w0.hand.play` `w0.panel.<contacts|demands|shelf|tickets|almanac>` |
| 20 | `data/cards/theme/palette.dev.json` | 改 | 36 个画面配色键（D.6） |
| 21 | `scripts/tests/cards/lib/card_t.gd` | 改 | 加 `anchor_in(id, rect) -> bool`、`anchor_ok_any(ids: Array) -> bool` |
| 22 | `scripts/tests/cards/W0/test_skeleton.gd` | 改 | D.7 |
| 23 | `scripts/tests/cards/W0/test_table_3days.gd` | 改 | D.7 |
| 24 | `scripts/tests/cards/W0/test_stage.gd` | 新 | `W0_stage`（D.7） |
| 25 | `scripts/tests/cards/suites/W0.txt` | 改 | 加一行 `W0_stage|res://scripts/tests/cards/W0/test_stage.gd|180|` |
| 26 | `docs/cards/ownership.json` | 改 | Claude 名下加：`scripts/cards/ui/common/card_stage_panel.gd` `card_stage_script.gd` `card_stage_api.gd` `card_dialog_api.gd` `card_hand_api.gd` `card_hero_api.gd` `card_checks_api.gd`、`scripts/cards/ui/common/w0/**`、`scenes/cards/_w0/**`、`docs/cards/prototype/**`（`api/**`、`mock/**` 已覆盖其余新文件）；`_doc` 加一句 `1.3 (2026-10-13): stage widgets' interface bases and W0 stubs are Claude's.` |

`test_next_day.gd`、`shot_table.gd`、`build_fixtures.gd`、`mock_engine.gd`、`card_panel.gd`、`card_anchors.gd`：**不用改**（`W0_next_day` 循环 `CardIds.PANELS`，多出来的 5 个抽屉 kind 自动被覆盖：桩宿主开成占位面板，Esc 关、不发指令）。

### D.2 `card_ids.gd` 加的东西（值照抄）

```gdscript
# ---------------- 面板的呈现（§7.8，1.3） ----------------
const SHOW_STAGE := &"stage"
const SHOW_DRAWER_L := &"drawer_l"
const SHOW_DRAWER_R := &"drawer_r"
const SHOW_OVERLAY := &"overlay"
const SHOW_HOST := &"host"
const PANEL_SHOW := {
	&"counter": &"stage", &"slots": &"stage", &"read": &"stage", &"demand": &"stage", &"fortune": &"stage",
	&"prison": &"stage", &"night": &"stage", &"settle": &"stage",
	&"contacts": &"drawer_l", &"demands": &"drawer_l", &"dossier": &"drawer_l",
	&"shelf": &"drawer_r", &"tickets": &"drawer_r", &"estates": &"drawer_r", &"almanac": &"drawer_r", &"settings": &"drawer_r",
	&"wheel": &"overlay", &"end_day": &"overlay", &"month_open": &"overlay", &"month_close": &"overlay",
	&"year_jump": &"overlay", &"game_over": &"overlay", &"short": &"overlay", &"contacts_full": &"overlay",
	&"kept_full": &"overlay", &"help": &"overlay", &"pause": &"overlay", &"minigame": &"host",
}
```
- `PANEL_SCENES` 加：`&"contacts": "res://scenes/cards/slots/ContactsDrawer.tscn"`、`&"demands": "res://scenes/cards/demand/DemandsDrawer.tscn"`、`&"shelf": "res://scenes/cards/counter/ShelfDrawer.tscn"`、`&"tickets": "res://scenes/cards/counter/TicketsDrawer.tscn"`、`&"almanac": "res://scenes/cards/fortune/AlmanacDrawer.tscn"`；`PANELS` 在 `&"minigame"` 前面加这 5 个。
- `const PANEL_STUB := "res://scenes/cards/_w0/PanelStub.tscn"`；`static func panel_scene(kind: StringName) -> String`：`minigame` 返回 `""`；`PANEL_SCENES` 里的路径 `ResourceLoader.exists()` 就返回它，否则返回 `PANEL_STUB`。（`PanelStub` 有 `var kind: StringName`，宿主在 `open()` 之前设上；§7.8 加一句说明。）
- `WIDGET_SCENES` 加：`&"stage": "res://scenes/cards/table/CardStage.tscn"`、`&"dialog": "res://scenes/cards/counter/DialogBox.tscn"`、`&"hand_fan": "res://scenes/cards/card/HandFan.tscn"`、`&"hero_bar": "res://scenes/cards/card/HeroBar.tscn"`、`&"checks": "res://scenes/cards/slots/CounterChecks.tscn"`；`const WIDGET_STUBS := {&"stage": "res://scenes/cards/_w0/Stage.tscn", &"dialog": "res://scenes/cards/_w0/DialogBox.tscn", &"hand_fan": "res://scenes/cards/_w0/HandFan.tscn", &"hero_bar": "res://scenes/cards/_w0/HeroBar.tscn", &"checks": "res://scenes/cards/_w0/CounterChecks.tscn"}`；`static func widget_scene(name: StringName) -> String`：真场景存在用它，否则 `WIDGET_STUBS[name]`（没有桩的名字返回 `WIDGET_SCENES[name]`）。
- 标签与热点：
```gdscript
const TABS_L: Array[StringName] = [&"contacts", &"demands", &"dossier", &"rules"]
const TABS_R: Array[StringName] = [&"shelf", &"tickets", &"estates", &"settings"]
const TAB_PANELS := {&"contacts": [&"contacts", {}], &"demands": [&"demands", {}], &"dossier": [&"dossier", {}],
	&"rules": [&"dossier", {"tab": "rules"}], &"shelf": [&"shelf", {}], &"tickets": [&"tickets", {}],
	&"estates": [&"estates", {}], &"settings": [&"settings", {}]}
const HOTSPOTS: Array[StringName] = [&"magnifier", &"abacus", &"cashbox", &"ledger", &"notebook", &"calendar",
	&"notice", &"notewall", &"lamp"]
const HOTSPOT_PANELS := {&"abacus": [&"dossier", {"tab": "rules"}], &"cashbox": [&"estates", {}],
	&"ledger": [&"tickets", {}], &"notebook": [&"dossier", {}], &"calendar": [&"almanac", {}], &"notewall": [&"demands", {}]}
```
- 演出：
```gdscript
const STAGE_SETS: Array[StringName] = [&"counter", &"candle", &"street", &"prison", &"temple", &"dock", &"market",
	&"teahouse", &"ricehall", &"pharmacy", &"post", &"baogong"]
const STAGE_TIMES: Array[StringName] = [&"day", &"dusk", &"night"]
const STAGE_SPOTS: Array[StringName] = [&"customer", &"companion", &"door", &"door_l", &"door_r", &"street"]
const CAST_LOOKS: Array[StringName] = [&"stand", &"walk", &"shadow"]
const PROP_SPOTS: Array[StringName] = [&"counter_left", &"counter_mid", &"counter_right", &"door_side", &"door_notice",
	&"wall_right"]
const STAGE_FX: Array[StringName] = [&"rain", &"fire", &"smoke", &"predawn", &"dim", &"cold", &"warm", &"drip", &"shake",
	&"seal"]
const STAGE_WALKS: Array[StringName] = [&"crowd", &"patrol", &"troops", &"refugees", &"hu2_men", &"none"]
const STAGE_AFTER_KEYS: Array[StringName] = [&"accept", &"counter", &"leave", &"refused", &"impatient", &"look",
	&"success", &"fail", &"read", &"keep", &"delay", &"lot", &"cezi", &"pass", &"done"]
const STAGE_TYPES: Array[StringName] = [&"person", &"event", &"fate", &"big_fate", &"life", &"news", &"street",
	&"prison", &"demand", &"night", &"pawn_ticket"]
const STAGE_KEYS: Array[String] = ["set", "cast", "props", "fx", "walk", "intro", "after", "brief"]
const STAGE_REF_REGEX := "^(body|lines\\.[a-z0-9_]+|outcomes\\.[a-z0-9_]+|choices\\.[a-z0-9_]+)$"
const STAGE_LIMITS := {"cast": 3, "props": 4, "fx": 3, "intro": 12, "after": 8}
const EXTRAS: Array[String] = ["ex_patrol", "ex_soldier", "ex_newsboy", "ex_girl", "ex_shopboy", "ex_oldman",
	"ex_porter", "ex_student", "ex_hu2_man"]
const HAND_PLAY_HOWS: Array[StringName] = [&"drag", &"button", &"key", &"auto"]
```
- `ANCHORS` 整个换成 B.4.2 的表（值 = 主人任务号；`a.hand` `a.hand.gold` 的值改成 `"C02"`），**另外保留** 7 个旧名，值写 `"renamed"`；加
```gdscript
const ANCHORS_RENAMED := {&"a.top.notice": &"a.scene.notice", &"a.left.self": &"a.hero",
	&"a.left.contacts": &"a.contacts", &"a.left.kept": &"a.hand.kept", &"a.right.tickets": &"a.scene.ledger",
	&"a.right.shelf": &"a.tab.shelf", &"a.right.dossier": &"a.scene.notebook"}
## [id, 改名后的新名或改名前的旧名]；没改过名的只有它自己（C16 找锚点时用；W2 删）
static func anchor_aliases(id: String) -> PackedStringArray
```
- `UI_EVENTS` 换成：`{&"panel_opened": "C01", &"panel_closed": "C01", &"drawer_opened": "C01", &"drawer_closed": "C01", &"hotspot_pressed": "C01", &"hand_selected": "C02", &"hand_played": "C02", &"card_zoomed": "C02", &"card_drag_started": "C02", &"slot_drop": "C03", &"dialog_advanced": "C04", &"dialog_skipped": "C04", &"reply_chosen": "C04", &"mg_tool": "C12-C15", &"guide_shown": "C16", &"guide_done": "C16"}`。
- 文件头注释加一句：`1.3（10-13 晚）：面板的呈现、标签与热点、演出常量、群演、新锚点与改名表、新界面事件、panel_scene()/widget_scene()。`

### D.3 `dsl_shapes.gd` 的 `check_stage(card)`

返回 `PackedStringArray`，每条 `"V38: …"` / `"V39: …"` / `"V40: …"` / `"V41: …"`；`card` 没有 `stage` 返回空。照合同 §4.9 的 V38、V39（只做本地部分：拍子的 `who` ∈ {`""`, `"me"`, `card.person`, 本块 `cast[].who`}）、V40、V41 逐条查，用 D.2 的常量；`after` 允许的键 = `STAGE_AFTER_KEYS` ∪ 本牌 `choices[].id`（`type == "demand"` 再加 `DEMAND_MODES`）。V38 的“拍子必须有非空 brief”也在这里查。不读 CardDB、不查人物登记和美术清单（那是 G01 的 V39 登记部分与 V42）。

### D.4 六个 W0 桩（能跑就行，样子朴素；字全走 CardText、颜色全走 CardTheme、`.gd` 字面量只有 ASCII）

| 桩 | 做什么 |
|---|---|
| `stage_stub.gd`（`extends CardStageApi`） | 铺一张 `TextureRect`（`CardArt.texture(CardStageScript.bg_id(...))`，1280×720）；`play()` 按站位摆人（`portrait.<who>`，`CardLayout.spot()`）和道具；`set_items` 摆物品 ×2；9 个热点用 `TextureButton`（`prop.<名>`），按下发 `hotspot_pressed` 与 `ui_event hotspot_pressed {id}`；`_can_drop_data/_drop_data` 收 `{"kind": "card"}` 发 `card_dropped`；登记 `a.scene` 与 `a.scene.*`；视图没有 `stage` 时按 `{"set": "counter", "time": "day", "sealed": false}`。 |
| `dialog_stub.gd`（`extends CardDialogApi`） | `DIALOG` 位置一个 Panel：一个 Label 显示当前一句（不逐字）、“跳过”按钮（`w0.dialog.skip`）、回话一列 Button；点 Label 推下一句；`opt` 且是草稿的跳过；回话 `anchor` 登记/注销；发三个信号和对应的 `ui_event`；登记 `a.dialog`（显示时）。 |
| `hand_stub.gd`（`extends CardHandApi`） | 在 `FAN` 带里把 `view.hand` + `view.kept` 平铺（不转角），用 `CardIds.widget_scene(&"card")` 的 CardWidget；按一次 = 选中（`card_selected` + `hand_selected`），再按一次 = 打出（`card_played` + `hand_played {how: "button"}`）；`play_uid` → `how: "auto"`；夜里排 `night_offers`（字典或字符串）+ “睡了”；登记 `a.hand` `a.hand.gold` `a.hand.kept`。 |
| `hero_stub.gd`（`extends CardHeroApi`） | `HERO` 一块（名字 + 四项属性点数）+ `CONTACT_MINIS` 三张小牌；拖头像出 `{"kind": "self"}`；登记 `a.hero` `a.contacts`；点了发 `person_pressed`。 |
| `checks_stub.gd`（`extends CardChecksApi`） | `show_checks` → `query("slots")` → 按 `slot_rect` 摆 CardSlotWidget（`widget_scene(&"slot")`），`place_requested` → `slot.place`、`remove_requested` → `slot.remove`，完了发 `changed`；`play_coins` 立刻发 `coins_finished`；登记 `a.slots.first` `a.slots.coins` `a.slots.money`。 |
| `panel_stub.gd`（`extends CardPanel`） | `var kind: StringName`；`open` → `W0Stub.build(self, kind, args)`；`autoplay_step` / `dismiss` 交给 `W0Stub`。 |

### D.5 Mock（`mock_scenario.gd`）

1. `view()` 加 `"stage": {"set": …, "time": …, "sealed": false}`：`set` = 手上有 `pr.cell`（或 `st.prison.uid` 不空）→ `prison`；`mode == "street"` → `street`；否则 `counter`。`time`：阶段 `night` `settle` → `night`；阶段 `day` → 用 `st["dealt_today"]`（`_deal()` 里记下今天发到手上的 uid）：D = 个数，R = 其中已不在手牌的个数，`D > 0 and R * 100 >= D * 60` → `dusk`，否则 `day`；其余 → `day`。`setup_day_full()` 把 9 张手牌记成今天发的（所以 `day_full` 是 `day`）。
2. `card_view()` 加：`"stage"`（定义里的 `stage`；没有就查 `stage_examples.json`；都没有 `{}`；去掉所有 `brief`）、`"source"`（消息牌的 `source`，否则 `""`）、`"wheel"`（`bf.wheel` → `"wh.big"`、`opens_wheel` 的值、否则 `""`）、`"fortune"`（`opens_fortune` 的值或 `""`）、条子加 `"demand": {"kind": d.kind, "tier": <当前档>}`。
3. `night_offers` 存成 `[{"def", "art", "choices"}]`（`art` 取定义的 `art`，`choices` 取选项 id）；`night.choose` 仍按 `def` 字符串收。`w0_stub.gd` 的夜牌自动一步取 `offers[0]` 时认字典（`.def`）也认字符串。
4. `stage_examples.json` 的内容：`ev.1938.police_check`（合同 §4.7.24 第一个例子）、`p.brother.1938.farewell`（第二个例子）、`fa.any.fire_next_door`（`cast: [{who: "ex_shopboy", at: "door"}]`、`fx: ["fire", "smoke"]`、`intro`：`ex_shopboy` 说 `lines.greet`、旁白 `body`）、`nt.family_dinner`（`fx: ["warm"]`）、`pr.cell`（`set: "prison"`）、`st.write_letters`（`set: "market"`、`cast: [{who: "ruhua", at: "door"}]`、`props: [{art: "prop.bench", at: "counter_mid"}]`）；每个 cast/prop/拍子都带 brief；全部过 `check_stage`。
5. 重新生成 10 个夹具：每个的视图都有 `stage`（`night` `settle` 两个是 `night`，`street_prison` 是 `prison`，其余 `day`）；`day_full` 里查良民证、失火、哥哥告别三张牌的 CardView 带 `stage`；`night` 夹具的 `night_offers` 是字典。

### D.6 `palette.dev.json` 加的键与开发初值

`scene_void #0d0a08` · `hud_bg #0d0a08cc` · `hud_ink #efe3c7` · `dialog_bg #1e140de6` · `dialog_ink #f4e2b0` · `dialog_name #e8c35a` · `dialog_me #b9c4a0` · `dialog_sys #9aa4aa` · `reply_bg #2b1c12` · `reply_hover #3a281b` · `reply_ink #f4e2b0` · `reply_off #6b5a46` · `tab_bg #24180f` · `tab_on #3a281b` · `drawer_bg #1a110bf2` · `drawer_ink #efe3c7` · `scrim #00000059` · `btn_day #e8c35a` · `btn_day_ready #7fbf4a` · `btn_day_confirm #c8452c` · `btn_day_night #5c6aa8` · `btn_day_ink #3a2408` · `night_tint #f2d9b8` · `night_dark #00000d59` · `candle_tint #ffdba8` · `cold_tint #a8b8d059` · `warm_tint #ffb86c33` · `predawn #141e3c59` · `lamp_glow #ffd25a40` · `rain #c8d8e899` · `fire_glow #ff7a2c66` · `smoke #4a423c80` · `seal_paper #f4efe0` · `silhouette #0d0d128c` · `hero_ring #e8c35a` · `guide_note #f4e6c6`（共 36 个；加上合同 §2.4 原有的就是全部键）。

### D.7 测试怎么跟着改

- **`W0_skeleton`**：`API` 表加 `CardLayout`（`screen` 1、`spot` 1、`prop_rect` 2、`slot_rect` 2、`coin_rect` 2）、`CardStageApi`（`refresh` 1、`play` 1、`clear_play` 0、`set_items` 1、`set_talking` 1、`set_dim_tools` 1、`spot_rect` 1；信号 `hotspot_pressed` `card_dropped`）、`CardDialogApi`（`show_lines` 3、`set_replies` 1、`clear` 0、`skip` 0、`is_idle` 0、`has_replies` 0、`set_max_bottom` 1、`current_uid` 0；信号 `advanced` `lines_done` `reply_chosen`）、`CardHandApi`（`refresh` 1、`set_low` 1、`set_away` 1、`select_index` 1、`play_selected` 0、`play_uid` 1、`card_rect` 1；信号 `card_played` `card_selected`）、`CardHeroApi`（`refresh` 1；信号 `person_pressed`）、`CardChecksApi`（`show_checks` 1、`hide_checks` 0、`is_shown` 0、`preview` 0、`play_coins` 2、`skip_coins` 0；信号 `changed` `coins_finished`）、`CardStagePanel`（`bind_stage` 4、`begin_play` 1、`end_play` 0、`on_reply` 1、`on_card_played` 2、`on_hotspot` 1，外加 `CardPanel` 的）、`CardStageScript`（`resolve` 2、`lines` 2、`bg_id` 2、`speaker` 1）；`CardDslShapes` 加 `check_stage` 1。面板场景的检查改成 `ResourceLoader.exists(CardIds.panel_scene(kind))`（`minigame` 除外）；控件改成 `ResourceLoader.exists(CardIds.widget_scene(w))`。目录检查加：`PANEL_SHOW` 的键 = `PANELS`；`ANCHORS_RENAMED` 的键都在 `ANCHORS` 里且值是 `"renamed"`、值（新名）都在 `ANCHORS` 里且值是任务号；`UI_EVENTS` 正好是 D.2 那 16 个；`HOTSPOTS` 每个在 `CardLayout` 里有矩形；配色检查的键加 `dialog_bg` `night_tint` `btn_day` `guide_note`。
- **`W0_table_3days`**：牌桌锚点的检查改成“新名或旧名有一个就行”（`t.anchor_ok_any([新, 旧])`），列表：`a.top.date` `a.top.weather` `a.top.money` `a.top.rep` `a.top.heat` `a.btn.close_day` `a.hand`、`[a.scene.notice, a.top.notice]` `[a.scene.ledger, a.right.tickets]` `[a.scene.notebook, a.right.dossier]` `[a.tab.shelf, a.right.shelf]` `[a.hero, a.left.self]` `[a.contacts, a.left.contacts]`（`a.hand.gold` `a.hand.kept`、`a.left.kept` 不在第 1 天查）；`ui_event` 的检查里 `hand_selected` 改成 `hand_selected` 或 `hand_played` 有一个；其余（指引按顺序亮、`command_done` 后面跟 `view_changed`、first 各一次、覆盖层鼠标穿透）不变。这样集成分支上的旧牌桌桩和 C01 合入后的新画面都能过。
- **`W0_stage`（新）**：①`CardLayout`：所有矩形在 1280×720 里；HUD、`DIALOG` 最大框、`FAN` 带（y 520–720）、`HERO`、`CONTACT_MINIS`、两侧标签、`END_DAY`、`STREET_REDEEM` 两两不重叠（#139 裁定：`DIALOG` 最大框是 52, 38, 380, 482，底边 520 = `FAN` 顶边，所以真的两两不重叠，测试不再用安全框绕开；框架版收尾默认，主创可改）；`S_*` × 4 = 对应的屏幕常量；`slot_rect`/`coin_rect` 以 x=640 为中线。②`check_stage`：`stage_examples.json` 每块没有错；反例各报对的规则号——未知键、`set: "moon"`、4 个 cast、`door` 和 `door_l` 同时用、`set: "temple"` 配 `street` 站位、`set: "prison"` 写 `walk`、拍子的 `who` 不在场、`ref: "title"`、拍子没 brief、`kept` 牌带 `stage`（V40）、`after` 的键不认识。③`CardStageScript`：person 默认 `cast` 站 `customer`、`intro` 的 ref 顺序与 `opt` 对；有 `source` 的消息牌、没有的（`ex_newsboy` 站 `door`）；条子（`hu2` + `prop.notice`）；查良民证用演出块覆盖；`lines(…, "accept")`；`bg_id` 的 day/dusk/night/street/candle。④Mock：新局第 1 天发牌后 `stage.time == "day"`，处理掉六成后 `dusk`，夜里 `night`；`street_prison` 是 `prison`；CardView 有 5 个新字段；`night_offers` 是字典；视图与查询过 `t.no_leaks`。⑤六个桩：各自实例化、用 `day_full` 的 Mock 调一遍冻结方法不报错、该登记的锚点 `has()`；一个内部类 `extends CardStagePanel` 的 `begin_play("<查良民证 uid>")` 让对话框桩显示了 intro 的第一句、场景桩摆了两个巡警。

**跑法**：`$GODOT --headless --path . --import` → 重新生成夹具 → `bash tools/run_card_tests.sh`（全绿，含 `W0_fixtures_up_to_date`、`W0_validate_examples`）→ `bash tools/run_legacy_smoke.sh`（全绿）。

---

