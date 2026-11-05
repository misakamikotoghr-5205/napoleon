# Observation keys are all in the catalog and carry no verdict words; results have only the five fields;
# the source never quotes verdict keys or uses free randomness.
# Catalog (DESIGN 3.2, 4.10): per part differs / wear are clear and hedge to <x>_maybe (partial) and
# unclear (vague); plain stays (clear, no longer sent); nothing_found is kept at every clarity. Every
# hedge target is in the catalog with the clarity it stands for.
# Owner C12. Contract: docs/cards/CARDS_INTERFACES.md 4.8, 8.2.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")

const BANNED: Array[String] = ["tell", "fake", "benign", "est", "real", "genuine", "authentic", "forged",
	"true", "false", "stolen", "origin", "market", "value", "true_value", "floor", "fake_text", "real_text",
	"verdict", "rare", "grade", "quality"]


func _initialize() -> void:
	var t := T.new(self, "C12_no_verdict")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	t.ok(mock.db != null, "text db")
	await t.frames(1)
	var cat: Dictionary = CardDB.read_json("res://data/cards/minigames/obs/spot.json").get("obs", {})
	_catalog(t, cat)
	for name in Lib.fixture_names():
		var params: Dictionary = Lib.fixture(name)
		for skill in [0.0, 0.2, 0.9]:
			var result: Dictionary = Lib.run(self, params, func(game: CardSpotGame) -> void: game.autoplay(skill))
			_result_ok(t, result, cat, "%s skill %.1f" % [name, skill])
	_scan(t)
	bus.queue_free()
	await t.frames(3)


func _catalog(t, cat: Dictionary) -> void:
	var want := {"differs": "clear", "wear": "clear", "plain": "clear", "unclear": "vague", "differs_maybe": "partial",
		"wear_maybe": "partial"}
	for pid in Lib.part_ids():
		for suffix in want.keys():
			var key := "obs.spot.%s.%s" % [pid, suffix]
			t.ok(cat.has(key), "catalog has " + key)
			if cat.has(key):
				t.eq(str(cat[key].get("fidelity", "")), str(want[suffix]), key + " fidelity")
		for said in ["differs", "wear"]:
			var key2 := "obs.spot.%s.%s" % [pid, said]
			var hedge: Dictionary = cat.get(key2, {}).get("hedge", {})
			t.eq(str(hedge.get("partial", "")), "obs.spot.%s.%s_maybe" % [pid, said], key2 + " hedge partial")
			t.eq(str(hedge.get("vague", "")), "obs.spot.%s.unclear" % pid, key2 + " hedge vague")
	t.ok(cat.has("obs.spot.nothing_found"), "catalog has nothing_found")
	var nf: Dictionary = cat.get("obs.spot.nothing_found", {})
	var kept_any := str(nf.get("fidelity", "")) == "any" or (str(nf.get("hedge", {}).get("partial", "")) ==
		"obs.spot.nothing_found" and str(nf.get("hedge", {}).get("vague", "")) == "obs.spot.nothing_found")
	t.ok(kept_any, "nothing_found is kept at every clarity")
	for key in cat.keys():
		_no_verdict(t, str(key))
		var hedge2 = cat[key].get("hedge", {})
		if typeof(hedge2) != TYPE_DICTIONARY:
			continue
		for level in (hedge2 as Dictionary).keys():
			var to := str(hedge2[level])
			t.ok(to == "" or cat.has(to), "%s hedge %s -> %s exists" % [key, level, to])
			if cat.has(to) and to != str(key):
				t.eq(str(cat[to].get("fidelity", "")), str(level), "%s hedge %s has that clarity" % [key, level])


func _result_ok(t, result: Dictionary, cat: Dictionary, label: String) -> void:
	t.eq(Lib.keys_of(result), PackedStringArray(Lib.RESULT_KEYS), label + " result keys")
	t.eq(bool(result.get("aborted", true)), false, label + " not aborted")
	for key in result.get("observations", []):
		t.ok(cat.has(str(key)), label + " known " + str(key))
		_no_verdict(t, str(key))
		t.ok(not str(key).ends_with(".plain"), label + " plain is no longer sent")


func _no_verdict(t, key: String) -> void:
	var parts := key.split(".")
	for w in CardIds.VERDICT_WORDS:
		t.ok(not parts.has(w), key + " segment " + w)
		t.ok(not key.contains("_" + w) and not key.contains(w + "_"), key + " word " + w)


## Files that draw random numbers use the layout domain (DESIGN P8); none quotes a verdict key or uses
## free randomness. (Was: every file names the domain; the drawing-only files draw nothing.)
func _scan(t) -> void:
	var dir := "res://scripts/cards/minigames/spot"
	for file_name in DirAccess.get_files_at(dir):
		if not str(file_name).ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(dir + "/" + str(file_name))
		for w in BANNED:
			t.ok(not text.contains("\"%s\"" % w), str(file_name) + " quotes " + w)
			t.ok(not text.contains("'%s'" % w), str(file_name) + " quotes " + w)
		t.ok(not text.contains("randf(") and not text.contains("randi("), str(file_name) + " no rand")
		t.ok(not text.contains("randomize("), str(file_name) + " no randomize")
		t.ok(not text.contains("RandomNumberGenerator"), str(file_name) + " no RNG class")
		if text.contains("Rng.draw("):
			t.ok(text.contains("c.mg.spot.layout"), str(file_name) + " uses layout domain")
