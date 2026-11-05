# C04 screenshots (not in the suite). One 1280x720 PNG per fixture, plus haggling and leave.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C04/shot_counter.gd -- --out=/tmp/shots/C04
extends SceneTree

const S = preload("res://scripts/tests/cards/C04/support.gd")

const STILLS: Array[String] = ["pawn", "sell", "buy", "redeem_by_rule", "redeem_sold", "choices", "after_look", "five_rounds"]
const UIDS := {
	"pawn": "c0002", "sell": "c0003", "buy": "c0004", "redeem_by_rule": "c0008", "redeem_sold": "c0009",
	"choices": "c0010", "after_look": "c0021", "five_rounds": "c0002", "counter_then_leave": "c0002",
}


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C04"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	for name in STILLS:
		var ctx: Dictionary = S.boot(self, name)
		await _frames(1)
		S.play(ctx, str(UIDS[name]))
		await _frames(3)
		await _save(out_dir, "C04_%s.png" % name)
		S.free_ctx(ctx)
		await _frames(2)
	var hag: Dictionary = S.boot(self, "pawn")
	await _frames(1)
	var panel: CardCounterPanel = S.play(hag, "c0002")
	await _frames(3)
	S.button(panel, "TierFair").pressed.emit()
	await _frames(2)
	await _save(out_dir, "C04_haggling.png")
	S.button(panel, "DeclineButton").pressed.emit()
	await _frames(2)
	await _save(out_dir, "C04_leave.png")
	S.free_ctx(hag)
	await _frames(1)
	quit(0)


func _save(dir_path: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := dir_path.path_join(file_name)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
