# G01 测试夹具：隔离数据根、纯核心上下文，不依赖其他任务的实现。
# 主人 G01；合同 §12.1–§12.2。
extends RefCounted

static func ctx(seed: int = 7, root: String = CardDB.DEFAULT_ROOT, examples: bool = true) -> CardCtx:
	var c := CardCtx.new()
	c.db = CardDB.load_all(root, {"only_examples": examples})
	c.state = CardState.create(seed, {"db_hash": c.db.hash()})
	c.conds = CardEngine.new().ctx.conds
	c.state.ns("loop").merge({"abs_day": 5, "stage_day": 5, "stage": 0, "phase": "day", "mode": "shop"})
	return c


static func write(path: String, data) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ", true, true))
	file.close()


static func copy_tree(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	for file in DirAccess.get_files_at(src):
		DirAccess.copy_absolute(src + "/" + file, dst + "/" + file)
	for sub in DirAccess.get_directories_at(src):
		copy_tree(src + "/" + sub, dst + "/" + sub)


## 删掉整个目录（测试把 text_ai 拿掉，只测人写层和兜底）
static func remove_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)


static func install(c: CardCtx) -> CardEngine:
	var e := CardEngine.new()
	e.ctx = c
	# 用新门面取得唯一登记表；不运行其他模块的桩，测试按需装自己替身。
	var holder := CardEngine.new()
	c.ops = holder.ctx.ops
	c.hooks = CardHooks.new()
	c.hooks.on(CardIds.HOOK_DAY_END, CardCoreInstall._on_day_end, 20, "G01")
	c.hooks.on(CardIds.HOOK_SETTLE, CardCoreInstall._on_settle, 20, "G01")
	return e


static func defs(c: CardCtx, uids: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for uid in uids:
		out.append(str(CardPiles.card(c, uid).get("def", "")))
	return out
