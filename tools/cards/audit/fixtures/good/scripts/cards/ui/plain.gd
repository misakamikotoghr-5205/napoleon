extends Node
# 注释里的中文不该被审核抓到
func alpha():
	var c := Color(1, 1, 1, 0.25)
	var w := Color.WHITE
	var t := Color.TRANSPARENT
	var s := "hello"

func legacy_after_return():
	if CardShip.is_ship():
		return
	var p := "res://audio/music/old.ogg"

func legacy_wrapped():
	if not CardShip.is_ship():
		var g := AudioStreamGenerator.new()
