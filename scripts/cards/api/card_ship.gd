# 是不是发行版（Steam 包带自定义特性 ship）。发行版不许读开发配色、不许显示【稿】、不许合成占位音频。
# 主人 W0（Claude），冻结。合同：docs/cards/CARDS_INTERFACES.md §2.3、§11。
class_name CardShip
extends RefCounted


static func is_ship() -> bool:
	return OS.has_feature("ship")
