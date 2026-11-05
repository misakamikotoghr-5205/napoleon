# 画面容器。1.3 起分区改到场景层、HUD 和抽屉；这个节点留下来，是因为 W0 和 C16 还拿 game.table 扫字。
# 主人 C01。不写 class_name。
extends Control

signal card_pressed(uid: String)

var bus: CardEventBus = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)


## W0 / 旧测仍可能调 table._on_card_pressed。
func _on_card_pressed(uid: String) -> void:
	if bus != null:
		bus.ui_event.emit(&"hand_selected", {"uid": uid})
	card_pressed.emit(uid)


## W0 / C04 旧测仍会调 table.refresh(view)；1.3 起画面由场景层/HUD 刷新，这里留空兼容。
## 不在此登记空 Control 热点——真锚点由 CardStage / DrawerHost 登记。
func refresh(_view: Dictionary) -> void:
	pass
