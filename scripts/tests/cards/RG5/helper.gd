# RG5 test helper: a private copy of data/cards with rules/legacy.json (ROGUE_V1.md §6.3) and the nine tutorial
# cards of days 1-3 gated by {"not": {"veteran": true}} (§5.6), under the test's own user:// directory.
# RG3 ships the same two changes in the real data; writing them again here is harmless. Owner RG5.
extends RefCounted

const LEGACY := {
	"_meta": {"owner": "RG3", "schema": 1, "brief": "RG5 test fixture: same content as ROGUE_V1.md 6.3."},
	"openings": {
		"og.default": {"veteran": false, "notice": "", "unlock_closed": 0, "order": 0},
		"og.shanghai": {"veteran": true, "notice": "rg5.notice.shanghai", "unlock_closed": 1, "order": 10},
	},
	"chronicle": {"kind_at": 20, "hard_at": -20},
}
const TUTORIAL_GATED: Array[String] = ["p.brother.1938.tut_handover", "p.zhang.1938.tut_pawn", "p.wu.1938.tut_sell",
	"p.xiaoding.1938.tut_buy", "p.sunyoung.1938.tut_pawn", "p.guanjia.1938.tut_buy", "ev.1938.tut_slots",
	"p.li.1938.tut_sell", "p.postman.1938.tut_buy"]
const VETERAN_WHEN := {"not": {"veteran": true}}


static func data_root(t) -> String:
	var root: String = t.user_dir() + "/cards"
	copy_tree("res://data/cards", root)
	write(root + "/rules/legacy.json", LEGACY)
	var path := root + "/era/1938/tutorial.json"
	var tut: Dictionary = CardDB.read_json(path)
	for card in tut.get("cards", []):
		if TUTORIAL_GATED.has(str(card.get("id", ""))):
			card["schedule"]["when"] = VETERAN_WHEN.duplicate(true)
	write(path, tut)
	return root


static func copy_tree(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	for file in DirAccess.get_files_at(src):
		if file.ends_with(".import") or file.ends_with(".uid"):
			continue
		DirAccess.copy_absolute(src + "/" + file, dst + "/" + file)
	for sub in DirAccess.get_directories_at(src):
		copy_tree(src + "/" + sub, dst + "/" + sub)


static func write(path: String, data) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ", true, true))
	f.close()


static func engine(root: String, save_dir: String, seed_value: int, run: Dictionary, bus: CardEventBus = null) -> CardEngine:
	var e := CardEngine.new(bus)
	var opts := {"seed": seed_value, "data_root": root, "save_dir": save_dir}
	if not run.is_empty():
		opts["run"] = run
	var r := e.new_game(opts)
	if not bool(r.get("ok", false)):
		push_error("RG5 helper: new_game failed " + str(r))
	return e


## Hand defs of the cards in hand.
static func hand_defs(e: CardEngine) -> Array:
	var out: Array = []
	for uid in CardPiles.list(e.ctx, CardIds.ZONE_HAND):
		out.append(str(CardPiles.card(e.ctx, uid).get("def", "")))
	return out


## Send day.end {confirm: true} until the given stage day's morning (or day when open_day) is reached.
static func to_morning(e: CardEngine, stage_day: int, limit: int = 200) -> bool:
	for _i in limit:
		var v := e.view()
		if str(v.get("phase", "")) == "morning" and int(v.get("date", {}).get("stage_day", 0)) == stage_day:
			return true
		if str(v.get("phase", "")) == "game_over":
			return false
		if not bool(e.send(&"day.end", {"confirm": true}).get("ok", false)):
			return false
	return false
