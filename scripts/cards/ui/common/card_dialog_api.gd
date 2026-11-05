# 卡牌版合同 1.3 的画面与演出骨架及验收。
# 主人 W0（Claude），X02 同步；参照接口合同 §7.11。
# Frozen dialog interface. Contract: CARDS_INTERFACES.md section 7.11.5.
class_name CardDialogApi
extends Control

signal advanced(index: int)
signal lines_done
signal reply_chosen(reply_id: String)

var chars_per_sec: int = 40


func show_lines(_uid: String, _lines: Array, _append: bool = false) -> void:
	pass


func set_replies(_replies: Array) -> void:
	pass


func clear() -> void:
	pass


func skip() -> void:
	pass


func is_idle() -> bool:
	return true


func has_replies() -> bool:
	return false


func set_max_bottom(_y: int) -> void:
	pass


func current_uid() -> String:
	return ""
