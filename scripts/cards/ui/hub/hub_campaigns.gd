## Read-only title model; the bridge resolves the default book and explicit legacy selection.
extends RefCounted

const Bridge = preload("res://scripts/cards/campaign/ocean_bridge.gd")
const Book = preload("res://scripts/cards/campaign/run/run_book.gd")
const BranchStart = preload("res://scripts/cards/campaign/run/run_branch_start.gd")
const Data = preload("res://scripts/cards/ui/hub/hub_data.gd")


static func model(opts: Dictionary, dir: String) -> Dictionary:
	var info := Bridge.title_info(dir)
	var resolved := Bridge.game_opts(opts)
	var path := str(resolved.get("book", ""))
	var explicit_book := not path.is_empty()
	var browse_path := path if explicit_book else Book.NAPOLEON
	var read := Book.read_json(browse_path)
	var raw: Dictionary = read.get("data", {}) if typeof(read.get("data")) == TYPE_DICTIONARY else {}
	var loaded := Book.load_bundle(browse_path)
	var bundle: Dictionary = loaded.get("book", {})
	var available := bool(resolved.get("ok", false)) and (not explicit_book or bool(loaded.get("ok", false)))
	var meta: Dictionary = info.get("meta", {})
	var debug := explicit_book and path not in Bridge.BOOKS.values()
	var selected := {}
	if explicit_book:
		selected = {"campaign": "napoleon", "book": path,
			"segment": str(resolved.get("game", {}).get("segment", raw.get("start", "trunk"))),
			"stage": resolved.get("game", {}).get("stage", 0)}
	var rows: Array = []
	for seg in raw.get("segments", {}):
		var spec: Dictionary = raw["segments"][seg]
		var chapters: Array = bundle.get("defs", {}).get(seg, {}).get("chapters", [])
		var unlocked: bool = str(spec.get("kind", "")) == "trunk" or debug or not meta.get("endings", {}).get(seg, []).is_empty() or not meta.get("volumes", {}).get(seg, []).is_empty()
		var count := chapters.size() if debug else mini(1, chapters.size())
		for stage in maxi(1, count):
			var chapter: Dictionary = chapters[stage] if stage < chapters.size() else {}
			var reason := ""
			if not bool(loaded.get("ok", false)):
				reason = Data.text("campaign_title.unavailable")
			elif not unlocked:
				reason = Data.text("campaign_title.locked")
			elif int(chapter.get("volume", 1)) > int(raw.get("volume", 1)):
				reason = str(raw.get("chapter_locked_message", Data.text("campaign_title.next_volume")))
			rows.append({"segment": str(seg), "stage": stage, "title": Data.text("campaign_title.chapter", {
				"brand": str(spec.get("brand", seg)), "chapter": str(chapter.get("title", Data.text("campaign_title.first_chapter")))}),
				"enabled": reason.is_empty(), "reason": reason,
				"options": {"campaign": "napoleon", "book": browse_path, "segment": str(seg), "stage": stage}})
	var branch_unlocked: bool = bool(meta.get("trunk_cleared", false)) or not meta.get("branches_reached", []).is_empty() or bool(info.get("branch", false))
	rows.append({"segment": "branch_point", "stage": -1, "title": Data.text("campaign_title.branch_point"),
		"enabled": branch_unlocked and not BranchStart.locate(bundle).is_empty(),
		"reason": "" if branch_unlocked and not BranchStart.locate(bundle).is_empty() else Data.text("campaign_title.branch_locked"),
		"options": {"campaign": "napoleon", "book": browse_path, "entry": "branch_point"}, "reseed": true})
	rows.append({"segment": "branch_resume", "stage": -1, "title": Data.text("campaign_title.branch_resume"),
		"enabled": branch_unlocked and bool(info.get("branch", false)),
		"reason": "" if branch_unlocked and bool(info.get("branch", false)) else Data.text("campaign_title.branch_missing"), "action": "branch"})
	var has_unlock: bool = branch_unlocked
	for key in ["endings", "volumes"]:
		for values in meta.get(key, {}).values():
			has_unlock = has_unlock or not values.is_empty()
	return {"explicit": explicit_book, "debug": debug, "raw": raw, "bundle": bundle, "info": info,
		"available": available, "reason": "" if available else Data.text("campaign_title.unavailable"),
		"selected": selected, "choices": rows, "show_chapters": explicit_book or has_unlock}


static func collection(model_data: Dictionary, seg: String) -> Dictionary:
	var meta: Dictionary = model_data.get("info", {}).get("meta", {})
	var got := {}
	for key in ["endings", "volumes"]:
		for id in meta.get(key, {}).get(seg, []):
			got[str(id)] = true
	var def: Dictionary = model_data.get("bundle", {}).get("defs", {}).get(seg, {})
	var all := {}
	var available = model_data.get("raw", {}).get("segments", {}).get(seg, {}).get("collection_endings")
	if typeof(available) == TYPE_ARRAY:
		for id in available:
			all[str(id)] = true
		var obtained := 0
		for id in got:
			if all.has(id):
				obtained += 1
		return {"visited": str(seg) in meta.get("branches_reached", []), "n": obtained, "total": all.size()}
	for row in def.get("endings", []):
		if typeof(row) == TYPE_DICTIONARY:
			all[str(row.get("id", ""))] = true
	for row in def.get("rules", {}).get("volume_endings", []):
		all[str(row.get("id", ""))] = true
	var default_ending := str(def.get("rules", {}).get("default_volume_ending", ""))
	if not default_ending.is_empty():
		all[default_ending] = true
	return {"visited": str(seg) in meta.get("branches_reached", []), "n": got.size(), "total": all.size()}
