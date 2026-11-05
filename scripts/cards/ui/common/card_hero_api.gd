# 卡牌版合同 1.3 的画面与演出骨架及验收。
# 主人 W0（Claude），X02 同步；参照接口合同 §7.11。
# Frozen hero interface. Contract: CARDS_INTERFACES.md section 7.11.6.
class_name CardHeroApi
extends Control

signal person_pressed(uid: String)


func refresh(_view: Dictionary) -> void:
	pass
