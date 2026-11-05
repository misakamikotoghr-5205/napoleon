# 可点、可拖的来源按钮。拖拽数据在 payload 里。主人 C03。不写 class_name。
# 合同：docs/cards/CARDS_INTERFACES.md §7.4（source）、§7.8。
extends Button

var payload: Dictionary = {}


func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or payload.is_empty():
		return null
	return payload.duplicate(true)
