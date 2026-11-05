# 卡牌版合同 1.3 的画面与演出骨架及验收。
# 主人 W0（Claude），X02 同步；参照接口合同 §7.11。
# Frozen stage panel base. Contract: CARDS_INTERFACES.md section 7.11.4.
class_name CardStagePanel
extends CardPanel

var stage: CardStageApi
var dialog: CardDialogApi
var checks: CardChecksApi
var hand: CardHandApi


func bind_stage(p_stage: CardStageApi, p_dialog: CardDialogApi, p_checks: CardChecksApi, p_hand: CardHandApi) -> void:
	stage = p_stage
	dialog = p_dialog
	checks = p_checks
	hand = p_hand


func begin_play(uid: String) -> Dictionary:
	if engine == null:
		return {}
	var card_view := engine.query(&"card", {"uid": uid})
	if card_view.is_empty() or not bool(card_view.get("ok", true)):
		return {}
	var script := CardStageScript.resolve(card_view, engine.view())
	if stage != null:
		stage.play(script)
	if dialog != null:
		dialog.show_lines(uid, CardStageScript.lines(script, "intro"))
	return script


func end_play() -> void:
	if stage != null:
		stage.clear_play()
	if dialog != null:
		dialog.clear()
	if checks != null:
		checks.hide_checks()
	if hand != null:
		hand.set_low(false)


func on_reply(_reply_id: String) -> void:
	pass


func on_card_played(_uid: String, _def_id: String) -> bool:
	return false


func on_hotspot(_id: StringName) -> bool:
	return false
