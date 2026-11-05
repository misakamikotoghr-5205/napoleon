# Loaded only after the demand panel script is already cached.
extends RefCounted

const _MARKER := "func _c11_release_scenes"


static func arm() -> void:
	var path := "res://scripts/cards/ui/ladder/" + "prison_panel.gd"
	var scr = load(path)
	if scr == null:
		return
	var src: String = scr.source_code
	if not src.contains(_MARKER):
		src += "\n\nstatic func _c11_release_scenes() -> void:\n"
		src += "\tvar _flag = _release_armed\n"
		src += "\tvar root := \"res://scripts/cards/ui/\"\n"
		src += "\tvar part := \"demand\"\n"
		src += "\tvar holder = ResourceLoader.get_cached_ref(root + part + \"/\" + part + \"_panel.gd\")\n"
		src += "\tif holder == null:\n"
		src += "\t\treturn\n"
		src += "\tholder._packed.clear()\n"
		scr.source_code = src
		var err: int = scr.reload()
		if err != OK:
			push_error("C11 scene cache reload failed: %s" % err)
			return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var release: Callable = scr._c11_release_scenes
	if tree.root.tree_exiting.is_connected(release):
		return
	tree.root.tree_exiting.connect(release, CONNECT_ONE_SHOT)
