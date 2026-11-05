# 合同 §12.5 黄金种子变更记录（2026-10-25 · 肉鸽 v1）

依据：`docs/cards/rogue/ROGUE_V1.md` §1 时间线、§14 RG6 第二阶段“黄金种子”、§15.1 红线“黄金种子”；合同 §12.5。
RG3 合入数据时 `G06_golden` 变红是预期内的，由 RG6 在集成头上一次重算。

## 变更

- 提交 `e75b73a3`（`test(G06)：重生 golden.json（§12.5，仅 golden.json；肉鸽 v1）`）只改 `scripts/tests/cards/golden/golden.json`。
- 两条用例都保留：examples / seed 7 / fair / 30 天，real / seed 7 / fair / 30 天；检查点仍是第 10、20、30 天，只换哈希。
- 没改 `test_golden.gd`，没改 `balance_main.gd`。

## 准确输入

| 项 | 值 |
|---|---|
| 源提交 | `7e6c0ee99a686559aea67973d685688a9f69f69a`（`rogue-integ`：`rogue-base` `3f59bac5` + RG1 → RG2 → RG5 → RG4 → RG3 → RG6，加 `appraise-ship` 的鉴定复审修正、集成修正、平衡三批调数，加 `rogue/RG6-docs` 文档合入） |
| `data/cards` 树 | `HEAD:data/cards` = `49508e409584e2a6705780670d2f1e1cad313c2e`（旧基线 `rogue-base:data/cards` = `8ffa0956835a317c4bb7cfc2a0a2dc1f9c28c753`） |
| `balance_overrides.json` SHA-256 | `c4e838759a859908e2a9f102d8150f9ba7d3643273a7c9ff079f720d774d84dc`（自 W2-5 起没变；平衡三批只改了 `era/common/relics.json` 的数字） |
| `db_hash`（examples） | 新 `43a6626bf5f2c3d4a5185107e28a7f4b87a92ac0a44ca7207d1a20ab9e596d63`；旧 `2a2143d78862af300fc4a4bb77753805a970a5eee9b4b5bc395a0180b3c116f5` |
| `db_hash`（real） | 新 `40bd996f6a6b67ef5defa62f479080152d0dcda924a2d2c8c527adcfd2d9c913`；旧 `0bf84f23bd943103b7d35a61f57ce2eeae29d1c811cb40ea17cb88d14550828e` |
| Godot | 4.7.1-stable (official)，headless；`XDG_DATA_HOME` 用私有目录（`user://` 不和别的 worktree 共用） |
| 运行结果 | examples：`ok=true`，30 天，`steps=790`（旧也是 790），`game_over_reason=""`；real：`ok=true`，30 天，`steps=692`（旧 709），`game_over_reason=""` |

重算命令（各写一个临时文件，再把两份的 `cases` 按 examples、real 的顺序拼成 `golden.json`；`--update-golden` 一次只写一种 `--data`，会整文件重写，所以没有直接写回仓库路径）：

```sh
for d in examples real; do
  GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . -s res://scripts/cards/sim/balance_main.gd -- \
    --data=$d --seed_from=7 --seeds=1 --policies=fair --days=30 --stages=3 \
    --update-golden --golden-out=<临时目录>/golden_$d.json --out=<临时目录>/runs_$d --date=2026-10-25
done
```

合并后在同一棵树上跑 `G06_golden`（两遍同种子、检查点、指令回放）通过。

## 检查点

| 用例 | 日 | 旧哈希 | 新哈希 |
|---|---:|---|---|
| examples | 10 | `dda22d50739f0ebe3f6dc9f78ea5d1224096cf70477f49023b3d4596ee6be3cd` | `1e22bf9e7a97672eef58c728c7a031b51b0025dedcd30c281e3bdffab57eec40` |
| examples | 20 | `12236f1f08f432f3d95c02b4dd7075a63289b9bfb21b3565d1749ea550c882c6` | `0903419c7580112c9a9bf38cbee510f8417498daf28f9bab7f81953bb9951d13` |
| examples | 30 | `e307fcf015ef98e31fc73273dc41748a1906d1e4b6446bd6e875c97bcde573c5` | `8ab6fe723a698777ffe3edf4905744fe7da3b9d3e6393f9abb2d370ca54dd411` |
| real | 10 | `57e84e9887085db96acaf53a2fe0bd59a0c213fb9aba5ed6cd3f881d13c89580` | `a7a29f37809833018117283798a4412f1a9d3a39285a35d04c580f4d2b338179` |
| real | 20 | `ba4bcf22a8c1d0ad0206e9139107b922802b5baffd42fced038cacf81c3b4ab8` | `06b360c3917d4015a93201e2496937e75ee2dd894c52d8901521eacb266fa0cd` |
| real | 30 | `a75a8081dd3ad4f763e724bd5724f1a224aff2cb61e38b9cd2d82776d7655952` | `a46971ea57ce5878be8cd9701b1642576d7c6f1c437e72b6de20829a45500203` |

## 为什么变（行为改了，不是 bug）

状态哈希（`CardState.hash()`）是整份状态去掉 `ui` 之后的 SHA-256，状态里存着开局时的 `db_hash`；`db_hash` 又是全部牌、全部规则文件、人物表去掉 `brief` / `text` / `_` 开头的键之后的哈希。所以只要机制数据或规则文件动了一个字，每个检查点的哈希都会变，哪怕局面一模一样。

1. **例子集：只有 `db_hash` 变，行为不变。** 例子集模式不读真数据的牌，但规则目录照读：RG3 新加的 `rules/relics.json`、`rules/stock.json`、`rules/legacy.json` 进了 `db_hash`。例子集里没有老物件、客源、货郎，盘账和物件模块按规格“没有数据就不写状态”（状态里没有 `relic`、`stock` 键），局面逐日相同（下面诊断 1）。
2. **真数据：`db_hash` 变，行为也变。**
   - 进 `db_hash` 的数据改动：三个规则文件；`era/common/relics.json`（十二件老物件，含平衡三批调过的数字）；`era/common/sources.json`（六种客源）；`era/1938/curio_peddler.json`（第 8 天货郎）；`era/1938/tutorial.json` 第 1 天三张教学牌的 `schedule.when: {not: {veteran: true}}`（第一本账 `veteran` 为假，不改行为）；十个官面事件的“人”格加 `tags: ["official"]`（集成修正 `feb2283c`，让孙府印泥盒能起作用）。
   - 行为改动（探针记下的 `stocktake` 面板与 `stock.pick` 指令，全部 `ok`）：

     | 天 | 报价 | 来源 | fair 挑的 |
     |---:|---|---|---|
     | 7 | `w0.0` | 周末盘账（1938 第 0 周只出客源，`source_only_weeks: ["0:0"]`） | `ky.dockhands` |
     | 8 | `p8` | 货郎 `p.stranger_peddler.1938.curios` 占一个日程位；策略的 `_choice_score` 让 `look` 排在 `send_off` 前 → `stock_offer` 两件寻常家什 | `rl.blue_curtain` |
     | 14 | `w0.1` | 周末盘账，3 样 | `rl.sun_inkpad` |
     | 21 | `w0.2` | 周末盘账，3 样 | `rl.master_steelyard` |
     | 28 | `w0.3` | 周末盘账，3 样 | `rl.old_almanac` |

     fair 在盘账上按原顺序挑第一样（规格 §14 RG6 第一阶段）。状态多了 `relic`、`stock` 两个命名空间；挑到的物件与客源改了之后的价钱、耐心、客流，30 天的指令数从 709 变成 692。
3. **鉴定改版：没有让本次哈希变。** 鉴定改版本身（私账答案、`econ.readings`、`spot` 画法、柜台付不起的价）在旧基线里已经算进去了（`rogue-base` 里的 `fbe280ac` 重算过一次）。`rogue-base` 之后合入的 `appraise-ship` 复审修正（找不同、吹银元、称分量、拼碎片、解密的界面与引擎修正，拼碎片观察的 `brief` 改写）不改任何检查点：诊断 2 里“新代码 + 旧数据”两条用例都逐字等于旧黄金；`minigames/obs/*.json` 本来就不进 `db_hash`（观察表单独存放，`brief` 也会被剥掉）。

## 诊断

探针（不进仓库，全文在文末）对 seed 7 / fair / 30 天，在第 10、20、30 天的同一时刻（`morning` / `month_close` 的第一次视图变化，和 `Telemetry` 取哈希的时刻相同）算两个哈希：原样的状态哈希（每一行都和 `Telemetry.hashes` 逐字相同，等于黄金里的值），以及把状态里的 `db_hash` 置成 `""` 之后的哈希。“旧”= `rogue-base`（`3f59bac5`，单独检出的 worktree），“新”= 本次源提交。

| 运行 | 代码 | 数据 | `db_hash` | 步数 | 原样哈希 | 置空 `db_hash` 后（第 10 / 20 / 30 天） |
|---|---|---|---|---:|---|---|
| E-旧 | 旧 | 旧 examples | `2a2143d7…` | 790 | = 旧黄金 | `a1e4a357…` / `b00ef4e0…` / `b281a747…` |
| E-新 | 新 | 新 examples | `43a6626b…` | 790 | = 新黄金 | `a1e4a357…` / `b00ef4e0…` / `b281a747…` |
| E-新码旧数 | 新 | 旧 examples（`--data-root` 指向旧树 `data/cards` 的拷贝） | `2a2143d7…` | 790 | = 旧黄金 | `a1e4a357…` / `b00ef4e0…` / `b281a747…` |
| R-旧 | 旧 | 旧 real | `0bf84f23…` | 709 | = 旧黄金 | `bd2072fe…` / `b6ee161d…` / `a2e5fca1…` |
| R-新码旧数 | 新 | 旧 real | `0bf84f23…` | 709 | = 旧黄金 | `bd2072fe…` / `b6ee161d…` / `a2e5fca1…` |
| R-关-无货郎 | 新 | 新 real，`balance_overrides.json` 加 `relics.enabled=false`、`stock.enabled=false`，删掉 `era/1938/curio_peddler.json` | `7e7064cf…` | 709 | 新值 | `bd2072fe…` / `b6ee161d…` / `a2e5fca1…` |
| R-关 | 新 | 新 real，同上但留着货郎 | `27ef25dd…` | 706 | 新值 | `0f696bd8…` / `c63f91a9…` / `b8497f62…` |
| R-新 | 新 | 新 real | `40bd996f…` | 692 | = 新黄金 | `00d85a27…` / `2553369d…` / `bbbed7ae…` |

置空后的完整哈希：

- examples（E-旧 = E-新 = E-新码旧数）：`a1e4a357dd0d0b626ceafa405b12d6f70e5b993cc0cfe35106ad3a2aa4a911ae`、`b00ef4e0ab9b852c49ce5734383ffe1773fe467169a258b03c81a90403bfcaee`、`b281a7476d73e3afdf2e10f45e7323e76c72bd90016ffda49785d06cbe104d9c`。
- real 旧（R-旧 = R-新码旧数 = R-关-无货郎）：`bd2072fe951a297cba374ea45e0f4d8dcab44bb1b333ff3fac56759e3216d2a1`、`b6ee161d3439f8a9407c5843097046b1ce8946efa5d31e49b7827c4e4eacad1b`、`a2e5fca181670fb17212e5e5ec2638c513766c8403f43dfc9b5d744f64197e62`。

结论：

1. **例子集：置空 `db_hash` 后新旧逐日哈希相同**（E-旧 = E-新）。例子集没有肉鸽数据，行为不变，变的只有 `db_hash`。集成那一步另做过同样意思的对照：新数据的拷贝只删 `rules/relics.json`、`rules/stock.json`、`rules/legacy.json`，例子集用例逐字回到旧黄金。
2. **代码本身不动黄金**（E-新码旧数、R-新码旧数逐字等于旧黄金，连 `db_hash` 都相同）：步骤 0、RG1、RG2、RG4、RG5、RG6 的代码、`appraise-ship` 修正和集成修正在没有新数据时不改任何一步，符合 §1“只有 RG3 合入数据让黄金变”。
3. **真数据里，真正改行为的只有肉鸽本身**：两个模块关掉、货郎拿走之后（R-关-无货郎），置空 `db_hash` 的逐日哈希回到旧值，步数也是 709；也就是说官面事件的 `official` 标签、教学牌的 `when`、平时不用的物件与客源牌只改 `db_hash`。留着货郎（R-关）就差一个日程位（706 步，规格 A1 说的“第 8 天货郎占一个日程位”）；两个模块打开（R-新）才有第 7/14/21/28 天盘账与第 8 天货郎的五次挑选。

## 探针全文

存成任意位置的 `golden_probe.gd`，在要比的那棵树里跑：
`godot --headless --path <树> -s <绝对路径>/golden_probe.gd -- --data=examples|real [--data-root=<数据根>] --out=<结果.json>`。

```gdscript
# Diagnostic probe (not part of the repo): runs the golden case (seed 7, fair, 30 days) and prints, for each
# checkpoint, the real state hash and the hash with state.db_hash blanked; also logs stocktake panels and picks.
extends SceneTree

const Telemetry := preload("res://scripts/cards/sim/telemetry.gd")
const Runner := preload("res://scripts/cards/sim/balance_main.gd")


func _initialize() -> void:
	var opts: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = str(arg).trim_prefix("--").split("=", true, 1)
		opts[parts[0]] = parts[1] if parts.size() == 2 else true
	var examples: bool = str(opts.get("data", "examples")) == "examples"
	var root: String = str(opts.get("data-root", "res://data/cards"))
	var bus: CardEventBus = CardEventBus.new()
	var engine: CardEngine = CardEngine.new(bus)
	var observer: RefCounted = Telemetry.new()
	var db: CardDB = CardDB.load_all(root, {"only_examples": examples})
	observer.attach(engine, db)
	var blank: Array = []
	var events: Array = []
	bus.view_changed.connect(func(_t: PackedStringArray) -> void:
		var v: Dictionary = engine.view()
		var day: int = int(v.get("date", {}).get("abs_day", 0))
		var phase: String = str(v.get("phase", ""))
		if phase in ["morning", "month_close"] and day in [10, 20, 30] \
				and not blank.any(func(h: Dictionary) -> bool: return int(h["abs_day"]) == day):
			var d: Dictionary = engine.ctx.state.data.duplicate(false)
			d.erase("ui")
			var full: String = _sha(d)
			d["db_hash"] = ""
			blank.append({"abs_day": day, "hash": full, "blank": _sha(d)}))
	bus.request_panel.connect(func(kind: StringName, args: Dictionary) -> void:
		if kind == &"stocktake":
			events.append({"day": int(engine.view().get("date", {}).get("abs_day", 0)), "panel": str(kind),
				"offer": str(args.get("offer", ""))}))
	bus.command_done.connect(func(cmd: StringName, args: Dictionary, ok: bool) -> void:
		if cmd == &"stock.pick":
			events.append({"day": int(engine.view().get("date", {}).get("abs_day", 0)), "cmd": str(cmd),
				"args": args.duplicate(true), "ok": ok}))
	var start: Dictionary = engine.new_game({"seed": 7, "only_examples": examples, "data_root": root,
		"save_dir": "user://golden_probe"})
	var result: Dictionary = CardAutoplay.play(engine, Runner.POLICIES["fair"].new(7), {"days": 30, "max_steps": 10000})
	var state: Dictionary = engine.ctx.state.data
	var out: Dictionary = {"start_ok": bool(start.get("ok", false)), "db_hash": str(state.get("db_hash", "")),
		"result": result, "telemetry_hashes": observer.hashes, "checkpoints": blank, "rogue_events": events,
		"state_keys": state.keys()}
	var file: FileAccess = FileAccess.open(str(opts.get("out", "user://golden_probe.json")), FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t", true, true) + "\n")
	file.close()
	bus.free()
	print("PROBE DONE")
	quit()


func _sha(d: Dictionary) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(JSON.stringify(d, "", true, true).to_utf8_buffer())
	return ctx.finish().hex_encode()
```

探针直接读 `engine.ctx.state`，只用于这份诊断；游戏、测试和平衡工具都不这样读。

## 后续影响

真数据用例以后会随任何 `data/cards/**` 或规则文件的机制改动再变（包括平衡再调数），按 §12.5 由合并的人重算，并在这里新开一份记录。

标记 `golden-change`。
