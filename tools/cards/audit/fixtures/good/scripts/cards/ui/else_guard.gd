extends Node
# Placeholder audio in the else of CardShip.is_ship() is not reachable in a ship build.
func legacy_in_else():
	if CardShip.is_ship():
		var used := "human"
	else:
		var g := AudioStreamGenerator.new()
		var p := "res://audio/music/else.ogg"

func legacy_else_same_line():
	if CardShip.is_ship():
		var used := "human"
	else: var g2 := AudioStreamGenerator.new()


func legacy_else_after_comment():
	if CardShip.is_ship():
		var used := "human"
	# same-indent comment must not close the ship if
	else:
		var g3 := AudioStreamGenerator.new()
		var p3 := "res://audio/music/comment.ogg"


func legacy_after_early_return():
	if CardShip.is_ship():
		return
	var g4 := AudioStreamGenerator.new()
	var p4 := "res://audio/music/returned.ogg"


func legacy_in_not_ship():
	if not CardShip.is_ship():
		var g5 := AudioStreamGenerator.new()
		var p5 := "res://audio/music/notship.ogg"
