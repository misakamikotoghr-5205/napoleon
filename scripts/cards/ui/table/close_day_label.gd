# “打烊 · 下一天”按处境换字（DESIGN_cards.md §九.7，主创 10-15）：指令仍是 day.end，规矩不变，只换按钮文字。
# 牢里 → c01.btn.close_day.mode.prison；街头 → .street；查封 → .sealed；铺子里 → 调用方给的原键。
# 处境先看 view.mode（street；以后若有 prison/sealed 也认），再看 view.stage {set, sealed}（G02 1.3）。牢里优先于查封（坐牢时铺子也关着）。
# 实际接线：card_game_root.gd._refresh_end()（#42 的根场景按钮 _end_title）。主人 C01；C11 核对街头、牢房。只读视图，不碰按钮能不能按。
# 辅助脚本：无 class_name，调用方 const 常量 preload（C01 卡“不能做的事”第 7 条、合同 §0）。
extends RefCounted

const PREFIX := "c01.btn.close_day.mode."
# 只替换“往下一天走”的那几个按钮键；开月、跳年、局终等原样保留。
const ADVANCE_KEYS := ["w0.btn.close_day", "c01.btn.close_day.end_day", "c01.btn.close_day.next_day", "c01.btn.close_day.skip_night"]


static func situation(view: Dictionary) -> String:
	var mode := str(view.get("mode", "shop"))
	var stage = view.get("stage", {})
	var st: Dictionary = stage if typeof(stage) == TYPE_DICTIONARY else {}
	if mode == "prison" or str(st.get("set", "")) == "prison":
		return "prison"
	if mode == "street" or str(st.get("set", "")) == "street":
		return "street"
	if mode == "sealed" or bool(st.get("sealed", false)):
		return "sealed"
	return "shop"


static func key_for(view: Dictionary, default_key: String) -> String:
	if str(view.get("phase", "")) == "game_over" or not ADVANCE_KEYS.has(default_key):
		return default_key
	var s := situation(view)
	return default_key if s == "shop" else PREFIX + s
