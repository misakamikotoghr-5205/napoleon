# 卡牌版合同 1.3 的画面与演出骨架及验收。
# 主人 W0（Claude），X02 同步；参照接口合同 §7.11。
# Frozen hand interface. Contract: CARDS_INTERFACES.md section 7.11.6.
class_name CardHandApi
extends Control

signal card_played(uid: String, def_id: String, how: StringName)
signal card_selected(uid: String)


func refresh(_view: Dictionary) -> void:
	pass


func set_low(_on: bool) -> void:
	pass


func set_away(_on: bool) -> void:
	pass


func select_index(_i: int) -> void:
	pass


func play_selected() -> bool:
	return false


func play_uid(_uid: String) -> bool:
	return false


func card_rect(_uid: String) -> Rect2:
	return Rect2()
