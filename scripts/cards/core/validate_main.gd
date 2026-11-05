# 数据校验的命令行：
#   $GODOT --headless --path . -s res://scripts/cards/core/validate_main.gd -- [--mode=default|strict|ship]
#       [--variant=ai-disclosure|no-disclosure] [--no-ai]
#       [--root=res://data/cards] [--examples] [--only=<路径或 glob，逗号分隔>] [--name=<测试名>]
#       [--packs=<剧情插件目录，逗号分隔；默认真数据查 res://packs>] [--no-packs] [--enable-pack=<id,…>]
# 每个问题一行 "DATA ERROR: …"（会让测试失败）或 "NOTE: …"；然后 "CARDS VALID <牌数> cards, <错误数> errors"；
# 没有错误时最后一行 "CARDS TEST PASS <名字>"，有错误退出码 1。主人 G01；W0 写好。合同：§4.9、§12.1。
extends SceneTree


func _initialize() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var mode := StringName(str(args.get("mode", "default")))
	var root := str(args.get("root", CardDB.DEFAULT_ROOT))
	var only := PackedStringArray()
	if args.has("only"):
		for p in str(args["only"]).split(",", false):
			only.append(p.strip_edges())
	var name := str(args.get("name", "validate"))
	if not mode in [&"default", &"strict", &"ship"]:
		print("DATA ERROR: -: -: V00 unknown --mode=%s" % mode)
		quit(1)
		return
	var raw_variant := str(args.get("variant", "")).strip_edges().to_lower().replace("_", "-")
	if args.has("no-ai") or args.has("no-disclosure") or args.has("human-only"):
		raw_variant = "no-disclosure"
	elif raw_variant == "" and (args.has("ai-disclosure") or args.has("with-ai")):
		raw_variant = "ai-disclosure"
	elif raw_variant == "":
		raw_variant = "no-disclosure" if OS.has_feature("no_ai") else "ai-disclosure"
	var variant := ""
	if raw_variant in ["ai", "ai-disclosure", "with-ai", "disclosure"]:
		variant = "ai-disclosure"
	elif raw_variant in ["no-ai", "no-disclosure", "human-only", "human"]:
		variant = "no-disclosure"
	else:
		print("DATA ERROR: -: -: V00 unknown --variant=%s" % raw_variant)
		quit(1)
		return
	var opts := {"examples": args.has("examples"), "only": only, "variant": variant}
	if args.has("no-packs"):
		opts["packs"] = PackedStringArray()
	elif args.has("packs"):
		opts["packs"] = PackedStringArray(str(args["packs"]).split(",", false))
	if args.has("enable-pack"):
		opts["enable_packs"] = PackedStringArray(str(args["enable-pack"]).split(",", false))
	var res := CardValidator.validate(root, mode, opts)
	for n in res["notes"]:
		print("NOTE: " + n)
	for e in res["errors"]:
		print("DATA ERROR: " + e)
	print("CARDS VALID %d cards, %d errors" % [res["cards"], (res["errors"] as PackedStringArray).size()])
	if (res["errors"] as PackedStringArray).is_empty():
		print("CARDS TEST PASS " + name)
		quit(0)
	else:
		quit(1)
