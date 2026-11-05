# 小镇界面测试的公共部分：实例化 Main、开一局小镇、等它回到可走动状态、收拾干净。
extends RefCounted

const Autoplayer = preload("res://scripts/tests/autoplayer.gd")
const TownGame = preload("res://scripts/town/town_game.gd")
const ShopOnly = preload("res://scripts/town/shop_only.gd")      # [shop-only]

var tree: SceneTree
var main
var town
var ap = null
var failures: int = 0
var shop_only: bool = false      # [shop-only] 默认关：老的界面测试要走到街上去；守铺的测试自己设成 true

func _init(p_tree: SceneTree) -> void:
	tree = p_tree

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func frames(n: int) -> void:
	for i in n:
		await tree.process_frame

func make_main():
	ShopOnly.set_override(1 if shop_only else 0)      # [shop-only]
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	main.autostart = false
	tree.root.add_child(main)
	await tree.process_frame
	main._ensure_town()
	town = main.town
	town.autosave = false
	town.save_path = TownGame.scratch_save_path("ui_test")      # 带进程号：并行跑也不抢同一个文件，更不碰玩家的存档
	return main

# 开新局（跳过序章，免得测试等太久）。auto：告示弹窗自动关；fast：快钟、瞬间淡入淡出。
func boot(p_seed: int = 7, fast: bool = false, with_autoplayer: bool = true) -> void:
	await make_main()
	town.set_fast(fast)
	town.auto_dismiss = true
	if with_autoplayer:
		town.director_ready.connect(_on_director)
	town.new_game(p_seed, "常年", true)
	await town.day_started
	await until_idle()

func _on_director(d) -> void:
	ap = Autoplayer.new(d, "town_fair", 1)
	ap.ui = main
	ap.tree = tree
	ap.step_delay = 0.0
	main.autoplayer = ap
	main.dialogue.instant = true

func until_idle(max_frames: int = 1800) -> bool:
	var n := 0
	while not town.is_idle_in_town() and n < max_frames:
		n += 1
		await tree.process_frame
	return town.is_idle_in_town()

func until(cond: Callable, max_frames: int = 1800) -> bool:
	var n := 0
	while not cond.call() and n < max_frames:
		n += 1
		await tree.process_frame
	return cond.call()

func shutdown() -> void:
	TownGame.remove_save_files(TownGame.scratch_save_path("ui_test"))
	if main != null and is_instance_valid(main):
		main.queue_free()
	await tree.process_frame
	await tree.process_frame
	DB.shutdown()
	var Cond = load("res://scripts/core/cond.gd")
	Cond.clear_cache()
