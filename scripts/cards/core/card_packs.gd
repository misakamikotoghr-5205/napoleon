# 剧情插件（story pack）读取：packs/<id>/pack.json 清单 + packs/<id>/text/**（路径、键与 data/cards/text/** 一一镜像）。
# CardDB 用它把插件读成独立的正文层（不与人写层、AI 层合并），CardValidator 复用清单检查。
# 坏插件只记进 warnings、整包（清单坏）或整文件 / 整条（正文坏）跳过，从不进 CardDB.errors()，所以不会挡住新局。
# 只带正文的插件不改 CardDB.hash()（哈希只算机制数据），存档照用。cards/ 与 art/ 增量只登记字段，暂不读取。
# 框架版收尾默认（2026-10-22，Claude），主创可改。说明 docs/cards/PLUGINS.md；合同 docs/cards/CARDS_INTERFACES.md §4.5。
extends RefCounted

## 插件格式版本：清单的 compat 必须是这个
const FORMAT := "cards-text/1"
const RES_DIR := "res://packs"
const USER_DIR := "user://packs"
const MANIFEST := "pack.json"
const DEFAULT_ORDER := 100
const ID_RE := "^[a-z0-9_]+$"
const HUMAN_RE := "^human:(A|B):\\d{4}-\\d{2}-\\d{2}$"
const AI_RE := "^ai:[^:]+:[^:]+:[0-9]{4}-[0-9]{2}-[0-9]{2}:.+$"
const SOURCES: Array[String] = ["human", "ai"]
## 清单里认识的键（_ 开头的注释键另外放行）
const MANIFEST_KEYS: Array[String] = ["id", "name", "version", "order", "source", "enabled", "compat",
	"base_db_hash", "description", "authors", "requires", "cards", "art"]

static var _mounted: Dictionary = {}    # 已挂载的 .pck 绝对路径 → 是否成功（进程内只挂一次）


## 解析出一套读取设置：{dirs, pck_dirs, enable, disable, no_ai}。
## 真数据（DEFAULT_ROOT、不是例子集）默认读 res://packs、user://packs，并先挂载 user://packs/*.pck
## 与（导出包里）exe 旁边 packs/*.pck；别的数据根默认不读插件，测试要显式给 opts.packs。
## 命令行（-- 之后）：--no-packs、--enable-pack=<id,…>、--disable-pack=<id,…>。
static func resolve(root: String, examples: bool, opts: Dictionary, default_root: String) -> Dictionary:
	var cli := cmdline()
	var out := {"dirs": PackedStringArray(), "pck_dirs": PackedStringArray(),
		"enable": PackedStringArray(_strings(opts.get("enable_packs", []))),
		"disable": PackedStringArray(_strings(opts.get("disable_packs", []))),
		"no_ai": bool(opts.get("no_ai", OS.has_feature("no_ai")))}
	(out["enable"] as PackedStringArray).append_array(cli["enable"])
	(out["disable"] as PackedStringArray).append_array(cli["disable"])
	if bool(opts.get("no_packs", false)) or bool(cli["no_packs"]):
		return out
	if opts.has("packs"):
		out["dirs"] = PackedStringArray(_strings(opts["packs"]))
		out["pck_dirs"] = PackedStringArray(_strings(opts.get("pck_dirs", [])))
	elif root == default_root and not examples:
		out["dirs"] = PackedStringArray([RES_DIR, USER_DIR])
		var pck_dirs := PackedStringArray([USER_DIR])
		if OS.has_feature("template"):
			pck_dirs.append(OS.get_executable_path().get_base_dir().path_join("packs"))
		out["pck_dirs"] = PackedStringArray(_strings(opts.get("pck_dirs", pck_dirs)))
	return out


static func cmdline() -> Dictionary:
	var out := {"no_packs": false, "enable": PackedStringArray(), "disable": PackedStringArray()}
	for a in OS.get_cmdline_user_args():
		if a == "--no-packs":
			out["no_packs"] = true
		elif a.begins_with("--enable-pack="):
			(out["enable"] as PackedStringArray).append_array(a.substr(14).split(",", false))
		elif a.begins_with("--disable-pack="):
			(out["disable"] as PackedStringArray).append_array(a.substr(15).split(",", false))
	return out


## 把 .pck 挂进 res://（不覆盖已有文件）。.pck 里应只放 packs/<id>/**，挂上后就是 res://packs/<id>/。
static func mount_pcks(pck_dirs: PackedStringArray, warnings: PackedStringArray) -> void:
	for dir in pck_dirs:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for f in files:
			if not f.ends_with(".pck"):
				continue
			var path := ProjectSettings.globalize_path(dir.path_join(f))
			if _mounted.has(path):
				continue
			_mounted[path] = ProjectSettings.load_resource_pack(path, false)
			if not bool(_mounted[path]):
				warnings.append("%s: story pack archive cannot be mounted; skipped" % path)


## 清单的问题（空 = 合格）。folder 是插件所在文件夹名（id 必须与它相同）。
static func manifest_problems(m: Dictionary, folder: String) -> PackedStringArray:
	var out := PackedStringArray()
	for k in m.keys():
		if not (str(k) in MANIFEST_KEYS or str(k).begins_with("_")):
			out.append("unknown manifest key '%s'" % k)
	var id = m.get("id")
	if typeof(id) != TYPE_STRING or RegEx.create_from_string(ID_RE).search(str(id)) == null:
		out.append("id must be [a-z0-9_]+")
	elif str(id) != folder:
		out.append("id '%s' must equal its folder name '%s'" % [id, folder])
	for k in ["name", "version"]:
		if typeof(m.get(k)) != TYPE_STRING or str(m.get(k)).strip_edges() == "":
			out.append("%s must be a non-empty string" % k)
	if m.has("order") and typeof(m["order"]) != TYPE_INT:
		out.append("order must be an integer")
	if m.has("enabled") and typeof(m["enabled"]) != TYPE_BOOL:
		out.append("enabled must be true or false")
	var source = m.get("source")
	if typeof(source) != TYPE_STRING or not str(source) in SOURCES:
		out.append("source must be human or ai")
	else:
		var prov = m.get("_provenance")
		if typeof(prov) != TYPE_STRING or RegEx.create_from_string(prov_re(str(source))).search(str(prov)) == null:
			out.append("_provenance must match %s" % ("human:(A|B):YYYY-MM-DD" if source == "human"
				else "ai:<tool>:<model>:YYYY-MM-DD:<id>"))
	if m.has("compat") and str(m["compat"]) != FORMAT:
		out.append("compat '%s' is not supported (this build reads %s)" % [m["compat"], FORMAT])
	for k in ["base_db_hash", "description"]:
		if m.has(k) and typeof(m[k]) != TYPE_STRING:
			out.append("%s must be a string" % k)
	for k in ["authors", "requires", "cards"]:
		if m.has(k) and (typeof(m[k]) != TYPE_ARRAY or not _all_strings(m[k])):
			out.append("%s must be an array of strings" % k)
	if m.has("art") and typeof(m["art"]) != TYPE_STRING:
		out.append("art must be a string path")
	return out


static func prov_re(source: String) -> String:
	return HUMAN_RE if source == "human" else AI_RE


## 读出所有插件。known: Callable(key: String) -> bool，判断正文键在骨架里有没有。
## 返回 {loaded: Array（按 order、id 升序；查字时从后往前）, info: Array（每个找到的插件一行）, files: PackedStringArray}
static func load_packs(cfg: Dictionary, known: Callable, warnings: PackedStringArray) -> Dictionary:
	mount_pcks(cfg.get("pck_dirs", PackedStringArray()), warnings)
	var enable: PackedStringArray = cfg.get("enable", PackedStringArray())
	var disable: PackedStringArray = cfg.get("disable", PackedStringArray())
	var found: Dictionary = {}
	var info: Array = []
	var files := PackedStringArray()
	for dir in cfg.get("dirs", PackedStringArray()):
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var folders := DirAccess.get_directories_at(dir)
		folders.sort()
		for folder in folders:
			var base := str(dir).path_join(folder)
			var mpath := base.path_join(MANIFEST)
			if not FileAccess.file_exists(mpath):
				continue
			files.append(mpath)
			var row := {"id": folder, "dir": base, "state": "skipped", "reason": ""}
			info.append(row)
			var m = CardDB.read_json(mpath)
			if typeof(m) != TYPE_DICTIONARY:
				row["reason"] = "pack.json cannot be parsed"
				warnings.append("%s: %s; pack skipped" % [mpath, row["reason"]])
				continue
			var problems := manifest_problems(m, folder)
			if not problems.is_empty():
				row["reason"] = "; ".join(problems)
				warnings.append("%s: %s; pack skipped" % [mpath, row["reason"]])
				continue
			row.merge({"name": str(m["name"]), "version": str(m["version"]), "order": int(m.get("order", DEFAULT_ORDER)),
				"source": str(m["source"]), "provenance": str(m["_provenance"]), "enabled": bool(m.get("enabled", true)),
				"requires": PackedStringArray(m.get("requires", [])), "base_db_hash": str(m.get("base_db_hash", ""))}, true)
			if found.has(folder):
				row["reason"] = "duplicate pack id (already read from %s)" % found[folder]["dir"]
				warnings.append("%s: %s; pack skipped" % [mpath, row["reason"]])
				continue
			if not m.has("compat"):
				warnings.append("%s: compat missing; read as %s" % [mpath, FORMAT])
			if disable.has(folder) or (not bool(row["enabled"]) and not enable.has(folder)):
				row["state"] = "disabled"
				continue
			if str(row["source"]) == "ai" and bool(cfg.get("no_ai", false)):
				row["reason"] = "AI pack in a no-AI build"
				warnings.append("%s: %s; pack skipped" % [mpath, row["reason"]])
				continue
			if not (m.get("cards", []) as Array).is_empty() or str(m.get("art", "")) != "":
				warnings.append("%s: cards/art deltas are not loaded yet; only text is used" % mpath)
			row["text"] = _read_text(base, str(row["source"]), known, warnings, files)
			row["state"] = "loaded"
			found[folder] = row
	# requires：要的插件没载入，这个也不载（反复去掉直到稳定）
	var changed := true
	while changed:
		changed = false
		for id in found.keys():
			for need in found[id]["requires"]:
				if not found.has(need):
					found[id]["state"] = "skipped"
					found[id]["reason"] = "requires pack '%s' which is not loaded" % need
					warnings.append("%s: %s; pack skipped" % [found[id]["dir"], found[id]["reason"]])
					found.erase(id)
					changed = true
					break
	var loaded: Array = found.values()
	loaded.sort_custom(_before)
	for row in info:
		if row["state"] != "loaded":
			row.erase("text")
	return {"loaded": loaded, "info": info, "files": files}


## 叠放顺序：order 小的在下，同 order 按 id；后面的覆盖前面的
static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["order"]) != int(b["order"]):
		return int(a["order"]) < int(b["order"])
	return str(a["id"]) < str(b["id"])


static func _read_text(base: String, source: String, known: Callable, warnings: PackedStringArray,
		files: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var re := RegEx.create_from_string(prov_re(source))
	for path in CardDB.list_json_recursive(base.path_join("text")):
		files.append(path)
		var doc = CardDB.read_json(path)
		if typeof(doc) != TYPE_DICTIONARY:
			warnings.append("%s: pack text cannot be parsed; file skipped" % path)
			continue
		var meta = doc.get("_meta", {})
		if typeof(meta) == TYPE_DICTIONARY and meta.has("_provenance") \
				and (typeof(meta["_provenance"]) != TYPE_STRING or re.search(str(meta["_provenance"])) == null):
			warnings.append("%s: _meta._provenance does not match the pack source (%s); file skipped" % [path, source])
			continue
		var keys: Array = doc.keys()
		keys.sort()
		for key in keys:
			var k := str(key)
			if k.begins_with("_"):
				continue
			var e = doc[key]
			if typeof(e) != TYPE_DICTIONARY:
				warnings.append("%s: entry %s is not an object; skipped" % [path, k])
				continue
			if e.has("_provenance") and (typeof(e["_provenance"]) != TYPE_STRING or re.search(str(e["_provenance"])) == null):
				warnings.append("%s: entry %s _provenance does not match the pack source; skipped" % [path, k])
				continue
			if known.is_valid() and not bool(known.call(k)):
				warnings.append("%s: unknown text key %s; skipped" % [path, k])
				continue
			if out.has(k):
				warnings.append("%s: duplicate text key %s in this pack; first one kept" % [path, k])
				continue
			out[k] = (e as Dictionary).duplicate(true)
	return out


static func _strings(v) -> Array:
	var out: Array = []
	if typeof(v) in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY]:
		for x in v:
			out.append(str(x))
	return out


static func _all_strings(v) -> bool:
	for x in v:
		if typeof(x) != TYPE_STRING:
			return false
	return true
