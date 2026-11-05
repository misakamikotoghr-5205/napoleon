# 卡牌版合同 1.3 的画面与演出骨架及验收。
# 主人 W0（Claude），X02 同步；参照接口合同 §7.11。
# Frozen counter checks interface. Contract: CARDS_INTERFACES.md section 7.11.7.
class_name CardChecksApi
extends Control

signal changed
signal coins_finished(success: bool)


func show_checks(_card_uid: String) -> void:
	pass


func hide_checks() -> void:
	pass


func is_shown() -> bool:
	return false


func preview() -> Dictionary:
	return {}


func play_coins(_faces: Array, _need: int) -> void:
	pass


func skip_coins() -> void:
	pass
