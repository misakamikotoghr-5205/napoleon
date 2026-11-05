# 三关集成测试私有数据根：复制 W0 例子，仅补缺失年份扇区与签档兜底。
# G02；共享缺失数据 issue #49。不会修改 W0 例子或正式游戏数据。
extends RefCounted


static func build(destination: String) -> String:
	for directory in ["rules", "_examples", "tags", "ui_keys"]:
		_copy_tree("res://data/cards/" + directory, destination + "/" + directory)
	var source: Dictionary = CardDB.read_json("res://data/cards/_examples/fortune/segments_1938.json")
	var additions: Array = []
	for year in ["1939", "1940"]:
		for definition in source.get("cards", []):
			if not definition.get("era", []).has("1938"):
				continue
			var card: Dictionary = definition.duplicate(true)
			card["id"] = str(card["id"]).replace("1938", year)
			card["era"] = [year]
			card["brief"] = "TEST_SEGMENT"
			card["_provenance"] = {"by": "ai", "task": "G02", "date": "2026-10-13"}
			additions.append(card)
	for grade in [0, 2, 3, 4]:
		additions.append({"id": "lot.g%s.g02_test" % grade, "type": "fortune_lot", "era": ["*"],
			"weight": 10, "grade": grade, "hint_tags": [], "brief": "TEST_LOT",
			"_provenance": {"by": "ai", "task": "G02", "date": "2026-10-13"}})
	var file: FileAccess = FileAccess.open(destination + "/_examples/fortune/g02_completion.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"_meta": {"owner": "G02", "schema": 1}, "cards": additions}, "\t"))
	return destination


static func _copy_tree(source: String, destination: String) -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	var files: PackedStringArray = DirAccess.get_files_at(source)
	files.sort()
	for name in files:
		var input: FileAccess = FileAccess.open(source + "/" + name, FileAccess.READ)
		var output: FileAccess = FileAccess.open(destination + "/" + name, FileAccess.WRITE)
		output.store_buffer(input.get_buffer(input.get_length()))
	var directories: PackedStringArray = DirAccess.get_directories_at(source)
	directories.sort()
	for name in directories:
		_copy_tree(source + "/" + name, destination + "/" + name)
