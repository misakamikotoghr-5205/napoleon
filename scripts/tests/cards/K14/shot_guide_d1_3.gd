# One real 1280x720 viewport PNG per tutorial checkpoint of the FORMAL new-save 1938 guide
# (shipped data/cards, mock:false); no fake headless images. Files are NN_<step>.png in walk order.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/K14/shot_guide_d1_3.gd -- --out=<dir>
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Walk = preload("res://scripts/tests/cards/K14/real_guide_walk.gd")
const U = preload("res://scripts/tests/cards/K14/qa_util.gd")

func _initialize() -> void:
	var t := T.new(self, "K14_shot_guide_d1_3")
	t.run_async(_run.bind(t))

func _run(t) -> void:
	root.size = Vector2i(1280, 720)
	var out := U.arg("out", "user://shots/K14_guide")
	if out.begins_with("res://") or out.begins_with("user://"):
		out = ProjectSettings.globalize_path(out)
	var headless := DisplayServer.get_name() == "headless"
	if headless:
		print("NOTE: headless display; running real three-day guide checks, viewport screenshots unavailable (no PNGs written)")
	else:
		t.eq(DirAccess.make_dir_recursive_absolute(out), OK, "create screenshot directory")
	var result: Dictionary = await Walk.new(Walk.FORMAL).play(t, self, {"mock": false, "guide": "on",
		"save_dir": t.user_dir().path_join("capture")}, out)
	if result.is_empty():
		return # play() records the real-engine failure.
	var want := Walk.expected_formal()
	t.ok(not want.is_empty(), "nonempty screenshot contract")
	t.eq(result["log"], want, "screenshots walk all formal tutorial steps in order")
	for step in want:
		t.eq(str(result["progress"].get(step, {}).get("status", "")), "done", "real guide done " + str(step))
		if not headless:
			t.ok(result["shots"].has(step), "viewport screenshot captured " + str(step))
	if not headless:
		t.eq(result["shots"].size(), want.size(), "one actual screenshot per guide step")
