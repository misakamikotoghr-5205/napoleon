# 卡牌版合同 1.3 的画面与演出骨架及验收。
# 主人 W0（Claude），X02 同步；参照接口合同 §7.11。
# Frozen scene interface. Contract: CARDS_INTERFACES.md section 7.11.3.
class_name CardStageApi
extends Control

signal hotspot_pressed(id: StringName)
signal card_dropped(data: Dictionary)


func refresh(_view: Dictionary) -> void:
	pass


func play(_script: Dictionary) -> void:
	pass


func clear_play() -> void:
	pass


func set_items(_items: Array) -> void:
	pass


func set_talking(_who: String) -> void:
	pass


func set_dim_tools(_on: bool) -> void:
	pass


func spot_rect(_spot: StringName) -> Rect2:
	return Rect2()
