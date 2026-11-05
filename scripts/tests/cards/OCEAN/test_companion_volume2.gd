## C17 contracts: legal camp commands, serialization, and real combat commands.
## Controlled injury/chapter fixtures below isolate casualty and departure boundaries;
## the full campaign acceptance test owns the unaided narrative playthrough.
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const C = preload("res://scripts/cards/campaign/companion_rules.gd")
const P = preload("res://scripts/cards/campaign/battle/battle_pairs.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const Campaign = preload("res://scripts/cards/campaign/ocean_campaign.gd")
const Book = preload("res://scripts/cards/campaign/run/run_book.gd")
const V = preload("res://scripts/cards/campaign/ocean_view.gd")
const H = preload("res://scripts/tests/cards/OCEAN/run_helpers.gd")
const Policy = preload("res://scripts/tests/cards/OCEAN/map_policy.gd")
const B2 = preload("res://scripts/cards/campaign/ocean_battle2.gd")
const FORMAL := "res://data/campaigns/napoleon/book_volume2.json"
var t

func _initialize() -> void:
	t = T.new(self, "OCEAN_companion_volume2")
	_camp_commands()
	_departures_and_age()
	_conditional_prose()
	_pair_battles()
	_hunter_and_fate()
	print("OCEAN companion volume2 assertions: %d" % t.checks)
	t.finish()

func _write(name: String, value: Dictionary) -> String:
	var path: String = t.user_dir() + "/" + name + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	return path

func _new(path: String = FORMAL, options: Dictionary = {}) -> RefCounted:
	var model := Campaign.new()
	var opts := {"book": path, "seed": 17}
	opts.merge(options, true)
	var result := model.new_game(opts)
	t.ok(result.get("ok", false), "campaign opens: " + str(result))
	return model

func _send(model, command: String, args: Dictionary = {}) -> Dictionary:
	var result: Dictionary = model.send(StringName(command), args)
	t.ok(result.get("ok", false), command + " " + str(args) + ": " + str(result))
	return result

func _reject(model, command: String, args: Dictionary, code: String) -> void:
	var before: String = model.hash()
	t.eq(model.send(StringName(command), args).get("err"), code, "reject " + code)
	t.eq(model.hash(), before, "rejected command leaves snapshot unchanged")

func _camp_commands() -> void:
	var raw: Dictionary = Book.read_json(H.MINI)["data"]
	raw["volume"] = 2
	var companions: Dictionary = Book.read_json(raw["companions"])["data"]
	var authored: Dictionary = Book.read_json("res://data/campaigns/napoleon/companions.json")["data"]["companions"]
	for id in companions["companions"]:
		for key in ["reserve", "keep", "named_pairs"]:
			if authored.get(id, {}).has(key):
				companions["companions"][id][key] = authored[id][key].duplicate(true) if typeof(authored[id][key]) in [TYPE_ARRAY, TYPE_DICTIONARY] else authored[id][key]
	companions["companions"]["larrey"] = authored["larrey"].duplicate(true)
	raw["companions"] = _write("companions", companions)
	var trunk: Dictionary = Book.read_json(raw["segments"]["trunk"]["file"])["data"]
	trunk["scenes"][0]["choices"][1]["rogue"]["recruit"] = ["corso", "larrey"]
	raw["segments"]["trunk"]["file"] = _write("trunk", trunk)
	var path := _write("book", raw)
	var model = _new(path)
	H.to_day(model)
	_send(model, "campaign.appraise", {"id": "mt_seal"})
	_send(model, "campaign.choose", {"choice": "mt_take_letter"})
	H.to_day(model)
	_reject(model, "campaign.companion_duty", {"id": "corso", "duty": "reserve"}, "wrong_node")
	t.ok(H.walk_to(model, "a_muster"), "walk to real camp: " + H.last_error)
	H.to_day(model)
	var before_gold := int(model.state["rogue"]["coins"]["gold"])
	var before_heat := int(model.state["metrics"]["heat"])
	var public_before := V.query(model, &"card", {"uid": "squad"})
	t.ok(public_before["choices"].any(func(row): return row["id"] == "action:reserve:corso" and row["enabled"]), "squad offers legal reserve command")
	_send(model, "campaign.companion_duty", {"id": "corso", "duty": "reserve"})
	t.eq(model.state["rogue"]["coins"]["gold"], before_gold + 1, "smuggling pays once")
	t.eq(model.state["metrics"]["heat"], before_heat + 1, "smuggling also costs suspicion")
	# Controlled post-promotion injury: treatment must retain the earned ceiling.
	model.state["rogue"]["companions"]["baptiste"]["max_hp"] = 30
	model.state["rogue"]["companions"]["baptiste"]["scarred"] = true
	model.state["rogue"]["companions"]["baptiste"]["b_max_hp"] = 23
	_send(model, "campaign.companion_duty", {"id": "larrey", "duty": "reserve"})
	t.eq(model.state["rogue"]["companions"]["baptiste"]["b_max_hp"], 30, "Larrey restores the promoted HP ceiling")
	t.eq(model.state["rogue"]["companions"]["baptiste"]["scarred"], false, "Larrey removes a living companion's scar")
	t.eq(C.deployment_error(model, "corso"), "companion_on_duty", "reserve cannot deploy")
	_reject(model, "campaign.companion_duty", {"id": "corso", "duty": "reserve"}, "already_used")
	_reject(model, "campaign.companion_duty", {"id": "corso", "duty": "field"}, "duty_committed")
	_reject(model, "campaign.companion_duty", {"id": "corso", "duty": "reserve", "extra": 1}, "bad_args")
	var status := V.query(model, &"campaign")
	t.ok(status.has("named_pairs"), "second volume exposes named pairs")
	var row: Dictionary = status["companions"].filter(func(x): return x["id"] == "corso")[0]
	t.eq(row["duty"], "reserve", "public duty reports current commitment")
	t.ok(not JSON.stringify(status).contains("leave_rule"), "query never publishes departure conditions")
	var restored := Campaign.new()
	restored.load_book(path)
	t.ok(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).get("ok", false), "reserve survives JSON restore")
	t.eq(restored.hash(), model.hash(), "restoring does not pay chapter reward twice")
	var bad: Dictionary = model.snapshot()
	bad["rogue"]["companions"]["corso"]["duty_chapter"] = 9
	t.ok(not restored.restore(bad).get("ok", false), "malformed reserve chapter rejected")
	t.ok(not C.valid_optional({"companions": {"x": {"left": true, "recruited": true}}}), "departed recruited row rejected")
	var legacy = _new(H.MINI)
	var original: Dictionary = legacy.snapshot()
	C.on_scene(legacy)
	C.after_battle(legacy, {"deployed_ever": ["baptiste", "marie"]}, {"outcome": "victory"})
	t.eq(legacy.snapshot(), original, "V1 callbacks make no state changes")
	t.ok(not V.query(legacy, &"campaign").has("named_pairs"), "V1 query has no added pair field")
	t.ok(not V.query(legacy, &"campaign")["companions"][0].has("duty"), "V1 query has no added duty fields")
	_engine_duty(path)

func _engine_duty(path: String) -> void:
	var engine := CardEngine.new()
	t.ok(engine.new_game({"book": path, "seed": 17, "save_dir": t.user_dir() + "/engine"}).get("ok", false), "CardEngine starts the companion contract fixture")
	var policy := Policy.new()
	for _step in 80:
		if engine.query(&"campaign.map").get("pos") == "a_muster" and engine.view().get("phase") == "day":
			break
		t.ok(policy.step(engine).get("ok", false), "engine walks to camp: " + policy.last_error)
	t.eq(engine.query(&"campaign.map").get("pos"), "a_muster", "engine reaches reserve decision in actual map")
	t.ok(engine.send(&"card.choose", {"uid": "squad", "choice": "action:reserve:corso"}).get("ok", false), "existing squad controls dispatch reserve through the bridge")
	var save_path: String = t.user_dir() + "/duty.json"
	t.ok(engine.save_game(save_path).get("ok", false), "engine saves committed duty")
	var restored := CardEngine.new()
	t.ok(restored.load_game(save_path).get("ok", false), "engine loads committed duty")
	t.eq(restored.state_hash(), engine.state_hash(), "engine restore retains duty and once-only payment")
	for _step in 80:
		if engine.query(&"campaign").get("battle2", {}).get("phase") == "lineup":
			break
		t.ok(policy.step(engine).get("ok", false), "engine reaches battle: " + policy.last_error)
	var hash_before := engine.state_hash()
	t.eq(engine.send(&"campaign.battle_begin", {"companions": ["corso"], "troops": [], "protagonist": false}).get("err"), "companion_on_duty", "actual battle command rejects a reserved companion")
	t.eq(engine.state_hash(), hash_before, "failed reserved deployment is atomic")
	for _step in 100:
		if engine.query(&"campaign").get("chapter_id") == "mt_two":
			break
		t.ok(policy.step(engine).get("ok", false), "engine crosses chapter: " + policy.last_error)
	var corso: Dictionary = engine.query(&"campaign")["companions"].filter(func(x): return x["id"] == "corso")[0]
	t.eq(engine.query(&"campaign").get("chapter_id"), "mt_two", "actual chapter transition completes")
	t.eq(corso["duty"], "field", "next chapter returns the reserve to field duty")

func _scene(model, id: String) -> void:
	for i in model.definition["scenes"].size():
		if model.definition["scenes"][i]["id"] == id:
			model.state["scene_index"] = i
			return
	t.ok(false, "fixture scene exists: " + id)

func _joined(model, ids: Array) -> void:
	for id in ids:
		model.state["rogue"]["companions"][id]["recruited"] = true
		model.state["rogue"]["companions"][id]["alive"] = true

func _departures_and_age() -> void:
	var model = _new()
	_joined(model, ["murat", "rustam", "pierre", "baptiste", "marie"])
	_scene(model, "collapse_fontainebleau")
	C.on_scene(model)
	t.ok(model.state["rogue"]["companions"]["murat"].get("left", false), "Murat leaves in the collapse chapter")
	t.ok(model.state["rogue"]["companions"]["murat"]["alive"], "departure is not death")
	t.eq(C.recruit_error(model, "murat"), "companion_departed", "departed companion cannot be recruited again")
	var loyal = _new()
	_joined(loyal, ["murat"])
	loyal.state["rogue"]["army"]["trust"]["hero|murat"] = 3
	_scene(loyal, "collapse_fontainebleau")
	C.on_scene(loyal)
	t.ok(C.present(loyal, "murat"), "earned trust protects Murat from departure")
	for scene in model.definition["scenes"]:
		if scene["chapter"] == "elba":
			_scene(model, str(scene["id"]))
			break
	C.on_scene(model)
	t.ok(model.state["rogue"]["companions"]["rustam"].get("left", false), "Rustam leaves at Elba")
	t.eq(C.deployment_error(model, "pierre"), "companion_too_young", "young Pierre is excluded from combat")
	var cristo = _new(FORMAL, {"segment": "cristo", "stage": 0})
	_joined(cristo, ["caderousse", "albert", "haydee"])
	var heat: int = cristo.state["metrics"]["heat"]
	C.after_choice(cristo, "c_caderousse")
	t.ok(cristo.state["rogue"]["companions"]["caderousse"].get("left", false), "Caderousse leaves after the authored trigger")
	t.eq(cristo.state["metrics"]["heat"], heat + 20, "Caderousse departure has its consequence")
	C.after_choice(cristo, "c_caderousse")
	t.eq(cristo.state["metrics"]["heat"], heat + 20, "departure consequence is not repeated")
	cristo.state["used_actions"]["c_peers"] = ["appraise:witness"]
	t.eq(C.lineup_error(cristo, ["albert", "haydee"]), "", "inspection alone does not trigger discord")
	cristo.state["used_actions"]["c_peers"].append("choice:testimony")
	t.eq(C.lineup_error(cristo, ["albert", "haydee"]), "companion_discord", "the concluded peers scene activates discord")
	cristo.state["flags"]["m_mercedes_spared"] = true
	t.eq(C.lineup_error(cristo, ["albert", "haydee"]), "", "Mercedes exception permits both children")
	var battle := _battle("old_friends", 1)
	_do(battle, "deploy", {"unit": "baptiste", "col": 0, "row": 2})
	_do(battle, "deploy", {"unit": "marie", "col": 1, "row": 2})
	while battle["phase"] != "over":
		_do(battle, "fight")
	var result := R.result(battle)
	t.eq(result["outcome"], "victory", "trust fixture really wins a battle")
	C.after_battle(model, battle, result)
	t.eq(C.trust(model, "baptiste", "marie"), 1, "nonhero companions earn trust after fighting together")
	C.after_battle(model, battle, {"outcome": "retreat"})
	t.eq(C.trust(model, "baptiste", "marie"), 1, "retreat does not grow trust")
	model.state["rogue"]["companions"]["marie"]["alive"] = false
	C.after_battle(model, battle, result)
	t.eq(C.trust(model, "baptiste", "marie"), 1, "permanent death prevents trust growth")

func _conditional_prose() -> void:
	var model = _new()
	_scene(model, "collapse_fontainebleau")
	V.setup_text(model)
	var baseline: String = V._overlay["ocean.scene.collapse_fontainebleau"]["paras"]
	_joined(model, ["baptiste", "marie"])
	model.state["rogue"]["army"]["trust"]["baptiste|marie"] = 3
	C.on_scene(model)
	V.setup_text(model)
	t.ok(V._overlay["ocean.scene.collapse_fontainebleau"]["paras"].length() > baseline.length(), "earned marriage adds visible prose after cache rebuild")
	var conquest = _new(FORMAL, {"segment": "conquest", "stage": 0})
	_scene(conquest, "k_final")
	V.setup_text(conquest)
	baseline = V._overlay["ocean.scene.k_final"]["paras"]
	_joined(conquest, ["dantes", "faria"])
	conquest.state["rogue"]["army"]["trust"]["dantes|faria"] = 3
	C.on_scene(conquest)
	V.setup_text(conquest)
	t.ok(V._overlay["ocean.scene.k_final"]["paras"].length() > baseline.length(), "Spada bond unlocks visible letter")
	var cristo = _new(FORMAL, {"segment": "cristo", "stage": 0})
	V.setup_text(cristo)
	baseline = V._overlay["g02.ending.m_wait_hope"]["t"]
	_joined(cristo, ["dantes", "haydee"])
	cristo.state["rogue"]["army"]["trust"]["dantes|haydee"] = 3
	C.on_scene(cristo)
	V.setup_text(cristo)
	t.ok(V._overlay["g02.ending.m_wait_hope"]["t"].length() > baseline.length(), "waiting and hope unlocks visible ending paragraph")

func _template() -> Dictionary:
	return {"id": "pair_test", "name": "Pair test", "scale": "skirmish", "turn_limit": 6, "enemy_morale": 99,
		"map": [".......", "E=====G", "......."], "routes": {"road": ["G2", "F2", "E2", "D2", "C2", "B2", "A2"]},
		"waves": [{"turn": 6, "route": "road", "units": ["whitecoat"]}], "order": {"type": "hold", "cell": "B3", "turn": 6}}

func _battle(id: String, level: int, flags: Dictionary = {}, overrides: Dictionary = {}) -> Dictionary:
	var members: Array = P.MEMBERS[id]
	var roster: Array = []
	for who in members:
		if who == "hero":
			continue
		var row := {"id": who, "cls": "engineer" if who in ["baptiste", "faria"] else "line", "hp": 30, "atk": 4, "def": 0, "block": 1, "cost": 1}
		row["skill"] = "fortify" if who in ["baptiste", "faria"] else "raise_flag"
		if who == "marie":
			row["atk"] = 0
		roster.append(row)
	var setup := {"template": _template(), "seed": 20, "volume": 2, "roster": roster, "protagonist": {"enabled": "hero" in members},
		"pairs": [{"id": id, "name": id, "a": members[0], "b": members[1], "tier": level}], "pair_flags": flags}
	setup.merge(overrides, true)
	var state := R.new_battle("pair_test", setup)
	t.ok(not state.has("error"), "pair combat setup valid: " + str(state.get("errors", [])))
	return state

func _do(state: Dictionary, command: String, args: Dictionary = {}) -> void:
	var result := R.apply(state, command, args)
	t.ok(result.get("ok", false), command + " " + str(args) + ": " + str(result))

func _deploy_pair(state: Dictionary, first: String, second: String) -> void:
	_do(state, "deploy", {"unit": first, "col": 0, "row": 2})
	_do(state, "deploy", {"unit": second, "col": 1, "row": 2})

func _pair_battles() -> void:
	var old := R.new_battle("pair_test", {"template": _template()})
	t.ok(not old.has("pair_state"), "legacy kernel acquires no pair state")
	var malformed := R.new_battle("pair_test", {"template": _template(), "pairs": [{"id": "shield", "a": "muiron", "b": "hero", "tier": 9}]})
	t.ok(malformed.has("error"), "invalid pair tier is rejected at setup")
	var state := _battle("rivals", 1)
	_deploy_pair(state, "lannes", "murat")
	t.eq(R._unit_atk(state, state["units"]["lannes"]), 6, "rival attack bonus reaches actual damage stats")
	var before := state.duplicate(true)
	R.view(state)
	R.preview(state)
	t.eq(state, before, "query and forecast never consume pair effects")
	var morale := int(state["morale"])
	_do(state, "fight")
	t.eq(state["morale"], morale - 1, "adjacent rivals consume morale each firefight")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(state))
	_do(state, "fight")
	_do(restored, "fight")
	t.eq(R.view(state), R.view(restored), "pair state survives JSON roundtrip deterministically")
	state = _battle("master_pupil", 3)
	_deploy_pair(state, "dantes", "faria")
	t.eq(R._unit_atk(state, state["units"]["dantes"]), 6, "adjacent mentor adds attack")
	_do(state, "fight")
	_do(state, "fight")
	before = state.duplicate(true)
	_do(state, "skill", {"unit": "faria", "col": 1, "row": 1})
	t.eq(state["units"].values().filter(func(u): return u["kind"] == "barricade").size(), 2, "Faria skill creates two real barricades")
	_do(state, "undo")
	t.eq(state, before, "undo removes both pair barricades and their IDs")
	state = _battle("old_friends", 3)
	_deploy_pair(state, "baptiste", "marie")
	state["units"]["baptiste"]["hp"] = 0 # Controlled lethal injury before the real casualty sweep.
	_do(state, "fight")
	t.eq(R._unit_atk(state, state["units"]["marie"]), 3, "zero-base medic gains the survivor's attack")
	t.eq(R.apply(state, "withdraw", {"unit": "marie"}).get("err"), "bond_committed", "enraged survivor cannot withdraw")
	t.eq(P.fate_bonus(state, "baptiste"), 1, "fallen spouse receives extra fate coin")
	t.eq(P.fate_bonus(state, "marie"), 1, "surviving spouse retains an extra future fate coin")
	state = _battle("shield", 2)
	_deploy_pair(state, "muiron", "hero")
	t.eq(P.target(state, {"tags": ["hunter"]}, state["units"]["hero"])["uid"], "muiron", "hunter targeting redirects to the guard")
	state["units"]["hero"]["hp"] = 0
	_do(state, "fight")
	t.eq(state["units"]["hero"]["hp"], 1, "guard saves a lethal hero hit through casualty sweep")
	t.eq(state["units"]["muiron"]["status"], "dying", "guard enters normal carry/fate lifecycle")
	t.eq(P.fate_bonus(state, "muiron"), -1, "guard's personal fate penalty is recorded")
	state = _battle("wait_and_hope", 2)
	_deploy_pair(state, "dantes", "haydee")
	state["units"]["dantes"]["hp"] -= 5
	_do(state, "fight")
	t.eq(state["units"]["dantes"]["hp"], state["units"]["dantes"]["max_hp"] - 3, "Haydee heals Dantes after combat")
	state["units"]["dantes"]["hp"] = 0
	_do(state, "fight")
	t.eq(state["units"]["haydee"]["charge"], R.SKILLS[state["units"]["haydee"]["skill"]]["charge"], "Dantes falling immediately readies Haydee")
	state = _battle("enemy_name", 3, {"truth": true, "auteuil": true})
	_deploy_pair(state, "bertuccio", "hero")
	morale = state["morale"]
	_do(state, "fight")
	t.eq(state["morale"], morale, "truth cancels Bertuccio discord")
	t.eq(P.target(state, {"tags": ["hunter"]}, state["units"]["hero"])["uid"], "bertuccio", "Auteuil guard redirects first hunter hit")
	t.eq(P.target(state, {"tags": ["hunter"]}, state["units"]["hero"])["uid"], "hero", "Auteuil guard is once per battle")
	state = _battle("old_neighbours", 2, {"caderousse_sworn": true})
	_deploy_pair(state, "caderousse", "dantes")
	t.eq(R._unit_atk(state, state["units"]["caderousse"]), 6, "sworn neighbour gains attack")
	_do(state, "fight")
	_do(state, "withdraw", {"unit": "dantes"})
	t.eq(R._unit_atk(state, state["units"]["caderousse"]), 6, "sworn bonus lasts through the battle")
	state = _battle("father_son", 2)
	_deploy_pair(state, "morel", "maximilien")
	_do(state, "fight")
	_do(state, "fight")
	_do(state, "fight")
	_do(state, "skill", {"unit": "morel"})
	t.eq(state["fx"]["flags"][-1]["until"], state["turn"] + 2, "father and son extend their row's flag to three turns")
	state = _battle("two_children", 2, {"mercedes": true})
	_deploy_pair(state, "albert", "haydee")
	t.eq(R._unit_atk(state, state["units"]["albert"]), 5, "reconciled children gain attack")
	state = _battle("last_square", 2)
	_deploy_pair(state, "cambronne", "ney")
	t.eq(P.morale(state, 2), 5, "last square rescues morale once")
	t.eq(P.morale(state, 2), 2, "last square cannot repeat its rescue")
	state["units"]["ney"]["kind"] = "npc"
	t.eq(P.tier(state, "last_square"), 0, "protected NPCs never stand in for a companion bond")

func _hunter_and_fate() -> void:
	var template := _template()
	template["waves"].push_front({"turn": 1, "route": "road", "units": ["dragoon"]})
	var state := _battle("shield", 1, {}, {"template": template})
	_do(state, "deploy", {"unit": "muiron", "col": 1, "row": 2})
	_do(state, "deploy", {"unit": "hero", "col": 2, "row": 2})
	var hero_hp: int = state["units"]["hero"]["hp"]
	var guard_hp: int = state["units"]["muiron"]["hp"]
	for _turn in 3:
		_do(state, "fight")
		if state["units"]["muiron"]["hp"] < guard_hp:
			break
	t.eq(state["units"]["hero"]["hp"], hero_hp, "a real hunter attack does not damage the protected hero")
	t.ok(state["units"]["muiron"]["hp"] < guard_hp, "a real hunter attack damages the guard")
	state = _battle("shield", 2)
	_do(state, "deploy", {"unit": "muiron", "col": 0, "row": 0})
	_do(state, "deploy", {"unit": "hero", "col": 2, "row": 2})
	t.eq(P.target(state, {"tags": ["hunter"]}, state["units"]["hero"])["uid"], "hero", "authored adjacent requirement prevents a remote interception")
	state["units"]["hero"]["hp"] = 0
	_do(state, "fight")
	t.eq(state["units"]["hero"]["status"], "down", "remote guard cannot substitute for the hero's fall")
	t.eq(state["units"]["muiron"]["status"], "ok", "remote guard stays alive")
	state = _battle("shield", 2)
	_deploy_pair(state, "muiron", "hero")
	state["units"]["muiron"]["scarred"] = true
	state["units"]["hero"]["hp"] = 0
	_do(state, "fight")
	_do(state, "carry", {"unit": "muiron"})
	_do(state, "retreat")
	var result := R.result(state)
	var fallen: Dictionary = result["fallen"].filter(func(f): return f["unit"] == "muiron")[0]
	t.eq(fallen["coins"], 3, "guard penalty and carry reward both reach the fate settlement")
	t.eq(fallen["carried"], true, "interception retains ordinary carrying rules")
	var json_state: Dictionary = JSON.parse_string(JSON.stringify(state))
	t.eq(R.result(json_state), result, "fate coins and mortality remain fixed after serialization")
	state = _battle("last_square", 2)
	state["template"] = "waterloo"
	state["units"]["cambronne"]["fated"] = true
	state["units"]["ney"]["fated"] = true
	_deploy_pair(state, "cambronne", "ney")
	state["units"]["cambronne"]["hp"] = 0
	_do(state, "fight")
	state["units"]["ney"]["hp"] = 0
	_do(state, "fight")
	_do(state, "retreat")
	result = R.result(state)
	for who in ["cambronne", "ney"]:
		fallen = result["fallen"].filter(func(f): return f["unit"] == who)[0]
		t.eq(fallen["coins"], 2, "Waterloo fate penalty is cancelled for " + who + " even when they fall on different turns")
	state = _battle("father_son", 2)
	_deploy_pair(state, "morel", "maximilien")
	state["units"]["morel"]["hp"] = 0
	_do(state, "fight")
	state["units"]["maximilien"]["hp"] = 0
	_do(state, "fight")
	_do(state, "retreat")
	result = R.result(state)
	fallen = result["fallen"].filter(func(f): return f["unit"] == "maximilien")[0]
	t.eq(fallen["coins"], 3, "father falling adds one to son's later fate roll")
