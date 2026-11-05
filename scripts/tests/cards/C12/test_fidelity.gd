# Clarity comes from the process only (DESIGN P3, 4.5): 300, +400 when the book was open before the first
# pin (or nothing was pinned), +300 when the lens was used; never from how many calls were right.
# Then the catalog's thresholds (clear >= 700, partial >= 350) give clear / partial / vague.
# Old assertion "autoplay(0.2) is less clear than autoplay(0.9) for every fixture" now only holds where
# the book starts shut (old params open it for you); measures are the player's ops, minutes are
# 2 a pin + 1 for opening the book. Owner C12. Contract: CARDS_INTERFACES 8.1, 12.2.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")


func _initialize() -> void:
	var t := T.new(self, "C12_fidelity")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	t.ok(mock.db != null, "text db")
	await t.frames(1)
	var cfg: Dictionary = CardDB.read_json("res://data/cards/rules/economy.json").get("appraise", {})
	var clear := int(cfg.get("clear_permille", 700))
	var partial := int(cfg.get("partial_permille", 350))
	var p: Dictionary = Lib.fixture("hairpin3")
	var rows: Array = [
		[[["atlas"], ["tool", "lens"], ["pin", 38, 24, 1], ["done"]], 1000, "book first + lens"],
		[[["atlas"], ["pin", 38, 24, 1], ["done"]], 700, "book first, no lens"],
		[[["tool", "lens"], ["pin", 38, 24, 1], ["atlas"], ["done"]], 600, "pinned before the book, lens"],
		[[["pin", 38, 24, 1], ["done"]], 300, "no book, no lens"],
		[[["atlas"], ["done"]], 700, "book, nothing pinned"],
		[[["done"]], 700, "nothing at all"],
	]
	for row in rows:
		var r = Lib.replay(self, p, row[0])
		t.eq(int(r.get("quality_permille", -1)), int(row[1]), str(row[2]))
		_check_result(t, r, str(row[2]))
	t.ok(1000 >= clear and 700 >= clear, "book first reads clear")
	t.ok(600 < clear and 600 >= partial, "no book first reads partial")
	t.ok(300 < partial, "no book, no lens reads vague")
	var right = Lib.replay(self, p, [["atlas"], ["tool", "lens"], ["pin", 28, 35, 2], ["pin", 38, 24, 1], ["done"]])
	var wrong = Lib.replay(self, p, [["atlas"], ["tool", "lens"], ["pin", 28, 35, 1], ["pin", 38, 24, 2], ["done"]])
	t.eq(right.get("quality_permille"), wrong.get("quality_permille"), "right or wrong, same clarity")
	var nothing = Lib.replay(self, p, [["atlas"], ["done"]])
	t.eq(nothing.get("observations"), ["obs.spot.nothing_found"], "book read, nothing pinned")
	var blind = Lib.replay(self, p, [["done"]])
	t.eq(blind.get("observations"), [], "book shut, nothing pinned: nothing to say")
	for name in Lib.fixture_names():
		var params: Dictionary = Lib.fixture(name)
		var low: Dictionary = Lib.run(self, params, func(game: CardSpotGame) -> void: game.autoplay(0.2))
		var high: Dictionary = Lib.run(self, params, func(game: CardSpotGame) -> void: game.autoplay(0.9))
		_check_result(t, low, name + " low")
		_check_result(t, high, name + " high")
		var shut := not bool(params.get("atlas_open", false))
		var pinned := not (low.get("measures", {}).get("spots", []) as Array).is_empty()
		if shut and pinned:
			t.ok(int(low["quality_permille"]) < clear, name + " skill 0.2 skips the book: not clear")
		t.ok(int(high["quality_permille"]) >= clear, name + " skill 0.9 opens the book: clear")
	bus.queue_free()
	await t.frames(3)


func _check_result(t, result: Dictionary, label: String) -> void:
	var q = result.get("quality_permille")
	t.ok(typeof(q) == TYPE_INT and int(q) >= 0 and int(q) <= 1000, label + " quality")
	var measures: Dictionary = result.get("measures", {})
	t.eq(Lib.keys_of(measures), PackedStringArray(Lib.MEASURE_KEYS), label + " measure keys")
	t.ok(typeof(measures.get("ink_used")) == TYPE_INT, label + " ink_used int")
	t.ok(typeof(measures.get("atlas")) == TYPE_BOOL and typeof(measures.get("lens")) == TYPE_BOOL, label + " flags")
	var spots: Array = measures.get("spots", [])
	t.ok(spots.size() <= int(measures.get("ink_used", 0)), label + " spots <= ink used")
	t.eq(t.find_floats(result).size(), 0, label + " no floats")
	var flipped := 1 if bool(measures.get("atlas", false)) and not _was_open(label) else 0
	t.ok(int(result.get("minutes", -1)) == int(measures.get("ink_used", 0)) * 2 + flipped, label + " minutes")


## Old fixtures start with the book open (no minute for it).
func _was_open(label: String) -> bool:
	for name in Lib.old_fixture_names():
		if label.begins_with(name + " ") and name != "no_atlas":
			return true
	return false
