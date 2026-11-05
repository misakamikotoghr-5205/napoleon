## Volume-two orders use real deployment, firefights, undo, serialization and controls.
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const Hud = preload("res://scripts/tests/cards/OCEAN/test_battle_hud.gd")
const BattlePanel = preload("res://scripts/cards/ui/battle/battle_panel.gd")
var t

func _initialize() -> void:
	t = T.new(self, "OCEAN_battle_orders")
	t.run_async(_body)

func _body() -> void:
	_validation()
	_compatibility()
	_extract()
	_escape()
	_protect()
	_escort()
	await _move_ui()
	print("OCEAN battle orders assertions: %d" % t.checks)

func _template(order: Dictionary, limit: int = 6) -> Dictionary:
	return {"id": "orders", "name": "Order test", "scale": "skirmish", "turn_limit": limit, "enemy_morale": 99,
		"map": [".......", "E=====G", "......."],
		"routes": {"road": ["G2", "F2", "E2", "D2", "C2", "B2", "A2"]},
		"waves": [{"turn": limit, "route": "road", "units": ["whitecoat"]}],
		"order": {"type": "hold", "cell": "B3", "turn": limit}, "order_next": order}

func _new(order: Dictionary, extra: Dictionary = {}, limit: int = 6) -> Dictionary:
	var options := {"template": _template(order, limit), "seed": 7, "volume": 2, "level": 1,
		"roster": [{"id": "dantes", "cls": "line", "hp": 50, "atk": 0, "block": 0, "cost": 1},
			{"id": "searcher", "cls": "line", "hp": 50, "atk": 0, "block": 0, "cost": 1}],
		"protagonist": {"enabled": true}}
	options.merge(extra, true)
	var state := R.new_battle("orders", options)
	t.ok(not state.has("error"), "valid order battle: " + str(state.get("errors", [])))
	return state

func _do(state: Dictionary, cmd: String, args: Dictionary = {}) -> void:
	t.ok(R.apply(state, cmd, args).get("ok", false), "legal " + cmd + " " + str(args))

func _reject(state: Dictionary, cmd: String, args: Dictionary, label: String) -> void:
	var before := state.duplicate(true)
	t.eq(R.apply(state, cmd, args).get("ok"), false, label + " rejects")
	t.eq(state, before, label + " does not mutate")

func _finish(state: Dictionary) -> Dictionary:
	for _turn in range(25):
		if state.get("phase") == "over":
			break
		_do(state, "fight")
	t.eq(state.get("phase"), "over", "fight terminates")
	return R.result(state)

func _validation() -> void:
	for order in [
		{"type": "escape", "unit": "dantes", "cells": ["Q99"], "turn": 6},
		{"type": "escape", "unit": "", "cells": [], "turn": 7},
		{"type": "extract", "cell": "A2", "turns": 0},
		{"type": "protect"}, {"type": "protect", "unit": "dantes", "npc": {}},
		{"type": "protect", "npc": {"id": "hero", "name": "bad", "hp": -1, "cell": "B3"}},
		{"type": "extract", "cell": "B3", "turns": 2, "escape": {"npc": {"id": "rescue", "name": "npc", "hp": 10, "cell": "C3"}, "path": ["C3", "A3"]}},
		{"type": "extract", "cell": "B3", "turns": 2, "escape": {"npc": {"id": "rescue", "name": "npc", "hp": 10, "cell": "C3"}, "path": ["C3", ""]}}
	]:
		t.ok(not R.validate_template(_template(order)).is_empty(), "malformed objective rejected: " + str(order))
	t.ok(not R.validate_template(_template({"type": "protect", "unit": "dantes"})).size(), "protect unit validates")
	var invalid := _template({})
	invalid["order"] = 5
	t.eq(R.new_battle("orders", {"template": invalid}).get("error"), "bad_template", "bad legacy order cannot crash selection")

func _compatibility() -> void:
	var template := _template({"type": "extract", "cell": "B3", "turns": 2})
	var old := R.new_battle("orders", {"template": template, "seed": 8, "act": 1})
	t.eq(old["order_goal"], template["order"], "no volume selects V1 fallback")
	t.ok(not old.has("order_progress"), "legacy state gains no objective fields")
	var one := R.new_battle("orders", {"template": template, "seed": 8, "act": 1, "volume": 1})
	t.eq(old, one, "explicit V1 is byte-equivalent")
	var state := _new({"type": "escape", "unit": "dantes", "cells": ["B3"], "turn": 6}, {"mods": {"prep_turn": 1}})
	t.eq(state["order_goal"]["turn"], 7, "preparation turn delays escape deadline")

func _extract() -> void:
	var state := _new({"type": "extract", "cell": "B3", "turns": 3, "gold_after": 3, "gold_each": 1})
	_do(state, "deploy", {"unit": "searcher", "col": 1, "row": 2})
	var before := state.duplicate(true)
	R.preview(state)
	R.view(state)
	t.eq(state, before, "preview and progress query do not collect")
	_do(state, "fight")
	t.eq(state["order_progress"]["count"], 1, "occupied completed firefight collects once")
	_do(state, "withdraw", {"unit": "searcher"})
	_do(state, "fight")
	t.eq(state["order_progress"]["count"], 1, "empty turn does not collect")
	_do(state, "fight")
	_do(state, "deploy", {"unit": "searcher", "col": 1, "row": 2})
	_do(state, "fight")
	t.eq(state["order_progress"]["count"], 2, "collection need not be consecutive")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(state))
	var result := _finish(state)
	t.eq(_finish(restored), result, "serialized collection has identical rewards")
	t.eq(result["order_done"], true, "cumulative extraction completed")
	t.eq(result["rewards"]["gold"], 2, "post-threshold extraction gold settled exactly once")
	var empty := _new({"type": "extract", "cell": "B3", "turns": 2})
	t.eq(_finish(empty)["order_done"], false, "surviving without collecting does not complete the order")

func _escape() -> void:
	var state := _new({"type": "escape", "unit": "dantes", "start_cell": "F3", "cells": ["B3"], "turn": 4})
	_reject(state, "deploy", {"unit": "dantes", "col": 1, "row": 2}, "cannot deploy straight at exit")
	_do(state, "deploy", {"unit": "dantes", "col": 5, "row": 2})
	_reject(state, "move", {"unit": "hero", "col": 4, "row": 2}, "only the escape target moves")
	_reject(state, "move", {"unit": "dantes", "col": 3, "row": 2}, "cannot teleport")
	_reject(state, "move", {"unit": "dantes", "col": 4, "row": 2, "extra": true}, "move rejects unknown args")
	var before := state.duplicate(true)
	R.preview_cmd(state, "move", {"unit": "dantes", "col": 4, "row": 2})
	t.eq(state, before, "move preview is pure")
	_do(state, "move", {"unit": "dantes", "col": 4, "row": 2})
	t.eq(state["cp"], int(before["cp"]) - 1, "move costs one CP")
	_reject(state, "move", {"unit": "dantes", "col": 3, "row": 2}, "at most one move per turn")
	_do(state, "undo")
	t.eq(state, before, "move undo restores resources and turn allowance")
	for col in [4, 3, 2, 1]:
		_do(state, "move", {"unit": "dantes", "col": col, "row": 2})
		_do(state, "fight")
	t.eq(state["units"]["dantes"]["status"], "escaped", "target leaves field at deadline")
	t.eq(_finish(state)["order_done"], true, "legal movement completes escape")
	var missed := _new({"type": "escape", "unit": "dantes", "cells": ["B3"], "turn": 2})
	_do(missed, "fight")
	_do(missed, "fight")
	_do(missed, "deploy", {"unit": "dantes", "col": 1, "row": 2})
	t.eq(_finish(missed)["order_done"], false, "late arrival cannot complete a missed deadline")
	var blocked := _new({"type": "escape", "unit": "dantes", "cells": ["B3"], "turn": 6})
	_do(blocked, "deploy", {"unit": "dantes", "col": 1, "row": 2})
	_do(blocked, "deploy", {"unit": "searcher", "col": 2, "row": 2})
	_reject(blocked, "move", {"unit": "dantes", "col": 2, "row": 2}, "occupied destination")
	_reject(blocked, "move", {"unit": "dantes", "col": 1, "row": 3}, "outside the battlefield")
	var voided := _new({"type": "escape", "unit": "dantes", "cells": ["F3"], "turn": 6}, {"mods": {"terrain": [{"cell": "C3", "terrain": "void"}]}})
	_do(voided, "deploy", {"unit": "dantes", "col": 1, "row": 2})
	_reject(voided, "move", {"unit": "dantes", "col": 2, "row": 2}, "cannot enter void")
	var costly := _new({"type": "escape", "unit": "dantes", "cells": ["F3"], "turn": 6}, {"roster": [{"id": "dantes", "cls": "line", "cost": 6}]})
	_do(costly, "deploy", {"unit": "dantes", "col": 1, "row": 2})
	_reject(costly, "move", {"unit": "dantes", "col": 2, "row": 2}, "cannot move without CP")
	var encounter := _template({"type": "escape", "unit": "dantes", "cells": ["B3"], "turn": 6})
	encounter["waves"][0]["turn"] = 1
	for hp in [30, 1]:
		var engaged := _new(encounter["order_next"], {"template": encounter, "roster": [{"id": "dantes", "cls": "line", "hp": hp, "cost": 1, "atk": 0, "block": 1, "def": 0}]})
		_do(engaged, "deploy", {"unit": "dantes", "col": 4, "row": 1})
		_do(engaged, "fight")
		t.eq(engaged["units"]["dantes"]["status"], "ok" if hp > 1 else "dying", "enemy actually engages escape target")
		_reject(engaged, "move", {"unit": "dantes", "col": 4, "row": 2}, "engaged or fallen unit cannot move")


func _protect() -> void:
	var absent := _new({"type": "protect", "unit": "dantes"})
	t.eq(_finish(absent)["order_done"], false, "undeployed partner cannot satisfy protection")
	var alive := _new({"type": "protect", "unit": "dantes"})
	_do(alive, "deploy", {"unit": "dantes", "col": 1, "row": 2})
	t.eq(_finish(alive)["order_done"], true, "deployed survivor protected")
	var goal := {"type": "protect", "npc": {"id": "witness", "name": "Witness", "cell": "B3", "hp": 12}}
	var witness := _new(goal)
	t.eq(witness["units"]["witness"]["status"], "ok", "fixed witness is present from start")
	t.eq(R.view(witness)["field_count"], 0, "witness does not consume soldier capacity")
	t.ok(not R.view(witness)["deploy_bar"].any(func(u: Dictionary) -> bool: return u["uid"] == "witness"), "witness has no player deployment card")
	_reject(witness, "withdraw", {"unit": "witness"}, "witness cannot be withdrawn to safety")
	_reject(witness, "move", {"unit": "witness", "col": 2, "row": 2}, "player cannot move a fixed witness")
	t.eq(_finish(witness)["order_done"], true, "living witness protected")
	var invaded := _template({"type": "protect", "npc": {"id": "witness", "name": "Witness", "cell": "E2", "hp": 12}}, 3)
	invaded["waves"][0]["turn"] = 1
	var failed := _new(invaded["order_next"], {"template": invaded}, 3)
	t.eq(_finish(failed)["order_done"], false, "enemy entering witness cell fails protection")
	t.eq(failed["units"]["witness"]["status"], "down", "invaded witness removed from battle")
	var shot := _template(goal, 3)
	shot["map"][0] = "......^"
	shot["waves"].append({"turn": 1, "at": "G1", "first_fire": 2, "units": ["gun"]})
	shot["order_next"]["npc"]["hp"] = 1
	var target := _new(shot["order_next"], {"template": shot}, 3)
	t.eq(_finish(target)["order_done"], false, "unprotected witness can be shot")
	t.eq(target["units"]["witness"]["status"], "down", "ranged witness damage resolves through normal HP")
	var partner_tpl := _template({"type": "protect", "unit": "dantes"}, 1)
	var partner := _new(partner_tpl["order_next"], {"template": partner_tpl, "roster": [{"id": "dantes", "cls": "line", "hp": 1, "atk": 0, "block": 1, "def": 0, "cost": 1}]}, 1)
	_do(partner, "deploy", {"unit": "dantes", "col": 4, "row": 1})
	t.eq(_finish(partner)["order_done"], false, "a fallen protected partner loses the objective")


func _escort() -> void:
	var order := {"type": "extract", "cell": "B3", "turns": 2, "escape": {
		"npc": {"id": "rescued", "name": "Rescued", "cell": "C3", "hp": 12}, "path": ["C3", "D3", "E3", "F3"]}}
	var state := _new(order)
	_do(state, "deploy", {"unit": "searcher", "col": 1, "row": 2})
	_do(state, "fight")
	t.ok(not state["units"].has("rescued"), "captive is absent before search completes")
	_do(state, "fight")
	t.eq(state["units"]["rescued"]["col"], 2, "search frees NPC at the authored exit")
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(state))
	var result := _finish(state)
	t.eq(_finish(loaded), result, "escorting survives serialization deterministically")
	t.eq(result["order_done"], true, "search and escort both complete")
	t.eq(state["units"]["rescued"]["status"], "escaped", "rescued NPC leaves battlefield safely")

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
	await t.frames(2)

func _move_ui() -> void:
	var state := _new({"type": "escape", "unit": "dantes", "start_cell": "F3", "cells": ["B3"], "turn": 6})
	_do(state, "deploy", {"unit": "dantes", "col": 5, "row": 2})
	var engine := Hud.FakeEngine.new()
	engine.state = state
	var panel := BattlePanel.new()
	panel.bind(engine, null)
	root.add_child(panel)
	panel.open({})
	await t.frames(3)
	var board = panel.get("_board")
	await _click(board.global_position + board.cell_center(5, 2))
	var button := panel.find_child("Act_move", true, false) as Button
	t.ok(button != null and button.is_visible_in_tree(), "escape target offers real movement control")
	if button != null:
		await _click(button.get_global_rect().get_center())
		await _click(board.global_position + board.cell_center(4, 2))
		t.eq(engine.state["units"]["dantes"]["col"], 4, "real control and grid click move escape target")
		t.ok(engine.sent.any(func(row: Array) -> bool: return row[0] == "campaign.battle_cmd" and row[1].get("cmd") == "move"), "UI sends public move command")
	panel.queue_free()
	await t.frames(2)
