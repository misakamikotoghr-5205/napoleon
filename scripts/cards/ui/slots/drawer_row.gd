# 人脉抽屉里的一行。拖出去的数据和头像、人脉小牌、留着的牌一样。主人 C03。不写 class_name。
# 换皮（10-22）：一行是一块 PanelContainer（人物行透明底、留着的牌是左边金线的批注条），里面自己排版。
# 鼠标 PASS：能拖，也不挡抽屉的滚轮。
extends PanelContainer

var payload: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_DRAG


func _get_drag_data(_at_position: Vector2) -> Variant:
	if payload.is_empty():
		return null
	return payload.duplicate(true)
