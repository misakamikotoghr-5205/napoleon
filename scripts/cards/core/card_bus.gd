# 卡牌版事件总线：引擎 → 界面（唯一例外 ui_event：界面发、只给新手指引和测试听，引擎永远不连它）。
# 主人 G01；W0（Claude）写好、签名冻结；autoload 名 CardBus。合同：docs/cards/CARDS_INTERFACES.md §7.6、§7.10.2。
# 引擎代码不直接引用 autoload CardBus，只用注入的 bus；无头测试 CardEventBus.new()，用完 free()。
class_name CardEventBus
extends Node

signal phase_changed(from: StringName, to: StringName)
## 界面重新读 engine.view()；topics 提示哪块变了。每条指令（ui.* 除外）的最后一条。
signal view_changed(topics: PackedStringArray)
signal cards_dealt(uids: PackedStringArray)
signal card_updated(uid: String)
## reason: resolved / refused / left / expired / gold_left / seized / informed
signal card_left(uid: String, reason: StringName)
signal coins_tossed(uid: String, faces: Array, need: int, success: bool)
signal wheel_spun(wheel_id: String, segment_id: String, stop_deg: float)
signal money_changed(old_amount: int, new_amount: int, reason_key: String)
## 只有 &"rep" 和 &"heat"
signal tier_changed(meter: StringName, old_tier: int, new_tier: int)
## kind: added / gap
signal dossier_changed(person: String, frag_id: String, kind: StringName)
signal notice(key: String, args: Dictionary)
signal minigame_requested(uid: String, item_id: String, kind: StringName, params: Dictionary)
## 引擎要求界面打开某个面板（月轮盘、牢房、钱不够……）
signal request_panel(kind: StringName, args: Dictionary)
signal game_over(reason: StringName)
signal saved(path: String, ok: bool)
## 某机制第一次出现（CardFirsts.mark，§7.10.6）；args 只放 uid/def/kind/person/no
signal first_time(mech: StringName, args: Dictionary)
## G02 门面在每条指令（ui.* 除外）的最后 view_changed 之前发
signal command_done(cmd: StringName, args: Dictionary, ok: bool)
## 只有界面发（CardIds.UI_EVENTS，§7.10.5）；引擎永远不连它
signal ui_event(name: StringName, args: Dictionary)

## 引擎 → 界面的信号名（门面按 ctx.out 顺序发；ui_event 不在里面）
const ENGINE_SIGNALS: Array[StringName] = [&"phase_changed", &"view_changed", &"cards_dealt", &"card_updated",
	&"card_left", &"coins_tossed", &"wheel_spun", &"money_changed", &"tier_changed", &"dossier_changed", &"notice",
	&"minigame_requested", &"request_panel", &"game_over", &"saved", &"first_time", &"command_done"]


## 按信号名发一条事件；args 按信号的参数类型转换（ctx.out 和 Mock 夹具里的 JSON 数组用它）。
## 不认识的信号名 push_error。
func emit_event(signal_name: StringName, args: Array) -> void:
	match signal_name:
		&"phase_changed":
			phase_changed.emit(StringName(str(args[0])), StringName(str(args[1])))
		&"view_changed":
			view_changed.emit(PackedStringArray(args[0] if args.size() > 0 else []))
		&"cards_dealt":
			cards_dealt.emit(PackedStringArray(args[0]))
		&"card_updated":
			card_updated.emit(str(args[0]))
		&"card_left":
			card_left.emit(str(args[0]), StringName(str(args[1])))
		&"coins_tossed":
			coins_tossed.emit(str(args[0]), Array(args[1]), int(args[2]), bool(args[3]))
		&"wheel_spun":
			wheel_spun.emit(str(args[0]), str(args[1]), float(args[2]))
		&"money_changed":
			money_changed.emit(int(args[0]), int(args[1]), str(args[2]))
		&"tier_changed":
			tier_changed.emit(StringName(str(args[0])), int(args[1]), int(args[2]))
		&"dossier_changed":
			dossier_changed.emit(str(args[0]), str(args[1]), StringName(str(args[2])))
		&"notice":
			notice.emit(str(args[0]), Dictionary(args[1]) if args.size() > 1 else {})
		&"minigame_requested":
			minigame_requested.emit(str(args[0]), str(args[1]), StringName(str(args[2])), Dictionary(args[3]))
		&"request_panel":
			request_panel.emit(StringName(str(args[0])), Dictionary(args[1]) if args.size() > 1 else {})
		&"game_over":
			game_over.emit(StringName(str(args[0])))
		&"saved":
			saved.emit(str(args[0]), bool(args[1]))
		&"first_time":
			first_time.emit(StringName(str(args[0])), Dictionary(args[1]) if args.size() > 1 else {})
		&"command_done":
			command_done.emit(StringName(str(args[0])), Dictionary(args[1]), bool(args[2]))
		&"ui_event":
			ui_event.emit(StringName(str(args[0])), Dictionary(args[1]) if args.size() > 1 else {})
		_:
			push_error("CardEventBus: unknown signal '%s'" % signal_name)
