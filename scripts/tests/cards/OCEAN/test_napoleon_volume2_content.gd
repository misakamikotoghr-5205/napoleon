extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Book = preload("res://scripts/cards/campaign/run/run_book.gd")
const Maps = preload("res://scripts/cards/campaign/map/map_validate.gd")
const Rules = preload("res://scripts/cards/campaign/map/map_rules.gd")
const V1 := "res://data/campaigns/napoleon/book.json"
const V2 := "res://data/campaigns/napoleon/book_volume2.json"
var t: RefCounted


func _initialize() -> void:
	t = T.new(self, "OCEAN_napoleon_volume2_content")
	var first := Book.load_bundle(V1)
	var second := Book.load_bundle(V2)
	t.ok(first.get("ok", false) and second.get("ok", false), "both volume books load")
	if not first.get("ok", false) or not second.get("ok", false):
		t.finish()
		return
	var old: Dictionary = first["book"]
	var full: Dictionary = second["book"]
	t.eq(old["volume"], 1, "first-volume file retains its identity")
	t.eq(full["volume"], 2, "second-volume file opens authored later chapters")
	for book in [old, full]:
		var valid := Book.validate(book)
		t.eq(valid["errors"], [], "complete book validation for volume " + str(book["volume"]))
		t.eq(valid["warnings"], [], "no map layout/budget warnings for volume " + str(book["volume"]))
	t.eq(_active_chapters(old), 15, "volume one still stops at its authored endings")
	t.eq(_active_chapters(full), 23, "volume two opens all 23 authored chapters")
	for seg in ["trunk", "conquest", "cristo", "ocean"]:
		t.ok(str(full["raw"]["segments"][seg]["map"]).contains("/maps/volume2/"), "volume two owns its map snapshot: " + seg)
		for sheet in full["maps"][seg]["sheets"]:
			t.eq(sheet.get("templates_needed", []), [], "open chapter has no missing template promise: " + str(sheet["chapter"]))
			for node in sheet["nodes"]:
				t.ok(str(node["type"]) != "teaser", "authored node is playable: " + str(node["id"]))
	_theatres(full)
	_battle_pools(full)
	var paris := Rules.sheet_of(full, "cristo", "paris_1838")
	var noirtier := Rules.node_of(paris, "st_honore")
	t.eq(noirtier.get("event"), "ev_noirtier_eyes", "Valentine's rescue has a discoverable fixed visit")
	t.ok("visit:backdoor" in noirtier.get("actions", []), "Noirtier visit preserves the house's existing transaction")
	print("OCEAN Napoleon volume2 content assertions: %d" % t.checks)
	t.finish()


func _active_chapters(book: Dictionary) -> int:
	var count := 0
	for definition in book["defs"].values():
		for chapter in definition["chapters"]:
			if int(chapter.get("volume", 1)) <= int(book["volume"]):
				count += 1
	return count


func _theatres(book: Dictionary) -> void:
	for pair in [["trunk", "orient_alps"], ["trunk", "austerlitz_jena"], ["trunk", "iberia_danube"], ["conquest", "iberia_channel"]]:
		var definition: Dictionary = book["defs"][pair[0]]
		var sheet := Rules.sheet_of(book, pair[0], pair[1])
		var before := JSON.stringify(sheet)
		var routes := Maps.campaign_routes(sheet, definition)
		t.eq(routes.size(), 2, str(pair[1]) + " validates both mutually exclusive theatres")
		for route in routes:
			var graph: Dictionary = route["sheet"]
			var at := str(pair[1]) + str(route["suffix"])
			t.eq(Rules.node_list(graph, "boss").size(), 1, at + " has its selected boss")
			t.eq(Rules.node_list(graph, "muster").size(), 1, at + " has its selected muster")
			var errors: Array = []
			Maps._r5(graph, at, errors)
			t.eq(errors, [], at + " has a proper council and camp chain")
			var invalid: Dictionary = graph.duplicate(true)
			for node in invalid["nodes"]:
				if str(node.get("role", "")) == "council":
					node.erase("role")
			errors = []
			Maps._r5(invalid, at, errors)
			t.ok(not errors.is_empty(), at + " still rejects a missing council")
			invalid = graph.duplicate(true)
			var council := ""
			for node in invalid["nodes"]:
				if str(node.get("role", "")) == "council":
					council = str(node["id"])
			invalid["links"].append({"a": council, "b": Rules.node_list(graph, "boss")[0], "legs": 1})
			errors = []
			Maps._r5(invalid, at, errors)
			t.ok(not errors.is_empty(), at + " still rejects a camp bypass")
		var no_exclusivity: Dictionary = definition.duplicate(true)
		no_exclusivity["rules"]["exclusive_flags"] = []
		var undeclared := Maps.campaign_routes(sheet, no_exclusivity)
		t.eq(undeclared.size(), 1, str(pair[1]) + " does not invent undeclared mutually exclusive routes")
		var errors: Array = []
		Maps._r5(undeclared[0]["sheet"], pair[1], errors)
		t.ok(not errors.is_empty(), str(pair[1]) + " rejects duplicate councils without a declared choice")
		t.eq(JSON.stringify(sheet), before, "validation projection does not modify runtime map")


func _battle_pools(book: Dictionary) -> void:
	for seg in ["trunk", "conquest"]:
		var pool: Dictionary = book["raw"]["battle_pool"][seg]
		var first := 1 if seg == "trunk" else 12
		var last := 12 if seg == "trunk" else 23
		for level in range(first, last + 1):
			var matches := 0
			for band in pool:
				var lo := int(str(band).get_slice("-", 0))
				var hi := int(str(band).get_slice("-", 1))
				if level >= lo and level <= hi:
					matches += 1
			t.eq(matches, 1, "%s L%d has one deterministic encounter band" % [seg, level])
